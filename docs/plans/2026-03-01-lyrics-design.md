# Lyrics Feature Design

**Goal:** 使用后端 `/getLyrics` 获取 LRC，播放页逐行同步滚动，迷你播放显示当前行+下一行。

**Scope:** 歌词获取、解析、缓存、播放页与迷你播放展示。

**Out of Scope:** 在线第三方歌词、歌词编辑、翻译/音译切换。

## Current State

- 客户端无歌词相关实现。
- 后端提供 `/getLyrics`，返回 Subsonic XML，`<lyrics>` 节点内为 LRC 文本。

## Target Behavior

- 优先使用 `song.id` 请求歌词，失败后可 fallback 到 `artist+title`。
- PlayerScreen 逐行同步高亮 + 自动滚动。
- MiniPlayer 显示当前行与下一行。
- 无歌词时显示“暂无歌词”。

## Architecture

- `SubsonicApiClient.getLyrics(...)` 调用 `/getLyrics` 并解析 XML。
- `LyricsService` 负责缓存和解析 LRC 文本。
- `LrcParser` 输出 `List<LyricLine>`。
- UI 订阅播放进度流计算当前行索引。

## Data Flow

1. 播放页/迷你播放订阅当前歌曲。
2. 调用 `LyricsService.getLyricsForSong(song)`：
   - 先查缓存
   - 调用 API 获取 LRC 文本
   - 解析为 `List<LyricLine>` 并缓存
3. 订阅进度流计算当前行索引，驱动 UI 高亮与滚动。

## API Contract

- Endpoint: `/getLyrics`
- Params: `id`（优先）、`artist`、`title`
- Response (XML):
  - `<subsonic-response status="ok">`
  - `<lyrics artist="..." title="...">LRC_TEXT</lyrics>`

## Parsing Rules

- 支持 `[mm:ss.xx]` / `[mm:ss]` 时间戳。
- 一行多时间戳拆分为多条 `LyricLine`。
- 过滤空文本与非法时间戳。
- 最终按时间排序。

## UI Behavior

- PlayerScreen:
  - ListView 显示全部歌词。
  - 当前行高亮（字号略大、颜色更亮）。
  - 自动滚动到当前行居中。
  - 用户手动滚动时暂停自动滚动一段时间后恢复。
- MiniPlayer:
  - 显示当前行 + 下一行（两行布局）。

## Dependencies

- 新增 `xml` 解析依赖（用于解析 Subsonic XML）。

## Error Handling

- API 失败或返回空：展示“暂无歌词”。
- 解析失败：记录日志并降级为空歌词。

## Testing

- 手动验证：
  1. 有歌词歌曲逐行同步滚动。
  2. 无歌词显示“暂无歌词”。
  3. 迷你播放显示两行。
  4. API 失败不崩溃。
