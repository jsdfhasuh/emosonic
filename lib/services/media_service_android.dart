import 'dart:io';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:just_audio/just_audio.dart';
import '../core/utils/logger.dart';
import '../data/models/models.dart';
import 'audio_handler.dart' as app_audio;
import 'media_service.dart';

/// Android Media Service Implementation
/// Uses audio_service plugin for system media controls
class MediaServiceAndroid implements MediaService {
  app_audio.AudioHandler? _handler;
  final AudioPlayer _player;
  final Logger _logger = Logger('MediaServiceAndroid');
  bool _isInitialized = false;

  MediaServiceAndroid(this._player);

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!Platform.isAndroid) {
      _logger.warning('MediaServiceAndroid should only be used on Android');
      return;
    }

    try {
      _logger.info('Initializing Android Media Service...');
      
      // Initialize audio service
      _handler = await audio_service.AudioService.init(
        builder: () => app_audio.AudioHandler(_player),
        config: audio_service.AudioServiceConfig(
          androidNotificationChannelId: 'com.example.emosonic.channel.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
        ),
      );

      _isInitialized = true;
      _logger.info('Android Media Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Android Media Service: $e');
      _logger.error('Stack trace: $stackTrace');
    }
  }

  @override
  void setMediaButtonListener({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
  }) {
    if (_handler == null) {
      _logger.warning('Cannot set media button listener: handler not initialized');
      return;
    }

    _handler!.setCallbacks(
      onPlay: onPlay,
      onPause: onPause,
      onNext: onNext,
      onPrevious: onPrevious,
      onStop: onStop,
    );
    _logger.info('Media button listeners set');
  }

  @override
  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? artUri,
    Duration? duration,
  }) async {
    if (_handler == null) return;

    try {
      await _handler!.updateMediaItemFromSong(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        artist: artist,
        album: album,
        artUri: artUri,
        duration: duration,
      );
      _logger.debug('Metadata updated: $title');
    } catch (e) {
      _logger.error('Failed to update metadata: $e');
    }
  }

  @override
  Future<void> setPlaybackState({
    required bool isPlaying,
    required Duration position,
    Duration? bufferedPosition,
    Duration? duration,
  }) async {
    if (_handler == null) return;

    // Playback state is automatically updated by AudioHandler listening to player
    _logger.debug('Playback state updated: isPlaying=$isPlaying, position=$position');
  }

  @override
  Future<void> updateQueue(List<Song> queue, int currentIndex, {String? Function(Song song)? getArtUri}) async {
    if (_handler == null) return;

    try {
      await _handler!.updateQueueFromSongs(queue, currentIndex, getArtUri: getArtUri);
      _logger.debug('Queue updated: ${queue.length} songs');
    } catch (e) {
      _logger.error('Failed to update queue: $e');
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_handler == null) return;

    if (enabled) {
      // Audio service is always enabled once initialized
      _logger.debug('Media service enabled');
    } else {
      // Don't call _handler.stop() here to avoid circular callback
      // The stop action should be handled by the callback itself
      _logger.debug('Media service disabled (notification will be removed)');
    }
  }

  @override
  Future<void> dispose() async {
    if (_handler != null) {
      await _handler!.stop();
      _handler = null;
      _isInitialized = false;
      _logger.info('Android Media Service disposed');
    }
  }
}
