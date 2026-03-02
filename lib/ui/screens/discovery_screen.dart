import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorTheme = ref.watch(colorThemeProvider);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSearchBar(context, ref, colorTheme),
              ),
            ),
            // Latest Albums
            SliverToBoxAdapter(
              child: _buildSectionTitle('最新专辑'),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ref.watch(newestAlbumsProvider).when(
                  data: (albums) => _buildNewestAlbumsCarousel(context, ref, albums),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Hot Recommendations (Frequent Albums)
            SliverToBoxAdapter(
              child: _buildSectionTitle('热门推荐'),
            ),
            SliverToBoxAdapter(
              child: ref.watch(randomAlbumsForHotProvider).when(
                data: (albums) => _buildHotRecommendations(context, ref, albums),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ),
            // Recently Played
            SliverToBoxAdapter(
              child: _buildSectionTitle('最近播放'),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ref.watch(recentAlbumsProvider).when(
                  data: (albums) => _buildRecentlyPlayed(context, ref, albums),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Random Albums
            SliverToBoxAdapter(
              child: _buildSectionTitle('随机发现'),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ref.watch(randomAlbumsForDiscoveryProvider).when(
                  data: (albums) => _buildRandomAlbums(context, ref, albums),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref, AppColorTheme colorTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorTheme.backgroundColor.withAlpha(204),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha(26),
              width: 1,
            ),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索歌曲、专辑、艺术家...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(128)),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white54),
                onPressed: () {},
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(color: Colors.white),
            onSubmitted: (query) {
              if (query.isNotEmpty) {
                // Save to search history
                ref.read(searchHistoryProvider.notifier).addSearch(query);

                // Navigate to search results using navigationProvider
                ref.read(navigationProvider.notifier).pushSearchResults(query);
              }
            },
          ),
        ),
        // Search History
        Consumer(
          builder: (context, ref, child) {
            final searchHistory = ref.watch(searchHistoryProvider);
            final colorTheme = ref.watch(colorThemeProvider);
            if (searchHistory.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '搜索历史',
                        style: TextStyle(
                          color: Colors.white.withAlpha(179),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(searchHistoryProvider.notifier).clearHistory();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '清除',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: searchHistory.map((query) {
                      return ActionChip(
                        label: Text(query),
                        labelStyle: const TextStyle(fontSize: 13),
                        backgroundColor: colorTheme.backgroundColor,
                        side: BorderSide(color: Colors.white.withAlpha(26)),
                        onPressed: () {
                          ref.read(navigationProvider.notifier).pushSearchResults(query);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildNewestAlbumsCarousel(BuildContext context, WidgetRef ref, List<Album> albums) {
    final colorTheme = ref.watch(colorThemeProvider);
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: albums.length.clamp(0, 10),
      itemBuilder: (context, index) {
        final album = albums[index];
        return GestureDetector(
          onTap: () {
            ref.read(navigationProvider.notifier).pushSongPage(album);
          },
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageCacheManager().getCachedImage(
                    imageUrl: album.coverArt != null
                        ? ref.read(apiClientProvider).getCoverArtUrl(album.coverArt!, itemId: album.id)
                        : '',
                    width: 140,
                    height: 140,
                    cacheKey: 'album_${album.id}',
                    placeholder: _buildPlaceholder(140, colorTheme: colorTheme),
                    errorWidget: _buildPlaceholder(140, colorTheme: colorTheme),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  album.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withAlpha(153),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHotRecommendations(BuildContext context, WidgetRef ref, List<Album> albums) {
    final colorTheme = ref.watch(colorThemeProvider);
    if (albums.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            '暂无热门推荐',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: albums.take(3).map((album) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorTheme.backgroundColor.withAlpha(204),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(26),
                width: 1,
              ),
            ),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageCacheManager().getCachedImage(
                  imageUrl: album.coverArt != null
                      ? ref.read(apiClientProvider).getCoverArtUrl(album.coverArt!, itemId: album.id)
                      : '',
                  width: 56,
                  height: 56,
                  cacheKey: 'album_${album.id}',
                  placeholder: _buildPlaceholder(56, colorTheme: colorTheme),
                  errorWidget: _buildPlaceholder(56, colorTheme: colorTheme),
                ),
              ),
              title: Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                album.artistName,
                style: TextStyle(
                  color: Colors.white.withAlpha(153),
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.play_circle, color: colorTheme.accentColor),
                onPressed: () {
                  // TODO: Play album
                },
              ),
              onTap: () {
                ref.read(navigationProvider.notifier).pushSongPage(album);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentlyPlayed(BuildContext context, WidgetRef ref, List<Album> albums) {
    final colorTheme = ref.watch(colorThemeProvider);
    if (albums.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '暂无播放记录',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return GestureDetector(
          onTap: () {
            ref.read(navigationProvider.notifier).pushSongPage(album);
          },
          child: Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageCacheManager().getCachedImage(
                    imageUrl: album.coverArt != null
                        ? ref.read(apiClientProvider).getCoverArtUrl(album.coverArt!, itemId: album.id)
                        : '',
                    width: 120,
                    height: 120,
                    cacheKey: 'album_${album.id}',
                    placeholder: _buildPlaceholder(120, colorTheme: colorTheme),
                    errorWidget: _buildPlaceholder(120, colorTheme: colorTheme),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  album.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withAlpha(153),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRandomAlbums(BuildContext context, WidgetRef ref, List<Album> albums) {
    final colorTheme = ref.watch(colorThemeProvider);
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return GestureDetector(
          onTap: () {
            ref.read(navigationProvider.notifier).pushSongPage(album);
          },
          child: Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageCacheManager().getCachedImage(
                    imageUrl: album.coverArt != null
                        ? ref.read(apiClientProvider).getCoverArtUrl(album.coverArt!, itemId: album.id)
                        : '',
                    width: 120,
                    height: 120,
                    cacheKey: 'album_${album.id}',
                    placeholder: _buildPlaceholder(120, colorTheme: colorTheme),
                    errorWidget: _buildPlaceholder(120, colorTheme: colorTheme),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  album.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withAlpha(153),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(double height, {double? width, AppColorTheme? colorTheme}) {
    return Container(
      width: width ?? height,
      height: height,
      color: colorTheme?.surfaceColor,
      child: Icon(
        Icons.album,
        size: height * 0.4,
        color: Colors.white.withAlpha(77),
      ),
    );
  }
}
