import 'dart:io';

import 'package:smtc_windows/smtc_windows.dart';
import '../core/utils/logger.dart';
import '../data/models/models.dart';

/// SMTC Service Interface
/// Provides Windows System Media Transport Controls functionality
abstract class SMTCService {
  static SMTCService? _instance;
  static final Logger _logger = Logger('SMTCService');

  /// Get singleton instance
  /// Returns Windows implementation on Windows, stub on other platforms
  static SMTCService get instance {
    if (_instance == null) {
      SMTCService._logger.info('SMTCService.instance called, Platform.isWindows=${Platform.isWindows}');
      if (Platform.isWindows) {
        SMTCService._logger.info('Creating Windows SMTC implementation');
        _instance = _SMTCServiceWindows();
      } else {
        SMTCService._logger.info('Creating stub SMTC implementation for ${Platform.operatingSystem}');
        _instance = _SMTCServiceStub();
      }
    }
    return _instance!;
  }

  /// Initialize SMTC
  Future<void> initialize();

  /// Set up button press listener
  void setButtonListener({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
  });

  /// Update metadata (song info)
  Future<void> updateMetadata(Song song, String? coverArtUrl);

  /// Update playback status
  /// Status values: 2=stopped, 3=playing, 4=paused
  Future<void> setPlaybackStatus(int status);

  /// Update timeline (progress)
  Future<void> updateTimeline({
    required int positionMs,
    required int durationMs,
  });

  /// Enable SMTC
  Future<void> enable();

  /// Disable SMTC
  Future<void> disable();

  /// Dispose SMTC
  Future<void> dispose();
}

/// Stub implementation for non-Windows platforms
class _SMTCServiceStub implements SMTCService {
  final Logger _logger = Logger('SMTCService');

  @override
  Future<void> initialize() async {
    _logger.debug('SMTCServiceStub.initialize() called - SMTC not supported on ${Platform.operatingSystem}');
  }

  @override
  void setButtonListener({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
  }) {
    // No-op on non-Windows platforms
  }

  @override
  Future<void> updateMetadata(Song song, String? coverArtUrl) async {
    // No-op on non-Windows platforms
  }

  @override
  Future<void> setPlaybackStatus(int status) async {
    // No-op on non-Windows platforms
  }

  @override
  Future<void> updateTimeline({
    required int positionMs,
    required int durationMs,
  }) async {
    // No-op on non-Windows platforms
  }

  @override
  Future<void> enable() async {
    // No-op on non-Windows platforms
  }

  @override
  Future<void> disable() async {
    // No-op on non-Windows platforms
  }

  @override
  Future<void> dispose() async {
    // No-op on non-Windows platforms
  }
}

/// Windows SMTC Implementation
/// Only used on Windows platform
class _SMTCServiceWindows implements SMTCService {
  SMTCWindows? _smtc;
  bool _isInitialized = false;
  final Logger _logger = Logger('SMTCService');

  @override
  Future<void> initialize() async {
    _logger.info('SMTCServiceWindows.initialize() called');
    
    if (_isInitialized) {
      _logger.info('SMTC already initialized, skipping');
      return;
    }

    if (!Platform.isWindows) {
      _logger.warning('Not on Windows platform (${Platform.operatingSystem}), cannot initialize SMTC');
      return;
    }

    try {
      _logger.info('Creating SMTCWindows instance...');
      _smtc = SMTCWindows(
        config: const SMTCConfig(
          fastForwardEnabled: false,
          nextEnabled: true,
          pauseEnabled: true,
          playEnabled: true,
          rewindEnabled: false,
          prevEnabled: true,
          stopEnabled: true,
        ),
      );
      _isInitialized = true;
      _logger.info('SMTC initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize SMTC: $e');
      _logger.error('Stack trace: $stackTrace');
    }
  }

  @override
  void setButtonListener({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
  }) {
    if (!_isInitialized || _smtc == null) {
      _logger.warning('Cannot set button listener: SMTC not initialized');
      return;
    }

    try {
      _smtc!.buttonPressStream.listen((event) {
        _logger.debug('SMTC button pressed: $event');
        switch (event) {
          case PressedButton.play:
            onPlay();
            break;
          case PressedButton.pause:
            onPause();
            break;
          case PressedButton.next:
            onNext();
            break;
          case PressedButton.previous:
            onPrevious();
            break;
          case PressedButton.stop:
            onStop();
            break;
          default:
            break;
        }
      });
    } catch (e) {
      _logger.error('Error setting button listener: $e');
    }
  }

  @override
  Future<void> updateMetadata(Song song, String? coverArtUrl) async {
    if (!_isInitialized || _smtc == null) return;

    try {
      await _smtc!.updateMetadata(
        MusicMetadata(
          title: song.title,
          album: song.albumName,
          artist: song.artistName,
          thumbnail: coverArtUrl,
        ),
      );
      _logger.debug('SMTC metadata updated: ${song.title}');
    } catch (e) {
      _logger.error('Failed to update SMTC metadata: $e');
    }
  }

  @override
  Future<void> setPlaybackStatus(int status) async {
    if (!_isInitialized || _smtc == null) return;

    try {
      PlaybackStatus playbackStatus;
      switch (status) {
        case 2:
          playbackStatus = PlaybackStatus.stopped;
          break;
        case 3:
          playbackStatus = PlaybackStatus.playing;
          break;
        case 4:
          playbackStatus = PlaybackStatus.paused;
          break;
        default:
          playbackStatus = PlaybackStatus.paused;
      }
      await _smtc!.setPlaybackStatus(playbackStatus);
      _logger.debug('SMTC playback status updated: $playbackStatus');
    } catch (e) {
      _logger.error('Failed to update SMTC playback status: $e');
    }
  }

  @override
  Future<void> updateTimeline({
    required int positionMs,
    required int durationMs,
  }) async {
    if (!_isInitialized || _smtc == null) return;

    try {
      await _smtc!.updateTimeline(
        PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: durationMs,
          positionMs: positionMs,
          minSeekTimeMs: 0,
          maxSeekTimeMs: durationMs,
        ),
      );
    } catch (e) {
      _logger.error('Failed to update SMTC timeline: $e');
    }
  }

  @override
  Future<void> enable() async {
    if (!_isInitialized || _smtc == null) return;
    try {
      await _smtc!.enableSmtc();
    } catch (e) {
      _logger.error('Failed to enable SMTC: $e');
    }
  }

  @override
  Future<void> disable() async {
    if (!_isInitialized || _smtc == null) return;
    try {
      await _smtc!.disableSmtc();
    } catch (e) {
      _logger.error('Failed to disable SMTC: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_smtc != null) {
      try {
        await _smtc!.dispose();
      } catch (e) {
        _logger.error('Error disposing SMTC: $e');
      }
      _smtc = null;
      _isInitialized = false;
      _logger.info('SMTC disposed');
    }
  }
}
