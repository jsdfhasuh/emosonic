import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../data/models/song.dart';
import '../../providers/providers.dart';
import '../../providers/starred_songs_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/star_button.dart';

class StarredSongsScreen extends ConsumerStatefulWidget {
  const StarredSongsScreen({super.key});

  @override
  ConsumerState<StarredSongsScreen> createState() => _StarredSongsScreenState();
}

class _StarredSongsScreenState extends ConsumerState<StarredSongsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Initial load
    Future.microtask(() {
      ref.read(starredSongsProvider.notifier).loadStarredSongs(refresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(starredSongsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(starredSongsProvider.notifier).loadStarredSongs(refresh: true);
  }

  void _playAll() {
    final state = ref.read(starredSongsProvider);
    if (state.songs.isNotEmpty) {
      final audioService = ref.read(audioPlayerServiceProvider);
      // Update current song to show MiniPlayer
      ref.read(currentSongProvider.notifier).state = state.songs.first;
      audioService.playQueue(state.songs, startIndex: 0);
    }
  }

  void _playSong(Song song) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final state = ref.read(starredSongsProvider);
    // Update current song to show MiniPlayer
    ref.read(currentSongProvider.notifier).state = song;
    audioService.playQueue(
      state.songs,
      startIndex: state.songs.indexOf(song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(starredSongsProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _buildContent(state),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildContent(StarredSongsState state) {
    if (state.isLoading && state.songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onRefresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.songs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.white30),
            SizedBox(height: 16),
            Text(
              '暂无收藏歌曲',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '点击歌曲旁边的心形图标收藏',
              style: TextStyle(color: Colors.white30, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Header with cover and play button
        SliverToBoxAdapter(
          child: _buildHeader(state),
        ),
        // Song list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= state.songs.length) {
                if (state.hasMore) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }

              final song = state.songs[index];
              return GestureDetector(
                onTap: () => _playSong(song),
                child: _buildSongItem(context, song, index),
              );
            },
            childCount: state.songs.length + (state.hasMore ? 1 : 0),
          ),
        ),
        // Bottom padding for mini player
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildHeader(StarredSongsState state) {
    final firstSong = state.songs.first;
    final apiClient = ref.read(apiClientProvider);
    
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Cover image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: firstSong.coverArt != null
                ? ImageCacheManager().getCachedImage(
                    imageUrl: apiClient.getCoverArtUrl(
                      firstSong.coverArt!,
                      itemId: firstSong.albumId,
                    ),
                    width: 200,
                    height: 200,
                    cacheKey: 'starred_cover_${firstSong.id}',
                    placeholder: _buildPlaceholder(),
                    errorWidget: _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            '我的收藏',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Song count
          Text(
            '共 ${state.songs.length} 首歌曲',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(179),
            ),
          ),
          const SizedBox(height: 16),
          // Play all button
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _playAll,
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                '全部播放',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8DD6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF2D3B4E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.favorite,
        size: 80,
        color: Colors.white30,
      ),
    );
  }

  Widget _buildSongItem(BuildContext context, Song song, int index) {
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
                ? const Icon(Icons.equalizer, color: Color(0xFF6B8DD6), size: 20)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrentSong
                          ? const Color(0xFF6B8DD6)
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
                    color: isCurrentSong ? const Color(0xFF6B8DD6) : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artistName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(153),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Star button
          StarButton(songId: song.id),
        ],
      ),
    );
  }
}