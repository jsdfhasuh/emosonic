# Sonic Player 项目开发记录

## 项目概述
使用 Flutter 开发的跨平台音乐播放器，支持 Windows 和 Android，连接 Subsonic/Sonic 音乐服务器。

---

## 开发记录

### 2026-02-08

#### 1. 项目初始化与环境配置
**改动内容**:
- 创建 Flutter 项目 `sonic_player`
- 配置 pubspec.yaml 依赖（just_audio、riverpod、dio、shared_preferences 等）
- 设置项目目录结构（core、data、providers、ui、services）
- 安装 Windows 开发环境（Visual Studio C++ 组件）

**相关文件**:
- `pubspec.yaml`
- `lib/` 目录结构

---

#### 2. 数据模型与 API 客户端
**改动内容**:
- 创建数据模型：ServerConfig、Artist、Album、Song
- 使用 freezed 和 json_serializable 生成不可变数据类
- 实现 SubsonicApiClient，支持 Token 认证
- 实现核心 API 方法：ping、getArtists、getAlbumsByArtist、getSongsByAlbum、search

**相关文件**:
- `lib/data/models/*.dart`
- `lib/data/services/subsonic/subsonic_api_client.dart`

**修复记录**:
- 修复 Album 模型类型转换错误（coverArt、year、songCount、duration 支持 String/num 混合类型）
- 修复 API 返回的 coverArt 为数字时，使用 itemId 构建正确 URL（ar-艺术家ID / al-专辑ID）

---

#### 3. 音频播放服务
**改动内容**:
- 封装 AudioPlayerService，基于 just_audio
- 实现播放/暂停/停止/seek/上一首/下一首
- 播放队列管理
- 后台播放支持（MediaItem）

**相关文件**:
- `lib/services/audio_player_service.dart`

**修复记录**:
- 添加 Windows 音频插件 `just_audio_windows: ^0.2.2`
- 修复 MissingPluginException 错误

---

#### 4. 状态管理（Riverpod）
**改动内容**:
- 配置 Riverpod providers
- 实现 serverConfigProvider（本地存储）
- 实现 apiClientProvider、audioPlayerServiceProvider
- 实现 artistsProvider、albumsProvider、songsProvider、searchProvider
- 实现 currentSongProvider、isPlayingProvider

**相关文件**:
- `lib/providers/providers.dart`

---

#### 5. UI 界面开发

##### 5.1 服务器配置页面
**改动内容**:
- 创建 ServerConfigScreen
- 表单验证（URL、用户名、密码）
- 连接测试功能
- 预填服务器地址 `http://192.168.100.74:5000`

**相关文件**:
- `lib/ui/screens/server_config_screen.dart`

##### 5.2 发现页（Discovery）
**改动内容**:
- 创建 DiscoveryScreen
- 搜索栏（带扫码按钮占位）
- 最新专辑横向滚动列表
- 每日推荐卡片列表
- 最近播放网格占位
- 随机发现网格布局

**设计特点**:
- 毛玻璃效果（半透明卡片）
- 深海蓝调深色主题
- 圆角设计（12-16dp）

**相关文件**:
- `lib/ui/screens/discovery_screen.dart`

##### 5.3 音乐库页面
**改动内容**:
- 创建 LibraryScreen
- 艺术家列表（带封面、专辑数量）
- 点击进入艺术家专辑列表

**相关文件**:
- `lib/ui/screens/library_screen.dart`

##### 5.4 专辑列表页面
**改动内容**:
- 创建 AlbumScreen
- 显示艺术家所有专辑
- 专辑封面、年份、歌曲数量
- 点击进入专辑详情

**修复记录**:
- 修复专辑封面 URL 构建（使用 `al-` 前缀）

**相关文件**:
- `lib/ui/screens/album_screen.dart`

##### 5.5 专辑详情页（重构）
**改动内容**:
- 重构 SongsScreen，采用 Header + Sticky Controls + List 布局
- 专辑信息 Header：左侧封面（120x120）+ 右侧专辑名/年份/艺人/星级评分
- Sticky 控制栏：全部播放按钮 + 收藏/排序/随机播放图标
- 歌曲列表：序号/播放指示器 + 歌曲名 + 下载状态/格式标签/艺人名 + 更多选项
- 滚动时导航栏自动变深色并显示专辑名

