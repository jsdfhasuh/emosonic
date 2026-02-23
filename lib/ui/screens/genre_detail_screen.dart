import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

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

  @override
  void initState() {
    super.initState();
    _logger.info('GenreDetailScreen initialized for genre: ${widget.genreName}');
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsByGenreProvider(widget.genreName));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(widget.genreName),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              // TODO: Play all songs in genre
            },
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) => _buildSongsList(context, ref, songs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorWidget(context, error),
      ),
    );
  }

  Widget _buildSongsList(BuildContext context, WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Text(
          '该流派暂无歌曲',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return _buildSongTile(context, ref, song);
      },
    );
  }

  Widget _buildSongTile(BuildContext context, WidgetRef ref, Song song) {
    return ListTile(
      leading: ClipRRect(
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
            color: const Color(0xFF2D3B4E),
            child: const Icon(Icons.music_note, size: 30, color: Colors.white54),
          ),
          errorWidget: Container(
            width: 50,
            height: 50,
            color: const Color(0xFF2D3B4E),
            child: const Icon(Icons.music_note, size: 30, color: Colors.white54),
          ),
        ),
      ),
      title: Text(
        song.title,
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
        icon: const Icon(Icons.play_arrow),
        onPressed: () async {
          final audioService = ref.read(audioPlayerServiceProvider);
          // Play as single song queue instead of playSong
          await audioService.playQueue([song], startIndex: 0);
          ref.read(currentSongProvider.notifier).state = song;
          ref.read(isPlayingProvider.notifier).state = true;
        },
      ),
      onTap: () async {
        final audioService = ref.read(audioPlayerServiceProvider);
        // Play as single song queue instead of playSong
        await audioService.playQueue([song], startIndex: 0);
        ref.read(currentSongProvider.notifier).state = song;
        ref.read(isPlayingProvider.notifier).state = true;
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object error) {
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
              // ignore: unused_result
              ref.refresh(songsByGenreProvider(widget.genreName));
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
