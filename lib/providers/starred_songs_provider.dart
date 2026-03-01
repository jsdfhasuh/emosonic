import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/song.dart';
import '../../data/models/starred_cache.dart';
import '../../data/services/subsonic/subsonic_api_client.dart';
import 'providers.dart';

/// Provider for the starred cache instance
final starredCacheProvider = Provider<StarredCache>((ref) => StarredCache());

/// State class for starred songs list (no pagination)
class StarredSongsState {
  final List<Song> songs;
  final bool isLoading;
  final String? error;

  const StarredSongsState({
    this.songs = const [],
    this.isLoading = false,
    this.error,
  });

  StarredSongsState copyWith({
    List<Song>? songs,
    bool? isLoading,
    String? error,
  }) {
    return StarredSongsState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing starred songs list (no pagination)
class StarredSongsNotifier extends StateNotifier<StarredSongsState> {
  final SubsonicApiClient _apiClient;
  final Ref _ref;

  StarredSongsNotifier(this._apiClient, this._ref) : super(const StarredSongsState());

  /// Load all starred songs at once
  Future<void> loadStarredSongs({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(
        songs: [],
        error: null,
      );
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load all starred songs without pagination
      final response = await _apiClient.getStarred2();

      final songsList = (response['song'] as List<dynamic>?)
          ?.map((json) => Song.fromJson(json as Map<String, dynamic>))
          .toList() ?? [];

      // Update cache with all starred song IDs
      final songIds = songsList.map((song) => song.id).toList();
      _ref.read(starredCacheProvider).updateStarredSongs(songIds);

      state = state.copyWith(
        songs: songsList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载收藏歌曲失败: $e',
      );
    }
  }
}

/// Provider for starred songs list
final starredSongsProvider = StateNotifierProvider<StarredSongsNotifier, StarredSongsState>(
  (ref) => StarredSongsNotifier(ref.read(apiClientProvider), ref),
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

        // Only refresh the specific song's starred status
        // Don't invalidate the whole list to avoid blank page
        ref.invalidate(isSongStarredProvider(songId));
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