**设计参考**: `new_album.md`

**相关文件**:
- `lib/ui/screens/songs_screen.dart`

##### 5.6 播放页面
**改动内容**:
- 创建 PlayerScreen
- 大封面显示（300x300）
- 歌曲信息（歌名、艺人、专辑）
- 进度条（Slider）+ 当前时间/总时长显示
- 播放控制（上一首/播放/暂停/下一首）

**修复记录**:
- 修复进度显示：使用歌曲元数据时长作为 just_audio 获取不到时的备用
- 添加进度条样式（深蓝色 `#6B8DD6`）

**相关文件**:
- `lib/ui/screens/player_screen.dart`

##### 5.7 设置页面
**改动内容**:
- 创建 SettingsScreen
- 服务器状态卡片（在线状态、地址、用户名）
- 传输与下载设置（移动网络播放、边听边存、缓存限额、音质选择）
- 播放控制设置（循环播放、启动自动播放、定时停止、音量标准化）
- 系统集成设置（个性化主题、存储空间管理）
- 账户管理（多服务器配置、自定义 API 端点）
- 退出登录按钮

**相关文件**:
- `lib/ui/screens/settings_screen.dart`

##### 5.8 全局 Mini Player
**改动内容**:
- 创建 MiniPlayer 组件
- 底部悬浮显示当前播放歌曲
- 封面缩略图 + 歌曲信息 + 播放控制
- 点击展开全屏播放器

**相关文件**:
- `lib/ui/widgets/mini_player.dart`

---

#### 6. 日志系统
**改动内容**:
- 创建 Logger 工具类
- 支持 DEBUG/INFO/WARNING/ERROR 级别
- 输出到控制台和本地文件
- 日志文件位置：`C:\Users\jsdfhasuh\Documents\debug.log`

**新增功能 - 日志轮转**:
- 每次应用启动时，自动将当前日志移动到 `debug.log.1`（上次运行日志）
- 新的日志写入 `debug.log`（当前运行日志）
- 支持按大小自动轮转（默认 10MB）
- 每写入 100 条日志检查一次文件大小
- 提供 `getLogPaths()` 方法获取两个日志文件路径
- 更新 `clearLogs()` 方法，同时清理当前和上次日志

**日志文件**:
- `debug.log` - 当前运行日志
- `debug.log.1` - 上次运行日志

**相关文件**:
- `lib/core/utils/logger.dart`

---

#### 7. 主题与样式
**改动内容**:
- 配置深色主题（深海蓝调）
- 主背景色：`#0A1628`
- 卡片背景色：`#1E293B`
- 强调色：`#6B8DD6`
- 底部导航栏样式
- Material 3 设计

**相关文件**:
- `lib/main.dart`

---

## 技术栈

- **框架**: Flutter 3.x (Dart)
- **音频播放**: just_audio + just_audio_windows
- **状态管理**: Riverpod
- **网络请求**: Dio
- **本地存储**: shared_preferences
- **数据序列化**: freezed + json_serializable
- **图片缓存**: cached_network_image + flutter_cache_manager
- **加密**: crypto (MD5)
- **图片缓存管理**: 自定义 ImageCacheManager

---

## 项目结构

```
sonic_player/
├── android/                    # Android 平台代码
├── windows/                    # Windows 平台代码
├── lib/
│   ├── main.dart              # 入口文件
│   ├── core/                  # 核心功能
│   │   └── utils/             # 工具函数
│   │       └── logger.dart    # 日志系统
│   ├── data/                  # 数据层
│   │   ├── models/            # 数据模型
│   │   │   ├── server_config.dart
│   │   │   ├── artist.dart
│   │   │   ├── album.dart
│   │   │   ├── song.dart
│   │   │   └── models.dart
│   │   ├── repositories/      # 数据仓库
│   │   └── services/          # 服务层
│   │       └── subsonic/      # Subsonic API
│   │           └── subsonic_api_client.dart
│   ├── providers/             # Riverpod Providers
│   │   └── providers.dart
│   ├── ui/                    # UI层
│   │   ├── screens/           # 页面
│   │   │   ├── server_config_screen.dart
│   │   │   ├── discovery_screen.dart
│   │   │   ├── library_screen.dart
│   │   │   ├── album_screen.dart
│   │   │   ├── songs_screen.dart
│   │   │   ├── player_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── widgets/           # 组件
│   │   │   └── mini_player.dart
│   │   └── navigation/        # 导航
│   └── services/              # 业务服务
│       └── audio_player_service.dart
├── test/                      # 测试代码
├── pubspec.yaml
└── README.md
```

