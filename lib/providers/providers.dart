import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/utils/logger.dart';
import '../core/cache/audio_cache_manager.dart';
import '../data/models/models.dart';
import '../data/models/search_result.dart';
import '../data/services/subsonic/subsonic_api_client.dart' show AlbumListType, SubsonicApiClient;
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import '../data/models/lyric_line.dart';

// Export navigation provider
export 'navigation_provider.dart';

// Export auto resume playback provider
export 'auto_resume_playback_provider.dart';

// Export color theme provider
export 'color_theme_provider.dart';

// Export sleep timer provider
export 'sleep_timer_provider.dart';

// Import server configs provider (must be before apiClientProvider)
// Using import instead of export to make serverConfigsProvider available immediately
import 'server_configs_provider.dart';

// Re-export server configs for other files
export 'server_configs_provider.dart';

// API Client Provider - listens to active server changes
// This is defined after importing server_configs_provider.dart
final apiClientProvider = Provider<SubsonicApiClient>((ref) {
  final client = SubsonicApiClient();
  // Watch serverConfigsProvider to rebuild when server changes
  final serverState = ref.watch(serverConfigsProvider);
  final activeServer = serverState.activeServer;
  
  if (activeServer != null) {
    client.setConfig(activeServer);
  }
  
  return client;
});



// Audio Player Service Provider
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = AudioPlayerService(apiClient);

  // Set up callback to sync current song state
  service.onSongChanged = (song) {
    if (song != null) {
      // Update current song provider
      ref.read(currentSongProvider.notifier).state = song;
    }
  };

  // Set up callback to sync playing state
  service.onPlayingStateChanged = (isPlaying) {
    ref.read(isPlayingProvider.notifier).state = isPlaying;
  };

  return service;
});

// Artists Provider
final artistsProvider = FutureProvider<List<Artist>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getArtists();
});

// Albums Provider
final albumsProvider = FutureProvider.family<List<Album>, String>((ref, artistId) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getAlbumsByArtist(artistId);
});

// Songs Provider
final songsProvider = FutureProvider.family<List<Song>, String>((ref, albumId) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getSongsByAlbum(albumId);
});

// Search Provider
final searchProvider = FutureProvider.family<SearchResult, String>((ref, query) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.search(query);
});

// Search History Provider
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const String _prefsKey = 'search_history';
  static const int _maxHistory = 10;

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_prefsKey) ?? [];
    state = history;
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;

    final newHistory = [query, ...state.where((q) => q != query)];
    if (newHistory.length > _maxHistory) {
      newHistory.removeLast();
    }

    state = newHistory;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, newHistory);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

// Genres Provider
final genresProvider = FutureProvider<List<Genre>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getGenres();
});

// Album List Provider - Paginated
final paginatedAlbumsProvider = StateNotifierProvider<PaginatedAlbumsNotifier, PaginatedAlbumsState>((ref) {
  return PaginatedAlbumsNotifier(ref.watch(apiClientProvider));
});

class PaginatedAlbumsState {
  final List<Album> albums;
  final bool isLoading;
  final bool hasMore;
  final int currentOffset;
  final String? error;
  final AlbumListType sortType;

  const PaginatedAlbumsState({
    this.albums = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentOffset = 0,
    this.error,
    this.sortType = AlbumListType.newest,
  });

  PaginatedAlbumsState copyWith({
    List<Album>? albums,
    bool? isLoading,
    bool? hasMore,
    int? currentOffset,
    String? error,
    AlbumListType? sortType,
  }) {
    return PaginatedAlbumsState(
      albums: albums ?? this.albums,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      error: error ?? this.error,
      sortType: sortType ?? this.sortType,
    );
  }
}

class PaginatedAlbumsNotifier extends StateNotifier<PaginatedAlbumsState> {
  final SubsonicApiClient _apiClient;
  static const int _pageSize = 50;

  PaginatedAlbumsNotifier(this._apiClient) : super(const PaginatedAlbumsState());

  Future<void> setSortType(AlbumListType type) async {
    if (state.sortType == type) return;
    // Reset state but keep the new sortType
    state = PaginatedAlbumsState(sortType: type);
    await loadMore();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final newAlbums = await _apiClient.getAlbumList(
        type: state.sortType,
        size: _pageSize,
        offset: state.currentOffset,
      );

      final allAlbums = [...state.albums, ...newAlbums];
      final hasMore = newAlbums.length == _pageSize;

      state = state.copyWith(
        albums: allAlbums,
        isLoading: false,
        hasMore: hasMore,
        currentOffset: state.currentOffset + newAlbums.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = const PaginatedAlbumsState();
    await loadMore();
  }
}

// Playlists Provider
final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getPlaylists();
});

// Playlist Songs Provider
final playlistSongsProvider = FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getPlaylistSongs(playlistId);
});

// Random Songs Provider
final randomSongsProvider = FutureProvider<List<Song>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getRandomSongs(size: 100);
});

