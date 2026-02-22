import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/song.dart';
import '../../data/models/starred_cache.dart';
import '../../data/services/subsonic/subsonic_api_client.dart';
import 'providers.dart';

/// Provider for the starred cache instance
final starredCacheProvider = Provider<StarredCache>((ref) => StarredCache());

/// State class for starred songs list
class StarredSongsState {
  final List<Song> songs;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int offset;
  final int limit;

  const StarredSongsState({
    this.songs = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = 50,
  });

  StarredSongsState copyWith({
    List<Song>? songs,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
  }) {
    return StarredSongsState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
    );
  }
}

/// Notifier for managing starred songs list
class StarredSongsNotifier extends StateNotifier<StarredSongsState> {
  final SubsonicApiClient _apiClient;

  StarredSongsNotifier(this._apiClient) : super(const StarredSongsState());

  /// Load starred songs (initial load or refresh)
  Future<void> loadStarredSongs({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(
        offset: 0,
        songs: [],
        hasMore: true,
        error: null,
      );
    }

    if (!state.hasMore && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.getStarred2(
        offset: state.offset,
        limit: state.limit,
      );

      final songsList = (response['song'] as List<dynamic>?)
          ?.map((json) => Song.fromJson(json as Map<String, dynamic>))
          .toList() ?? [];

      final allSongs = refresh
          ? songsList
          : [...state.songs, ...songsList];

      state = state.copyWith(
        songs: allSongs,
        isLoading: false,
        hasMore: songsList.length >= state.limit,
        offset: state.offset + songsList.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载收藏歌曲失败: $e',
      );
    }
  }

  /// Load more songs (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await loadStarredSongs();
  }
}

/// Provider for starred songs list
final starredSongsProvider = StateNotifierProvider<StarredSongsNotifier, StarredSongsState>(
  (ref) => StarredSongsNotifier(ref.read(apiClientProvider)),
);

/// Provider to check if a specific song is starred
final isSongStarredProvider = StateProvider.family<bool, String>(
  (ref, songId) {
    final cache = ref.watch(starredCacheProvider);
    return cache.isStarred(songId);
  },
);

/// Provider to toggle star status for a song
final toggleStarProvider = Provider.family<Future<void> Function(), String>(
  (ref, songId) {
    return () async {
      final apiClient = ref.read(apiClientProvider);
      final cache = ref.read(starredCacheProvider);
      final isStarred = cache.isStarred(songId);

      try {
        if (isStarred) {
          await apiClient.unstar(songIds: [songId]);
          cache.removeStarred(songId);
        } else {
          await apiClient.star(songIds: [songId]);
          cache.addStarred(songId);
        }

        // Invalidate starred songs provider to refresh list
        ref.invalidate(starredSongsProvider);
      } catch (e) {
        rethrow;
      }
    };
  },
);

/// Provider to initialize starred cache from server
final initializeStarredCacheProvider = FutureProvider<void>((ref) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final cache = ref.read(starredCacheProvider);
    
    final response = await apiClient.getStarred2();
    
    final songIds = (response['song'] as List<dynamic>?)
        ?.map((json) => json['id'] as String)
        .toList() ?? [];
    
    cache.updateStarredSongs(songIds);
  } catch (e) {
    // Silently fail - don't break app startup
    // ignore: avoid_print
    print('Failed to initialize starred cache: $e');
  }
});