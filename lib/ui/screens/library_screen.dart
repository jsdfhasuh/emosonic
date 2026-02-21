import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cache/audio_cache_manager.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../data/models/models.dart';
import '../../data/services/subsonic/subsonic_api_client.dart';
import '../../providers/providers.dart';
import '../../providers/providers.dart' show offlineModeProvider, cachedSongsProvider;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: LibraryCategory.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get current navigation state
    final navigation = ref.watch(navigationProvider);

    // Handle library category restoration when returning from sub-pages
    if (navigation.currentPage == PageType.library &&
        navigation.libraryTargetCategory != null) {
      final targetIndex = _getCategoryIndex(navigation.libraryTargetCategory!);
      if (targetIndex != -1 && targetIndex != _tabController.index) {
        // Use addPostFrameCallback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tabController.animateTo(targetIndex);
          // Update the provider state as well
          ref.read(libraryCategoryProvider.notifier).state =
              LibraryCategory.values[targetIndex];
        });
      }
    }

    // Listen to navigation state for library category changes from other pages
    ref.listen(navigationProvider, (previous, next) {
      // Trigger when: 1) navigating to library page with different category
      final shouldSwitchTab = (next.currentPage == PageType.library &&
              next.libraryTargetCategory != null) &&
          (previous?.currentPage != PageType.library ||
              previous?.libraryTargetCategory != next.libraryTargetCategory);

      if (shouldSwitchTab) {
        final targetIndex = _getCategoryIndex(next.libraryTargetCategory!);
        if (targetIndex != -1 && targetIndex != _tabController.index) {
          _tabController.animateTo(targetIndex);
          // Update the provider state as well
          ref.read(libraryCategoryProvider.notifier).state =
              LibraryCategory.values[targetIndex];
        }
      }
    });

    final isOffline = ref.watch(offlineModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          if (isOffline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                border: Border.all(color: Colors.orange, width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: Colors.orange, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '离线模式',
                    style: TextStyle(
                      color: Colors.orange[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context, ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context, ref);
            },
          ),
          // Show create playlist button when on playlists tab (index 4)
          if (_tabController.index == 4)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '创建歌单',
              onPressed: () => _showCreatePlaylistDialog(context, ref),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: LibraryCategory.values
              .map((category) => Tab(text: category.label))
              .toList(),
          onTap: (index) {
            ref.read(libraryCategoryProvider.notifier).state =
                LibraryCategory.values[index];
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 流派
          const _GenresView(),
          // 专辑
          const _AlbumsView(),
          // 歌手
          const _ArtistsView(),
          // 单曲
          const _SongsView(),
          // 歌单
          const _PlaylistsView(),
          // 已缓存
          const _CachedView(),
        ],
      ),
    );
  }

  int _getCategoryIndex(LibraryTargetCategory category) {
    switch (category) {
      case LibraryTargetCategory.genres:
        return 0;
      case LibraryTargetCategory.albums:
        return 1;
      case LibraryTargetCategory.artists:
        return 2;
      case LibraryTargetCategory.songs:
        return 3;
      case LibraryTargetCategory.playlists:
        return 4;
    }
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('搜索'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '输入搜索关键词...',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (query) {
              if (query.isNotEmpty) {
                Navigator.pop(context);
                ref.read(searchHistoryProvider.notifier).addSearch(query);
                ref.read(navigationProvider.notifier).pushSearchResults(query);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置'),
        content: const Text('确定要退出当前服务器连接吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(serverConfigProvider.notifier).clearConfig();
              Navigator.pop(context);
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新歌单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '歌单名称',
                hintText: '输入歌单名称',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '输入歌单备注',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入歌单名称')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.createPlaylist(
        name: nameController.text.trim(),
      );

      // Refresh playlists list
      ref.invalidate(playlistsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('歌单 "${nameController.text.trim()}" 创建成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }
}

// 流派视图
class _GenresView extends ConsumerWidget {
  const _GenresView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresProvider);

    return genresAsync.when(
      data: (genres) => _buildGenresList(context, ref, genres),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(context, ref, error),
    );
  }

  Widget _buildGenresList(BuildContext context, WidgetRef ref, List<Genre> genres) {
    if (genres.isEmpty) {
      return const Center(child: Text('没有找到流派'));
    }

    return ListView.builder(
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final genre = genres[index];
        return ListTile(
          title: Text(genre.name),
          subtitle: Text('${genre.songCount ?? 0} 首歌曲, ${genre.albumCount ?? 0} 张专辑'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ref.read(navigationProvider.notifier).pushGenrePage(genre.name);
          },
        );
      },
    );
  }
}

// 专辑视图
class _AlbumsView extends ConsumerStatefulWidget {
  const _AlbumsView();

  @override
  ConsumerState<_AlbumsView> createState() => _AlbumsViewState();
}

class _AlbumsViewState extends ConsumerState<_AlbumsView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedAlbumsProvider.notifier).loadMore();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(paginatedAlbumsProvider.notifier).loadMore();
    }
  }

  void _showSortMenu(BuildContext context) {
    final state = ref.read(paginatedAlbumsProvider);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '排序方式',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildSortOption('最新添加', AlbumListType.newest, state.sortType),
            _buildSortOption('最近播放', AlbumListType.recent, state.sortType),
            _buildSortOption('播放最多', AlbumListType.frequent, state.sortType),
            _buildSortOption('随机', AlbumListType.random, state.sortType),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, AlbumListType type, AlbumListType currentType) {
    final isSelected = type == currentType;
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF6B8DD6)) : null,
      onTap: () {
        ref.read(paginatedAlbumsProvider.notifier).setSortType(type);
        // Reset scroll position to top
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedAlbumsProvider);

    if (state.albums.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.albums.isEmpty && state.error != null) {
      return _buildErrorWidget(context, ref, state.error!);
    }

    if (state.albums.isEmpty) {
      return const Center(child: Text('没有找到专辑'));
    }

    return Column(
      children: [
        // Sort button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showSortMenu(context),
                icon: const Icon(Icons.sort, size: 18),
                label: Text(_getSortLabel(state.sortType)),
              ),
            ],
          ),
        ),
        // Album grid
        Expanded(
          child: _buildAlbumsGrid(context, ref, state),
        ),
      ],
    );
  }

  String _getSortLabel(AlbumListType type) {
    switch (type) {
      case AlbumListType.newest:
        return '最新';
      case AlbumListType.recent:
        return '最近';
      case AlbumListType.frequent:
        return '热门';
      case AlbumListType.random:
        return '随机';
      default:
        return '排序';
    }
  }

  Widget _buildAlbumsGrid(BuildContext context, WidgetRef ref, PaginatedAlbumsState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double maxAlbumWidth = 140;
        const double spacing = 8;
        const double padding = 16;

        final availableWidth = constraints.maxWidth - padding;
        int crossAxisCount = (availableWidth / maxAlbumWidth).floor();
        if (crossAxisCount < 3) crossAxisCount = 3;
        if (crossAxisCount > 8) crossAxisCount = 8;

        final totalSpacing = spacing * (crossAxisCount - 1);
        final albumWidth = (availableWidth - totalSpacing) / crossAxisCount;
        final albumHeight = albumWidth / 0.7;

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: albumWidth / albumHeight,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: state.albums.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.albums.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final album = state.albums[index];
            return _AlbumCard(
              album: album,
              onTap: () {
                ref.read(navigationProvider.notifier).pushSongPage(album);
              },
            );
          },
        );
      },
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = album.coverArt != null
        ? ref.read(apiClientProvider).getCoverArtUrl(
            album.coverArt!,
            itemId: album.id,
          )
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ImageCacheManager().getCachedImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                cacheKey: 'album_${album.id}',
                placeholder: Container(
                  color: const Color(0xFF2D3B4E),
                  child: const Icon(Icons.album, size: 48, color: Colors.white54),
                ),
                errorWidget: Container(
                  color: const Color(0xFF2D3B4E),
                  child: const Icon(Icons.album, size: 48, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            album.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// 歌手视图
class _ArtistsView extends ConsumerWidget {
  const _ArtistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);

    return artistsAsync.when(
      data: (artists) => _buildArtistsList(context, ref, artists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(context, ref, error),
    );
  }

  Widget _buildArtistsList(BuildContext context, WidgetRef ref, List<Artist> artists) {
    if (artists.isEmpty) {
      return const Center(child: Text('没有找到艺术家'));
    }

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
              width: 50,
              height: 50,
              cacheKey: 'artist_${artist.id}',
              placeholder: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2D3B4E),
                child: const Icon(Icons.person, size: 30, color: Colors.white54),
              ),
              errorWidget: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2D3B4E),
                child: const Icon(Icons.person, size: 30, color: Colors.white54),
              ),
            ),
          ),
          title: Text(artist.name),
          subtitle: artist.albumCount != null
              ? Text('${artist.albumCount} 张专辑')
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ref.read(navigationProvider.notifier).pushAlbumPage(artist);
          },
        );
      },
    );
  }
}

