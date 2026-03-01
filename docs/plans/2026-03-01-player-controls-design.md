# 播放页面控制控件增强 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在播放页面 AppBar 添加"更多"菜单按钮，集成播放速度调节和定时关闭功能；同时确保窄屏（Android）下音量按钮可从更多菜单访问。

**Architecture:**
- 播放速度：使用 `just_audio` 的 `setSpeed()` API，通过 Riverpod StateNotifier 管理状态并持久化到 SharedPreferences
- 定时关闭：复用已有的 `sleepTimerProvider` / `SleepTimerNotifier`，在更多菜单中提供入口
- 更多菜单：使用 bottom sheet（与项目现有模式一致），包含各功能入口
- 窄屏适配：在 `isNarrow` 模式下隐藏的音量按钮改为在更多菜单中提供入口

**Tech Stack:** Flutter, Riverpod, just_audio, shared_preferences

---

## 现有资产清单

| 资产 | 文件 | 状态 |
|------|------|------|
| 音量控制 | `lib/ui/widgets/volume_control.dart` | 已实现，bottom sheet 风格 |
| 播放模式 | `lib/ui/widgets/playback_mode_controls.dart` | 已实现 |
| 定时关闭 | `lib/providers/sleep_timer_provider.dart` | 已实现，有 countdown 和 scheduled 两种模式 |
| AudioPlayerService | `lib/services/audio_player_service.dart` | 有 setVolume/setLoopMode 等，无 setSpeed |
| PlayerScreen | `lib/ui/screens/player_screen.dart` | 现有 AppBar: PlaybackModeControls + queue_music 按钮 |

---

## Task 1: 扩展 AudioPlayerService 支持播放速度

**Files:**
- Modify: `lib/services/audio_player_service.dart`

**Step 1: 添加播放速度控制方法**

在 `audio_player_service.dart` 的 shuffle mode 区域之后（约 970 行），添加：

```dart
// Playback speed control
Future<void> setSpeed(double speed) async {
  final clampedSpeed = speed.clamp(0.5, 2.0);
  _logger.debug('Setting playback speed to: $clampedSpeed');
  await _player.setSpeed(clampedSpeed);
}

Stream<double> get speedStream => _player.speedStream;

double get currentSpeed => _player.speed;
```

**Step 2: 运行静态分析**

Run: `flutter analyze lib/services/audio_player_service.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/services/audio_player_service.dart
git commit -m "feat: add playback speed control to AudioPlayerService"
```

---

## Task 2: 创建播放速度 Provider

**Files:**
- Modify: `lib/providers/providers.dart`

**Step 1: 添加速度 StreamProvider**

在 `shuffleModeProvider` 之后（约 359 行），添加：

```dart
// Playback Speed Provider
final speedProvider = StreamProvider<double>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.speedStream;
});
```

**Step 2: 创建持久化 Provider**

在文件末尾（`cachedSongsProvider` 之后），添加：

```dart
// Playback speed setting (persisted)
final playbackSpeedSettingProvider = StateNotifierProvider<PlaybackSpeedSettingNotifier, double>((ref) {
  return PlaybackSpeedSettingNotifier();
});

class PlaybackSpeedSettingNotifier extends StateNotifier<double> {
  static const double defaultSpeed = 1.0;

  PlaybackSpeedSettingNotifier() : super(defaultSpeed) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('playback_speed') ?? defaultSpeed;
  }

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('playback_speed', clamped);
    state = clamped;
  }
}
```

**Step 3: 运行静态分析**

Run: `flutter analyze lib/providers/providers.dart`
Expected: No issues

**Step 4: Commit**

```bash
git add lib/providers/providers.dart
git commit -m "feat: add playback speed provider with persistence"
```

---

## Task 3: 在应用启动时恢复播放速度

**Files:**
- Modify: `lib/main.dart`

**Step 1: 在 restorePlaybackState 完成后应用速度设置**

在 `main.dart` 中，找到播放状态恢复逻辑完成的位置，添加：

```dart
// Apply saved playback speed
final savedSpeed = container.read(playbackSpeedSettingProvider);
if (savedSpeed != 1.0) {
  final audioService = container.read(audioPlayerServiceProvider);
  audioService.setSpeed(savedSpeed);
}
```

需要添加导入：
```dart
import 'providers/sleep_timer_provider.dart'; // 如果还没有
```

**Step 2: 运行静态分析**

