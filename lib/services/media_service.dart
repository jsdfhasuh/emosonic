import '../data/models/models.dart';

/// Unified Media Service Interface
/// Provides media control functionality for both Windows and Android
abstract class MediaService {
  /// Initialize the media service
  Future<void> initialize();

  /// Set up media button listeners (play, pause, next, previous, stop)
  void setMediaButtonListener({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
    required Function() onStop,
  });

  /// Update media metadata (song info, album art)
  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? artUri,
    Duration? duration,
  });

  /// Update playback state
  /// isPlaying: true = playing, false = paused
  /// position: current playback position
  /// bufferedPosition: buffered duration
  Future<void> setPlaybackState({
    required bool isPlaying,
    required Duration position,
    Duration? bufferedPosition,
    Duration? duration,
  });

  /// Update queue (for Android notification)
  /// [getArtUri] is a function that takes a song and returns the full artwork URL
  Future<void> updateQueue(List<Song> queue, int currentIndex, {String? Function(Song song)? getArtUri});

  /// Enable/disable media controls
  Future<void> setEnabled(bool enabled);

  /// Dispose the media service
  Future<void> dispose();
}
