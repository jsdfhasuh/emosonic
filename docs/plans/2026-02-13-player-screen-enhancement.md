# 播放页面增强功能实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**目标:** 为播放页面添加音量控制、播放列表侧边栏、循环模式等功能

**架构:** 
- 使用 just_audio 的 API 控制音量、循环模式、随机播放
- 使用 shared_preferences 保存用户偏好设置
- 使用 Drawer 实现播放列表侧边栏
- 所有状态使用 Riverpod 管理

**技术栈:** Flutter, Riverpod, just_audio, shared_preferences

---

## 功能清单

1. **音量控制** - 在播放控制栏添加音量滑块
2. **播放列表侧边栏** - 从右侧滑出的播放队列
3. **循环模式** - 单曲循环/列表循环/不循环
4. **随机播放** - 切换随机播放模式
5. **播放速度** - 0.5x - 2.0x 速度调节（可选）

---

## Task 1: 扩展 AudioPlayerService 支持音量和播放模式

**文件:**
- 修改: `lib/services/audio_player_service.dart`

**步骤 1: 添加音量控制方法**

```dart
// Volume control
Future<void> setVolume(double volume) async {
  await _player.setVolume(volume.clamp(0.0, 1.0));
}

Stream<double> get volumeStream => _player.volumeStream;

Future<double> get currentVolume async => _player.volume;
```

**步骤 2: 添加循环模式控制**

```dart
// Loop mode
Future<void> setLoopMode(LoopMode mode) async {
  await _player.setLoopMode(mode);
}

Stream<LoopMode> get loopModeStream => _player.loopModeStream;

Future<LoopMode> get currentLoopMode async => _player.loopMode;
```

**步骤 3: 添加随机播放控制**

```dart
// Shuffle mode
Future<void> setShuffleModeEnabled(bool enabled) async {
  await _player.setShuffleModeEnabled(enabled);
}

Stream<bool> get shuffleModeEnabledStream => _player.shuffleModeEnabledStream;

Future<bool> get shuffleModeEnabled async => _player.shuffleModeEnabled;
```

**步骤 4: 运行静态分析**

运行: `flutter analyze lib/services/audio_player_service.dart`
预期: No errors

**步骤 5: 提交**

```bash
git add lib/services/audio_player_service.dart
git commit -m "feat: add volume, loop mode and shuffle controls to AudioPlayerService"
```

---

## Task 2: 创建播放设置 Provider

**文件:**
- 修改: `lib/providers/providers.dart`

**步骤 1: 创建音量 Provider**

```dart
// Volume Provider
final volumeProvider = StreamProvider<double>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.volumeStream;
});

final currentVolumeProvider = FutureProvider<double>((ref) async {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return await audioService.currentVolume;
});
```

**步骤 2: 创建循环模式 Provider**

```dart
// Loop Mode Provider
final loopModeProvider = StreamProvider<LoopMode>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.loopModeStream;
});

final currentLoopModeProvider = FutureProvider<LoopMode>((ref) async {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return await audioService.currentLoopMode;
});
```

**步骤 3: 创建随机播放 Provider**

```dart
// Shuffle Mode Provider
final shuffleModeProvider = StreamProvider<bool>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.shuffleModeEnabledStream;
});

final currentShuffleModeProvider = FutureProvider<bool>((ref) async {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return await audioService.shuffleModeEnabled;
});
```

**步骤 4: 导入 LoopMode**

```dart
import 'package:just_audio/just_audio.dart' show LoopMode;
```

**步骤 5: 运行静态分析**

运行: `flutter analyze lib/providers/providers.dart`
预期: No errors

**步骤 6: 提交**

```bash
git add lib/providers/providers.dart
git commit -m "feat: add volume, loop mode and shuffle providers"
```

---

## Task 3: 创建播放列表侧边栏组件

**文件:**
- 创建: `lib/ui/widgets/playlist_drawer.dart`

