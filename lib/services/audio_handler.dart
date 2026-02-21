import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../core/utils/logger.dart';
import '../data/models/models.dart';

/// Android Audio Handler
/// Handles media session, notifications, and system media controls
class AudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final Logger _logger = Logger('AudioHandler');
  
  // Callbacks for media button actions
  Function()? _onPlay;
  Function()? _onPause;
  Function()? _onNext;
  Function()? _onPrevious;
  Function()? _onStop;

  AudioHandler(this._player) {
    _logger.info('AudioHandler initialized');
    _setupPlayerListeners();
  }

  void setCallbacks({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onNext = onNext;
    _onPrevious = onPrevious;
    _onStop = onStop;
    _logger.info('AudioHandler callbacks set');
  }

  void _setupPlayerListeners() {
    // Listen to playback state changes
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Listen to current song index changes (for queue)
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        _logger.debug('Current index changed: $index');
      }
    });
  }

  /// Broadcast current playback state to system
  void _broadcastState() {
    final playing = _player.playing;
    final processingState = _getProcessingState();
    
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));
  }

  AudioProcessingState _getProcessingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Update media item (metadata)
  Future<void> setMediaItem(MediaItem mediaItem) async {
    _logger.info('Setting media item: ${mediaItem.title}');
    this.mediaItem.add(mediaItem);
    _broadcastState();
  }
  
  /// Helper method to create and set media item from song data
  Future<void> updateMediaItemFromSong({
    required String id,
    required String title,
    required String artist,
    required String album,
    String? artUri,
    Duration? duration,
  }) async {
    _logger.info('Updating media item from song: $title');
    
    final mediaItem = MediaItem(
      id: id,
      album: album,
      title: title,
      artist: artist,
      artUri: artUri != null ? Uri.parse(artUri) : null,
      duration: duration,
      displayTitle: title,
      displaySubtitle: artist,
      displayDescription: album,
    );

    await setMediaItem(mediaItem);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _logger.info('Updating queue: ${queue.length} songs');
    this.queue.add(queue);
    _broadcastState();
  }
  
  /// Helper method to update queue from songs
  Future<void> updateQueueFromSongs(List<Song> songs, int currentIndex, {String? Function(Song song)? getArtUri}) async {
    _logger.info('Updating queue from songs: ${songs.length} songs, current: $currentIndex');
    
    final queue = songs.map((song) {
      String? artUrl;
      if (getArtUri != null) {
        artUrl = getArtUri(song);
        _logger.debug('Generated art URL for ${song.title}: $artUrl');
      } else if (song.coverArt != null) {
        // Fallback: use coverArt directly if it's already a URL
        artUrl = song.coverArt;
        _logger.debug('Using raw coverArt for ${song.title}: $artUrl');
      }
      
      // Validate URL before parsing
      Uri? artUri;
      if (artUrl != null && artUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(artUrl);
          // Check if URL has a valid scheme (http/https) and host
          if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority) {
            artUri = uri;
            _logger.debug('Parsed art URI for ${song.title}: $artUri');
          } else {
            _logger.warning('Invalid art URL for ${song.title}: $artUrl (missing scheme or host)');
          }
        } catch (e) {
          _logger.error('Failed to parse art URI for ${song.title}: $artUrl, error: $e');
        }
      } else {
        _logger.debug('No art URL for ${song.title}, using default icon');
      }
      
      return MediaItem(
        id: song.id,
        album: song.albumName,
        title: song.title,
        artist: song.artistName,
        artUri: artUri,
        duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      );
    }).toList();

    await updateQueue(queue);
    
    // Update current media item
    if (currentIndex >= 0 && currentIndex < queue.length) {
      mediaItem.add(queue[currentIndex]);
    }
    
    _broadcastState();
  }

  // Media button handlers
  @override
  Future<void> play() async {
    _logger.info('AudioHandler: Play requested');
    _onPlay?.call();
  }

  @override
  Future<void> pause() async {
    _logger.info('AudioHandler: Pause requested');
    _onPause?.call();
  }

  bool _isStopping = false;
  
  @override
  Future<void> stop() async {
    if (_isStopping) {
      _logger.debug('AudioHandler: Stop already in progress, ignoring');
      return;
    }
    _isStopping = true;
    _logger.info('AudioHandler: Stop requested');
    try {
      _onStop?.call();
    } finally {
      _isStopping = false;
    }
  }

  @override
  Future<void> skipToNext() async {
    _logger.info('AudioHandler: Next requested');
    _onNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    _logger.info('AudioHandler: Previous requested');
    _onPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    _logger.info('AudioHandler: Seek to $position');
    await _player.seek(position);
  }

  @override
  Future<void> onTaskRemoved() async {
    _logger.info('AudioHandler: Task removed');
    await stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    _logger.info('AudioHandler: Notification deleted');
    await stop();
  }
}
