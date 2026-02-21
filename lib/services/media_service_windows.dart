import 'dart:io';
import 'package:just_audio/just_audio.dart';
import '../core/utils/logger.dart';
import '../data/models/models.dart';
import 'media_service.dart';
import 'smtc_service.dart';

/// Windows Media Service Implementation
/// Wraps the existing SMTC service
class MediaServiceWindows implements MediaService {
  final SMTCService _smtc = SMTCService.instance;
  final Logger _logger = Logger('MediaServiceWindows');
  bool _isInitialized = false;

  MediaServiceWindows(AudioPlayer player);

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!Platform.isWindows) {
      _logger.warning('MediaServiceWindows should only be used on Windows');
      return;
    }

    try {
      _logger.info('Initializing Windows Media Service (SMTC)...');
      await _smtc.initialize();
      _isInitialized = true;
      _logger.info('Windows Media Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Windows Media Service: $e');
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
    _smtc.setButtonListener(
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
    // Create a temporary Song object for SMTC
    final song = Song(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      artistName: artist,
      albumName: album,
      albumId: '',
      artistId: '',
      coverArt: artUri,
    );
    
    await _smtc.updateMetadata(song, artUri);
    _logger.debug('Metadata updated: $title');
  }

  @override
  Future<void> setPlaybackState({
    required bool isPlaying,
    required Duration position,
    Duration? bufferedPosition,
    Duration? duration,
  }) async {
    final status = isPlaying ? 3 : 4; // 3=playing, 4=paused
    await _smtc.setPlaybackStatus(status);
    
    if (duration != null) {
      await _smtc.updateTimeline(
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
      );
    }
    
    _logger.debug('Playback state updated: isPlaying=$isPlaying');
  }

  @override
  Future<void> updateQueue(List<Song> queue, int currentIndex, {String? Function(Song song)? getArtUri}) async {
    // SMTC doesn't support queue display, but we can log it
    _logger.debug('Queue updated: ${queue.length} songs (SMTC does not support queue display)');
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _smtc.enable();
    } else {
      await _smtc.disable();
    }
  }

  @override
  Future<void> dispose() async {
    await _smtc.dispose();
    _isInitialized = false;
    _logger.info('Windows Media Service disposed');
  }
}