---

## 已知问题

1. **音频播放**: just_audio 在 Windows 上流媒体时长获取不稳定，已使用元数据时长作为备用
2. **封面加载**: 部分专辑封面返回 404，可能是服务器未配置封面图片
3. **后台播放**: Android 后台播放需要额外配置（未完全实现）

---

## 待优化项

- [ ] 实现搜索功能
- [ ] 添加播放列表管理
- [ ] 实现最近播放记录（本地存储）
- [ ] 添加收藏/喜欢功能
- [ ] 实现离线缓存
- [ ] 添加歌词显示
- [ ] 优化图片加载和缓存
- [ ] 实现 Android 后台播放
- [ ] 添加音量标准化功能
- [ ] 实现多服务器切换

---

## 构建命令

```bash
# 运行（Windows）
flutter run -d windows

# 构建 Windows 应用
flutter build windows

# 构建 Android APK
flutter build apk

# 代码生成（freezed/json_serializable）
dart run build_runner build --delete-conflicting-outputs
```

---

## 日志位置

Windows: `C:\Users\jsdfhasuh\Documents\debug.log`

---

### 2026-02-11

#### 1. 发现页修复与优化
**改动内容**:
- **修复最新专辑**: 从显示艺术家改为显示真实专辑数据
  - 创建 `newestAlbumsProvider` 调用 API 获取最新专辑
  - 新增 `_buildNewestAlbumsCarousel` 方法显示专辑封面、名称、艺术家
  
- **修复热门推荐**: 使用随机专辑代替播放最多专辑（后端 API 500 错误）
  - 创建 `randomAlbumsForHotProvider` 获取 5 个随机专辑
  - 显示专辑列表（封面 + 名称 + 艺术家）

- **修复最近播放**: 从占位符改为真实数据
  - 创建 `recentAlbumsProvider` 调用 API 获取最近播放专辑
  - 改为横向滚动列表，卡片尺寸 120x120
  - 显示专辑封面、名称、艺术家

- **修复随机发现**: 从显示艺术家改为显示专辑
  - 创建 `randomAlbumsForDiscoveryProvider` 获取 10 个随机专辑
  - 改为横向滚动列表，卡片尺寸 120x120
  - 显示专辑封面、名称、艺术家

- **移除查看更多按钮**: 所有区块的"查看更多"按钮已移除

**相关文件**:
- `lib/providers/providers.dart`
- `lib/ui/screens/discovery_screen.dart`

---

#### 2. 队列同步修复
**改动内容**:
- 修复"立即播放"时歌曲未添加到队列的问题
- 在 `songs_screen.dart` 中同步更新 Provider 和 AudioService
- 添加 `syncQueue` 方法到 `AudioPlayerService`
- 队列 Provider 使用 Riverpod 实现自动 UI 刷新

**相关文件**:
- `lib/services/audio_player_service.dart`
- `lib/providers/providers.dart`
- `lib/ui/screens/songs_screen.dart`
- `lib/ui/screens/player_screen.dart`

---

#### 3. 导航与路由修复
**改动内容**:
- 修复专辑点击导航错误（使用 `Navigator.pushNamed` 改为 `navigationProvider`）
- 统一使用 `navigationProvider` 管理所有页面导航
- 修复热门推荐和最近播放的点击跳转

**相关文件**:
- `lib/ui/screens/discovery_screen.dart`

---

#### 4. 歌单详情页面
**改动内容**:
- 创建 `PlaylistDetailScreen` 歌单详情页面
  - 显示歌单封面、名称、描述、歌曲数量
  - "播放全部"和"随机播放"按钮
  - 歌曲列表（序号、标题、艺术家、时长）
  - 点击歌曲播放，长按显示选项菜单
  - 支持返回导航

- 扩展导航 Provider
  - 添加 `PageType.playlistDetail`
  - 添加 `selectedPlaylist` 字段
  - 添加 `pushPlaylistPage()` 方法

- 创建 `playlistSongsProvider` 获取歌单内歌曲

