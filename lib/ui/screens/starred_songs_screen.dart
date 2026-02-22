import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(starredSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        centerTitle: true,
      ),
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

    return ListView.builder(
      controller: _scrollController,
      itemCount: state.songs.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.songs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final song = state.songs[index];
        return GestureDetector(
          onTap: () => _playSong(song),
          child: _buildSongItem(context, song, index),
        );
      },
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

  void _playSong(Song song) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final state = ref.read(starredSongsProvider);
    audioService.playQueue(
      state.songs,
      startIndex: state.songs.indexOf(song),
    );
  }
}