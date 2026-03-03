import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cache/audio_cache_manager.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../providers/providers.dart';

class CacheManagerScreen extends ConsumerStatefulWidget {
  const CacheManagerScreen({super.key});

  @override
  ConsumerState<CacheManagerScreen> createState() => _CacheManagerScreenState();
}

class _CacheManagerScreenState extends ConsumerState<CacheManagerScreen> {
  List<CachedSongInfo> _cachedSongs = [];
  bool _isLoading = true;
  double _totalSizeMB = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cacheManager = AudioCacheManager();
      final songs = await cacheManager.getCachedSongsInfo();
      final stats = await cacheManager.getCacheStats();

      setState(() {
        _cachedSongs = songs;
        _totalCount = stats['fileCount'] as int;
        _totalSizeMB = stats['totalSizeMB'] as double;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showTopSnackBar(context, message: '加载缓存信息失败: $e');
      }
    }
  }

  Future<void> _playCachedSong(CachedSongInfo song) async {
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      // TODO: 需要从缓存信息中获取完整的 Song 对象
      // 暂时显示提示
      showTopSnackBar(context, message: '播放缓存歌曲: ${song.fileName}');
    } catch (e) {
      showTopSnackBar(context, message: '播放失败: $e');
    }
  }

  Future<void> _deleteCachedSong(CachedSongInfo song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这首缓存歌曲吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final cacheManager = AudioCacheManager();
        await cacheManager.removeFile(song.songId);
        await _loadCacheInfo();
        if (mounted) {
          showTopSnackBar(context, message: '已删除缓存歌曲');
        }
      } catch (e) {
        if (mounted) {
          showTopSnackBar(context, message: '删除失败: $e');
        }
      }
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有缓存的歌曲吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final cacheManager = AudioCacheManager();
        await cacheManager.clearCache();
        await _loadCacheInfo();
        if (mounted) {
          showTopSnackBar(context, message: '已清空所有缓存');
        }
      } catch (e) {
        if (mounted) {
          showTopSnackBar(context, message: '清空失败: $e');
        }
      }
    }
  }

  String _formatSize(double mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    } else {
      return '${mb.toStringAsFixed(2)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = ref.watch(colorThemeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCacheInfo,
            tooltip: '刷新',
          ),
          if (_cachedSongs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _clearAllCache,
              tooltip: '清空全部',
            ),
        ],
      ),
      body: Column(
        children: [
          // 缓存统计卡片
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '缓存统计',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('歌曲数量: $_totalCount 首'),
                      Text('占用空间: ${_formatSize(_totalSizeMB)}'),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorTheme.accentColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.storage,
                    size: 32,
                    color: colorTheme.accentColor,
                  ),
                ),
              ],
            ),
          ),
          // 缓存列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cachedSongs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 64,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '暂无缓存歌曲',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '播放歌曲时会自动缓存',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCacheInfo,
                        child: ListView.builder(
                          itemCount: _cachedSongs.length,
                          itemBuilder: (context, index) {
                            final song = _cachedSongs[index];
                            return ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colorTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                  image: song.coverArtLocalPath != null
                                      ? DecorationImage(
                                          image: FileImage(File(song.coverArtLocalPath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: song.coverArtLocalPath == null
                                    ? Icon(
                                        Icons.music_note,
                                        color: colorTheme.accentColor,
                                      )
                                    : null,
                              ),
                              title: Text(
                                song.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (song.displaySubtitle.isNotEmpty)
                                    Text(
                                      song.displaySubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text('大小: ${song.formattedSize}'),
                                  Text('缓存时间: ${song.formattedCreatedAt}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () => _playCachedSong(song),
                                    tooltip: '播放',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteCachedSong(song),
                                    tooltip: '删除',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
