import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../widgets/playlist_selection_dialog.dart';

class GenreDetailScreen extends ConsumerStatefulWidget {
  final String genreName;
  final VoidCallback? onBack;

  const GenreDetailScreen({
    super.key,
    required this.genreName,
    this.onBack,
  });

  @override
  ConsumerState<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends ConsumerState<GenreDetailScreen> {
  final Logger _logger = Logger('GenreDetailScreen');
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _logger.info('GenreDetailScreen initialized for genre: ${widget.genreName}');
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
    _logger.debug('Building GenreDetailScreen');
    final songsAsync = ref.watch(songsByGenreProvider(widget.genreName));

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
      _logger.warning('No songs found for genre: ${widget.genreName}');
      return const Center(child: Text('该流派暂无歌曲'));
    }

    final colorTheme = ref.watch(colorThemeProvider);

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
              ? Text(widget.genreName, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
        ),

        // Genre Header (Hero Section)
        SliverToBoxAdapter(
          child: _buildGenreHeader(context, ref, songs),
        ),

        // Songs List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Text(
                  '歌曲列表',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorTheme.accentColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${songs.length} 首',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(179),
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
              return _buildSongTile(context, ref, song, index);
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

  Widget _buildGenreHeader(BuildContext context, WidgetRef ref, List<Song> songs) {
    final colorTheme = ref.watch(colorThemeProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Genre Icon
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorTheme.accentColor,
                  colorTheme.secondaryAccentColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorTheme.accentColor.withAlpha(51),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.music_note,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Genre Name
          Text(
            widget.genreName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Song Count
          Text(
            '${songs.length} 首歌曲',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(179),
            ),
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play All Button
              ElevatedButton.icon(
                onPressed: () async {
                  final audioService = ref.read(audioPlayerServiceProvider);
                  await audioService.playQueue(songs, startIndex: 0);
                  ref.read(currentSongProvider.notifier).state = songs.first;
                  ref.read(isPlayingProvider.notifier).state = true;
                  showTopSnackBar(context, message: '开始播放: ${widget.genreName}');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放全部'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Add to Queue Button
              ElevatedButton.icon(
                onPressed: () async {
                  final audioService = ref.read(audioPlayerServiceProvider);
                  for (final song in songs) {
                    await audioService.addToQueue(song);
                  }
                  showTopSnackBar(context, message: '已添加 ${songs.length} 首歌曲到队列');
                },
                icon: const Icon(Icons.playlist_add),
                label: const Text('添加到队列'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTheme.surfaceColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSongTile(BuildContext context, WidgetRef ref, Song song, int index) {
    final isCurrentSong = ref.watch(currentSongProvider)?.id == song.id;
    final isPlaying = ref.watch(isPlayingProvider);
    final colorTheme = ref.watch(colorThemeProvider);

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Index or Playing Indicator
          Container(
            width: 32,
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
          // Cover Art
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
              width: 50,
              height: 50,
              placeholder: Container(
                width: 50,
                height: 50,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.music_note, size: 30, color: Colors.white54),
              ),
              errorWidget: Container(
                width: 50,
                height: 50,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.music_note, size: 30, color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        song.title,
        style: TextStyle(
          fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.normal,
          color: isCurrentSong ? colorTheme.accentColor : Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${song.artistName} - ${song.albumName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showSongOptions(context, ref, song),
      ),
      onTap: () async {
        final audioService = ref.read(audioPlayerServiceProvider);
        await audioService.playQueue([song], startIndex: 0);
        ref.read(currentSongProvider.notifier).state = song;
        ref.read(isPlayingProvider.notifier).state = true;
      },
    );
  }

  void _showSongOptions(BuildContext context, WidgetRef ref, Song song) {
    final colorTheme = ref.read(colorThemeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: colorTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withAlpha(26)),
                ),
              ),
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
                      width: 50,
                      height: 50,
                      placeholder: Container(
                        width: 50,
                        height: 50,
                        color: colorTheme.surfaceColor,
                        child: const Icon(Icons.music_note, color: Colors.white54),
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
            
            // Options
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.white70),
              title: const Text('立即播放'),
              onTap: () async {
                Navigator.pop(context);
                final audioService = ref.read(audioPlayerServiceProvider);
                await audioService.playQueue([song], startIndex: 0);
                ref.read(currentSongProvider.notifier).state = song;
                ref.read(isPlayingProvider.notifier).state = true;
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white70),
              title: const Text('添加到队列'),
              onTap: () async {
                Navigator.pop(context);
                final audioService = ref.read(audioPlayerServiceProvider);
                await audioService.addToQueue(song);
                showTopSnackBar(context, message: '已添加到队列: ${song.title}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.white70),
              title: const Text('收藏歌曲'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement favorite
                showTopSnackBar(context, message: '收藏功能开发中');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check, color: Colors.white70),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => PlaylistSelectionDialog(song: song),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Object error, StackTrace? stack) {
    _logger.error('Error loading genre songs: $error');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载失败: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(songsByGenreProvider(widget.genreName));
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
