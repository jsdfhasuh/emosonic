# Album Pagination Implementation

## Overview
Implement pagination for album list with lazy image loading to handle large music libraries (tens of thousands of albums).

## Architecture

### 1. Data Layer
- **Page Size**: 50 albums per page
- **Offset-based pagination**: Using `offset` parameter in API
- **State Management**: Riverpod for reactive updates

### 2. UI Layer
- **GridView.builder**: Efficient list rendering
- **ScrollController**: Monitor scroll position
- **Visibility Detection**: Load images only for visible items

### 3. Image Loading
- **Concurrency Limit**: Max 5 simultaneous downloads
- **Priority Queue**: Visible items load first
- **Preload**: 2 rows above and below visible area

## Implementation Details

### State Structure
```dart
class PaginatedAlbumsState {
  final List<Album> albums;
  final bool isLoading;
  final bool hasMore;
  final int currentOffset;
  final String? error;
  
  const PaginatedAlbumsState({
    this.albums = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentOffset = 0,
    this.error,
  });
}
```

### Loading Strategy
1. Initial load: First 50 albums
2. Scroll to 80%: Load next 50
3. Image loading: Only for visible + preload area
4. Memory limit: Keep all loaded albums (user expectation)

### API Changes
```dart
// Add offset parameter
Future<List<Album>> getAlbumList({
  AlbumListType type = AlbumListType.newest,
  int size = 50,
  int offset = 0,
});
```

### Image Loading Queue
```dart
class ImageLoadQueue {
  final maxConcurrent = 5;
  final List<String> _queue = [];
  final Set<String> _loading = {};
  
  void enqueue(String cacheKey, {bool highPriority = false});
  void dequeue(String cacheKey);
}
```

## Implementation Status

### ✅ Completed

1. **lib/data/services/subsonic/subsonic_api_client.dart**
   - ✅ Offset parameter already supported in getAlbumList
   - ✅ Default image size set to 600px

2. **lib/providers/providers.dart**
   - ✅ Added PaginatedAlbumsState class
   - ✅ Added PaginatedAlbumsNotifier with loadMore() and refresh()
   - ✅ Page size: 50 albums per request

3. **lib/ui/screens/library_screen.dart**
   - ✅ Converted _AlbumsView to StatefulWidget
   - ✅ Added ScrollController with pagination trigger (80% scroll)
   - ✅ Implemented lazy loading indicator at bottom
   - ✅ Auto-load more albums on scroll

### ⏳ Pending

4. **lib/core/utils/image_cache_manager.dart**
   - ImageLoadQueue for concurrency control
   - Priority loading for visible items
   - Preload 2 rows above and below

## Key Implementation Details

### Pagination Logic
```dart
// Trigger load when scrolled to 80%
if (_scrollController.position.pixels >=
    _scrollController.position.maxScrollExtent * 0.8) {
  ref.read(paginatedAlbumsProvider.notifier).loadMore();
}
```

### State Management
- Uses Riverpod StateNotifier
- Maintains list of all loaded albums
- Tracks loading state and hasMore flag
- Supports pull-to-refresh

### UI Updates
- Shows loading indicator at bottom when loading more
- GridView.builder efficiently recycles widgets
- LayoutBuilder calculates optimal column count dynamically

## Performance Considerations

- GridView.builder recycles widgets efficiently
- Only visible items trigger image loading
- Preload prevents visible lag when scrolling
- Cancel loading for items that scroll out of view