**相关文件**:
- `lib/ui/screens/playlist_detail_screen.dart` (新增)
- `lib/providers/navigation_provider.dart`
- `lib/providers/providers.dart`
- `lib/main.dart`
- `lib/ui/screens/library_screen.dart`

---

#### 5. LibraryScreen 标签导航增强
**改动内容**:
- 添加 `LibraryTargetCategory` 枚举支持标签跳转
- 实现 `switchToLibraryCategory()` 方法
- LibraryScreen 监听导航状态自动切换标签
- 支持从其他页面跳转到指定标签（虽然查看更多已移除，但功能保留）

**相关文件**:
- `lib/providers/navigation_provider.dart`
- `lib/ui/screens/library_screen.dart`

---

## 当前功能状态

### 已实现功能
- ✅ 服务器连接与认证
- ✅ 音频播放（播放/暂停/seek/上一首/下一首）
- ✅ 播放队列管理
- ✅ 音乐库浏览（流派、专辑、艺术家、歌曲、歌单）
- ✅ 发现页（最新专辑、热门推荐、最近播放、随机发现）
- ✅ 专辑详情页
- ✅ 歌单详情页
- ✅ 流派详情页
- ✅ 播放页面
- ✅ MiniPlayer
- ✅ 设置页面
- ✅ 日志系统
- ✅ 图片缓存

### 待实现功能
- [ ] 搜索功能
- [ ] 收藏/喜欢功能
- [ ] 离线缓存
- [ ] 歌词显示
- [ ] Android 后台播放
- [ ] 音量标准化
- [ ] 多服务器切换

---

---

### 2026-02-13

#### 1. 搜索功能完整实现
**改动内容**:
- 创建 `SearchResult` 数据模型，支持艺术家/专辑/歌曲分类
- 扩展 Subsonic API 搜索方法，返回完整搜索结果
- 创建搜索结果页面，使用 TabBar 分栏展示
  - 艺术家列表（带封面）
  - 专辑列表（带封面）
  - 歌曲列表（带播放按钮）
- 实现搜索历史功能
  - 保存最近 10 条搜索记录
  - 使用 shared_preferences 本地存储
  - 发现页显示搜索历史标签
  - 点击历史快速搜索
- 发现页和音乐库都支持搜索入口
- 修复搜索页面导航和 MiniPlayer 显示问题
  - 将 SearchResultsScreen 集成到 MainScreen 导航系统
  - 添加 `PageType.searchResults` 和 `searchQuery` 状态

**相关文件**:
- `lib/data/models/search_result.dart` (新增)
- `lib/ui/screens/search_results_screen.dart` (新增)
- `test/models/search_result_test.dart` (新增)
- `lib/data/services/subsonic/subsonic_api_client.dart`
- `lib/providers/providers.dart`
- `lib/providers/navigation_provider.dart`
- `lib/ui/screens/discovery_screen.dart`
- `lib/ui/screens/library_screen.dart`
- `lib/main.dart`

---

#### 2. 播放页面增强功能
**改动内容**:
- **音量控制**
  - 在播放控制栏添加音量滑块（0-100%）
  - 点击音量图标快速静音/恢复
  - 实时显示当前音量
  
- **播放列表侧边栏**
  - 从右侧滑出的播放队列面板
  - 显示当前队列所有歌曲
  - 高亮显示正在播放的歌曲
  - 支持点击切换歌曲
  - 支持从队列移除歌曲
  - 支持清空整个队列
  
- **播放模式控制**
  - 循环模式切换（不循环/列表循环/单曲循环）
  - 随机播放开关
  - 图标状态实时反馈
  
- **技术实现**
  - 扩展 `AudioPlayerService` 支持音量和播放模式 API
  - 创建 `PlaylistDrawer` 组件
  - 创建 `VolumeControl` 组件
  - 创建 `PlaybackModeControls` 组件
  - 使用 Riverpod Streams 实时同步状态

**相关文件**:
- `lib/services/audio_player_service.dart`
- `lib/providers/providers.dart`
- `lib/ui/widgets/playlist_drawer.dart` (新增)
- `lib/ui/widgets/volume_control.dart` (新增)
- `lib/ui/widgets/playback_mode_controls.dart` (新增)
- `lib/ui/screens/player_screen.dart`

---

## 当前功能状态

