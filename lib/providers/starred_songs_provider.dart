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
<<<<<<< HEAD
  final int? totalCount;
=======
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c

  const StarredSongsState({
    this.songs = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.offset = 0,
    this.limit = 50,
<<<<<<< HEAD
    this.totalCount,
=======
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c
  });

  StarredSongsState copyWith({
    List<Song>? songs,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? offset,
    int? limit,
<<<<<<< HEAD
    int? totalCount,
=======
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c
  }) {
    return StarredSongsState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
<<<<<<< HEAD
      totalCount: totalCount ?? this.totalCount,
=======
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c
    );
  }
}

/// Notifier for managing starred songs list
class StarredSongsNotifier extends StateNotifier<StarredSongsState> {
  final SubsonicApiClient _apiClient;
<<<<<<< HEAD
  final Ref _ref;

  StarredSongsNotifier(this._apiClient, this._ref) : super(const StarredSongsState());
=======

  StarredSongsNotifier(this._apiClient) : super(const StarredSongsState());
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c

  /// Load starred songs (initial load or refresh)
  Future<void> loadStarredSongs({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(
        offset: 0,
        songs: [],
        hasMore: true,
        error: null,
<<<<<<< HEAD
        totalCount: null,
=======
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c
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

<<<<<<< HEAD
      // Update cache with all starred song IDs
      final songIds = allSongs.map((song) => song.id).toList();
      _ref.read(starredCacheProvider).updateStarredSongs(songIds);

      // Fix: hasMore should be true only if we got exactly 'limit' songs
      // If we got fewer, we've reached the end
      state = state.copyWith(
        songs: allSongs,
        isLoading: false,
        hasMore: songsList.length == state.limit,
        offset: state.offset + songsList.length,
        totalCount: response['song'] != null 
            ? (response['song'] as List).length + state.offset
            : allSongs.length,
=======
      state = state.copyWith(
        songs: allSongs,
        isLoading: false,
        hasMore: songsList.length >= state.limit,
        offset: state.offset + songsList.length,
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c
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
<<<<<<< HEAD
  (ref) => StarredSongsNotifier(ref.read(apiClientProvider), ref),
=======
  (ref) => StarredSongsNotifier(ref.read(apiClientProvider)),
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c
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

<<<<<<< HEAD
        // Only refresh the specific song's starred status
        // Don't invalidate the whole list to avoid blank page
        ref.refresh(isSongStarredProvider(songId));
=======
        // Invalidate starred songs provider to refresh list
        ref.invalidate(starredSongsProvider);
>>>>>>> 9b98f38f03ce18f1c5af23b3c1a8f1058206373c
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