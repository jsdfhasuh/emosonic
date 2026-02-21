# Android 切歌卡住修复计划

**目标：**  
解决 Android 上"按切歌无效，需要先暂停才切换"的问题。采用平台分支策略，避免 MediaCodec 释放竞态。

**结论：**  
在 Android 上不使用 `stop()` 触发硬释放，改用 `pause() + seek(0)` 软切换，并延迟 100~200ms 后 `setAudioSource + play`。

---

## 方案概述

### Windows（保持现状）
- `stop()` → `setAudioSource()` → `play()`

### Android（新策略）
- `pause()` → `seek(Duration.zero)` → `delay(150ms)` → `setAudioSource()` → `play()`

---

## 修改点清单

### 1. AudioPlayerService：平台分支播放策略
**文件：** `lib/services/audio_player_service.dart`

**修改内容：**
- 在 `playSong()` 中加入 `Platform.isAndroid` 分支
- Android: 不调用 `stop()`，改用 `pause()+seek(0)` + 延迟
- Windows: 保持 `stop()` 逻辑

---

### 2. 增加日志确认分支
**文件：** `lib/services/audio_player_service.dart`

**日志建议：**
- `Android soft switch: pause + seek(0)`
- `Windows hard switch: stop`

---

## 风险控制

- Android 上切歌可能略慢（100~200ms）
- Windows 行为不受影响

---

## 实施状态

- [x] 计划文档创建
- [ ] 修改 AudioPlayerService
- [ ] 测试验证
