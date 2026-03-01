import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/logger.dart';

/// Provider for auto resume playback setting
final autoResumePlaybackProvider = StateNotifierProvider<AutoResumePlaybackNotifier, bool>((ref) {
  return AutoResumePlaybackNotifier();
});

/// Notifier for managing auto resume playback setting
class AutoResumePlaybackNotifier extends StateNotifier<bool> {
  static const String _prefsKey = 'auto_resume_playback';
  static const bool _defaultValue = false;
  final Logger _logger = Logger('AutoResumePlaybackNotifier');
  bool _isInitialized = false;

  AutoResumePlaybackNotifier() : super(_defaultValue) {
    _loadSetting();
  }

  /// Check if the setting has been loaded from storage
  bool get isInitialized => _isInitialized;

  Future<void> _loadSetting() async {
    _logger.info('[DEBUG] _loadSetting() called, starting to load...');
    try {
      _logger.info('[DEBUG] Getting SharedPreferences instance...');
      final prefs = await SharedPreferences.getInstance();
      _logger.info('[DEBUG] SharedPreferences instance obtained');
      
      _logger.info('[DEBUG] Reading key: $_prefsKey');
      final value = prefs.getBool(_prefsKey);
      _logger.info('[DEBUG] Raw value from prefs: $value');
      
      state = value ?? _defaultValue;
      _isInitialized = true;
      _logger.info('[DEBUG] Final state set to: $state (default was: $_defaultValue)');
      _logger.info('Loaded auto resume playback setting: $state');
    } catch (e, stackTrace) {
      _logger.error('[DEBUG] Exception in _loadSetting: $e');
      _logger.error('[DEBUG] Stack trace: $stackTrace');
      state = _defaultValue;
      _isInitialized = true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
      state = enabled;
      _logger.info('Auto resume playback setting updated: $enabled');
    } catch (e) {
      _logger.error('Failed to save auto resume playback setting: $e');
    }
  }
}

/// Model for playback state
class PlaybackState {
  final List<String> queue;
  final int currentIndex;
  final int positionMs;
  final DateTime savedAt;

  const PlaybackState({
    required this.queue,
    required this.currentIndex,
    required this.positionMs,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'queue': queue,
      'currentIndex': currentIndex,
      'positionMs': positionMs,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory PlaybackState.fromJson(Map<String, dynamic> json) {
    return PlaybackState(
      queue: List<String>.from(json['queue'] ?? []),
      currentIndex: json['currentIndex'] ?? 0,
      positionMs: json['positionMs'] ?? 0,
      savedAt: DateTime.parse(json['savedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Provider for playback state persistence
final playbackStatePersistenceProvider = Provider<PlaybackStatePersistence>((ref) {
  return PlaybackStatePersistence();
});

/// Class for persisting and restoring playback state
class PlaybackStatePersistence {
  static const String _queueKey = 'last_playback_queue';
  static const String _indexKey = 'last_playback_index';
  static const String _positionKey = 'last_playback_position';
  static const String _savedAtKey = 'last_playback_saved_at';
  final Logger _logger = Logger('PlaybackStatePersistence');

  /// Save current playback state
  Future<void> savePlaybackState({
    required List<String> queue,
    required int currentIndex,
    required int positionMs,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_queueKey, queue);
      await prefs.setInt(_indexKey, currentIndex);
      await prefs.setInt(_positionKey, positionMs);
      await prefs.setString(_savedAtKey, DateTime.now().toIso8601String());
      _logger.debug('Playback state saved: index=$currentIndex, position=${positionMs}ms, queue=${queue.length} songs');
    } catch (e) {
      _logger.error('Failed to save playback state: $e');
    }
  }

  /// Load saved playback state
  Future<PlaybackState?> loadPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey);
      
      if (queue == null || queue.isEmpty) {
        _logger.debug('No saved playback state found');
        return null;
      }

      final currentIndex = prefs.getInt(_indexKey) ?? 0;
      final positionMs = prefs.getInt(_positionKey) ?? 0;
      final savedAtStr = prefs.getString(_savedAtKey);
      
      return PlaybackState(
        queue: queue,
        currentIndex: currentIndex.clamp(0, queue.length - 1),
        positionMs: positionMs,
        savedAt: savedAtStr != null ? DateTime.parse(savedAtStr) : DateTime.now(),
      );
    } catch (e) {
      _logger.error('Failed to load playback state: $e');
      return null;
    }
  }

  /// Clear saved playback state
  Future<void> clearPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_indexKey);
      await prefs.remove(_positionKey);
      await prefs.remove(_savedAtKey);
      _logger.info('Playback state cleared');
    } catch (e) {
      _logger.error('Failed to clear playback state: $e');
    }
  }
}