**步骤 1: 创建 PlaylistDrawer 组件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class PlaylistDrawer extends ConsumerWidget {
  const PlaylistDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);
    final currentSong = ref.watch(currentSongProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withAlpha(26),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.queue_music),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '播放队列',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${queue.length} 首歌曲',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: () {
                      // Clear queue
                      ref.read(queueProvider.notifier).clearQueue();
                      audioService.clearQueue();
                    },
                  ),
                ],
              ),
            ),
            
            // Queue List
            Expanded(
              child: queue.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_off, size: 64, color: Colors.white54),
                          SizedBox(height: 16),
                          Text('队列为空', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isCurrent = currentSong?.id == song.id;
                        
                        return ListTile(
                          leading: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent 
                                  ? const Color(0xFF6B8DD6) 
                                  : Colors.white54,
                              fontWeight: isCurrent 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                          title: Text(
                            song.title,
                            style: TextStyle(
                              color: isCurrent 
                                  ? const Color(0xFF6B8DD6) 
                                  : Colors.white,
                              fontWeight: isCurrent 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            song.artistName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(179),
                            ),
                          ),
                          trailing: isCurrent
                              ? const Icon(
                                  Icons.equalizer, 
                                  color: Color(0xFF6B8DD6), 
                                  size: 20,
                                )
                              : IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    ref.read(queueProvider.notifier)
                                        .removeFromQueue(song);
                                    audioService.removeFromQueue(song);
                                  },
                                ),
                          onTap: () async {
                            await audioService.playQueue(queue, startIndex: index);
                            ref.read(currentSongProvider.notifier).state = song;
                            ref.read(isPlayingProvider.notifier).state = true;
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**步骤 2: 运行静态分析**

运行: `flutter analyze lib/ui/widgets/playlist_drawer.dart`
预期: No errors

**步骤 3: 提交**

```bash
git add lib/ui/widgets/playlist_drawer.dart
git commit -m "feat: create playlist drawer widget"
```

---

## Task 4: 创建音量控制组件

**文件:**
- 创建: `lib/ui/widgets/volume_control.dart`

**步骤 1: 创建 VolumeControl 组件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class VolumeControl extends ConsumerWidget {
  const VolumeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeAsync = ref.watch(currentVolumeProvider);
    final volumeStream = ref.watch(volumeProvider);

    return volumeAsync.when(
      data: (initialVolume) {
        return StreamBuilder<double>(
          initialData: initialVolume,
          stream: volumeStream.asStream(),
          builder: (context, snapshot) {
            final volume = snapshot.data ?? initialVolume;
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    volume == 0 
                        ? Icons.volume_off 
                        : volume < 0.5 
                            ? Icons.volume_down 
                            : Icons.volume_up,
                    size: 24,
                  ),
                  onPressed: () {
                    final audioService = ref.read(audioPlayerServiceProvider);
                    if (volume > 0) {
                      audioService.setVolume(0);
                    } else {
                      audioService.setVolume(0.5);
                    }
                  },
                ),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: volume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    activeColor: const Color(0xFF6B8DD6),
                    inactiveColor: Colors.white.withAlpha(51),
                    onChanged: (value) {
                      final audioService = ref.read(audioPlayerServiceProvider);
                      audioService.setVolume(value);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

**步骤 2: 运行静态分析**

运行: `flutter analyze lib/ui/widgets/volume_control.dart`
预期: No errors

**步骤 3: 提交**

```bash
git add lib/ui/widgets/volume_control.dart
git commit -m "feat: create volume control widget"
```

---

## Task 5: 创建播放模式控制组件

**文件:**
- 创建: `lib/ui/widgets/playback_mode_controls.dart`

**步骤 1: 创建 PlaybackModeControls 组件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/providers.dart';

class PlaybackModeControls extends ConsumerWidget {
  const PlaybackModeControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loopModeAsync = ref.watch(currentLoopModeProvider);
    final shuffleModeAsync = ref.watch(currentShuffleModeProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shuffle button
        shuffleModeAsync.when(
          data: (isShuffled) {
            return StreamBuilder<bool>(
              initialData: isShuffled,
              stream: ref.watch(shuffleModeProvider).asStream(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? isShuffled;
                return IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: enabled 
                        ? const Color(0xFF6B8DD6) 
                        : Colors.white54,
                  ),
                  onPressed: () {
                    final audioService = ref.read(audioPlayerServiceProvider);
                    audioService.setShuffleModeEnabled(!enabled);
                  },
                );
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        
        // Loop mode button
        loopModeAsync.when(
          data: (loopMode) {
            return StreamBuilder<LoopMode>(
              initialData: loopMode,
              stream: ref.watch(loopModeProvider).asStream(),
              builder: (context, snapshot) {
                final mode = snapshot.data ?? loopMode;
                IconData icon;
                String tooltip;
                
                switch (mode) {
                  case LoopMode.off:
                    icon = Icons.repeat;
                    tooltip = '列表循环: 关闭';
                    break;
                  case LoopMode.one:
                    icon = Icons.repeat_one;
                    tooltip = '单曲循环';
                    break;
                  case LoopMode.all:
                    icon = Icons.repeat;
                    tooltip = '列表循环';
                    break;
                }
                
                return IconButton(
                  icon: Icon(
                    icon,
                    color: mode == LoopMode.off 
                        ? Colors.white54 
                        : const Color(0xFF6B8DD6),
                  ),
                  tooltip: tooltip,
                  onPressed: () {
                    final audioService = ref.read(audioPlayerServiceProvider);
                    LoopMode nextMode;
                    switch (mode) {
                      case LoopMode.off:
                        nextMode = LoopMode.all;
                        break;
                      case LoopMode.all:
                        nextMode = LoopMode.one;
                        break;
                      case LoopMode.one:
                        nextMode = LoopMode.off;
                        break;
                    }
                    audioService.setLoopMode(nextMode);
                  },
                );
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
```

**步骤 2: 运行静态分析**

运行: `flutter analyze lib/ui/widgets/playback_mode_controls.dart`
预期: No errors

**步骤 3: 提交**

```bash
git add lib/ui/widgets/playback_mode_controls.dart
git commit -m "feat: create playback mode controls widget"
```

---

## Task 6: 修改 PlayerScreen 集成所有功能

**文件:**
- 修改: `lib/ui/screens/player_screen.dart`

**步骤 1: 添加导入**

```dart
import '../widgets/playlist_drawer.dart';
import '../widgets/volume_control.dart';
import '../widgets/playback_mode_controls.dart';
```

**步骤 2: 添加 endDrawer**

在 Scaffold 中添加：
```dart
endDrawer: const PlaylistDrawer(),
```

**步骤 3: 修改 AppBar 添加播放列表按钮**

```dart
appBar: AppBar(
  title: const Text('正在播放'),
  actions: [
    const PlaybackModeControls(),
    IconButton(
      icon: const Icon(Icons.queue_music),
      onPressed: () {
        Scaffold.of(context).openEndDrawer();
      },
    ),
  ],
),
```

**步骤 4: 在控制栏添加音量控制**

在 Controls section 添加 VolumeControl：
```dart
// Controls
Flexible(
  flex: 2,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const PlaybackModeControls(),
      const SizedBox(width: 16),
      IconButton(
        iconSize: 40,
        icon: const Icon(Icons.skip_previous),
        onPressed: () async {
          await audioService.playPrevious();
          final newSong = audioService.currentSong;
          if (newSong != null) {
            ref.read(currentSongProvider.notifier).state = newSong;
          }
        },
      ),
      const SizedBox(width: 24),
      IconButton(
        iconSize: 64,
        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
        onPressed: () async {
          if (isPlaying) {
            await audioService.pause();
            ref.read(isPlayingProvider.notifier).state = false;
          } else {
            await audioService.play();
            ref.read(isPlayingProvider.notifier).state = true;
          }
        },
      ),
      const SizedBox(width: 24),
      IconButton(
        iconSize: 40,
        icon: const Icon(Icons.skip_next),
        onPressed: () async {
          await audioService.playNext();
          final newSong = audioService.currentSong;
          if (newSong != null) {
            ref.read(currentSongProvider.notifier).state = newSong;
          }
        },
      ),
      const SizedBox(width: 16),
      const VolumeControl(),
    ],
  ),
),
```

**步骤 5: 运行静态分析**

运行: `flutter analyze lib/ui/screens/player_screen.dart`
预期: No errors

**步骤 6: 提交**

```bash
git add lib/ui/screens/player_screen.dart
git commit -m "feat: integrate volume, playlist and playback mode controls into PlayerScreen"
```

---

## Task 7: 保存用户偏好设置

**文件:**
- 修改: `lib/providers/providers.dart`

**步骤 1: 创建设置 Provider**

```dart
// Playback Settings Provider
final playbackSettingsProvider = StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>((ref) {
  return PlaybackSettingsNotifier();
});

class PlaybackSettings {
  final double volume;
  final LoopMode loopMode;
  final bool shuffleMode;

  const PlaybackSettings({
    this.volume = 1.0,
    this.loopMode = LoopMode.off,
    this.shuffleMode = false,
  });

  PlaybackSettings copyWith({
    double? volume,
    LoopMode? loopMode,
    bool? shuffleMode,
  }) {
    return PlaybackSettings(
      volume: volume ?? this.volume,
      loopMode: loopMode ?? this.loopMode,
      shuffleMode: shuffleMode ?? this.shuffleMode,
    );
  }
}

class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettings> {
  static const String _volumeKey = 'playback_volume';
  static const String _loopModeKey = 'playback_loop_mode';
  static const String _shuffleKey = 'playback_shuffle';

  PlaybackSettingsNotifier() : super(const PlaybackSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final volume = prefs.getDouble(_volumeKey) ?? 1.0;
    final loopModeIndex = prefs.getInt(_loopModeKey) ?? 0;
    final shuffle = prefs.getBool(_shuffleKey) ?? false;
    
    state = PlaybackSettings(
      volume: volume,
      loopMode: LoopMode.values[loopModeIndex],
      shuffleMode: shuffle,
    );
  }

  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, volume);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    state = state.copyWith(loopMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_loopModeKey, mode.index);
  }

  Future<void> setShuffleMode(bool enabled) async {
    state = state.copyWith(shuffleMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shuffleKey, enabled);
  }
}
```

**步骤 2: 在应用启动时应用设置**

在 main.dart 中初始化音频服务后应用设置：
```dart
// Apply saved playback settings
final settings = container.read(playbackSettingsProvider);
final audioService = container.read(audioPlayerServiceProvider);
audioService.setVolume(settings.volume);
audioService.setLoopMode(settings.loopMode);
audioService.setShuffleModeEnabled(settings.shuffleMode);
```

**步骤 3: 监听设置变化并保存**

在 VolumeControl 和 PlaybackModeControls 中监听变化并保存：
```dart
// 在 onChanged 中
final settingsNotifier = ref.read(playbackSettingsProvider.notifier);
settingsNotifier.setVolume(value);
```

**步骤 4: 运行静态分析**

运行: `flutter analyze lib/providers/providers.dart`
预期: No errors

**步骤 5: 提交**

```bash
git add lib/providers/providers.dart lib/main.dart
git commit -m "feat: add playback settings persistence with shared_preferences"
```

---

## Task 8: 最终验证

**步骤 1: 运行所有测试**

```bash
flutter test
```
预期: All tests pass

**步骤 2: 运行静态分析**

```bash
flutter analyze
```
预期: No issues found

**步骤 3: 手动测试验证**

1. **音量控制**:
   - 打开播放页面
   - 调节音量滑块
   - 点击静音按钮
   - 检查音量是否正确变化

2. **播放列表**:
   - 点击播放列表按钮
   - 侧边栏从右侧滑出
   - 显示当前队列
   - 点击歌曲可以切换
   - 可以移除歌曲

3. **循环模式**:
   - 点击循环按钮切换模式
   - 检查图标变化（不循环/列表循环/单曲循环）
   - 验证实际播放行为

4. **随机播放**:
   - 点击随机按钮
   - 检查图标颜色变化
   - 验证播放顺序是否随机

5. **设置持久化**:
   - 修改音量/循环模式/随机播放
   - 重启应用
   - 检查设置是否保留

**步骤 4: 提交最终更改**

```bash
git commit -m "feat: complete player screen enhancement with volume, playlist and playback controls"
```

---

## 注意事项

1. **UI 布局**: 确保在小屏幕上所有控件都能正常显示
2. **性能**: 使用 StreamBuilder 避免不必要的重建
3. **错误处理**: 所有异步操作都有错误处理
4. **用户体验**: 添加适当的 tooltip 和视觉反馈
5. **状态同步**: 确保 UI 状态与音频播放器状态同步
