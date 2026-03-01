# Lyrics Tabbed Player Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 播放页面使用顶部 Segmented 切换“专辑/歌词”分页，统一分页切换展示

**Architecture:** PlayerScreen 增加分页状态，顶部 Segmented 控件驱动渲染专辑页或歌词页；宽屏不再并排显示

**Tech Stack:** Flutter, Riverpod

---

### Task 1: 新增播放器分页状态

**Files:**
- Modify: `lib/providers/providers.dart`

**Step 1: Write the failing test**

暂无测试。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

新增枚举与 provider：

```dart
enum PlayerTab { album, lyrics }

final playerTabProvider = StateProvider<PlayerTab>((ref) => PlayerTab.album);
```

**Step 4: Run test to verify it passes**

手动验证切换。

**Step 5: Commit**

```bash
```

---

### Task 2: PlayerScreen 顶部 Segmented 切换

**Files:**
- Modify: `lib/ui/screens/player_screen.dart`

**Step 1: Write the failing test**

暂无测试。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

- 添加顶部 Segmented 控件（例如 `SegmentedButton`）
- 绑定 `playerTabProvider`
- 切换时更新 provider

**Step 4: Run test to verify it passes**

手动验证切换。

**Step 5: Commit**

```bash
```

---

### Task 3: PlayerScreen 分页结构重构

**Files:**
- Modify: `lib/ui/screens/player_screen.dart`

**Step 1: Write the failing test**

暂无测试。

**Step 2: Run test to verify it fails**

跳过。

**Step 3: Write minimal implementation**

- 提取原专辑页内容为 `_buildAlbumPage(...)`
- 新增 `_buildLyricsPage(...)` 使用 `LyricsDisplay`
- 根据 `playerTabProvider` 渲染对应页面
- 移除宽屏并排歌词展示逻辑

**Step 4: Run test to verify it passes**

手动验证：切换正确显示对应页面。

**Step 5: Commit**

```bash
```

---

### Task 4: 手动验证

**Steps:**
1. 打开播放页默认显示“专辑”
2. 切换到“歌词”显示同步歌词
3. 返回“专辑”仍正常
4. 宽屏不再显示右侧歌词
5. 迷你播放歌词仍可用

**Expected:** 分页切换正确，歌词同步滚动正常，布局统一

---
