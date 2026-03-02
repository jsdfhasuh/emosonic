import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../providers/color_theme_provider.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  final VoidCallback? onBack;

  const SearchResultsScreen({
    super.key,
    required this.query,
    this.onBack,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchProvider(widget.query));

    return Scaffold(
      appBar: AppBar(
        title: Text('搜索: ${widget.query}'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '艺术家'),
            Tab(text: '专辑'),
            Tab(text: '歌曲'),
          ],
        ),
      ),
      body: searchResults.when(
        data: (result) => TabBarView(
          controller: _tabController,
          children: [
            _buildArtistsList(result.artists),
            _buildAlbumsList(result.albums),
            _buildSongsList(result.songs),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('搜索失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(searchProvider(widget.query)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistsList(List<Artist> artists) {
    if (artists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text('没有找到艺术家', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    final colorTheme = ref.watch(colorThemeProvider);
    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ImageCacheManager().getCachedImage(
              imageUrl: artist.coverArt != null
                  ? ref.read(apiClientProvider).getCoverArtUrl(
                      artist.coverArt!,
                      itemId: 'ar-${artist.id}',
                    )
                  : '',
              width: 48,
              height: 48,
              cacheKey: 'artist_${artist.id}',
              placeholder: Container(
                width: 48,
                height: 48,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.person, color: Colors.white54),
              ),
              errorWidget: Container(
                width: 48,
                height: 48,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.person, color: Colors.white54),
              ),
            ),
          ),
          title: Text(artist.name),
          subtitle: Text('${artist.albumCount ?? 0} 张专辑'),
          onTap: () {
            ref.read(navigationProvider.notifier).pushAlbumPage(artist);
          },
        );
      },
    );
  }

  Widget _buildAlbumsList(List<Album> albums) {
    if (albums.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.album_outlined, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text('没有找到专辑', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    final colorTheme = ref.watch(colorThemeProvider);
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ImageCacheManager().getCachedImage(
              imageUrl: album.coverArt != null
                  ? ref.read(apiClientProvider).getCoverArtUrl(
                      album.coverArt!,
                      itemId: album.id,
                    )
                  : '',
              width: 48,
              height: 48,
              cacheKey: 'album_${album.id}',
              placeholder: Container(
                width: 48,
                height: 48,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.album, color: Colors.white54),
              ),
              errorWidget: Container(
                width: 48,
                height: 48,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.album, color: Colors.white54),
              ),
            ),
          ),
          title: Text(album.name),
          subtitle: Text(album.artistName),
          onTap: () {
            ref.read(navigationProvider.notifier).pushSongPage(album);
          },
        );
      },
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text('没有找到歌曲', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    final colorTheme = ref.watch(colorThemeProvider);
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
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
              width: 48,
              height: 48,
              cacheKey: 'album_${song.albumId}',
              placeholder: Container(
                width: 48,
                height: 48,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.music_note, color: Colors.white54),
              ),
              errorWidget: Container(
                width: 48,
                height: 48,
                color: colorTheme.surfaceColor,
                child: const Icon(Icons.music_note, color: Colors.white54),
              ),
            ),
          ),
          title: Text(song.title),
          subtitle: Text('${song.artistName} · ${song.albumName}'),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              _playSong(song, songs, index);
            },
          ),
          onTap: () {
            _playSong(song, songs, index);
          },
        );
      },
    );
  }

  void _playSong(Song song, List<Song> songs, int index) {
    final audioService = ref.read(audioPlayerServiceProvider);
    final queueNotifier = ref.read(queueProvider.notifier);

    queueNotifier.clearQueue();
    for (final s in songs) {
      queueNotifier.addToQueue(s);
    }

    audioService.playQueue(songs, startIndex: index);
    ref.read(currentSongProvider.notifier).state = song;
    ref.read(isPlayingProvider.notifier).state = true;
  }
}
