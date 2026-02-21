import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
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
      
      // Refresh playlist list
      ref.invalidate(playlistsProvider);
      
      if (mounted) {
        Navigator.of(context).pop(playlistId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建歌单 "$name" 并添加歌曲')),
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
            // Create new playlist area
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
              // Display existing playlist list
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
              // Create new playlist button
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

/// Display playlist selection dialog helper method
/// 
/// Returns selected playlist ID, or null if cancelled
Future<String?> showPlaylistSelectionDialog(
  BuildContext context,
  Song song,
) async {
  return showDialog<String>(
    context: context,
    builder: (context) => PlaylistSelectionDialog(song: song),
  );
}