// 单曲视图
class _SongsView extends ConsumerWidget {
  const _SongsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(randomSongsProvider);
    final isOffline = ref.watch(offlineModeProvider);
    final cachedSongsAsync = ref.watch(cachedSongsProvider);

    return songsAsync.when(
      data: (songs) {
        if (isOffline) {
          return cachedSongsAsync.when(
            data: (cachedIds) => _buildSongsList(context, ref, songs, cachedIds, isOffline),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorWidget(context, ref, error),
          );
        }
        return _buildSongsList(context, ref, songs, [], isOffline);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(context, ref, error),
    );
  }

  Widget _buildSongsList(BuildContext context, WidgetRef ref, List<Song> songs, List<String> cachedIds, bool isOffline) {
    List<Song> displaySongs = songs;
    
    if (isOffline) {
      displaySongs = songs.where((song) => cachedIds.contains(song.id)).toList();
    }

    if (displaySongs.isEmpty) {
      if (isOffline) {
        return _buildOfflineEmptyState();
      }
      return const Center(child: Text('没有找到歌曲'));
    }

    return ListView.builder(
      itemCount: displaySongs.length,
      itemBuilder: (context, index) {
        final song = displaySongs[index];
        final isCached = cachedIds.contains(song.id);
        
        return ListTile(
          leading: Stack(
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
                  width: 50,
                  height: 50,
                  cacheKey: 'song_${song.id}',
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
              if (isOffline && isCached)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B8DD6),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.download_done,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(song.title),
          subtitle: Text('${song.artistName} - ${song.albumName}'),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              final audioService = ref.read(audioPlayerServiceProvider);
              await audioService.playSong(song);
              ref.read(currentSongProvider.notifier).state = song;
              ref.read(isPlayingProvider.notifier).state = true;
            },
          ),
        );
      },
    );
  }

  Widget _buildOfflineEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            '离线模式',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '没有已缓存的歌曲',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '请连接网络后播放歌曲，它们会自动缓存到本地',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 歌单视图
