# Desktop Navigation Rail Design

**Goal:** 在 Windows/macOS/Linux 使用左侧可折叠导航栏，移动端保持底部导航。

**Scope:** 发现/音乐库/收藏/播放/设置主导航。

**Out of Scope:** 视觉风格重构、播放页布局调整、导航项新增。

## Current State

- 主导航使用 `BottomNavigationBar`，定义在 `lib/main.dart`。
- MiniPlayer 固定在页面底部。
- 桌面端与移动端共享同一导航布局。

## Target Behavior

- 桌面端显示 `NavigationRail` 左侧栏。
- 默认折叠，仅显示图标；点击汉堡按钮展开显示文字。
- 折叠状态持久化（桌面端有效）。
- 移动端保持 `BottomNavigationBar`。

## Architecture

- 桌面端：`Scaffold.body` 使用 `Row`。
  - 左侧：`NavigationRail`（可折叠）。
  - 右侧：现有内容 `Stack`（主页面 + MiniPlayer）。
- 移动端：保持现有 `Scaffold` + `BottomNavigationBar`。

## Data Flow

- `desktopNavExpanded` 状态：
  - 初始化：从 `SharedPreferences` 读取。
  - 切换：点击汉堡按钮更新状态并写入 prefs。
- 页面切换：复用 `_getBottomNavIndex` 与 `_onBottomNavTap`。

## UI Behavior

- 汉堡按钮仅在桌面端显示。
- 折叠状态影响 `NavigationRail.extended`。
- MiniPlayer 仍固定在页面底部。

## Error Handling

- prefs 读取失败时默认折叠。
- 仅在桌面端读取/写入折叠状态。

## Testing

- 手动验证：
  1. 桌面端启动时默认折叠。
  2. 点击汉堡按钮展开/折叠。
  3. 重启应用后折叠状态保持。
  4. 移动端仍显示底部导航。
