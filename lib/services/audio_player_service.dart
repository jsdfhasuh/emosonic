import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../data/models/models.dart';
import '../data/services/subsonic/subsonic_api_client.dart';
import '../core/utils/logger.dart';
import '../core/cache/audio_cache_manager.dart';
import 'media_service.dart';
import 'media_service_factory.dart';

class AudioPlayerService {
  AudioPlayer _player = AudioPlayer();
  final SubsonicApiClient _apiClient;
  final Logger _logger = Logger('AudioPlayerService');
  late MediaService _mediaService;
  final Dio _dio = Dio();

  final List<Song> _queue = [];
  int _currentIndex = -1;
  StreamSubscription? _positionSubscription;
  
  // Stream controller for queue changes
  final _queueChangeController = StreamController<void>.broadcast();
  Stream<void> get queueChangeStream => _queueChangeController.stream;

  // Lock to prevent concurrent playSong calls
  final _playLock = Lock();

  // Track currently playing song ID to prevent duplicate playback
  String? _currentlyPlayingSongId;

  // Callback for song changes - used to sync UI state
  Function(Song?)? onSongChanged;
  
  // Callback for playing state changes - used to sync UI state
  Function(bool)? onPlayingStateChanged;

  // Track if player needs to be recreated (Android only)
  bool _needsPlayerRecreation = false;

  // Debounce mechanism for playback completion to prevent multiple triggers
  DateTime? _lastCompletionTime;

  // Flag to prevent auto-advance during manual song switching
  bool _isSwitchingSong = false;

  // Call ID for tracking playQueue operations (to handle async completion)
  int _playQueueCallId = 0;
  int _lastPlayQueueCallId = 0;

  // Flag to track completion state across the service
  bool _hasTriggeredCompletion = false;

  AudioPlayerService(this._apiClient) {
    _logger.info('AudioPlayerService initialized');
    _mediaService = MediaServiceFactory.getService(_player);
    _initializeAudioSession();
    _initializeMediaService();
    _setupPositionListener();
  }

