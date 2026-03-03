import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../widgets/playlist_selection_dialog.dart';
import '../widgets/star_button.dart';

class SongsScreen extends ConsumerStatefulWidget {
  final Album album;
  final VoidCallback? onBack;

  const SongsScreen({
    super.key,
    required this.album,
    this.onBack,
  });

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  final Logger _logger = Logger('SongsScreen');
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _logger.info('SongsScreen initialized for album: ${widget.album.name} (ID: ${widget.album.id})');
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
    _logger.debug('Building SongsScreen');
    final songsAsync = ref.watch(songsProvider(widget.album.id));
    final colorTheme = ref.watch(colorThemeProvider);

    return Scaffold(
      body: songsAsync.when(
        data: (songs) => _buildContent(context, ref, songs, colorTheme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorWidget(error, stack),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Song> songs, AppColorTheme colorTheme) {
    if (songs.isEmpty) {
      _logger.warning('No songs found for album: ${widget.album.name}');
      return const Center(child: Text('没有找到歌曲'));
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // App Bar with back button
        SliverAppBar(
          pinned: true,
          expandedHeight: 0,
          backgroundColor: _isScrolled
              ? colorTheme.backgroundColor
              : Colors.transparent,
          elevation: _isScrolled ? 4 : 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          title: _isScrolled 
              ? Text(widget.album.name, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
        ),

        // Album Header (Hero Section)
        SliverToBoxAdapter(
          child: _buildAlbumHeader(context, ref, colorTheme),
        ),

        // Sticky Control Bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _ControlBarDelegate(
            songCount: songs.length,
            onPlayAll: () => _playAll(context, songs),
            colorTheme: colorTheme,
          ),
        ),

        // Song List
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildSongItem(context, ref, songs, songs[index], index, colorTheme),
            childCount: songs.length,
          ),
        ),

        // Bottom padding for mini player
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildAlbumHeader(BuildContext context, WidgetRef ref, AppColorTheme colorTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageCacheManager().getCachedImage(
              imageUrl: widget.album.coverArt != null
                  ? ref.read(apiClientProvider).getCoverArtUrl(
                      widget.album.coverArt!,
                      itemId: widget.album.id
                    )
                  : '',
              width: 120,
              height: 120,
              cacheKey: 'album_${widget.album.id}',
              placeholder: _buildPlaceholder(colorTheme),
              errorWidget: _buildPlaceholder(colorTheme),
            ),
          ),
          const SizedBox(width: 16),
          // Album Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.album.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.album.year ?? ''} ${widget.album.artistName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(179),
                  ),
                ),
                const SizedBox(height: 12),
                // Star rating
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star_border,
                      size: 18,
                      color: Colors.amber.withAlpha(128),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(AppColorTheme colorTheme) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: colorTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.album, size: 50, color: Colors.white54),
    );
  }

  Widget _buildSongItem(BuildContext context, WidgetRef ref, List<Song> songs, Song song, int index, AppColorTheme colorTheme) {
    final isCurrentSong = ref.watch(currentSongProvider)?.id == song.id;
    final isPlaying = ref.watch(isPlayingProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Track number or playing indicator
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: isCurrentSong && isPlaying
                ? Icon(Icons.equalizer, color: colorTheme.accentColor, size: 20)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrentSong
                          ? colorTheme.accentColor
                          : Colors.white.withAlpha(128),
                      fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.w500,
                    color: isCurrentSong ? colorTheme.accentColor : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Download indicator
                    Icon(
                      Icons.check_circle,
                      size: 12,
                      color: Colors.green.withAlpha(179),
                    ),
                    const SizedBox(width: 6),
                    // Format badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorTheme.accentColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'flac ${song.bitRate ?? 0}K',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorTheme.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Artist name
                    Expanded(
                      child: Text(
                        song.artistName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(153),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Star button
          StarButton(songId: song.id),
          // More options
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20, color: Colors.white54),
            onPressed: () => _showSongOptions(context, ref, songs, song),
          ),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext context, WidgetRef ref, List<Song> songs, Song song) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final isInQueue = audioService.queue.any((s) => s.id == song.id);
    final colorTheme = ref.read(colorThemeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: colorTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Song info header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: ImageCacheManager().getCachedImage(
                      imageUrl: song.coverArt != null
                          ? ref.read(apiClientProvider).getCoverArtUrl(
                              song.coverArt!,
                              itemId: song.albumId,
                            )
                          : '',
                      cacheKey: 'song_${song.id}',
                      width: 48,
                      height: 48,
                      placeholder: Container(
                        width: 48,
                        height: 48,
                        color: colorTheme.surfaceColor,
                        child: const Icon(Icons.music_note, size: 24, color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artistName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withAlpha(179),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Menu items
            _buildMenuItem(
              icon: Icons.play_circle_filled,
              label: '马上播放',
              onTap: () {
                Navigator.pop(context);
                _playNow(context, ref, songs, song);
              },
            ),
            _buildMenuItem(
              icon: Icons.play_arrow,
              label: '下一首播放',
              onTap: () {
                Navigator.pop(context);
                _playNext(context, ref, song);
              },
            ),
            _buildMenuItem(
              icon: Icons.queue_music,
              label: '添加到队列',
              onTap: () {
                Navigator.pop(context);
                _addToQueue(context, ref, song);
              },
            ),
            _buildMenuItem(
              icon: Icons.playlist_add,
              label: '添加到播放列表',
              onTap: () {
                Navigator.pop(context);
                _showPlaylistSelection(context, ref, song);
              },
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.info_outline,
              label: '查看歌曲信息',
              onTap: () {
                Navigator.pop(context);
                _showSongInfo(context, ref, song);
              },
            ),
            _buildMenuItem(
              icon: Icons.share,
              label: '分享',
              onTap: () {
                Navigator.pop(context);
                _shareSong(song);
              },
            ),
            if (isInQueue)
              _buildMenuItem(
                icon: Icons.remove_circle_outline,
                label: '从队列移除',
                onTap: () {
                  Navigator.pop(context);
                  _removeFromQueue(context, ref, song);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label),
      onTap: onTap,
    );
  }

  void _playNow(BuildContext context, WidgetRef ref, List<Song> songs, Song song) async {
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      final container = ProviderScope.containerOf(context);
      
      // [DEBUG] Get current queue state
      final currentQueue = audioService.queue;
      final currentIndex = audioService.currentIndex;
      
      // [DEBUG] Log queue state
      _logger.info('[DEBUG_PLAY_NOW] Selected song: ${song.title} (ID: ${song.id})');
      _logger.info('[DEBUG_PLAY_NOW] Current queue length: ${currentQueue.length}');
      _logger.info('[DEBUG_PLAY_NOW] Current index: $currentIndex');
      _logger.info('[DEBUG_PLAY_NOW] Current queue songs: ${currentQueue.map((s) => '${s.title}[${s.id}]').toList()}');
      
      List<Song> newQueue;
      
      if (currentQueue.isEmpty || currentIndex >= currentQueue.length) {
        // Queue is empty or index out of bounds: just play the selected song
        newQueue = [song];
        _logger.info('[DEBUG_PLAY_NOW] Queue is empty, creating single song queue');
      } else {
        // Build new queue: [selected song] + [current song and all after]
        final remainingSongs = currentQueue.sublist(currentIndex);
        newQueue = [
          song,  // New song at first position
          ...remainingSongs,  // Current song and all after
        ];
        _logger.info('[DEBUG_PLAY_NOW] Remaining songs from current: ${remainingSongs.map((s) => '${s.title}[${s.id}]').toList()}');
      }
      
      // [DEBUG] Log new queue
      _logger.info('[DEBUG_PLAY_NOW] New queue length: ${newQueue.length}');
      _logger.info('[DEBUG_PLAY_NOW] New queue songs: ${newQueue.map((s) => '${s.title}[${s.id}]').toList()}');
      
      // Update state immediately for better UX
      container.read(currentSongProvider.notifier).state = song;
      container.read(isPlayingProvider.notifier).state = true;
      
      // [DEBUG] Log before playQueue
      _logger.info('[DEBUG_PLAY_NOW] Calling playQueue with startIndex: 0');
      
      // Play new queue starting from first song (the selected one)
      await audioService.playQueue(newQueue, startIndex: 0);
      
      // [DEBUG] Log after playQueue
      _logger.info('[DEBUG_PLAY_NOW] playQueue completed');
      
      if (context.mounted) {
        showTopSnackBar(context, message: '正在播放: ${song.title}');
      }
    } catch (e) {
      _logger.error('Failed to play now: $e');
      if (context.mounted) {
        showTopSnackBar(context, message: '播放失败: $e');
      }
    }
  }

  void _playNext(BuildContext context, WidgetRef ref, Song song) async {
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      final queueNotifier = ref.read(queueProvider.notifier);
      
      // Update queue in provider first (for UI)
      final currentIndex = audioService.currentIndex;
      queueNotifier.insertNext(song, currentIndex);
      
      // Then update audio service
      await audioService.insertNext(song);
      
      if (context.mounted) {
        showTopSnackBar(context, message: '将在下一首播放');
      }
    } catch (e) {
      _logger.error('Failed to play next: $e');
      if (context.mounted) {
        showTopSnackBar(context, message: '操作失败: $e');
      }
    }
  }

  void _addToQueue(BuildContext context, WidgetRef ref, Song song) async {
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      final queueNotifier = ref.read(queueProvider.notifier);
      
      // Update queue in provider first (for UI)
      queueNotifier.addToQueue(song);
      
      // Then update audio service
      await audioService.addToQueue(song);
      
      if (context.mounted) {
        showTopSnackBar(context, message: '已添加到队列');
      }
    } catch (e) {
      _logger.error('Failed to add to queue: $e');
      if (context.mounted) {
        showTopSnackBar(context, message: '操作失败: $e');
      }
    }
  }

  void _showPlaylistSelection(BuildContext context, WidgetRef ref, Song song) async {
    await showPlaylistSelectionDialog(context, song);
  }

  void _showSongInfo(BuildContext context, WidgetRef ref, Song song) {
    final colorTheme = ref.read(colorThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorTheme.backgroundColor,
        title: const Text('歌曲信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('标题', song.title),
            _buildInfoRow('艺术家', song.artistName),
            _buildInfoRow('专辑', song.albumName),
            _buildInfoRow('时长', _formatDuration(Duration(seconds: song.duration ?? 0))),
            _buildInfoRow('格式', song.contentType ?? 'Unknown'),
            _buildInfoRow('比特率', '${song.bitRate ?? 0} kbps'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white.withAlpha(179),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _shareSong(Song song) {
    final text = '正在听 ${song.title} - ${song.artistName} via Sonic Player';
    SharePlus.instance.share(ShareParams(text: text));
  }

  void _removeFromQueue(BuildContext context, WidgetRef ref, Song song) async {
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.removeFromQueue(song);
      if (context.mounted) {
        showTopSnackBar(context, message: '已从队列移除');
      }
    } catch (e) {
      _logger.error('Failed to remove from queue: $e');
      if (context.mounted) {
        showTopSnackBar(context, message: '操作失败: $e');
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildErrorWidget(Object error, StackTrace stack) {
    _logger.error('Error loading songs: $error, stackTrace: $stack');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(songsProvider(widget.album.id)),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Future<void> _playAll(BuildContext context, List<Song> songs) async {
    _logger.info('Playing ${songs.length} songs');
    
    // Get ref from context to ensure it's valid
    final container = ProviderScope.containerOf(context);
    final audioService = container.read(audioPlayerServiceProvider);
    final currentSong = container.read(currentSongProvider);
    
    // Check if this album is already loaded in the queue
    final isCurrentAlbum = audioService.queue.isNotEmpty && 
                          audioService.queue[0].albumId == songs[0].albumId;
    
    if (isCurrentAlbum && currentSong != null) {
      // Same album already loaded, just ensure playing
      await audioService.play();
      container.read(isPlayingProvider.notifier).state = true;
      return;
    }
    
    // Update state immediately for better UX (MiniPlayer will show right away)
    container.read(currentSongProvider.notifier).state = songs[0];
    container.read(isPlayingProvider.notifier).state = true;
    
    // Update queue provider for UI
    container.read(queueProvider.notifier).setQueue(songs);
    
    // Then load audio asynchronously
    try {
      await audioService.playQueue(songs, startIndex: 0);
    } catch (e) {
      _logger.error('Failed to play queue: $e');
      // Reset state on error
      container.read(currentSongProvider.notifier).state = null;
      container.read(isPlayingProvider.notifier).state = false;
      if (context.mounted) {
        showTopSnackBar(context, message: '播放失败: $e');
      }
    }
  }
}

// Sticky Control Bar Delegate
class _ControlBarDelegate extends SliverPersistentHeaderDelegate {
  final int songCount;
  final VoidCallback onPlayAll;
  final AppColorTheme colorTheme;

  _ControlBarDelegate({required this.songCount, required this.onPlayAll, required this.colorTheme});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: colorTheme.backgroundColor.withAlpha(230),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Play All Button
          ElevatedButton.icon(
            onPressed: onPlayAll,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text('全部播放 (共$songCount首)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorTheme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Spacer(),
          // Action buttons
          IconButton(
            icon: const Icon(Icons.star_border, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.shuffle, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
