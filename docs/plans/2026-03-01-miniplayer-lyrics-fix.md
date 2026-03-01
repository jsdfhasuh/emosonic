# MiniPlayer Lyrics Reload Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 切歌后 MiniPlayer 歌词能正确重新加载并同步显示

**Architecture:** 在 `_MiniPlayerLyricsState` 中监听 `song.id` 变化，重置状态并重新加载歌词与进度监听

**Tech Stack:** Flutter, Riverpod

---

### Task 1: 增加 didUpdateWidget 处理切歌

**Files:**
- Modify: `lib/ui/widgets/mini_player.dart`

**Step 1: Write the failing test**

暂无测试，手动验证为主。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

在 `_MiniPlayerLyricsState` 中新增：

```dart
@override
void didUpdateWidget(covariant _MiniPlayerLyrics oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.song.id != widget.song.id) {
    _lyrics = [];
    _currentIndex = 0;
    _positionSubscription?.cancel();
    _setupPositionListener();
    _loadLyrics();
  }
}
```

**Step 4: Run test to verify it passes**

手动验证切歌后歌词更新。

**Step 5: Commit**

```bash
```

---

### Task 2: 手动验证

**Steps:**
1. 播放有歌词歌曲 → MiniPlayer 显示两行歌词
2. 切换到无歌词歌曲 → MiniPlayer 显示“暂无歌词”
3. 再切换到有歌词歌曲 → 正确显示歌词
4. 连续切歌多次 → 显示始终正确

**Expected:** MiniPlayer 歌词与当前歌曲始终一致

---