  Future<void> _initializeAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _logger.info('Audio session configured');
  }

  void _initializeMediaService() {
    _mediaService.initialize().then((_) {
      _mediaService.setMediaButtonListener(
        onPlay: () async {
          _logger.debug('Media: Play button pressed');
          await play();
        },
        onPause: () async {
          _logger.debug('Media: Pause button pressed');
          await pause();
        },
        onNext: () async {
          _logger.debug('Media: Next button pressed');
          await playNext();
        },
        onPrevious: () async {
          _logger.debug('Media: Previous button pressed');
          await playPrevious();
        },
        onStop: () async {
          _logger.debug('Media: Stop button pressed');
          await stop();
        },
      );
    });
  }



  void _setupPositionListener() {
    DateTime? _lastSeekTime;

    _positionSubscription = _player.positionStream.listen((position) {
      final duration = _player.duration;
      if (duration != null) {
        _mediaService.setPlaybackState(
          isPlaying: _player.playing,
          position: position,
          bufferedPosition: _player.bufferedPosition,
          duration: duration,
        );

        // Check if playback is near completion (backup detection for seek issue)
        final remaining = duration - position;
        if (remaining.inMilliseconds < 500 &&
            remaining.inMilliseconds > 0 &&
            _player.playing &&
            !_hasTriggeredCompletion) {
          // Check if we recently seeked (avoid triggering immediately after seek)
          if (_lastSeekTime == null ||
              DateTime.now().difference(_lastSeekTime!).inSeconds > 1) {
            _logger.info(
                'Playback near completion detected via position (remaining: ${remaining.inMilliseconds}ms)');
            _hasTriggeredCompletion = true;
            _onPlaybackComplete();
          }
        }

        // Reset completion flag when position moves away from end
        if (remaining.inMilliseconds > 1000) {
          _hasTriggeredCompletion = false;
        }
      }
    });

    // Listen for playback completion
    _player.playerStateStream.listen((state) {
      _logger.debug('Player state changed: processingState=${state.processingState}, playing=${state.playing}');
      if (state.processingState == ProcessingState.completed) {
        _logger.debug('Song playback completed via playerState, currentIndex=$_currentIndex, currentSong=${_queue.isNotEmpty && _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex].title : "none"}');
        if (!_hasTriggeredCompletion) {
          _hasTriggeredCompletion = true;
          _onPlaybackComplete();
        } else {
          _logger.debug('Completion already handled, skipping duplicate');
        }
      }
    });

    // Listen for seek events to track when user seeks
    _player.positionStream.listen((position) {
      // This is a workaround to detect seek - we'll compare with expected position
    });



    // Listen for playing state changes
    _player.playingStream.listen((isPlaying) {
      _logger.info('Player playing state changed: $isPlaying');
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(isPlaying);
      }
    });
  }

  // Call this when seek is performed
  void onSeekPerformed() {
    _logger.info('Seek performed, resetting completion detection');
  }

  Future<void> _onPlaybackComplete() async {
    // Check if manual song switch is in progress
    if (_isSwitchingSong) {
      _logger.debug('Skipping auto-advance: manual song switch in progress');
      return;
    }

    // Debounce: prevent multiple triggers within 2 seconds
    final now = DateTime.now();
    if (_lastCompletionTime != null &&
        now.difference(_lastCompletionTime!).inMilliseconds < 2000) {
      _logger.debug('Playback completion debounced (within 2 seconds)');
      return;
    }
    _lastCompletionTime = now;

    _logger.info('Playback completed, checking for next song, currentIndex: $_currentIndex');
    _logger.info('BEFORE auto-advance: position=${_player.position}, duration=${_player.duration}, playing=${_player.playing}');
    
    // Submit completed scrobble for current song
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      final completedSong = _queue[_currentIndex];
      _logger.info('Submitting completed scrobble for: ${completedSong.title}');
      await _submitScrobble(completedSong.id, submission: true);
    }
    
    if (_currentIndex < _queue.length - 1) {
      _logger.info('Playing next song in queue (auto-advance)');
      _currentIndex++;
      _logger.info('Auto-advance: moved to index $_currentIndex');

      final currentSong = _queue[_currentIndex];
      _logger.info('Auto-advance target: ${currentSong.title}');

      if (Platform.isWindows) {
        // Windows: Use setAudioSource for reliable switching
        _logger.info('Windows auto-advance: Using setAudioSource');
        await _playSongWithSetAudioSource(currentSong);
      } else {
        // Android: Use seekToNext for ConcatenatingAudioSource
        await _player.seekToNext();
        
        // Update currently playing song ID
        _currentlyPlayingSongId = currentSong.id;

        // Update UI state
        if (onSongChanged != null) {
          onSongChanged!(currentSong);
        }

        // Update media metadata
        _updateMediaMetadataForCurrentSong();
      }

      // Pre-cache more songs after switching
      _preCacheNextSongsAsync(3);
      
      _logger.info('Auto-advance completed: final position=${_player.position}');
    } else {
      _logger.info('End of queue reached');
      _currentlyPlayingSongId = null;
    }
  }

  /// Update media metadata for current song
  Future<void> _updateMediaMetadataForCurrentSong() async {
    final currentSong = _queue[_currentIndex];
    final coverArtUrl = currentSong.coverArt != null
        ? _apiClient.getCoverArtUrl(currentSong.coverArt!, itemId: currentSong.albumId)
        : null;
    await _mediaService.updateMetadata(
      title: currentSong.title,
      artist: currentSong.artistName,
      album: currentSong.albumName,
      artUri: coverArtUrl,
      duration: currentSong.duration != null ? Duration(seconds: currentSong.duration!) : null,
    );
  }

  AudioPlayer get player => _player;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Song? get currentSong {
    return _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex]
        : null;
  }

  // Method to sync queue from external source (e.g., queueProvider)
  void syncQueue(List<Song> songs) {
    _queue.clear();
    _queue.addAll(songs);
    _logger.debug('Queue synced with ${songs.length} songs');
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> playSong(Song song, {bool enableCache = true}) async {
    // Use lock to prevent concurrent playback
    await _playLock.synchronized(() async {
      // Check if already playing this song
      if (_currentlyPlayingSongId == song.id) {
        _logger.debug('Song ${song.title} is already playing, skipping');
        return;
      }
      
      _logger.info('Playing song: ${song.title} (ID: ${song.id})');
      
      try {
        // Update currently playing song ID immediately
        _currentlyPlayingSongId = song.id;

        // Platform-specific playback switching strategy
        if (Platform.isAndroid) {
          // Android: Recreate player to avoid MediaCodec state issues
          _logger.info('Android: Recreating player before switching song');
          await _disposeAndRecreatePlayer();
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          // Windows: Use hard stop (original behavior)
          _logger.info('Windows hard switch: stop');
          await _player.stop();
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Platform-specific: Android always streams, others use cache if available
        final cacheManager = AudioCacheManager();
        final cachedFilePath = await cacheManager.getCachedFilePath(song.id);
        
        AudioSource audioSource;
        bool isPlayingFromCache = false;
        
        if (Platform.isAndroid) {
          // Android: Always stream to avoid MediaCodec issues
          _logger.info('Android: Streaming playback');
          final streamUrl = _apiClient.getStreamUrl(song.id);
          _logger.debug('Stream URL: $streamUrl');
          
          audioSource = AudioSource.uri(
            Uri.parse(streamUrl),
            tag: MediaItem(
              id: song.id,
              album: song.albumName,
              title: song.title,
              artist: song.artistName,
              artUri: song.coverArt != null
                  ? Uri.parse(_apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId))
                  : null,
              duration: song.duration != null
                  ? Duration(seconds: song.duration!)
                  : null,
            ),
          );
        } else if (cachedFilePath != null) {
          // Windows/Linux: Play from local cache
          _logger.info('Windows: cache playback allowed - Playing from cache: ${song.title}');
          audioSource = AudioSource.uri(
            Uri.file(cachedFilePath),
            tag: MediaItem(
              id: song.id,
              album: song.albumName,
              title: song.title,
              artist: song.artistName,
              artUri: song.coverArt != null
                  ? Uri.parse(_apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId))
                  : null,
              duration: song.duration != null
                  ? Duration(seconds: song.duration!)
                  : null,
            ),
          );
          isPlayingFromCache = true;
        } else {
          // Windows/Linux: Play from network stream
          final streamUrl = _apiClient.getStreamUrl(song.id);
          _logger.debug('Stream URL: $streamUrl');
          
          audioSource = AudioSource.uri(
            Uri.parse(streamUrl),
            tag: MediaItem(
              id: song.id,
              album: song.albumName,
              title: song.title,
              artist: song.artistName,
              artUri: song.coverArt != null
                  ? Uri.parse(_apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId))
                  : null,
              duration: song.duration != null
                  ? Duration(seconds: song.duration!)
                  : null,
            ),
          );
        }
        
        await _player.setAudioSource(audioSource);
        
        // Small delay to ensure audio source is loaded
        await Future.delayed(const Duration(milliseconds: 100));

        await _player.play();
        _logger.info('Started playing: ${song.title} ${isPlayingFromCache ? "(from cache)" : "(from network)"}');

        // Cache the song in background if not cached and caching is enabled
        if (!isPlayingFromCache && enableCache) {
          _cacheSongInBackground(song);
        }

        // Update media metadata
        final coverArtUrl = song.coverArt != null
            ? _apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId)
            : null;
        await _mediaService.updateMetadata(
          title: song.title,
          artist: song.artistName,
          album: song.albumName,
          artUri: coverArtUrl,
          duration: song.duration != null ? Duration(seconds: song.duration!) : null,
        );
        await _mediaService.setPlaybackState(
          isPlaying: true,
          position: Duration.zero,
          duration: song.duration != null ? Duration(seconds: song.duration!) : null,
        );
        await _mediaService.setEnabled(true);

        // Update queue display with cover art URL generator
        await _mediaService.updateQueue(_queue, _currentIndex, getArtUri: (song) {
          if (song.coverArt != null) {
            return _apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId);
          }
          return null;
        });

        // Notify listeners that song has changed
        if (onSongChanged != null) {
          onSongChanged!(song);
        }

        // Submit "now playing" scrobble
        await _submitScrobble(song.id, submission: false);
      } catch (e, stackTrace) {
        _logger.error('Error playing song: $e, stackTrace: $stackTrace');
        // Reset currently playing song ID on error
        _currentlyPlayingSongId = null;
        rethrow;
      }
    });
  }

  /// Cache song in background after playback starts
  void _cacheSongInBackground(Song song) {
    Future.microtask(() async {
      try {
        final cacheManager = AudioCacheManager();
        
        // Check if already cached
        if (await cacheManager.isCached(song.id)) {
          _logger.debug('Song already cached: ${song.title}');
          return;
        }

        final streamUrl = _apiClient.getStreamUrl(song.id);
        _logger.debug('Background caching: ${song.title}');

        // Download the audio file
        final response = await _dio.get(
          streamUrl,
          options: Options(responseType: ResponseType.bytes),
        );

        if (response.statusCode == 200) {
          // Save to temp file first
          final tempDir = await Directory.systemTemp.createTemp('sonic_audio_');
          final tempFile = File('${tempDir.path}/${song.id}.tmp');
          await tempFile.writeAsBytes(response.data);

          // Get cover art URL if available
          String? coverArtUrl;
          if (song.coverArt != null && song.coverArt!.isNotEmpty) {
            coverArtUrl = _apiClient.getCoverArtUrl(
              song.coverArt!,
              itemId: song.albumId,
            );
          }

          // Move to cache with metadata
          await cacheManager.putFile(
            song.id,
            tempFile.path,
            streamUrl,
            isFavorite: false,
            title: song.title,
            artist: song.artistName,
            album: song.albumName,
            albumId: song.albumId,
            duration: song.duration,
            coverArt: coverArtUrl,
          );

          // Cleanup temp file
          await tempFile.delete();
          await tempDir.delete();

          _logger.info('Background cached: ${song.title}');
        }
      } catch (e) {
        _logger.error('Failed to background cache ${song.title}: $e');
      }
    });
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    // Generate new call ID to track this operation
    final callId = ++_playQueueCallId;
    _lastPlayQueueCallId = callId;
    
    _logger.info('Playing queue with ${songs.length} songs, starting at index $startIndex');
    
    // Check for empty queue
    if (songs.isEmpty) {
      _logger.warning('Cannot play empty queue');
      return;
    }
    
    // Validate startIndex
    if (startIndex < 0 || startIndex >= songs.length) {
      _logger.warning('Invalid startIndex: $startIndex, queue length: ${songs.length}, using 0');
      startIndex = 0;
    }
    
    // Stop current playback and reset state to prevent old completion events
    await _player.stop();
    _hasTriggeredCompletion = false;
    _lastCompletionTime = null;
    
    _queue.clear();
    _queue.addAll(songs);
    _currentIndex = startIndex;

    // Notify listeners
    _queueChangeController.add(null);

    // Update queue in media service with cover art URL generator
    await _mediaService.updateQueue(_queue, _currentIndex, getArtUri: (song) {
      if (song.coverArt != null) {
        return _apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId);
      }
      return null;
    });

    if (_currentIndex < _queue.length) {
      if (Platform.isWindows) {
        // Windows: Use single song playback to avoid ConcatenatingAudioSource crashes
        await _playSongWithSetAudioSource(_queue[_currentIndex]);
      } else {
        // Android: Use ConcatenatingAudioSource for seamless playback
        await _playQueueWithConcatenatingSource(startIndex, callId);
      }

      // Pre-cache entire queue in background
      _preCacheQueueAsync();
    } else {
      _logger.warning('Start index $startIndex is out of range (queue length: ${_queue.length})');
    }
  }

  /// Pre-cache entire queue in background
  void _preCacheQueueAsync() {
    _logger.info('Starting pre-cache for entire queue: ${_queue.length} songs');
    Future.microtask(() async {
      await preCacheSongs(_queue, maxConcurrent: 2);
    });
  }

  /// Play queue using ConcatenatingAudioSource for seamless song switching
  Future<void> _playQueueWithConcatenatingSource(int startIndex, int callId) async {
    _logger.info('Creating ConcatenatingAudioSource for ${_queue.length} songs, starting at $startIndex');

    try {
      // Create audio sources for all songs in queue
      // Priority: use cache if available, otherwise stream
      final audioSources = await Future.wait(_queue.map((song) async {
        return await _createAudioSourceForSong(song);
      }).toList());

      // Create concatenating source
      final concatenatingSource = ConcatenatingAudioSource(
        children: audioSources,
      );

      // Set the audio source
      await _player.setAudioSource(concatenatingSource, initialIndex: startIndex);
      
      // Check if this call is still valid (not superseded by a newer operation)
      if (callId != _lastPlayQueueCallId) {
        _logger.info('CallId $callId is expired, aborting _playQueueWithConcatenatingSource');
        return;
      }
      
      // Update current index tracking
      _currentIndex = startIndex;
      final currentSong = _queue[_currentIndex];
      _currentlyPlayingSongId = currentSong.id;
      
      _logger.info('ConcatenatingAudioSource loaded, starting playback at index $startIndex: ${currentSong.title}');

      // Start playback
      await _player.play();
      
      // Check again if this call is still valid before updating UI
      if (callId != _lastPlayQueueCallId) {
        _logger.info('CallId $callId is expired after play(), skipping onSongChanged');
        return;
      }
      
      // Update UI state
      _logger.info('About to call onSongChanged from _playQueueWithConcatenatingSource with: ${currentSong.title}');
      if (onSongChanged != null) {
        onSongChanged!(currentSong);
      }

      // Update media metadata
      final coverArtUrl = currentSong.coverArt != null
          ? _apiClient.getCoverArtUrl(currentSong.coverArt!, itemId: currentSong.albumId)
          : null;
      await _mediaService.updateMetadata(
        title: currentSong.title,
        artist: currentSong.artistName,
        album: currentSong.albumName,
        artUri: coverArtUrl,
        duration: currentSong.duration != null ? Duration(seconds: currentSong.duration!) : null,
      );
      await _mediaService.setPlaybackState(
        isPlaying: true,
        position: Duration.zero,
        duration: currentSong.duration != null ? Duration(seconds: currentSong.duration!) : null,
      );
      await _mediaService.setEnabled(true);

      // Check again before submitting scrobble
      if (callId != _lastPlayQueueCallId) {
        _logger.info('CallId $callId is expired before scrobble, skipping');
        return;
      }

      // Submit "now playing" scrobble for first song
      _logger.info('Submitting now playing scrobble for first song: ${currentSong.title}');
      await _submitScrobble(currentSong.id, submission: false);

      _logger.info('Started playing queue with ConcatenatingAudioSource');
    } catch (e, stackTrace) {
      _logger.error('Error creating ConcatenatingAudioSource: $e, stackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Create audio source for a song, preferring cache if available
  Future<AudioSource> _createAudioSourceForSong(Song song) async {
    _logger.info('[DEBUG] Song meta: id=${song.id}, title=${song.title}, contentType=${song.contentType}, bitRate=${song.bitRate}, duration=${song.duration}');
    final cacheManager = AudioCacheManager();
    final cachedFilePath = await cacheManager.getCachedFilePath(song.id);

    // Check if cache playback is enabled
    final prefs = await SharedPreferences.getInstance();
    final cachePlaybackEnabled = prefs.getBool('audio_cache_playback_enabled') ?? true;

    if (cachePlaybackEnabled && cachedFilePath != null) {
      // Use cached file
      _logger.info('Using cached file for: ${song.title}');
      return AudioSource.uri(
        Uri.file(cachedFilePath),
        tag: MediaItem(
          id: song.id,
          album: song.albumName,
          title: song.title,
          artist: song.artistName,
          artUri: song.coverArt != null
              ? Uri.parse(_apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId))
              : null,
          duration: song.duration != null
              ? Duration(seconds: song.duration!)
              : null,
        ),
      );
    } else {
      // Use network stream
      final streamUrl = _apiClient.getStreamUrl(song.id);
      _logger.info('Using network stream for: ${song.title}');
      return AudioSource.uri(
        Uri.parse(streamUrl),
        tag: MediaItem(
          id: song.id,
          album: song.albumName,
          title: song.title,
          artist: song.artistName,
          artUri: song.coverArt != null
              ? Uri.parse(_apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId))
              : null,
          duration: song.duration != null
              ? Duration(seconds: song.duration!)
              : null,
        ),
      );
    }
  }

  void _preCacheNextSongsAsync(int count) {
    // Run pre-caching in background
    Future.microtask(() async {
      await preCacheNextSongs(count);
    });
  }

  Future<void> playNext() async {
    // Increment callId to invalidate any pending playQueue operations
    final callId = ++_playQueueCallId;
    _lastPlayQueueCallId = callId;
    
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      final currentSong = _queue[_currentIndex];

      if (Platform.isWindows) {
        // Windows: Use setAudioSource for reliable switching
        await _playSongWithSetAudioSource(currentSong);
      } else {
        // Android: Use seekToNext for ConcatenatingAudioSource
        await _player.seekToNext();

        // Update currently playing song ID
        _currentlyPlayingSongId = currentSong.id;

        // Update UI state
        if (onSongChanged != null) {
          onSongChanged!(currentSong);
        }

        // Update media metadata
        final coverArtUrl = currentSong.coverArt != null
            ? _apiClient.getCoverArtUrl(currentSong.coverArt!, itemId: currentSong.albumId)
            : null;
        await _mediaService.updateMetadata(
          title: currentSong.title,
          artist: currentSong.artistName,
          album: currentSong.albumName,
          artUri: coverArtUrl,
          duration: currentSong.duration != null ? Duration(seconds: currentSong.duration!) : null,
        );
      }
    }
  }

  Future<void> playPrevious() async {
    // Increment callId to invalidate any pending playQueue operations
    final callId = ++_playQueueCallId;
    _lastPlayQueueCallId = callId;
    
    if (_currentIndex > 0) {
      _currentIndex--;
      final currentSong = _queue[_currentIndex];

      if (Platform.isWindows) {
        // Windows: Use setAudioSource for reliable switching
        await _playSongWithSetAudioSource(currentSong);
      } else {
        // Android: Use seekToPrevious for ConcatenatingAudioSource
        await _player.seekToPrevious();

        // Update currently playing song ID
        _currentlyPlayingSongId = currentSong.id;

        // Update UI state
        if (onSongChanged != null) {
          onSongChanged!(currentSong);
        }

        // Update media metadata
        final coverArtUrl = currentSong.coverArt != null
            ? _apiClient.getCoverArtUrl(currentSong.coverArt!, itemId: currentSong.albumId)
            : null;
        await _mediaService.updateMetadata(
          title: currentSong.title,
          artist: currentSong.artistName,
          album: currentSong.albumName,
          artUri: coverArtUrl,
          duration: currentSong.duration != null ? Duration(seconds: currentSong.duration!) : null,
        );
      }
    }
  }

  /// Play a single song using setAudioSource (for Windows)
  Future<void> _playSongWithSetAudioSource(Song song) async {
      // Set flag to prevent auto-advance during manual song switch
      _isSwitchingSong = true;
      _logger.debug('=== _playSongWithSetAudioSource START ===');
      _logger.debug('Target song: ${song.title} (ID: ${song.id})');
      _logger.debug('Current state before switch: index=$_currentIndex, playing=${_player.playing}, processingState=${_player.processingState}, _isSwitchingSong=$_isSwitchingSong');

    try {
      // Update currently playing song ID
      _currentlyPlayingSongId = song.id;

      // Create audio source
      _logger.debug('Creating audio source for: ${song.title}');
      final audioSource = await _createAudioSourceForSong(song);
      _logger.debug('Audio source created successfully');

      // Set audio source and play
      _logger.debug('Calling setAudioSource()...');
      await _player.setAudioSource(audioSource);
      _logger.debug('setAudioSource() completed, processingState=${_player.processingState}');

      // Wait for audio source to be ready before playing
      _logger.debug('Waiting for audio source to be ready...');
      var waitCount = 0;
      while (_player.processingState != ProcessingState.ready && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 50));
        waitCount++;
      }
      _logger.debug('Audio source ready after ${waitCount * 50}ms, processingState=${_player.processingState}');

      // Reset position to beginning for new song
      _logger.info('BEFORE seek: position=${_player.position}, duration=${_player.duration}');
      await _player.seek(Duration.zero);
      _logger.info('AFTER seek: position=${_player.position}');
      
      // Verify position is actually zero, retry if not
      var verifyCount = 0;
      while (_player.position.inMilliseconds > 100 && verifyCount < 20) {
        _logger.warning('Position not reset, retrying... position=${_player.position}, attempt=$verifyCount');
        await Future.delayed(const Duration(milliseconds: 50));
        await _player.seek(Duration.zero);
        verifyCount++;
      }
      _logger.info('Position verified: ${_player.position}, retries=$verifyCount');

      _logger.debug('Calling play()...');
      await _player.play();
      _logger.info('AFTER play: playing=${_player.playing}, position=${_player.position}');
      
      // Song switch completed, reset flag
      _isSwitchingSong = false;
      _logger.debug('Song switch completed, _isSwitchingSong reset to false');

      // Update UI state
      if (onSongChanged != null) {
        onSongChanged!(song);
      }

      // Update media metadata
      _logger.debug('Updating media metadata for: ${song.title}');
      final coverArtUrl = song.coverArt != null
          ? _apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId)
          : null;
      await _mediaService.updateMetadata(
        title: song.title,
        artist: song.artistName,
        album: song.albumName,
        artUri: coverArtUrl,
        duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      );
      await _mediaService.setPlaybackState(
        isPlaying: true,
        position: Duration.zero,
        duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      );

      // Submit "now playing" scrobble
      _logger.info('Submitting now playing scrobble for: ${song.title}');
      await _submitScrobble(song.id, submission: false);

      _logger.debug('=== _playSongWithSetAudioSource END ===');
      _logger.info('Successfully started playing: ${song.title}');
    } catch (e, stackTrace) {
      _logger.error('=== _playSongWithSetAudioSource ERROR ===');
      _logger.error('Error playing song with setAudioSource: $e, stackTrace: $stackTrace');
      // Reset flag on error
      _isSwitchingSong = false;
      _logger.debug('Reset _isSwitchingSong to false due to error');
      rethrow;
    }
  }

  Future<void> play() async {
    _logger.debug('Resuming playback');
    await _player.play();
    await _mediaService.setPlaybackState(
      isPlaying: true,
      position: _player.position,
      duration: _player.duration,
    );
  }

  Future<void> pause() async {
    _logger.debug('Pausing playback');
    await _player.pause();
    await _mediaService.setPlaybackState(
      isPlaying: false,
      position: _player.position,
      duration: _player.duration,
    );
  }

  Future<void> stop() async {
    _logger.debug('Stopping playback');
    await _player.stop();
    await _mediaService.setEnabled(false);
  }
  
  Future<void> seek(Duration position) async {
    _logger.debug('Seeking to position: $position');
    await _player.seek(position);
  }

  Future<void> addToQueue(Song song) async {
    _logger.info('Adding song to queue: ${song.title}');
    _queue.add(song);
    _queueChangeController.add(null);
    await _mediaService.updateQueue(_queue, _currentIndex, getArtUri: (song) {
      if (song.coverArt != null) {
        return _apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId);
      }
      return null;
    });
  }

  Future<void> insertNext(Song song) async {
    _logger.info('Inserting song next: ${song.title}');
    final insertIndex = _currentIndex + 1;
    if (insertIndex <= _queue.length) {
      _queue.insert(insertIndex, song);
      _queueChangeController.add(null);
      await _mediaService.updateQueue(_queue, _currentIndex, getArtUri: (song) {
        if (song.coverArt != null) {
          return _apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId);
        }
        return null;
      });
    }
  }

  Future<void> removeFromQueue(Song song) async {
    _logger.info('Removing song from queue: ${song.title}');
    final index = _queue.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      if (index == _currentIndex) {
        // If removing current song, stop playback
        await stop();
      } else if (index < _currentIndex) {
        // If removing before current, adjust index
        _currentIndex--;
      }
      _queue.removeAt(index);
      _queueChangeController.add(null);
      await _mediaService.updateQueue(_queue, _currentIndex, getArtUri: (song) {
        if (song.coverArt != null) {
          return _apiClient.getCoverArtUrl(song.coverArt!, itemId: song.albumId);
        }
        return null;
      });
    }
  }

  // Volume control
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    _logger.debug('Setting volume to: $clampedVolume');
    await _player.setVolume(clampedVolume);
  }

  Stream<double> get volumeStream => _player.volumeStream;

  double get currentVolume => _player.volume;

  // Loop mode control
  Future<void> setLoopMode(LoopMode mode) async {
    _logger.debug('Setting loop mode to: $mode');
    await _player.setLoopMode(mode);
  }

  Stream<LoopMode> get loopModeStream => _player.loopModeStream;

  LoopMode get currentLoopMode => _player.loopMode;

  // Shuffle mode control
  Future<void> setShuffleModeEnabled(bool enabled) async {
    _logger.debug('Setting shuffle mode to: $enabled');
    await _player.setShuffleModeEnabled(enabled);
  }

  Stream<bool> get shuffleModeEnabledStream => _player.shuffleModeEnabledStream;

  bool get shuffleModeEnabled => _player.shuffleModeEnabled;

  /// Set playback speed (0.5x to 2.0x)
  Future<void> setSpeed(double speed) async {
    try {
      final clampedSpeed = speed.clamp(0.5, 2.0);
      _logger.debug('Setting playback speed to: $clampedSpeed');
      await _player.setSpeed(clampedSpeed);
    } catch (e) {
      _logger.error('Error setting playback speed: $e');
      rethrow;
    }
  }

  Stream<double> get speedStream => _player.speedStream;

  double get currentSpeed => _player.speed;

  // Clear queue but keep current song
  Future<void> clearQueueExceptCurrent() async {
    _logger.info('Clearing queue except current song');
    final current = currentSong;
    if (current != null) {
      _queue.clear();
      _queue.add(current);
      _logger.info('Setting _currentIndex = 0 (from clearQueueExceptCurrent)');
      _currentIndex = 0;
      _logger.info('Queue cleared, kept current song: ${current.title}');
    } else {
      _queue.clear();
      _logger.info('Setting _currentIndex = -1 (from clearQueueExceptCurrent)');
      _currentIndex = -1;
      _logger.info('Queue cleared (no current song)');
    }
    _queueChangeController.add(null);
    await _mediaService.updateQueue(_queue, _currentIndex);
  }

  // Clear entire queue
  Future<void> clearQueue() async {
    _logger.info('Clearing entire queue');
    _queue.clear();
    _logger.info('Setting _currentIndex = -1 (from clearQueue)');
    _currentIndex = -1;
    _queueChangeController.add(null);
    await _mediaService.updateQueue(_queue, _currentIndex);
    // Stop playback when clearing queue
    await stop();
    // Clear saved playback state
    await _clearSavedPlaybackState();
  }

  /// Clear saved playback state from SharedPreferences
  Future<void> _clearSavedPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_playback_queue');
      await prefs.remove('last_playback_index');
      await prefs.remove('last_playback_position');
      await prefs.remove('last_playback_saved_at');
      await prefs.remove('last_playback_songs_data');
      _logger.info('Saved playback state cleared');
    } catch (e) {
      _logger.error('Failed to clear saved playback state: $e');
    }
  }

  /// Pre-cache songs in the queue for offline playback
  Future<void> preCacheSongs(List<Song> songs, {int maxConcurrent = 2}) async {
    final cacheManager = AudioCacheManager();
    final dio = Dio();

    var cachedCount = 0;
    var failedCount = 0;

    _logger.info('Starting pre-cache for ${songs.length} songs');

    // Process songs in batches to avoid overwhelming the system
    for (var i = 0; i < songs.length; i += maxConcurrent) {
      final batch = songs.skip(i).take(maxConcurrent).toList();

      await Future.wait(batch.map((song) async {
        try {
          // Check if already cached
          if (await cacheManager.isCached(song.id)) {
            _logger.debug('Song already cached: ${song.title}');
            return;
          }

          final streamUrl = _apiClient.getStreamUrl(song.id);
          _logger.debug('Pre-caching: ${song.title}');

          // Download the audio file
          final response = await dio.get(
            streamUrl,
            options: Options(responseType: ResponseType.bytes),
          );

          if (response.statusCode == 200) {
            // Save to temp file first
            final tempDir = await Directory.systemTemp.createTemp('sonic_audio_');
            final tempFile = File('${tempDir.path}/${song.id}.tmp');
            await tempFile.writeAsBytes(response.data);

            // Get cover art URL if available
            String? coverArtUrl;
            if (song.coverArt != null && song.coverArt!.isNotEmpty) {
              coverArtUrl = _apiClient.getCoverArtUrl(
                song.coverArt!,
                itemId: song.albumId,
              );
            }

            // Move to cache with metadata
            await cacheManager.putFile(
              song.id,
              tempFile.path,
              streamUrl,
              isFavorite: false, // TODO: Check if song is favorited
              title: song.title,
              artist: song.artistName,
              album: song.albumName,
              albumId: song.albumId,
              duration: song.duration,
              coverArt: coverArtUrl,
            );

            // Cleanup temp file
            await tempFile.delete();
            await tempDir.delete();

            cachedCount++;
            _logger.info('Pre-cached: ${song.title}');
          }
        } catch (e) {
          failedCount++;
          _logger.error('Failed to pre-cache ${song.title}: $e');
        }
      }));
    }

    _logger.info('Pre-cache complete: $cachedCount cached, $failedCount failed');
  }

  /// Pre-cache next N songs in queue
  Future<void> preCacheNextSongs(int count) async {
    if (_currentIndex < 0 || _queue.isEmpty) return;

    final nextSongs = _queue
        .skip(_currentIndex + 1)
        .take(count)
        .toList();

    if (nextSongs.isNotEmpty) {
      await preCacheSongs(nextSongs, maxConcurrent: 1);
    }
  }

  /// Play a cached audio file directly
  Future<void> playCachedFile(String filePath, {
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? coverArt,
  }) async {
    _logger.info('Playing cached file: $filePath');
    
    try {
      // Stop current playback before loading new source
      await _player.stop();

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Cached file does not exist: $filePath');
      }

      // Create audio source from file
      final audioSource = AudioSource.uri(
        Uri.file(filePath),
        tag: MediaItem(
          id: filePath,
          album: album ?? '未知专辑',
          title: title ?? '未知歌曲',
          artist: artist ?? '未知艺术家',
          artUri: coverArt != null
              ? Uri.parse(_apiClient.getCoverArtUrl(coverArt, itemId: ''))
              : null,
          duration: duration != null
              ? Duration(seconds: duration)
              : null,
        ),
      );

      await _player.setAudioSource(audioSource);

      // Small delay to ensure audio source is loaded
      await Future.delayed(const Duration(milliseconds: 100));

      await _player.play();
      _logger.info('Started playing cached file: $filePath');

      // Update media metadata
      await _mediaService.updateMetadata(
        title: title ?? '未知歌曲',
        artist: artist ?? '未知艺术家',
        album: album ?? '未知专辑',
        artUri: coverArt,
        duration: duration != null ? Duration(seconds: duration) : null,
      );
      await _mediaService.setPlaybackState(
        isPlaying: true,
        position: Duration.zero,
        duration: duration != null ? Duration(seconds: duration) : null,
      );
      await _mediaService.setEnabled(true);
    } catch (e, stackTrace) {
      _logger.error('Error playing cached file: $e, stackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Submit scrobble (play record) to server
  Future<void> _submitScrobble(String trackId, {bool submission = true}) async {
    try {
      // Check if scrobble is enabled (default to true)
      final prefs = await SharedPreferences.getInstance();
      final scrobbleEnabled = prefs.getBool('scrobble_enabled') ?? true;
      
      if (!scrobbleEnabled) {
        _logger.debug('Scrobble disabled, skipping submission');
        return;
      }

      _logger.info('Submitting scrobble: trackId=$trackId, submission=$submission');
      await _apiClient.scrobble(trackId, submission: submission);
      _logger.info('Scrobble submitted successfully');
    } catch (e) {
      _logger.error('Failed to submit scrobble: $e');
      // Don't throw - scrobble failures shouldn't break playback
    }
  }

  Future<void> dispose() async {
    _logger.info('Disposing AudioPlayerService');
    _positionSubscription?.cancel();
    await _queueChangeController.close();
    await _mediaService.dispose();
    await _player.dispose();
  }

  /// Save current playback state for auto-resume
  Future<void> savePlaybackState() async {
    try {
      if (_queue.isEmpty || _currentIndex < 0) {
        _logger.info('[DEBUG] savePlaybackState: queue is empty or index < 0, skipping save');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final queueIds = _queue.map((song) => song.id).toList();
      final position = _player.position.inMilliseconds;

      _logger.info('[DEBUG] savePlaybackState: Saving state...');
      _logger.info('[DEBUG] savePlaybackState: queueIds=$queueIds');
      _logger.info('[DEBUG] savePlaybackState: currentIndex=$_currentIndex');
      _logger.info('[DEBUG] savePlaybackState: position=${position}ms');
      _logger.info('[DEBUG] savePlaybackState: currentSong=${_queue[_currentIndex].title}');

      await prefs.setStringList('last_playback_queue', queueIds);
      await prefs.setInt('last_playback_index', _currentIndex);
      await prefs.setInt('last_playback_position', position);
      await prefs.setString('last_playback_saved_at', DateTime.now().toIso8601String());

      // Also save full song data for restoration
      final songsData = _queue.map((song) => song.toJson()).toList();
      await prefs.setString('last_playback_songs_data', jsonEncode(songsData));

      _logger.info('[DEBUG] savePlaybackState: State saved successfully');
      _logger.info('Playback state saved: index=$_currentIndex, position=${position}ms, queue=${queueIds.length} songs');
    } catch (e) {
      _logger.error('[DEBUG] savePlaybackState: Failed to save: $e');
      _logger.error('Failed to save playback state: $e');
    }
  }

  /// Restore playback state from saved data
  /// Returns true if state was restored successfully
  Future<bool> restorePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueIds = prefs.getStringList('last_playback_queue');

      if (queueIds == null || queueIds.isEmpty) {
        _logger.debug('No saved playback state found');
        return false;
      }

      final currentIndex = prefs.getInt('last_playback_index') ?? 0;
      final position = prefs.getInt('last_playback_position') ?? 0;

      _logger.info('Restoring playback state: index=$currentIndex, position=${position}ms, queue=${queueIds.length} songs');

      // Note: Subsonic API doesn't have a getSong endpoint
      // We'll store the full song info in a separate key for restoration
      // For now, we can only restore if we have the cached song data
      final cachedSongsJson = prefs.getString('last_playback_songs_data');
      if (cachedSongsJson == null) {
        _logger.warning('No cached song data found for restoration');
        return false;
      }

      try {
        final List<dynamic> songsData = jsonDecode(cachedSongsJson);
        final List<Song> restoredQueue = songsData
            .map((json) => Song.fromJson(json))
            .where((song) => queueIds.contains(song.id))
            .toList();

        if (restoredQueue.isEmpty) {
          _logger.warning('No valid songs could be restored from cached data');
          return false;
        }

        // Reorder to match original queue order
        restoredQueue.sort((a, b) {
          final indexA = queueIds.indexOf(a.id);
          final indexB = queueIds.indexOf(b.id);
          return indexA.compareTo(indexB);
        });

        // Set up the queue
        _queue.clear();
        _queue.addAll(restoredQueue);
        _currentIndex = currentIndex.clamp(0, _queue.length - 1);

        // Load the audio source but don't play yet
        final currentSong = _queue[_currentIndex];
        _logger.info('Restoring to song: ${currentSong.title} at position ${position}ms');

        if (Platform.isWindows) {
          // Windows: Use setAudioSource
          final audioSource = await _createAudioSourceForSong(currentSong);
          await _player.setAudioSource(audioSource);
          await _player.seek(Duration(milliseconds: position));
        } else {
          // Android: Set up ConcatenatingAudioSource
          await _playQueueWithConcatenatingSource(_currentIndex, ++_playQueueCallId);
          await _player.seek(Duration(milliseconds: position), index: _currentIndex);
        }

        // Update UI state
        _currentlyPlayingSongId = currentSong.id;
        if (onSongChanged != null) {
          onSongChanged!(currentSong);
        }

        // Update media metadata
        await _updateMediaMetadataForCurrentSong();

        _logger.info('Playback state restored successfully');
        return true;
      } catch (e) {
        _logger.error('Failed to parse cached song data: $e');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to restore playback state: $e, $stackTrace');
      return false;
    }
  }

  /// Get current playback state for saving
  Map<String, dynamic>? getCurrentPlaybackState() {
    if (_queue.isEmpty || _currentIndex < 0) {
      return null;
    }

    return {
      'queue': _queue.map((song) => song.id).toList(),
      'currentIndex': _currentIndex,
      'position': _player.position.inMilliseconds,
    };
  }

  /// Dispose and recreate the player (for Android song switching)
  Future<void> _disposeAndRecreatePlayer() async {
    _logger.info('Disposing and recreating AudioPlayer for Android');
    
    // Cancel old subscription
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    // Dispose old player
    try {
      await _player.dispose();
    } catch (e) {
      _logger.warning('Error disposing player: $e');
    }
    
    // Create new player instance
    _player = AudioPlayer();
    
    // Re-setup position listener
    _setupPositionListener();
    
    _logger.info('AudioPlayer recreated successfully');
  }
}
