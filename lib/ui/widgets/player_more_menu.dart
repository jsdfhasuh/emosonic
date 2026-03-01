import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../providers/sleep_timer_provider.dart';

/// Show the "more options" bottom sheet on the player screen.
void showPlayerMoreMenu(BuildContext context, WidgetRef ref, {bool showVolumeEntry = false}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: _PlayerMoreMenuContent(showVolumeEntry: showVolumeEntry),
      );
    },
  );
}

class _PlayerMoreMenuContent extends ConsumerWidget {
  final bool showVolumeEntry;

  const _PlayerMoreMenuContent({required this.showVolumeEntry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepTimerState = ref.watch(sleepTimerProvider);
    final speedAsync = ref.watch(speedProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '更多选项',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Volume entry (only on narrow screens)
          if (showVolumeEntry)
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('音量调节'),
              onTap: () {
                Navigator.pop(context);
                // Reuse existing VolumeControl bottom sheet
                _showVolumeBottomSheet(context, ref);
              },
            ),

          // Playback speed
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('播放速度'),
            trailing: speedAsync.when(
              data: (speed) => Text(
                '${speed.toStringAsFixed(1)}x',
                style: const TextStyle(color: Color(0xFF6B8DD6)),
              ),
              loading: () => const Text('1.0x'),
              error: (_, __) => const Text('1.0x'),
            ),
            onTap: () {
              Navigator.pop(context);
              _showSpeedPicker(context, ref);
            },
          ),

          // Sleep timer
          ListTile(
            leading: Icon(
              Icons.timer,
              color: sleepTimerState.isActive ? const Color(0xFF6B8DD6) : null,
            ),
            title: const Text('定时关闭'),
            trailing: Text(
              sleepTimerState.displayText,
              style: TextStyle(
                color: sleepTimerState.isActive
                    ? const Color(0xFF6B8DD6)
                    : Colors.white54,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showSleepTimerPicker(context, ref, sleepTimerState);
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Open the existing VolumeControl bottom sheet.
  void _showVolumeBottomSheet(BuildContext context, WidgetRef ref) {
    final volumeAsync = ref.watch(volumeProvider);

    volumeAsync.when(
      data: (volume) {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E293B),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '音量调节',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<double>(
                      stream: ref.read(audioPlayerServiceProvider).volumeStream,
                      initialData: volume,
                      builder: (context, snapshot) {
                        final v = snapshot.data ?? volume;
                        return Column(
                          children: [
                            Text(
                              '${(v * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B8DD6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Slider(
                              value: v,
                              min: 0,
                              max: 1,
                              divisions: 100,
                              activeColor: const Color(0xFF6B8DD6),
                              inactiveColor: Colors.white.withAlpha(26),
                              onChanged: (value) {
                                ref.read(audioPlayerServiceProvider).setVolume(value);
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Show playback speed picker bottom sheet.
  void _showSpeedPicker(BuildContext context, WidgetRef ref) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final currentSpeed = audioService.currentSpeed;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '播放速度',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ...speeds.map((speed) {
                final isSelected = (speed - currentSpeed).abs() < 0.01;
                return ListTile(
                  title: Text(
                    '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 1 : 2)}x',
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF6B8DD6) : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF6B8DD6))
                      : null,
                  onTap: () {
                    audioService.setSpeed(speed);
                    ref.read(playbackSpeedSettingProvider.notifier).setSpeed(speed);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Show sleep timer picker bottom sheet.
  void _showSleepTimerPicker(
    BuildContext context,
    WidgetRef ref,
    SleepTimerState currentState,
  ) {
    final countdownOptions = [15, 30, 45, 60, 90, 120];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '定时关闭',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (currentState.isActive)
                      TextButton(
                        onPressed: () {
                          ref.read(sleepTimerProvider.notifier).cancelTimer();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '取消定时',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
              if (currentState.isActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 16, color: Color(0xFF6B8DD6)),
                      const SizedBox(width: 8),
                      Text(
                        '当前: ${currentState.displayText}',
                        style: const TextStyle(color: Color(0xFF6B8DD6)),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              ...countdownOptions.map((minutes) {
                final label = minutes >= 60
                    ? '${minutes ~/ 60} 小时${minutes % 60 > 0 ? ' ${minutes % 60} 分钟' : ''}'
                    : '$minutes 分钟';
                return ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: Text(label),
                  onTap: () {
                    ref.read(sleepTimerProvider.notifier).setCountdown(minutes);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
