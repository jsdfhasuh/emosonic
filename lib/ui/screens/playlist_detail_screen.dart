import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../widgets/playlist_selection_dialog.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  final VoidCallback? onBack;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    this.onBack,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final Logger _logger = Logger('PlaylistDetailScreen');
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _logger.info('PlaylistDetailScreen initialized for playlist: ${widget.playlist.name} (ID: ${widget.playlist.id})');
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final isScrolled = offset > 200;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.debug('Building PlaylistDetailScreen');
    final songsAsync = ref.watch(playlistSongsProvider(widget.playlist.id));

    return Scaffold(
      body: songsAsync.when(
        data: (songs) => _buildContent(context, ref, songs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorWidget(error, stack),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty) {
      _logger.warning('No songs found for playlist: ${widget.playlist.name}');
      return const Center(child: Text('歌单中没有歌曲'));
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // App Bar with back button
        SliverAppBar(
          pinned: true,
          expandedHeight: 0,
          backgroundColor: _isScrolled 
              ? const Color(0xFF1E293B) 
              : Colors.transparent,
          elevation: _isScrolled ? 4 : 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          title: _isScrolled 
              ? Text(widget.playlist.name, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
        ),

        // Playlist Header (Hero Section)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Playlist Cover - use al-{coverArt} format like album covers
                Hero(
                  tag: 'playlist_${widget.playlist.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ImageCacheManager().getCachedImage(
                      imageUrl: widget.playlist.coverArt != null
                          ? ref.read(apiClientProvider).getCoverArtUrl(
                              widget.playlist.coverArt!,
                              itemId: widget.playlist.coverArt!,
                            )
                          : '',
                      width: 200,
                      height: 200,
                      cacheKey: 'playlist_${widget.playlist.id}',
                      placeholder: Container(
                        width: 200,
                        height: 200,
                        color: const Color(0xFF2D3B4E),
                        child: const Icon(Icons.playlist_play, size: 80, color: Colors.white54),
                      ),
                      errorWidget: Container(
                        width: 200,
                        height: 200,
                        color: const Color(0xFF2D3B4E),
                        child: const Icon(Icons.playlist_play, size: 80, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Playlist Name
                Text(
                  widget.playlist.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Playlist Info
                Text(
                  '${widget.playlist.songCount ?? songs.length} 首歌曲 · ${widget.playlist.owner ?? '未知'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(179),
                  ),
                ),
                if (widget.playlist.comment != null && widget.playlist.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.playlist.comment!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(128),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Play All Button
                    ElevatedButton.icon(
                      onPressed: () => _playAll(context, ref, songs),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('播放全部'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8DD6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Shuffle Button
                    IconButton(
                      onPressed: () => _shufflePlay(context, ref, songs),
                      icon: const Icon(Icons.shuffle),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Songs List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '歌曲列表',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
                const Spacer(),
                Text(
                  '${songs.length} 首',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(128),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Songs List
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = songs[index];
              return _buildSongItem(context, ref, song, index);
            },
            childCount: songs.length,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildSongItem(BuildContext context, WidgetRef ref, Song song, int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: SizedBox(
        width: 50,
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(128),
            ),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        song.artistName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withAlpha(153),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song.duration != null)
            Text(
              _formatDuration(Duration(seconds: song.duration!)),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withAlpha(128),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () => _showSongOptions(context, ref, song, index),
          ),
        ],
      ),
      onTap: () => _playSong(context, ref, song, index),
      onLongPress: () => _showSongOptions(context, ref, song, index),
    );
  }

  void _playAll(BuildContext context, WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty) return;
    
    final audioService = ref.read(audioPlayerServiceProvider);
    final queueNotifier = ref.read(queueProvider.notifier);
    
    // Clear queue and add all songs
    queueNotifier.clearQueue();
    for (final song in songs) {
      queueNotifier.addToQueue(song);
    }
    
    // Play first song
    audioService.playQueue(songs, startIndex: 0);
    
    _logger.info('Playing all ${songs.length} songs from playlist');
  }

  void _shufflePlay(BuildContext context, WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty) return;
    
    final shuffledSongs = List<Song>.from(songs)..shuffle();
    _playAll(context, ref, shuffledSongs);
    
    _logger.info('Shuffling and playing ${songs.length} songs from playlist');
  }

  void _playSong(BuildContext context, WidgetRef ref, Song song, int index) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final queueNotifier = ref.read(queueProvider.notifier);
    final songsAsync = ref.read(playlistSongsProvider(widget.playlist.id));
    
    songsAsync.when(
      data: (songs) {
        // Check if song is already in queue
        final currentQueue = queueNotifier.queue;
        final isInQueue = currentQueue.any((s) => s.id == song.id);
        
        // If not in queue, add all playlist songs
        if (!isInQueue) {
          queueNotifier.clearQueue();
          for (final s in songs) {
            queueNotifier.addToQueue(s);
          }
        }
        
        // Play the selected song
        audioService.playQueue(songs, startIndex: index);
        
        _logger.info('Playing song: ${song.title} from playlist');
      },
      loading: () {},
      error: (err, __) {},
    );
  }

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

  void _showSongOptions(BuildContext context, WidgetRef ref, Song song, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('立即播放'),
                onTap: () {
                  Navigator.pop(context);
                  _playSong(context, ref, song, -1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('添加到队列'),
                onTap: () {
                  Navigator.pop(context);
                  final audioService = ref.read(audioPlayerServiceProvider);
                  final queueNotifier = ref.read(queueProvider.notifier);
                  queueNotifier.addToQueue(song);
                  audioService.addToQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已添加到队列')),
                  );
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
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildErrorWidget(Object error, StackTrace stack) {
    _logger.error('Error loading playlist songs: $error, stackTrace: $stack');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(playlistSongsProvider(widget.playlist.id)),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
