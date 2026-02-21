import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import 'songs_screen.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  final Artist artist;
  final VoidCallback? onBack;

  const AlbumScreen({
    super.key,
    required this.artist,
    this.onBack,
  });

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  final Logger _logger = Logger('AlbumScreen');

  @override
  void initState() {
    super.initState();
    _logger.info('AlbumScreen initialized for artist: ${widget.artist.name} (ID: ${widget.artist.id})');
  }

  @override
  Widget build(BuildContext context) {
    _logger.debug('Building AlbumScreen');
    final albumsAsync = ref.watch(albumsProvider(widget.artist.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist.name),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: albumsAsync.when(
        data: (albums) {
          _logger.info('Loaded ${albums.length} albums');
          return _buildAlbumList(context, ref, albums);
        },
        loading: () {
          _logger.debug('Loading albums...');
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) {
          _logger.error('Error loading albums: $error, stackTrace: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(albumsProvider(widget.artist.id)),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumList(BuildContext context, WidgetRef ref, List<Album> albums) {
    if (albums.isEmpty) {
      _logger.warning('No albums found for artist: ${widget.artist.name}');
      return const Center(
        child: Text('没有找到专辑'),
      );
    }

    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        _logger.debug('Building album list item: ${album.name} (ID: ${album.id})');
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ImageCacheManager().getCachedImage(
              imageUrl: album.coverArt != null
                  ? ref.read(apiClientProvider).getCoverArtUrl(album.coverArt!, itemId: album.id)
                  : '',
              width: 50,
              height: 50,
              cacheKey: 'album_${album.id}',
              placeholder: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2D3B4E),
                child: const Icon(Icons.album, size: 30, color: Colors.white54),
              ),
              errorWidget: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2D3B4E),
                child: const Icon(Icons.album, size: 30, color: Colors.white54),
              ),
            ),
          ),
          title: Text(album.name),
          subtitle: album.year != null
              ? Text('${album.year} · ${album.songCount ?? 0} 首歌曲')
              : Text('${album.songCount ?? 0} 首歌曲'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _logger.info('Navigating to songs screen for album: ${album.name}');
            if (widget.onBack != null) {
              // Use new navigation
              ref.read(navigationProvider.notifier).pushSongPage(album);
            } else {
              // Compatible with old navigation
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SongsScreen(album: album),
                ),
              );
            }
          },
        );
      },
    );
  }
}
