# Shuffle Queue State Consistency Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让随机播放状态与队列顺序一致，UI 状态不再掉落，且跨队列持续随机

**Architecture:** 用 AudioPlayerService 维护唯一 shuffle 状态源，UI 订阅这个状态；playQueue 在 shuffle 开启时立即打乱新队列并保持当前歌在队首

**Tech Stack:** Flutter, Riverpod, just_audio

---

### Task 1: 定义统一 shuffle 状态流（AudioPlayerService）

**Files:**
- Modify: `lib/services/audio_player_service.dart`

**Step 1: Write the failing test**

由于当前测试环境已有大量失败，暂不新增自动化测试。改为手动验证（见 Task 5）。

**Step 2: Run test to verify it fails**

跳过（已有既存失败）。

**Step 3: Write minimal implementation**

```dart
final _shuffleModeController = StreamController<bool>.broadcast();
Stream<bool> get shuffleModeStateStream => _shuffleModeController.stream;
```

在 `setShuffleModeEnabled()` 内：

```dart
_shuffleModeEnabled = enabled;
_shuffleModeController.add(enabled);
```

`playQueue()` 不再重置 shuffle 状态。当 `_shuffleModeEnabled == true` 时，
对新队列立即 shuffle 并把当前歌曲放在队首。

**Step 4: Run test to verify it passes**

手动验证（Task 5）。

**Step 5: Commit**

```bash
git add lib/services/audio_player_service.dart
git commit -m "fix: unify shuffle state source and preserve shuffle across queues"
```

---

### Task 2: 让 UI 使用新的 shuffle 状态流

**Files:**
- Modify: `lib/providers/providers.dart`
- Modify: `lib/ui/widgets/playback_mode_controls.dart`

**Step 1: Write the failing test**

暂不新增自动化测试。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

`shuffleModeProvider` 改为监听 `audioService.shuffleModeStateStream`：

```dart
final shuffleModeProvider = StreamProvider<bool>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.shuffleModeStateStream;
});
```

`PlaybackModeControls` 继续使用该 provider，并保持持久化：

```dart
await ref.read(shuffleModeSettingProvider.notifier).setShuffleMode(newState);
```

**Step 4: Run test to verify it passes**

手动验证（Task 5）。

**Step 5: Commit**

```bash
git add lib/providers/providers.dart lib/ui/widgets/playback_mode_controls.dart
git commit -m "fix: bind shuffle UI to service state stream"
```

---

### Task 3: 处理跨队列持续随机

**Files:**
- Modify: `lib/services/audio_player_service.dart`

**Step 1: Write the failing test**

暂不新增自动化测试。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

`playQueue()` 修改：

```dart
if (_shuffleModeEnabled) {
  _originalQueue = List<Song>.from(songs);
  _queue.clear();
  _queue.addAll(songs);
  _shuffleQueueKeepingCurrent();
  _currentIndex = 0;
}
```

其中 `_shuffleQueueKeepingCurrent()` 的职责：
- 打乱 `_queue`
- 当前播放歌移到 index 0

**Step 4: Run test to verify it passes**

手动验证（Task 5）。

**Step 5: Commit**

```bash
git add lib/services/audio_player_service.dart
git commit -m "fix: keep shuffle on new queues"
```

---

### Task 4: 启动时恢复 shuffle 状态并同步 UI

**Files:**
- Modify: `lib/main.dart`

**Step 1: Write the failing test**

暂不新增自动化测试。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

在 `_restorePlaybackState()` 中：

```dart
final savedShuffleMode = container.read(shuffleModeSettingProvider);
await audioService.setShuffleModeEnabled(savedShuffleMode);
```

**Step 4: Run test to verify it passes**

手动验证（Task 5）。

**Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "fix: restore shuffle state on startup"
```

---

### Task 5: 手动验证

**Steps:**
1. 开启随机播放 → 图标变亮
2. 连续点击下一首 5 次 → 播放顺序为打乱队列
3. 进入任意列表点击播放新歌 → 随机仍保持，队列显示为打乱顺序
4. 关闭随机播放 → 队列恢复原始顺序
5. 再次开启随机 → 队列重新打乱
6. 重启应用 → 随机状态恢复

**Expected:** UI 状态与队列顺序完全一致

---

### Task 6: 修复随机播放按钮启动时消失的问题

**Files:**
- Modify: `lib/providers/providers.dart`
- Modify: `lib/ui/widgets/playback_mode_controls.dart`

**Step 1: Write the failing test**

暂不新增自动化测试。手动验证：启动应用后随机播放按钮应该可见。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

将 `shuffleModeProvider` 从 `StreamProvider` 改为 `StateNotifierProvider`，确保有初始值：

```dart
// Shuffle Mode Provider - 使用 StateNotifierProvider 确保有初始值
final shuffleModeProvider = StateNotifierProvider<ShuffleModeNotifier, bool>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return ShuffleModeNotifier(audioService);
});

class ShuffleModeNotifier extends StateNotifier<bool> {
  StreamSubscription<bool>? _subscription;
  
  ShuffleModeNotifier(AudioPlayerService audioService) : super(false) {
    // 立即获取当前状态
    state = audioService.shuffleModeEnabled;
    
    // 监听状态变化
    _subscription = audioService.shuffleModeStateStream.listen((enabled) {
      state = enabled;
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

修改 `PlaybackModeControls` 使用新的 provider：

```dart
final shuffleMode = ref.watch(shuffleModeProvider);
// ...
IconButton(
  icon: Icon(
    Icons.shuffle,
    color: shuffleMode 
        ? const Color(0xFF6B8DD6) 
        : Colors.white54,
  ),
  // ...
)
```

**Step 4: Run test to verify it passes**

手动验证：
1. 启动应用
2. 随机播放按钮应该可见（默认灰色/关闭状态）
3. 点击按钮可以切换状态

**Step 5: Commit**

```bash
git add lib/providers/providers.dart lib/ui/widgets/playback_mode_controls.dart
git commit -m "fix: ensure shuffle button is always visible with initial state"
```
