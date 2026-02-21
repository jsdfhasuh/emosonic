# 歌单管理功能完整实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现完整的歌单管理功能，包括创建歌单、添加歌曲到歌单、从歌单移除歌曲

**Architecture:** 
- API 层：扩展 SubsonicApiClient，添加 `createPlaylist`、`updatePlaylist`、`deletePlaylist` 方法
- UI 层：创建 `PlaylistSelectionDialog` 组件，支持选择现有歌单或创建新歌单
- 集成层：替换现有的 TODO 占位符，在歌单详情页添加移除歌曲功能

**Tech Stack:** Flutter, Riverpod, Subsonic API

---

## Task 1: 添加歌单管理 API 方法

**Files:**
- Modify: `lib/data/services/subsonic/subsonic_api_client.dart`

**Step 1: 添加 createPlaylist 方法**

在 `subsonic_api_client.dart` 中，找到 `getPlaylistSongs` 方法之后，添加以下方法：

```dart
/// 创建新歌单
/// 
/// [name] - 歌单名称（必需）
/// [songIds] - 要添加的歌曲ID列表（可选）
/// 
/// 返回创建的歌单ID
Future<String> createPlaylist({
  required String name,
  List<String>? songIds,
}) async {
  final queryParams = <String, String>{
    'name': name,
  };
  
  if (songIds != null && songIds.isNotEmpty) {
    for (var i = 0; i < songIds.length; i++) {
      queryParams['songId[$i]'] = songIds[i];
    }
  }
  
  final response = await _get('createPlaylist', queryParams: queryParams);
  
  if (response.data['subsonic-response']['status'] == 'ok') {
    // createPlaylist 返回的歌单信息在 playlist 字段中
    final playlistData = response.data['subsonic-response']['playlist'];
    if (playlistData != null && playlistData['id'] != null) {
      return playlistData['id'].toString();
    }
    throw Exception('创建歌单成功但未返回歌单ID');
  } else {
    final error = response.data['subsonic-response']['error'];
    throw Exception('创建歌单失败: ${error?['message'] ?? '未知错误'}');
  }
}
```

**Step 2: 添加 updatePlaylist 方法**

```dart
/// 更新歌单
/// 
/// [playlistId] - 歌单ID（必需）
/// [name] - 新歌单名称（可选）
/// [comment] - 新备注（可选）
/// [public] - 是否公开（可选）
/// [songIdsToAdd] - 要添加的歌曲ID列表（可选）
/// [songIndexesToRemove] - 要移除的歌曲索引列表（可选）
/// 
/// Subsonic API 使用 songIndexToRemove 而不是 songIdToRemove
Future<void> updatePlaylist({
  required String playlistId,
  String? name,
  String? comment,
  bool? public,
  List<String>? songIdsToAdd,
  List<int>? songIndexesToRemove,
}) async {
  final queryParams = <String, String>{
    'playlistId': playlistId,
  };
  
  if (name != null) {
    queryParams['name'] = name;
  }
  if (comment != null) {
    queryParams['comment'] = comment;
  }
  if (public != null) {
    queryParams['public'] = public.toString();
  }
  if (songIdsToAdd != null && songIdsToAdd.isNotEmpty) {
    for (var i = 0; i < songIdsToAdd.length; i++) {
      queryParams['songIdToAdd[$i]'] = songIdsToAdd[i];
    }
  }
  if (songIndexesToRemove != null && songIndexesToRemove.isNotEmpty) {
    for (var i = 0; i < songIndexesToRemove.length; i++) {
      queryParams['songIndexToRemove[$i]'] = songIndexesToRemove[i].toString();
    }
  }
  
  final response = await _get('updatePlaylist', queryParams: queryParams);
  
  if (response.data['subsonic-response']['status'] != 'ok') {
    final error = response.data['subsonic-response']['error'];
    throw Exception('更新歌单失败: ${error?['message'] ?? '未知错误'}');
  }
}
```

