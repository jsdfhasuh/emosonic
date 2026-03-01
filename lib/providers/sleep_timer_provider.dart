import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/logger.dart';
import '../services/audio_player_service.dart';
import 'providers.dart';

/// Sleep timer mode
enum SleepTimerMode {
  countdown,
  scheduled,
}

/// Sleep timer state
class SleepTimerState {
  final bool isActive;
  final SleepTimerMode? mode;
  final DateTime? targetTime;
  final int? remainingMinutes;
  final DateTime? createdAt;

  const SleepTimerState({
    this.isActive = false,
    this.mode,
    this.targetTime,
    this.remainingMinutes,
    this.createdAt,
  });

  SleepTimerState copyWith({
    bool? isActive,
    SleepTimerMode? mode,
    DateTime? targetTime,
    int? remainingMinutes,
    DateTime? createdAt,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      targetTime: targetTime ?? this.targetTime,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayText {
    if (!isActive) return '未设置';
    
    if (mode == SleepTimerMode.countdown && remainingMinutes != null) {
      return '倒计时: $remainingMinutes 分钟';
    }
    
    if (mode == SleepTimerMode.scheduled && targetTime != null) {
      final hour = targetTime!.hour.toString().padLeft(2, '0');
      final minute = targetTime!.minute.toString().padLeft(2, '0');
      return '定时: $hour:$minute';
    }
    
    return '未设置';
  }
}

/// Provider for sleep timer
final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier(ref);
});

/// Notifier for managing sleep timer
class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  static const String _prefsKey = 'sleep_timer_state';
  final Logger _logger = Logger('SleepTimerNotifier');
  final Ref _ref;
  Timer? _timer;

  SleepTimerNotifier(this._ref) : super(const SleepTimerState()) {
    _loadState();
  }

  /// Load saved state from preferences
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(_prefsKey);
      
      if (stateJson != null) {
        // Parse saved state and restore timer if needed
        _logger.info('Loaded sleep timer state: $stateJson');
        // TODO: Implement state restoration
      }
    } catch (e) {
      _logger.error('Failed to load sleep timer state: $e');
    }
  }

  /// Save current state to preferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // TODO: Implement state serialization
      _logger.info('Saved sleep timer state');
    } catch (e) {
      _logger.error('Failed to save sleep timer state: $e');
    }
  }

  /// Set countdown timer (in minutes)
  Future<void> setCountdown(int minutes) async {
    // Cancel existing timer
    cancelTimer();
    
    final targetTime = DateTime.now().add(Duration(minutes: minutes));
    
    state = SleepTimerState(
      isActive: true,
      mode: SleepTimerMode.countdown,
      targetTime: targetTime,
      remainingMinutes: minutes,
      createdAt: DateTime.now(),
    );
    
    _logger.info('Set countdown timer: $minutes minutes');
    
    // Start timer
    _startTimer();
    await _saveState();
  }

  /// Set scheduled timer (specific time)
  Future<void> setScheduled(DateTime targetTime) async {
    // Cancel existing timer
    cancelTimer();
    
    // If target time is in the past, assume it's for tomorrow
    DateTime adjustedTime = targetTime;
    if (targetTime.isBefore(DateTime.now())) {
      adjustedTime = targetTime.add(const Duration(days: 1));
    }
    
    state = SleepTimerState(
      isActive: true,
      mode: SleepTimerMode.scheduled,
      targetTime: adjustedTime,
      createdAt: DateTime.now(),
    );
    
    _logger.info('Set scheduled timer: ${adjustedTime.toIso8601String()}');
    
    // Start timer
    _startTimer();
    await _saveState();
  }

  /// Cancel current timer
  Future<void> cancelTimer() async {
    _timer?.cancel();
    _timer = null;
    
    state = const SleepTimerState(isActive: false);
    
    _logger.info('Cancelled sleep timer');
    await _saveState();
  }

  /// Start the timer
  void _startTimer() {
    _timer?.cancel();
    
    if (!state.isActive || state.targetTime == null) return;
    
    final now = DateTime.now();
    final duration = state.targetTime!.difference(now);
    
    if (duration.isNegative) {
      // Target time has already passed
      _logger.warning('Target time has already passed');
      cancelTimer();
      return;
    }
    
    _logger.info('Starting timer for ${duration.inMinutes} minutes');
    
    _timer = Timer(duration, () async {
      await _onTimerComplete();
    });
    
    // Update remaining minutes periodically for countdown mode
    if (state.mode == SleepTimerMode.countdown) {
      _startCountdownUpdates();
    }
  }

  /// Start periodic updates for countdown display
  void _startCountdownUpdates() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!state.isActive || state.targetTime == null) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final remaining = state.targetTime!.difference(now);
      
      if (remaining.isNegative) {
        timer.cancel();
        return;
      }
      
      state = state.copyWith(remainingMinutes: remaining.inMinutes);
    });
  }

  /// Called when timer completes
  Future<void> _onTimerComplete() async {
    _logger.info('Sleep timer completed, pausing playback');
    
    try {
      // Get audio service and pause
      final audioService = _ref.read(audioPlayerServiceProvider);
      await audioService.pause();
      
      _logger.info('Playback paused by sleep timer');
    } catch (e) {
      _logger.error('Failed to pause playback: $e');
    }
    
    // Clear timer state
    state = const SleepTimerState(isActive: false);
    await _saveState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