Run: `flutter analyze lib/main.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: restore playback speed on app startup"
```

---

## Task 4: 创建"更多"菜单 Bottom Sheet 组件

**Files:**
- Create: `lib/ui/widgets/player_more_menu.dart`

**Step 1: 创建组件**

```dart
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
      return _PlayerMoreMenuContent(showVolumeEntry: showVolumeEntry);
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
    final audioService = ref.read(audioPlayerServiceProvider);
    final volume = audioService.currentVolume;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
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
                    stream: audioService.volumeStream,
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
                              audioService.setVolume(value);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
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
```

**Step 2: 运行静态分析**

Run: `flutter analyze lib/ui/widgets/player_more_menu.dart`
Expected: No issues

**Step 3: Commit**

```bash
git add lib/ui/widgets/player_more_menu.dart
git commit -m "feat: create player more menu with speed and sleep timer"
```

---

## Task 5: 修改 PlayerScreen 集成更多菜单

**Files:**
- Modify: `lib/ui/screens/player_screen.dart`

**Step 1: 添加导入**

在现有 import 区域添加：

```dart
import '../widgets/player_more_menu.dart';
```

**Step 2: 将 PlayerScreen 从 ConsumerWidget 改为 ConsumerStatefulWidget**

需要 `ConsumerStatefulWidget` 来使用 `WidgetRef` 传递给 `showPlayerMoreMenu`。

```dart
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // ... build method moved here, replace ref.watch -> ref.watch, ref.read -> ref.read
```

**Step 3: 修改 AppBar actions**

将 AppBar 的 actions 修改为：

```dart
actions: [
  const PlaybackModeControls(),
  IconButton(
    icon: const Icon(Icons.more_vert),
    onPressed: () {
      // Check if narrow screen for volume entry
      final screenWidth = MediaQuery.of(context).size.width;
      final isNarrow = screenWidth < 400;
      showPlayerMoreMenu(context, ref, showVolumeEntry: isNarrow);
    },
  ),
  Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.queue_music),
      onPressed: () {
        Scaffold.of(context).openEndDrawer();
      },
    ),
  ),
],
```

**Step 4: 运行静态分析**

Run: `flutter analyze lib/ui/screens/player_screen.dart`
Expected: No issues

**Step 5: Commit**

```bash
git add lib/ui/screens/player_screen.dart
git commit -m "feat: add more menu button to player screen AppBar"
```

---

## Task 6: 最终验证

**Step 1: 运行完整静态分析**

Run: `flutter analyze`
Expected: No issues found

**Step 2: 运行测试**

Run: `flutter test`
Expected: All tests pass

**Step 3: 手动测试清单**

1. **更多菜单入口**:
   - 打开播放页面
   - 点击 AppBar 中的 `⋮` 按钮
   - 验证 bottom sheet 弹出，显示"播放速度"和"定时关闭"

2. **播放速度**:
   - 在更多菜单点击"播放速度"
   - 选择 1.5x
   - 验证音乐播放加速
   - 再次打开菜单，显示 1.5x
   - 选择 1.0x 恢复正常
   - 重启应用，验证速度设置被保留

3. **定时关闭**:
   - 在更多菜单点击"定时关闭"
   - 选择 15 分钟
   - 返回更多菜单，显示"倒计时: 15 分钟"
   - 点击"取消定时"
   - 验证状态回到"未设置"

4. **窄屏音量**:
   - 在 Android 设备上测试
   - 更多菜单中应显示"音量调节"入口
   - 点击后弹出音量调节 bottom sheet

5. **速度持久化**:
   - 设置速度为 1.25x
   - 关闭并重启应用
   - 播放歌曲，验证速度仍为 1.25x

**Step 4: 最终提交**

```bash
git add -A
git commit -m "feat: complete player controls enhancement with speed and sleep timer"
```

---

## 注意事项

1. **不修改现有 VolumeControl 组件** — 仅在窄屏 more menu 中提供二级入口
2. **不修改 PlaybackModeControls** — 保持 AppBar 中已有的位置
3. **歌词和输出设备** — 当前无实现，不在 more menu 中显示
4. **Bottom sheet 风格** — 与项目中 VolumeControl、PlaylistDrawer 等保持一致
5. **播放速度范围** — 0.5x ~ 2.0x，`just_audio` 原生支持
6. **定时关闭** — 完全复用 `sleep_timer_provider.dart`，零新逻辑
