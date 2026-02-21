# 歌曲缓存功能实现计划

**Goal:** 实现边下边播的歌曲缓存系统，支持离线播放、预缓存、可配置缓存容量，并在设置中管理缓存

**Architecture:** 
- 使用 just_audio 的 LockCachingAudioSource 实现边下边播缓存
- 复用现有的 SonicCacheManager 架构，创建专门的 AudioCacheManager 管理音频缓存
- 通过 Provider 管理缓存设置和离线状态
- 在 LibraryScreen 添加离线模式筛选，只显示已缓存歌曲

**Tech Stack:** 
- just_audio (LockCachingAudioSource)
- SonicCacheManager (复用现有架构)
- Riverpod (状态管理)
- shared_preferences (设置持久化)
- connectivity_plus (网络状态检测)

---

## Phase 1: 核心缓存管理器

### Task 1.1: 创建 AudioCacheManager 类

创建 lib/core/cache/audio_cache_manager.dart，包含：
- 可配置缓存大小（默认 2GB，最大 10GB）
- LRU + 时间淘汰策略
- 收藏歌曲优先保留（90天 vs 30天）
- 预缓存队列歌曲支持

在 main.dart 中初始化 AudioCacheManager

---

### Task 1.2: 创建缓存设置 Provider

修改 lib/providers/providers.dart，添加：
- audioCacheEnabledProvider - 开关缓存功能
- audioCacheSizeProvider - 缓存大小配置（100MB-10GB）
- audioCacheStatsProvider - 缓存统计信息
- offlineModeProvider - 离线模式状态
- cachedSongsProvider - 已缓存歌曲列表

---

## Phase 2: 集成 LockCachingAudioSource

### Task 2.1: 修改 AudioPlayerService 支持缓存

修改 lib/services/audio_player_service.dart：
- 修改 playSong 方法使用 LockCachingAudioSource
- 添加 preCacheSongs 方法批量缓存歌曲
- 添加 preCacheNextSongs 方法预缓存队列中的下一首
- 支持缓存开关（根据 audioCacheEnabledProvider）

---

## Phase 3: 设置页面集成

### Task 3.1: 实现缓存设置 UI

修改 lib/ui/screens/settings_screen.dart：
- "边听边存"开关改为可交互
- "缓存限额"改为可点击，弹出选择对话框（512MB-8GB 选项）
- "存储空间管理"显示真实缓存统计
- 添加缓存管理对话框，支持清空缓存

---

## Phase 4: 离线模式支持

### Task 4.1: 添加网络状态检测

修改 pubspec.yaml 添加 connectivity_plus: ^5.0.2
修改 lib/providers/providers.dart 更新 offlineModeProvider

---

### Task 4.2: 在 LibraryScreen 添加离线筛选

修改 lib/ui/screens/library_screen.dart：
- AppBar 显示离线模式指示器
- 离线模式下只显示已缓存的歌曲
- 无缓存歌曲时显示友好提示

---

## Phase 5: 预缓存功能

### Task 5.1: 添加队列预缓存

修改 lib/services/audio_player_service.dart：
- 开始播放时自动预缓存下一首歌曲
- 切换歌曲时触发预缓存

---

### Task 5.2: 添加手动预缓存按钮

修改 lib/ui/widgets/playlist_drawer.dart：
- 在播放队列头部添加"下载"按钮
- 点击缓存队列中的所有歌曲

---

## 测试清单

- [ ] 播放歌曲时自动缓存到本地
- [ ] 断网后能播放已缓存的歌曲
- [ ] 设置页面可以调整缓存大小
- [ ] 设置页面可以清空缓存
- [ ] 离线模式只显示已缓存歌曲
- [ ] 队列预缓存功能正常工作
- [ ] 收藏歌曲有更长的缓存有效期

---

**预计开发时间：2-3 小时**

需要我开始执行吗？