class _PlaylistsView extends ConsumerWidget {
  const _PlaylistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return playlistsAsync.when(
      data: (playlists) => _buildPlaylistsList(context, ref, playlists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(context, ref, error),
    );
  }

  Widget _buildPlaylistsList(BuildContext context, WidgetRef ref, List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return const Center(child: Text('没有找到歌单'));
    }

    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ImageCacheManager().getCachedImage(
               imageUrl: playlist.coverArt != null
                  ? ref.read(apiClientProvider).getCoverArtUrl(
                      playlist.coverArt!,
                      itemId: playlist.coverArt!,
                    )
                  : '',
              width: 50,
              height: 50,
              cacheKey: 'playlist_${playlist.id}',
              placeholder: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2D3B4E),
                child: const Icon(Icons.playlist_play, size: 30, color: Colors.white54),
              ),
              errorWidget: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2D3B4E),
                child: const Icon(Icons.playlist_play, size: 30, color: Colors.white54),
              ),
            ),
          ),
          title: Text(playlist.name),
          subtitle: Text('${playlist.songCount ?? 0} 首歌曲'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ref.read(navigationProvider.notifier).pushPlaylistPage(playlist);
          },
        );
      },
    );
  }
}

// 错误组件
Widget _buildErrorWidget(BuildContext context, WidgetRef ref, Object error) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('加载失败: $error'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => ref.refresh(libraryCategoryProvider),
          child: const Text('重试'),
        ),
      ],
    ),
  );
}

// 已缓存视图
class _CachedView extends ConsumerStatefulWidget {
  const _CachedView();

  @override
  ConsumerState<_CachedView> createState() => _CachedViewState();
}

class _CachedViewState extends ConsumerState<_CachedView> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载缓存信息失败: $e')),
        );
      }
    }
  }

  Future<void> _playCachedSong(CachedSongInfo song) async {
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.playCachedFile(
        song.filePath,
        title: song.displayTitle,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        coverArt: song.coverArt,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在播放: ${song.displayTitle}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除缓存歌曲')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已清空所有缓存')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空失败: $e')),
          );
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
    return Column(
      children: [
        // 缓存统计卡片
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
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
                  color: const Color(0xFF6B8DD6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.storage,
                  size: 32,
                  color: Color(0xFF6B8DD6),
                ),
              ),
            ],
          ),
        ),
        // 操作按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadCacheInfo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ),
              const SizedBox(width: 8),
              if (_cachedSongs.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearAllCache,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('清空全部', style: TextStyle(color: Colors.red)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                            leading: _buildCachedSongCover(song, ref),
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
                                Text('大小: ${song.formattedSize} • 缓存时间: ${song.formattedCreatedAt}'),
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
    );
  }

  Widget _buildCachedSongCover(CachedSongInfo song, WidgetRef ref) {
    // 如果有本地封面路径，显示本地图片
    if (song.coverArtLocalPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(song.coverArtLocalPath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultCover();
          },
        ),
      );
    }
    
    // 如果有封面URL但没有本地路径，尝试从网络加载
    if (song.coverArt != null && song.coverArt!.isNotEmpty) {
      // 检查是否是完整URL（以http开头）
      if (song.coverArt!.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ImageCacheManager().getCachedImage(
            imageUrl: song.coverArt!,
            width: 48,
            height: 48,
            cacheKey: 'cached_song_${song.songId}',
            placeholder: _buildDefaultCover(),
            errorWidget: _buildDefaultCover(),
          ),
        );
      } else {
        // 旧数据：coverArt是ID而不是URL，尝试使用albumId构建URL
        if (song.albumId != null && song.albumId!.isNotEmpty) {
          final coverUrl = ref.read(apiClientProvider).getCoverArtUrl(
            song.coverArt!,
            itemId: song.albumId!,
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageCacheManager().getCachedImage(
              imageUrl: coverUrl,
              width: 48,
              height: 48,
              cacheKey: 'cached_song_${song.songId}',
              placeholder: _buildDefaultCover(),
              errorWidget: _buildDefaultCover(),
            ),
          );
        }
        return _buildDefaultCover();
      }
    }
    
    // 默认封面
    return _buildDefaultCover();
  }

  Widget _buildDefaultCover() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2D3B4E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.music_note,
        color: Color(0xFF6B8DD6),
      ),
    );
  }
}