// Songs by Genre Provider
final songsByGenreProvider = FutureProvider.family<List<Song>, String>((ref, genre) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getSongsByGenre(genre);
});

// Recent Albums Provider
final recentAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getAlbumList(type: AlbumListType.recent, size: 10);
});

// Random Albums Provider (Hot Recommendations)
final randomAlbumsForHotProvider = FutureProvider<List<Album>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getAlbumList(type: AlbumListType.random, size: 5);
});

// Random Albums Provider (Discovery)
final randomAlbumsForDiscoveryProvider = FutureProvider<List<Album>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getAlbumList(type: AlbumListType.random, size: 10);
});

// Newest Albums Provider
final newestAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getAlbumList(type: AlbumListType.newest, size: 10);
});

// Queue Notifier - manages queue state
final queueProvider = StateNotifierProvider<QueueNotifier, List<Song>>((ref) {
  return QueueNotifier();
});

class QueueNotifier extends StateNotifier<List<Song>> {
  QueueNotifier() : super([]);

  void setQueue(List<Song> songs) {
    state = songs;
  }

  void addToQueue(Song song) {
    state = [...state, song];
  }

  void insertNext(Song song, int currentIndex) {
    final insertIndex = currentIndex + 1;
    if (insertIndex <= state.length) {
      final newQueue = [...state];
      newQueue.insert(insertIndex, song);
      state = newQueue;
    }
  }

  void removeFromQueue(Song song) {
    state = state.where((s) => s.id != song.id).toList();
  }

  void clearQueue() {
    state = [];
  }

  List<Song> get queue => state;
}

// Library Category Provider
final libraryCategoryProvider = StateProvider<LibraryCategory>((ref) => LibraryCategory.artists);

// Current Song Provider
final currentSongProvider = StateProvider<Song?>((ref) => null);

// Listen to current song changes
void initCurrentSongListener(ProviderContainer container) {
  container.listen(currentSongProvider, (previous, next) {
    // Current song state changed
  });
}

// Is Playing Provider
final isPlayingProvider = StateProvider<bool>((ref) => false);

// Image Cache Disabled Provider
final imageCacheDisabledProvider = StateNotifierProvider<ImageCacheDisabledNotifier, bool>((ref) {
  return ImageCacheDisabledNotifier();
});

class ImageCacheDisabledNotifier extends StateNotifier<bool> {
  ImageCacheDisabledNotifier() : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('image_cache_disabled') ?? false;
  }

  Future<void> setDisabled(bool disabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('image_cache_disabled', disabled);
    state = disabled;
  }
}

// Volume Provider
final volumeProvider = StreamProvider<double>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.volumeStream;
});

// Loop Mode Provider
final loopModeProvider = StreamProvider<LoopMode>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.loopModeStream;
});

// Shuffle Mode Provider - 使用 StateNotifierProvider 确保有初始值
final shuffleModeProvider = StateNotifierProvider<ShuffleModeNotifier, bool>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return ShuffleModeNotifier(audioService);
});

class ShuffleModeNotifier extends StateNotifier<bool> {
  StreamSubscription<bool>? _subscription;

  ShuffleModeNotifier(AudioPlayerService audioService) : super(false) {
    // 立即获取当前状态
    state = audioService.shuffleModeEnabled;

    // 监听状态变化
    _subscription = audioService.shuffleModeStateStream.listen((enabled) {
      state = enabled;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Playback Speed Provider
final speedProvider = StreamProvider<double>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.speedStream;
});

// Audio cache settings
final audioCacheEnabledProvider = StateNotifierProvider<AudioCacheEnabledNotifier, bool>((ref) {
  return AudioCacheEnabledNotifier();
});

class AudioCacheEnabledNotifier extends StateNotifier<bool> {
  AudioCacheEnabledNotifier() : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('audio_cache_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_cache_enabled', enabled);
    state = enabled;
  }
}

// Audio cache playback settings
final audioCachePlaybackEnabledProvider = StateNotifierProvider<AudioCachePlaybackEnabledNotifier, bool>((ref) {
  return AudioCachePlaybackEnabledNotifier();
});

class AudioCachePlaybackEnabledNotifier extends StateNotifier<bool> {
  AudioCachePlaybackEnabledNotifier() : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('audio_cache_playback_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_cache_playback_enabled', enabled);
    state = enabled;
  }
}

final audioCacheSizeProvider = StateNotifierProvider<AudioCacheSizeNotifier, int>((ref) {
  return AudioCacheSizeNotifier();
});

class AudioCacheSizeNotifier extends StateNotifier<int> {
  static const int defaultSize = 2048; // 2GB

  AudioCacheSizeNotifier() : super(defaultSize) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt('audio_cache_size_mb') ?? defaultSize;
    // Apply to cache manager
    await AudioCacheManager().setMaxCacheSizeMB(state);
  }

  Future<void> setSize(int sizeMB) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('audio_cache_size_mb', sizeMB);
    state = sizeMB;
    await AudioCacheManager().setMaxCacheSizeMB(sizeMB);
  }
}

final audioCacheStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await AudioCacheManager().getCacheStats();
});

// Scrobble setting
final scrobbleEnabledProvider = StateNotifierProvider<ScrobbleEnabledNotifier, bool>((ref) {
  return ScrobbleEnabledNotifier();
});

class ScrobbleEnabledNotifier extends StateNotifier<bool> {
  static const bool defaultValue = true;

  ScrobbleEnabledNotifier() : super(defaultValue) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('scrobble_enabled') ?? defaultValue;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scrobble_enabled', enabled);
    state = enabled;
  }
}

// Window close behavior setting (Windows only)
final windowCloseBehaviorProvider = StateNotifierProvider<WindowCloseBehaviorNotifier, String>((ref) {
  return WindowCloseBehaviorNotifier();
});

class WindowCloseBehaviorNotifier extends StateNotifier<String> {
  static const String defaultBehavior = 'ask'; // ask, minimize, exit

  WindowCloseBehaviorNotifier() : super(defaultBehavior) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('window_close_behavior') ?? defaultBehavior;
  }

  Future<void> setBehavior(String behavior) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('window_close_behavior', behavior);
    state = behavior;
  }
}

// Cache cover image setting
final cacheCoverImageProvider = StateNotifierProvider<CacheCoverImageNotifier, bool>((ref) {
  return CacheCoverImageNotifier();
});

class CacheCoverImageNotifier extends StateNotifier<bool> {
  CacheCoverImageNotifier() : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('cache_cover_image') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cache_cover_image', enabled);
    state = enabled;
  }
}

// Offline mode with real connectivity detection
final offlineModeProvider = StateNotifierProvider<OfflineModeNotifier, bool>((ref) {
  return OfflineModeNotifier();
});

class OfflineModeNotifier extends StateNotifier<bool> {
  StreamSubscription? _connectivitySubscription;

  OfflineModeNotifier() : super(false) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check initial connectivity
    await _checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOffline = result == ConnectivityResult.none;
      if (isOffline != state) {
        state = isOffline;
        Logger('OfflineModeNotifier').info('Network status changed: ${isOffline ? "offline" : "online"}');
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    state = result == ConnectivityResult.none;
  }

  /// Manual override for testing or user preference
  void setOfflineMode(bool offline) {
    state = offline;
  }

  void toggle() {
    state = !state;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

// Cached songs provider
final cachedSongsProvider = FutureProvider<List<String>>((ref) async {
  return await AudioCacheManager().getCachedSongIds();
});

// Playback speed setting (persisted)
final playbackSpeedSettingProvider = StateNotifierProvider<PlaybackSpeedSettingNotifier, double>((ref) {
  return PlaybackSpeedSettingNotifier();
});

class PlaybackSpeedSettingNotifier extends StateNotifier<double> {
  static const double defaultSpeed = 1.0;

  PlaybackSpeedSettingNotifier() : super(defaultSpeed) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('playback_speed') ?? defaultSpeed;
  }

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('playback_speed', clamped);
    state = clamped;
  }
}

// Shuffle mode setting (persisted)
final shuffleModeSettingProvider = StateNotifierProvider<ShuffleModeSettingNotifier, bool>((ref) {
  return ShuffleModeSettingNotifier();
});

class ShuffleModeSettingNotifier extends StateNotifier<bool> {
  ShuffleModeSettingNotifier() : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('shuffle_mode') ?? false;
  }

  Future<void> setShuffleMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shuffle_mode', enabled);
    state = enabled;
  }
}

// Desktop navigation rail expanded state (persisted)
final desktopNavExpandedProvider = StateNotifierProvider<DesktopNavExpandedNotifier, bool>((ref) {
  return DesktopNavExpandedNotifier();
});

class DesktopNavExpandedNotifier extends StateNotifier<bool> {
  DesktopNavExpandedNotifier() : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('desktop_nav_expanded') ?? false;
  }

  Future<void> setExpanded(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('desktop_nav_expanded', expanded);
    state = expanded;
  }
}

// Lyrics Service Provider
final lyricsServiceProvider = Provider<LyricsService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LyricsService(apiClient);
});

// Lyrics Provider - fetches lyrics for a specific song
final lyricsProvider = FutureProvider.family<List<LyricLine>, Song>((ref, song) async {
  final lyricsService = ref.watch(lyricsServiceProvider);
  return lyricsService.getLyricsForSong(song);
});

// Current lyric index provider - tracks which line is currently playing
final currentLyricIndexProvider = StateProvider<int>((ref) => 0);

// Player screen tab enum
enum PlayerTab { album, lyrics }

// Player screen tab provider
final playerTabProvider = StateProvider<PlayerTab>((ref) => PlayerTab.album);