### 已实现功能
- ✅ 服务器连接与认证
- ✅ 音频播放（播放/暂停/seek/上一首/下一首/音量控制）
- ✅ 播放队列管理（查看/切换/移除）
- ✅ 音乐库浏览（流派、专辑、艺术家、歌曲、歌单）
- ✅ 发现页（最新专辑、热门推荐、最近播放、随机发现）
- ✅ 搜索功能（艺术家/专辑/歌曲 + 搜索历史）
- ✅ 专辑详情页
- ✅ 歌单详情页
- ✅ 流派详情页
- ✅ 播放页面（音量、播放列表、循环模式、随机播放）
- ✅ MiniPlayer
- ✅ 设置页面
- ✅ 日志系统
- ✅ 图片缓存

### 待实现功能
- [ ] 收藏/喜欢功能
- [ ] 离线缓存
- [ ] 歌词显示
- [ ] Android 后台播放
- [ ] 音量标准化
- [ ] 多服务器切换

---

### 2026-02-13 (晚)

#### 3. 播放页面问题修复
**改动内容**:
- **修复播放队列按钮**
  - 使用 Builder 包裹 IconButton 获取正确的 Scaffold context
  - 解决点击无反应的问题
  
- **改进音量控制设计**
  - 改为底部弹出式设计（Bottom Sheet）
  - 大滑块（全宽），易于精准调节
  - 实时显示音量百分比（0-100%）
  - 添加快速音量按钮（静音/25%/50%/75%/100%）
  - 点击音量图标弹出，再次点击关闭
  - 类似 iOS 控制中心的交互体验

**相关文件**:
- `lib/ui/screens/player_screen.dart`
- `lib/ui/widgets/volume_control.dart`

---

#### 4. 播放队列和按钮显示修复
**改动内容**:
- **修复播放队列显示问题**
  - 问题：`PlaylistDrawer` 使用 `queueProvider`，但队列实际存储在 `AudioPlayerService`
  - 解决：改为直接使用 `audioService.queue` 和 `audioService.currentSong`
  - 结果：播放队列正确显示所有歌曲，包括正在播放的歌曲
  
- **添加动态音频波形动画**
  - 创建 `AudioWaveform` 组件，显示动态波形动画
  - 创建 `AudioEqualizer` 组件，显示均衡器风格动画
  - 使用 `AnimationController` 实现流畅的动画效果
  - 多个条形图错开动画，模拟真实音频波形
  - 替代原来的静态 `Icons.equalizer` 图标
  
- **修复随机播放按钮**
  - 添加 tooltip：'随机播放: 开启' / '随机播放: 关闭'
  - 鼠标悬停显示状态提示
  
- **修复清空队列按钮**
  - 改为 `TextButton.icon`，显示图标和文字"清空"
  - 添加 tooltip：'清空队列（保留当前歌曲）'
  - 添加确认对话框，防止误操作
  
- **修复清空队列逻辑**
  - 新增 `clearQueueExceptCurrent()` 方法
  - 清空时保留当前正在播放的歌曲
  - 仅清除队列中的其他歌曲
  - 同步更新 `queueProvider` 状态
  
- **修复队列刷新问题**
  - 问题：清空队列后页面不自动刷新
  - 解决：添加 `queueChangeStream` 通知机制
  - 实现：使用 `StreamController.broadcast()` 广播队列变化
  - 修改 `PlaylistDrawer` 为 `StatefulWidget`，使用 `StreamBuilder` 监听变化
  - 在 `addToQueue`, `removeFromQueue`, `clearQueue`, `clearQueueExceptCurrent` 等方法中触发通知
  - 结果：任何队列操作都会立即刷新 UI

- **MiniPlayer 播放列表添加波形动画**
  - 在 MiniPlayer 的播放列表弹窗中，为当前播放歌曲添加 `AudioWaveform` 动画
  - 与 PlaylistDrawer 保持一致的用户体验
  - 替换原来的静态 `Icons.equalizer` 图标

**相关文件**:
- `lib/ui/widgets/playlist_drawer.dart`
- `lib/ui/widgets/playback_mode_controls.dart`
- `lib/ui/widgets/audio_waveform.dart` (新增)
- `lib/ui/widgets/mini_player.dart`
- `lib/services/audio_player_service.dart`

---

*最后更新: 2026-02-13*