**Step 3: 添加 deletePlaylist 方法**

```dart
/// 删除歌单
/// 
/// [playlistId] - 要删除的歌单ID
Future<void> deletePlaylist(String playlistId) async {
  final response = await _get(
    'deletePlaylist',
    queryParams: {'id': playlistId},
  );
  
  if (response.data['subsonic-response']['status'] != 'ok') {
    final error = response.data['subsonic-response']['error'];
    throw Exception('删除歌单失败: ${error?['message'] ?? '未知错误'}');
  }
}
```

**Step 4: 验证代码无语法错误**

运行: `flutter analyze lib/data/services/subsonic/subsonic_api_client.dart`
Expected: No issues found

**Step 5: Commit**

```bash
git add lib/data/services/subsonic/subsonic_api_client.dart
git commit -m "feat(api): add playlist management methods (create, update, delete)"
```

---

## Task 2: 创建 PlaylistSelectionDialog 组件

**Files:**
- Create: `lib/ui/widgets/playlist_selection_dialog.dart`

**Step 1: 创建对话框组件文件**

创建新文件 `lib/ui/widgets/playlist_selection_dialog.dart`，内容如下：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/services/subsonic/subsonic_api_client.dart';
import '../../providers/providers.dart';

/// 歌单选择对话框
/// 
/// 显示现有歌单列表，支持创建新歌单
/// 返回选中的歌单ID，或null表示取消
class PlaylistSelectionDialog extends ConsumerStatefulWidget {
  final Song song;
  
  const PlaylistSelectionDialog({
    super.key,
    required this.song,
  });
  
  @override
  ConsumerState<PlaylistSelectionDialog> createState() => _PlaylistSelectionDialogState();
}

