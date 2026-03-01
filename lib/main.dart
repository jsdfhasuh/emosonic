import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/screens/server_config_screen.dart';
import 'ui/screens/discovery_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/player_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/album_screen.dart';
import 'ui/screens/songs_screen.dart';
import 'ui/screens/genre_detail_screen.dart';
import 'ui/screens/playlist_detail_screen.dart';
import 'ui/screens/search_results_screen.dart';
import 'ui/screens/starred_songs_screen.dart';
import 'ui/widgets/mini_player.dart';
import 'providers/providers.dart';
import 'providers/auto_resume_playback_provider.dart';
import 'providers/app_theme_provider.dart';
import 'core/utils/logger.dart';
import 'core/utils/image_cache_manager.dart';
import 'core/cache/audio_cache_manager.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for Windows
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    
    // Initialize SMTC for Windows
    await SMTCWindows.initialize();
  }

  // Load saved log level from local storage
  await Logger.loadLogLevel();

  // Initialize cache managers
  await ImageCacheManager().initialize();
  await AudioCacheManager().initialize();
  
  // Load image cache setting
  final prefs = await SharedPreferences.getInstance();
  final cacheDisabled = prefs.getBool('image_cache_disabled') ?? false;
  ImageCacheManager().setCacheDisabled(cacheDisabled);

  // Initialize logger
  final logger = Logger('Main');
  await logger.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF0A1628),
    ),
  );

  logger.info('App starting...');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeServer = ref.watch(serverConfigsProvider).activeServer;
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      title: 'Sonic Player',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode.flutterThemeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF6B8DD6),
          secondary: const Color(0xFF8B5CF6),
          surface: Colors.grey[100]!,
          onSurface: Colors.black87,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.grey[100]!,
          selectedItemColor: const Color(0xFF6B8DD6),
          unselectedItemColor: Colors.black54,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6B8DD6),
          secondary: const Color(0xFF8B5CF6),
          surface: const Color(0xFF1E293B),
          onSurface: Colors.white.withAlpha(230),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          selectedItemColor: Color(0xFF6B8DD6),
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B).withAlpha(204),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: activeServer == null
          ? const ServerConfigScreen()
          : const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WindowListener {
  String _windowCloseBehavior = 'ask';

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _initTrayService();
    }
    // Restore playback state if auto-resume is enabled
    _restorePlaybackState();
    // Cache window close behavior
    _loadWindowCloseBehavior();
  }

  Future<void> _loadWindowCloseBehavior() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _windowCloseBehavior = prefs.getString('window_close_behavior') ?? 'ask';
      Logger('Main').info('Cached window_close_behavior: $_windowCloseBehavior');
    } catch (e) {
      Logger('Main').error('Failed to load window_close_behavior: $e');
    }
  }

  Future<void> _restorePlaybackState() async {
    Logger('Main').info('[DEBUG] _restorePlaybackState() started');

    // Wait for provider to be initialized
    Logger('Main').info('[DEBUG] Waiting for provider initialization...');
    final notifier = ref.read(autoResumePlaybackProvider.notifier);
    while (!notifier.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    Logger('Main').info('[DEBUG] Provider initialized');

    Logger('Main').info('[DEBUG] Reading autoResumePlaybackProvider...');
    final autoResumeEnabled = ref.read(autoResumePlaybackProvider);
    Logger('Main').info('[DEBUG] autoResumePlaybackProvider value: $autoResumeEnabled');

    if (!autoResumeEnabled) {
      Logger('Main').info('[DEBUG] Auto resume playback is disabled, returning');
      return;
    }

    Logger('Main').info('Auto resume playback is enabled, attempting to restore...');

    // Get container before any async operations
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);

    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      final restored = await audioService.restorePlaybackState();

      if (restored) {
        Logger('Main').info('Playback state restored successfully');
        // Update currentSongProvider to refresh MiniPlayer
        final currentSong = audioService.currentSong;
        if (currentSong != null) {
          Logger('Main').info('[DEBUG] Updating currentSongProvider with: ${currentSong.title}');
          ref.read(currentSongProvider.notifier).state = currentSong;
          Logger('Main').info('[DEBUG] currentSongProvider updated successfully');
        }

        // Apply saved playback speed
        final savedSpeed = container.read(playbackSpeedSettingProvider);
        if (savedSpeed != 1.0) {
          try {
            await audioService.setSpeed(savedSpeed);
          } catch (e) {
            Logger('Main').error('Failed to restore playback speed: $e');
          }
        }

        // Apply saved shuffle mode
        final savedShuffleMode = container.read(shuffleModeSettingProvider);
        if (savedShuffleMode) {
          try {
            await audioService.setShuffleModeEnabled(true);
          } catch (e) {
            Logger('Main').error('Failed to restore shuffle mode: $e');
          }
        }
      } else {
        Logger('Main').info('No playback state to restore or restore failed');
      }
    } catch (e, stackTrace) {
      Logger('Main').error('[DEBUG] Exception in _restorePlaybackState: $e');
      Logger('Main').error('[DEBUG] Stack trace: $stackTrace');
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      TrayService().dispose();
    }
    super.dispose();
  }

  Future<void> _initTrayService() async {
    final audioService = ref.read(audioPlayerServiceProvider);
    await TrayService().initialize(audioService);
    // Prevent window from closing immediately
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    final startTime = DateTime.now();
    Logger('Main').info('Exit timing: onWindowClose started at ${startTime.toIso8601String()}');

    // Save playback state asynchronously without blocking
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      audioService.savePlaybackState().then((_) {
        Logger('Main').info('Playback state saved before exit (async)');
      }).catchError((e) {
        Logger('Main').error('Failed to save playback state: $e');
      });
    } catch (e) {
      Logger('Main').error('Failed to start playback state save: $e');
    }

    // Use cached behavior to avoid blocking on SharedPreferences
    final behavior = _windowCloseBehavior;
    Logger('Main').info('Exit timing: Using cached behavior: $behavior');
    
    switch (behavior) {
      case 'exit':
        // Direct exit - hide window first then force close
        Logger('Main').info('Exit timing: Hiding window before exit');
        
        // Hide window immediately for better UX
        await windowManager.hide();
        
        // Allow window to close
        await windowManager.setPreventClose(false);
        
        // Force exit immediately - skip cleanup to ensure fast exit
        Logger('Main').info('Exit timing: Calling exit(0)');
        exit(0);
      case 'minimize':
        // Minimize to tray
        await windowManager.hide();
        break;
      case 'ask':
      default:
        // Show confirmation dialog
        final shouldExit = await TrayService.showExitConfirmation(context);
        if (shouldExit) {
          await TrayService().dispose();
          await windowManager.destroy();
        } else {
          await windowManager.hide();
        }
        break;
    }
  }

  @override
  void onWindowFocus() {
    // Ensure window is shown when focused
  }

  @override
  Widget build(BuildContext context) {
    final navigation = ref.watch(navigationProvider);
    final navigationNotifier = ref.read(navigationProvider.notifier);

    // Check if desktop platform
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return PopScope(
      canPop: !navigationNotifier.canPop,
      onPopInvokedWithResult: (didPop, result) {
        // If there are sub-pages, go back instead of exiting the app
        if (!didPop && navigationNotifier.canPop) {
          navigationNotifier.pop();
        }
      },
      child: Scaffold(
        body: isDesktop
            ? _buildDesktopLayout(navigation, navigationNotifier)
            : _buildMobileLayout(navigation, navigationNotifier),
        // Only show bottom navigation bar on mobile main pages
        bottomNavigationBar: !isDesktop && _shouldShowBottomNav(navigation.currentPage)
            ? BottomNavigationBar(
                currentIndex: _getBottomNavIndex(navigation.currentPage),
                onTap: (index) => _onBottomNavTap(index, navigationNotifier),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore_outlined),
                    activeIcon: Icon(Icons.explore),
                    label: '发现',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.library_music_outlined),
                    activeIcon: Icon(Icons.library_music),
                    label: '音乐库',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite_outline),
                    activeIcon: Icon(Icons.favorite),
                    label: '收藏',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.play_circle_outline),
                    activeIcon: Icon(Icons.play_circle),
                    label: '播放',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildDesktopLayout(NavigationState navigation, NavigationNotifier navigationNotifier) {
    final isExpanded = ref.watch(desktopNavExpandedProvider);

    return Row(
      children: [
        // Left navigation rail
        NavigationRail(
          extended: isExpanded,
          minExtendedWidth: 200,
          minWidth: 72,
          selectedIndex: _getBottomNavIndex(navigation.currentPage),
          onDestinationSelected: (index) => _onBottomNavTap(index, navigationNotifier),
          leading: IconButton(
            iconSize: 28,
            icon: Icon(isExpanded ? Icons.menu_open : Icons.menu),
            onPressed: () {
              ref.read(desktopNavExpandedProvider.notifier).setExpanded(!isExpanded);
            },
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.explore_outlined, size: 28),
              selectedIcon: Icon(Icons.explore, size: 28),
              label: Text('发现'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.library_music_outlined, size: 28),
              selectedIcon: Icon(Icons.library_music, size: 28),
              label: Text('音乐库'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.favorite_outline, size: 28),
              selectedIcon: Icon(Icons.favorite, size: 28),
              label: Text('收藏'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.play_circle_outline, size: 28),
              selectedIcon: Icon(Icons.play_circle, size: 28),
              label: Text('播放'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined, size: 28),
              selectedIcon: Icon(Icons.settings, size: 28),
              label: Text('设置'),
            ),
          ],
        ),
        // Vertical divider
        const VerticalDivider(thickness: 1, width: 1),
        // Main content area
        Expanded(
          child: Stack(
            children: [
              // Main page content
              _buildMainContent(navigation.currentPage),

              // Sub-pages (Album/Songs) as overlay
              if (navigation.currentPage == PageType.album &&
                  navigation.selectedArtist != null)
                AlbumScreen(
                  artist: navigation.selectedArtist!,
                  onBack: () => navigationNotifier.pop(),
                ),

              if (navigation.currentPage == PageType.songs &&
                  navigation.selectedAlbum != null)
                SongsScreen(
                  album: navigation.selectedAlbum!,
                  onBack: () => navigationNotifier.pop(),
                ),

              if (navigation.currentPage == PageType.genreDetail &&
                  navigation.selectedGenre != null)
                GenreDetailScreen(
                  genreName: navigation.selectedGenre!,
                  onBack: () => navigationNotifier.pop(),
                ),

              if (navigation.currentPage == PageType.playlistDetail &&
                  navigation.selectedPlaylist != null)
                PlaylistDetailScreen(
                  playlist: navigation.selectedPlaylist!,
                  onBack: () => navigationNotifier.pop(),
                ),

              if (navigation.currentPage == PageType.searchResults &&
                  navigation.searchQuery != null)
                SearchResultsScreen(
                  query: navigation.searchQuery!,
                  onBack: () => navigationNotifier.pop(),
                ),

              // MiniPlayer - show on all pages except player page
              if (navigation.currentPage != PageType.player)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MiniPlayer(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(NavigationState navigation, NavigationNotifier navigationNotifier) {
    return Stack(
      children: [
        // Main page content
        _buildMainContent(navigation.currentPage),

        // Sub-pages (Album/Songs) as overlay
        if (navigation.currentPage == PageType.album &&
            navigation.selectedArtist != null)
          AlbumScreen(
            artist: navigation.selectedArtist!,
            onBack: () => navigationNotifier.pop(),
          ),

        if (navigation.currentPage == PageType.songs &&
            navigation.selectedAlbum != null)
          SongsScreen(
            album: navigation.selectedAlbum!,
            onBack: () => navigationNotifier.pop(),
          ),

        if (navigation.currentPage == PageType.genreDetail &&
            navigation.selectedGenre != null)
          GenreDetailScreen(
            genreName: navigation.selectedGenre!,
            onBack: () => navigationNotifier.pop(),
          ),

        if (navigation.currentPage == PageType.playlistDetail &&
            navigation.selectedPlaylist != null)
          PlaylistDetailScreen(
            playlist: navigation.selectedPlaylist!,
            onBack: () => navigationNotifier.pop(),
          ),

        if (navigation.currentPage == PageType.searchResults &&
            navigation.searchQuery != null)
          SearchResultsScreen(
            query: navigation.searchQuery!,
            onBack: () => navigationNotifier.pop(),
          ),

        // MiniPlayer - show on all pages except player page
        if (navigation.currentPage != PageType.player)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
      ],
    );
  }

  Widget _buildMainContent(PageType page, [Set<PageType>? visited]) {
    // Prevent infinite recursion
    visited ??= {};
    if (visited.contains(page)) {
      return const DiscoveryScreen();
    }
    visited.add(page);

    switch (page) {
      case PageType.discovery:
        return const DiscoveryScreen();
      case PageType.library:
        return const LibraryScreen();
      case PageType.starred:
        return const StarredSongsScreen();
      case PageType.player:
        return const PlayerScreen();
      case PageType.settings:
        return const SettingsScreen();
      default:
        // For sub-pages, show the corresponding main page
        if (page == PageType.album ||
            page == PageType.songs ||
            page == PageType.genreDetail ||
            page == PageType.playlistDetail ||
            page == PageType.searchResults) {
          // Return to the previous main page (from pageStack)
          final navigation = ref.read(navigationProvider);
          if (navigation.pageStack.isNotEmpty) {
            final mainPage = navigation.pageStack.last.pageType;
            // Only recurse if it's a main page
            if (mainPage == PageType.discovery ||
                mainPage == PageType.library ||
                mainPage == PageType.starred ||
                mainPage == PageType.player ||
                mainPage == PageType.settings) {
              return _buildMainContent(mainPage, visited);
            }
          }
          return const DiscoveryScreen();
        }
        return const DiscoveryScreen();
    }
  }

  bool _shouldShowBottomNav(PageType page) {
    // Only show bottom navigation bar on main pages
    return page == PageType.discovery ||
        page == PageType.library ||
        page == PageType.starred ||
        page == PageType.player ||
        page == PageType.settings;
  }

  int _getBottomNavIndex(PageType page) {
    switch (page) {
      case PageType.discovery:
        return 0;
      case PageType.library:
        return 1;
      case PageType.starred:
        return 2;
      case PageType.player:
        return 3;
      case PageType.settings:
        return 4;
      default:
        return 0;
    }
  }

  void _onBottomNavTap(int index, NavigationNotifier notifier) {
    switch (index) {
      case 0:
        notifier.switchToMainPage(PageType.discovery);
        break;
      case 1:
        notifier.switchToMainPage(PageType.library);
        break;
      case 2:
        notifier.switchToMainPage(PageType.starred);
        break;
      case 3:
        notifier.switchToMainPage(PageType.player);
        break;
      case 4:
        notifier.switchToMainPage(PageType.settings);
        break;
    }
  }
}
