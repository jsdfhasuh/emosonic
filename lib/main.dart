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
import 'core/utils/logger.dart';
import 'core/utils/image_cache_manager.dart';
import 'core/cache/audio_cache_manager.dart';
import 'services/tray_service.dart';
import 'services/audio_player_service.dart';

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
    final serverConfig = ref.watch(serverConfigProvider);

    return MaterialApp(
      title: 'Sonic Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
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
      home: serverConfig == null
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
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _initTrayService();
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
    final prefs = await SharedPreferences.getInstance();
    final behavior = prefs.getString('window_close_behavior') ?? 'ask';
    
    switch (behavior) {
      case 'exit':
        // Direct exit
        await TrayService().dispose();
        await windowManager.destroy();
        break;
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

    return PopScope(
      canPop: !navigationNotifier.canPop,
      onPopInvokedWithResult: (didPop, result) {
        // If there are sub-pages, go back instead of exiting the app
        if (!didPop && navigationNotifier.canPop) {
          navigationNotifier.pop();
        }
      },
      child: Scaffold(
        body: Stack(
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
        // Only show bottom navigation bar on main pages
        bottomNavigationBar: _shouldShowBottomNav(navigation.currentPage)
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
