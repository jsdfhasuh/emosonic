import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/models.dart';

// Page type enum
enum PageType {
  discovery, // Discovery page
  library, // Library page
  starred, // Starred songs page
  player, // Player page
  settings, // Settings page
  album, // Album list page (artist detail)
  songs, // Song list page (album detail)
  genreDetail, // Genre detail page
  playlistDetail, // Playlist detail page
  searchResults, // Search results page
}

// Library target category for navigation
enum LibraryTargetCategory {
  genres,
  albums,
  artists,
  songs,
  playlists,
}

// Navigation history item - saves complete state for back navigation
class NavigationHistoryItem {
  final PageType pageType;
  final LibraryTargetCategory? libraryCategory;
  final Artist? selectedArtist;
  final Album? selectedAlbum;
  final String? selectedGenre;
  final Playlist? selectedPlaylist;

  const NavigationHistoryItem({
    required this.pageType,
    this.libraryCategory,
    this.selectedArtist,
    this.selectedAlbum,
    this.selectedGenre,
    this.selectedPlaylist,
  });
}

// Page state
class NavigationState {
  final PageType currentPage;
  final Artist? selectedArtist;
  final Album? selectedAlbum;
  final String? selectedGenre; // For genre detail page
  final Playlist? selectedPlaylist; // For playlist detail page
  final String? searchQuery; // For search results page
  final LibraryTargetCategory? libraryTargetCategory; // For library page navigation
  final List<NavigationHistoryItem> pageStack; // Page stack for back navigation

  const NavigationState({
    required this.currentPage,
    this.selectedArtist,
    this.selectedAlbum,
    this.selectedGenre,
    this.selectedPlaylist,
    this.searchQuery,
    this.libraryTargetCategory,
    this.pageStack = const [],
  });

  NavigationState copyWith({
    PageType? currentPage,
    Artist? selectedArtist,
    Album? selectedAlbum,
    String? selectedGenre,
    Playlist? selectedPlaylist,
    String? searchQuery,
    LibraryTargetCategory? libraryTargetCategory,
    List<NavigationHistoryItem>? pageStack,
  }) {
    return NavigationState(
      currentPage: currentPage ?? this.currentPage,
      selectedArtist: selectedArtist ?? this.selectedArtist,
      selectedAlbum: selectedAlbum ?? this.selectedAlbum,
      selectedGenre: selectedGenre ?? this.selectedGenre,
      selectedPlaylist: selectedPlaylist ?? this.selectedPlaylist,
      searchQuery: searchQuery ?? this.searchQuery,
      libraryTargetCategory: libraryTargetCategory ?? this.libraryTargetCategory,
      pageStack: pageStack ?? this.pageStack,
    );
  }
}

// Navigation state Provider
final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(const NavigationState(currentPage: PageType.discovery));

  // Switch to main page (bottom navigation)
  void switchToMainPage(PageType page) {
    if (page == PageType.discovery ||
        page == PageType.library ||
        page == PageType.starred ||
        page == PageType.player ||
        page == PageType.settings) {
      state = NavigationState(currentPage: page);
    }
  }

  // Switch to library page with specific category
  void switchToLibraryCategory(LibraryTargetCategory category) {
    // Always update state to trigger listeners, even if already on library page
    state = state.copyWith(
      currentPage: PageType.library,
      libraryTargetCategory: category,
    );
  }

  // Enter album page (artist detail)
  void pushAlbumPage(Artist artist) {
    state = state.copyWith(
      currentPage: PageType.album,
      selectedArtist: artist,
      pageStack: [
        ...state.pageStack,
        NavigationHistoryItem(
          pageType: state.currentPage,
          libraryCategory: state.libraryTargetCategory,
          selectedArtist: state.selectedArtist,
          selectedAlbum: state.selectedAlbum,
          selectedGenre: state.selectedGenre,
          selectedPlaylist: state.selectedPlaylist,
        ),
      ],
    );
  }

  // Enter song page (album detail)
  void pushSongPage(Album album) {
    state = state.copyWith(
      currentPage: PageType.songs,
      selectedAlbum: album,
      pageStack: [
        ...state.pageStack,
        NavigationHistoryItem(
          pageType: state.currentPage,
          libraryCategory: state.libraryTargetCategory,
          selectedArtist: state.selectedArtist,
          selectedAlbum: state.selectedAlbum,
          selectedGenre: state.selectedGenre,
          selectedPlaylist: state.selectedPlaylist,
        ),
      ],
    );
  }

  // Enter genre detail page
  void pushGenrePage(String genreName) {
    state = state.copyWith(
      currentPage: PageType.genreDetail,
      selectedGenre: genreName,
      pageStack: [
        ...state.pageStack,
        NavigationHistoryItem(
          pageType: state.currentPage,
          libraryCategory: state.libraryTargetCategory,
          selectedArtist: state.selectedArtist,
          selectedAlbum: state.selectedAlbum,
          selectedGenre: state.selectedGenre,
          selectedPlaylist: state.selectedPlaylist,
        ),
      ],
    );
  }

  // Enter playlist detail page
  void pushPlaylistPage(Playlist playlist) {
    state = state.copyWith(
      currentPage: PageType.playlistDetail,
      selectedPlaylist: playlist,
      pageStack: [
        ...state.pageStack,
        NavigationHistoryItem(
          pageType: state.currentPage,
          libraryCategory: state.libraryTargetCategory,
          selectedArtist: state.selectedArtist,
          selectedAlbum: state.selectedAlbum,
          selectedGenre: state.selectedGenre,
          selectedPlaylist: state.selectedPlaylist,
        ),
      ],
    );
  }

  // Enter search results page
  void pushSearchResults(String query) {
    state = state.copyWith(
      currentPage: PageType.searchResults,
      searchQuery: query,
      pageStack: [
        ...state.pageStack,
        NavigationHistoryItem(
          pageType: state.currentPage,
          libraryCategory: state.libraryTargetCategory,
          selectedArtist: state.selectedArtist,
          selectedAlbum: state.selectedAlbum,
          selectedGenre: state.selectedGenre,
          selectedPlaylist: state.selectedPlaylist,
        ),
      ],
    );
  }

  // Go back to previous page
  void pop() {
    if (state.pageStack.isNotEmpty) {
      final previousItem = state.pageStack.last;
      final newStack = state.pageStack.sublist(0, state.pageStack.length - 1);

      state = NavigationState(
        currentPage: previousItem.pageType,
        pageStack: newStack,
        // Restore complete state from history
        libraryTargetCategory: previousItem.libraryCategory,
        selectedArtist: previousItem.selectedArtist,
        selectedAlbum: previousItem.selectedAlbum,
        selectedGenre: previousItem.selectedGenre,
        selectedPlaylist: previousItem.selectedPlaylist,
        // Clear searchQuery when popping from search results
        searchQuery: null,
      );
    }
  }

  // Check if can go back
  bool get canPop => state.pageStack.isNotEmpty;
}
