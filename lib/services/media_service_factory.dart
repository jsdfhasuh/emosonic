import 'dart:io';
import 'package:just_audio/just_audio.dart';
import '../core/utils/logger.dart';
import '../data/models/models.dart';
import 'media_service.dart';
import 'media_service_android.dart';
import 'media_service_windows.dart';

/// Media Service Factory
/// Creates platform-specific media service implementation
class MediaServiceFactory {
  static MediaService? _instance;
  static final Logger _logger = Logger('MediaServiceFactory');

  /// Get the appropriate media service for the current platform
  static MediaService getService(AudioPlayer player) {
    if (_instance == null) {
      _logger.info('Creating MediaService for platform: ${Platform.operatingSystem}');
      
      if (Platform.isWindows) {
        _logger.info('Using Windows Media Service (SMTC)');
        _instance = MediaServiceWindows(player);
      } else if (Platform.isAndroid) {
        _logger.info('Using Android Media Service (audio_service)');
        _instance = MediaServiceAndroid(player);
      } else {
        _logger.info('Using stub Media Service for ${Platform.operatingSystem}');
        _instance = _MediaServiceStub(player);
      }
    }
    return _instance!;
  }

  /// Reset the singleton (for testing)
  static void reset() {
    _instance = null;
  }
}

/// Stub implementation for unsupported platforms
class _MediaServiceStub implements MediaService {
  final Logger _logger = Logger('MediaServiceStub');

  _MediaServiceStub(AudioPlayer player);

  @override
  Future<void> initialize() async {
    _logger.debug('Stub media service initialized');
  }

  @override
  void setMediaButtonListener({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
  }) {
    // No-op
  }

  @override
  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? artUri,
    Duration? duration,
  }) async {
    // No-op
  }

  @override
  Future<void> setPlaybackState({
    required bool isPlaying,
    required Duration position,
    Duration? bufferedPosition,
    Duration? duration,
  }) async {
    // No-op
  }

  @override
  Future<void> updateQueue(List<Song> queue, int currentIndex, {String? Function(Song song)? getArtUri}) async {
    // No-op
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    // No-op
  }

  @override
  Future<void> dispose() async {
    // No-op
  }
}