class _PlaylistSelectionDialogState extends ConsumerState<PlaylistSelectionDialog> {
  bool _isLoading = false;
  bool _isCreating = false;
  final TextEditingController _nameController = TextEditingController();
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _addToPlaylist(Playlist playlist) async {
    setState(() => _isLoading = true);
    
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.updatePlaylist(
        playlistId: playlist.id,
        songIdsToAdd: [widget.song.id],
      );
      
      if (mounted) {
        Navigator.of(context).pop(playlist.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加到歌单 "${playlist.name}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _createAndAddToNewPlaylist() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入歌单名称')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final apiClient = ref.read(apiClientProvider);
      final playlistId = await apiClient.createPlaylist(
        name: name,
        songIds: [widget.song.id],
      );
      
      // 刷新歌单列表
      ref.invalidate(playlistsProvider);
      
      if (mounted) {
        Navigator.of(context).pop(playlistId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建歌单 "${name}" 并添加歌曲')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsProvider);
    
    return AlertDialog(
      title: const Text('添加到歌单'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 创建新歌单区域
            if (_isCreating) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '新歌单名称',
                  hintText: '输入歌单名称',
                ),
                autofocus: true,
                onSubmitted: (_) => _createAndAddToNewPlaylist(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isCreating = false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _createAndAddToNewPlaylist,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('创建并添加'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 显示现有歌单列表
              playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('暂无歌单，请创建新歌单'),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(playlist.name),
                        subtitle: playlist.comment != null && playlist.comment!.isNotEmpty
                            ? Text(
                                playlist.comment!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Text('${playlist.songCount ?? 0} 首'),
                        onTap: _isLoading ? null : () => _addToPlaylist(playlist),
                        enabled: !_isLoading,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('加载失败: $error'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 创建新歌单按钮
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _isCreating = true),
                icon: const Icon(Icons.add),
                label: const Text('创建新歌单'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 显示歌单选择对话框的便捷方法
/// 
/// 返回选中的歌单ID，或null表示取消
Future<String?> showPlaylistSelectionDialog(
  BuildContext context,
  Song song,
) async {
  return showDialog<String>(
    context: context,
    builder: (context) => PlaylistSelectionDialog(song: song),
  );
}
```

**Step 2: 验证代码无语法错误**

运行: `flutter analyze lib/ui/widgets/playlist_selection_dialog.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/ui/widgets/playlist_selection_dialog.dart
git commit -m "feat(ui): add PlaylistSelectionDialog component for adding songs to playlists"
```

---

## Task 3: 在 SongsScreen 中集成歌单选择功能

**Files:**
- Modify: `lib/ui/screens/songs_screen.dart`

**Step 1: 导入 PlaylistSelectionDialog**

在 `songs_screen.dart` 文件顶部，添加导入：

```dart
import '../widgets/playlist_selection_dialog.dart';
```

**Step 2: 替换 _showPlaylistSelection 方法**

找到 `_showPlaylistSelection` 方法（约第 547-554 行），替换为：

```dart
void _showPlaylistSelection(BuildContext context, WidgetRef ref, Song song) async {
  await showPlaylistSelectionDialog(context, song);
}
```

**Step 3: 验证代码无语法错误**

运行: `flutter analyze lib/ui/screens/songs_screen.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/ui/screens/songs_screen.dart
git commit -m "feat(ui): integrate playlist selection in SongsScreen"
```

---

## Task 4: 在 PlaylistDetailScreen 中添加移除歌曲功能

**Files:**
- Modify: `lib/ui/screens/playlist_detail_screen.dart`

**Step 1: 添加移除歌曲方法**

在 `PlaylistDetailScreen` 类中，找到 `_playSong` 方法，在其后添加以下方法：

```dart
Future<void> _removeSongFromPlaylist(BuildContext context, WidgetRef ref, Song song, int index) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('移除歌曲'),
      content: Text('确定要从歌单中移除 "${song.title}" 吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('移除'),
        ),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  try {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.updatePlaylist(
      playlistId: widget.playlist.id,
      songIndexesToRemove: [index],
    );
    
    // 刷新歌单歌曲列表
    ref.invalidate(playlistSongsProvider(widget.playlist.id));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已从歌单中移除')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移除失败: $e')),
      );
    }
  }
}
```

**Step 2: 修改歌曲列表项，添加长按菜单**

找到歌曲列表的 `ListTile` 构建代码（在 `ListView.builder` 中），修改为支持长按显示菜单：

查找类似以下代码：
```dart
ListTile(
  leading: ...,
  title: ...,
  // ... 其他属性
)
```

将其包装在 `InkWell` 或添加 `onLongPress`：

```dart
ListTile(
  leading: ...,
  title: ...,
  // ... 其他现有属性
  onLongPress: () {
    _showSongOptions(context, ref, song, index);
  },
)
```

**Step 3: 添加 _showSongOptions 方法**

在 `_removeSongFromPlaylist` 方法后，添加：

```dart
void _showSongOptions(BuildContext context, WidgetRef ref, Song song, int index) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('播放'),
            onTap: () {
              Navigator.pop(context);
              _playSong(ref, song, index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('添加到其他歌单'),
            onTap: () async {
              Navigator.pop(context);
              await showPlaylistSelectionDialog(context, song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
            title: const Text('从歌单移除', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _removeSongFromPlaylist(context, ref, song, index);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('取消'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
```

**Step 4: 添加导入语句**

在文件顶部添加：
```dart
import '../widgets/playlist_selection_dialog.dart';
```

**Step 5: 验证代码无语法错误**

运行: `flutter analyze lib/ui/screens/playlist_detail_screen.dart`
Expected: No issues found

**Step 6: Commit**

```bash
git add lib/ui/screens/playlist_detail_screen.dart
git commit -m "feat(ui): add remove song from playlist and move to other playlist features"
```

---

## Task 5: 在 LibraryScreen 中添加创建歌单功能

**Files:**
- Modify: `lib/ui/screens/library_screen.dart`

**Step 1: 添加创建歌单按钮**

在 `LibraryScreen` 的 `build` 方法中，找到 AppBar 或歌单列表区域，添加创建歌单按钮。

如果歌单标签页有 AppBar 操作按钮区域，添加：

```dart
IconButton(
  icon: const Icon(Icons.add),
  tooltip: '创建歌单',
  onPressed: () => _showCreatePlaylistDialog(context, ref),
),
```

**Step 2: 添加 _showCreatePlaylistDialog 方法**

在 `LibraryScreen` 类中添加：

```dart
Future<void> _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final commentController = TextEditingController();
  
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('创建新歌单'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '歌单名称',
              hintText: '输入歌单名称',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: commentController,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              hintText: '输入歌单备注',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入歌单名称')),
              );
              return;
            }
            Navigator.of(context).pop(true);
          },
          child: const Text('创建'),
        ),
      ],
    ),
  );
  
  if (result != true) return;
  
  try {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.createPlaylist(
      name: nameController.text.trim(),
    );
    
    // 刷新歌单列表
    ref.invalidate(playlistsProvider);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('歌单 "${nameController.text.trim()}" 创建成功')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败: $e')),
      );
    }
  }
}
```

**Step 3: 验证代码无语法错误**

运行: `flutter analyze lib/ui/screens/library_screen.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/ui/screens/library_screen.dart
git commit -m "feat(ui): add create playlist button in LibraryScreen"
```

---

## Task 6: 确保 playlistSongsProvider 支持刷新

**Files:**
- Verify: `lib/providers/providers.dart`

**Step 1: 检查 playlistSongsProvider 定义**

确认 `playlistSongsProvider` 使用 `FutureProvider.family` 定义，类似：

```dart
final playlistSongsProvider = FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getPlaylistSongs(playlistId);
});
```

**Step 2: 如果定义正确，无需修改**

`FutureProvider.family` 天然支持通过 `ref.invalidate()` 刷新。

**Step 3: Commit（如果需要修改）**

```bash
git add lib/providers/providers.dart
git commit -m "feat(provider): ensure playlistSongsProvider supports refresh"
```

---

## Task 7: 功能测试

**Test Steps:**

1. **测试创建歌单**
   - 打开音乐库 -> 歌单标签
   - 点击创建歌单按钮
   - 输入名称和备注，点击创建
   - 验证：新歌单出现在列表中

2. **测试添加歌曲到现有歌单**
   - 进入任意专辑
   - 点击歌曲右侧三个点
   - 选择"添加到播放列表"
   - 选择现有歌单
   - 验证：显示"已添加到歌单"提示
   - 进入该歌单，验证歌曲已添加

3. **测试添加歌曲到新歌单**
   - 进入任意专辑
   - 点击歌曲右侧三个点
   - 选择"添加到播放列表"
   - 点击"创建新歌单"
   - 输入名称，点击"创建并添加"
   - 验证：显示成功提示
   - 进入音乐库 -> 歌单，验证新歌单存在且包含歌曲

4. **测试从歌单移除歌曲**
   - 进入任意歌单详情
   - 长按歌曲
   - 选择"从歌单移除"
   - 确认移除
   - 验证：歌曲从列表中消失

5. **测试添加到其他歌单**
   - 进入歌单详情
   - 长按歌曲
   - 选择"添加到其他歌单"
   - 选择目标歌单
   - 验证：歌曲被添加到目标歌单

**Step 1: Commit 测试完成**

```bash
git commit --allow-empty -m "test: verify playlist management features work correctly"
```

---

## Summary

完成以上 7 个 Task 后，将实现：

1. ✅ 创建歌单 API
2. ✅ 更新歌单 API（添加/移除歌曲）
3. ✅ 删除歌单 API
4. ✅ 歌单选择对话框（支持创建新歌单）
5. ✅ 歌曲添加到歌单功能
6. ✅ 从歌单移除歌曲功能
7. ✅ 在歌单间移动歌曲功能
8. ✅ 音乐库中创建歌单功能

所有功能都通过 Riverpod 状态管理实现自动 UI 刷新。
