# Image Cache Improvement Plan

## Status: ✅ IMPLEMENTED

## Problem Analysis

1. **Cache Pollution** - JSON error responses are being cached instead of images
2. **Cache Key Issues** - URL changes (different tokens) but cacheKey remains same
3. **Size Parameter** - Cache keys include size, causing multiple cache entries for same image

## Solution Implemented

### 1. Auto-Retry Mechanism ✅
When JSON error detected in cache:
- **Detection**: Check if cached data starts with `{` (JSON)
- **Action**: Delete invalid cache automatically
- **Max retries**: 2 times with suffix `_retry1`, `_retry2`
- **Logging**: Detailed error logging for debugging

### 2. Simplified Cache Keys ✅
Cache keys standardized (no size parameter):
- Album: `album_${albumId}`
- Artist: `artist_${artistId}`
- Playlist: `playlist_${playlistId}`
- Song: Uses album cover `album_${albumId}`

### 3. Cache Disable Option ✅
Added setting to disable image caching:
- Location: Settings → "Don't use image cache"
- Effect: Images reload from server every time
- Persistence: Saved to SharedPreferences

## Implementation Details

### ImageCacheManager Changes
```dart
// New methods:
- setCacheDisabled(bool)  // Enable/disable caching
- isCacheDisabled         // Check cache status
- _isJsonError()          // Detect JSON errors
- _checkAndRetry()        // Auto-retry logic

// Modified:
- getCachedImage()        // Added retryCount parameter
- errorWidget callback    // Auto-detect and retry on JSON errors
```

### Key Features
1. **Automatic retry**: When Invalid image data error occurs, automatically deletes cache
2. **JSON detection**: Checks if cached data is JSON error response
3. **No size in cacheKey**: Consistent caching regardless of display size
4. **Disable option**: Users can disable caching entirely

## Usage

### Normal Usage (with retry)
```dart
ImageCacheManager().getCachedImage(
  imageUrl: imageUrl,
  cacheKey: 'album_${album.id}',  // No size in key
  width: 100,
  height: 100,
)
```

### Disable Cache
```dart
// In settings or app initialization:
ImageCacheManager().setCacheDisabled(true);
```

## Files Modified

### New Custom Cache System
1. ✅ `lib/core/cache/cache_entry.dart` - Cache metadata models
2. ✅ `lib/core/cache/sonic_cache_manager.dart` - Custom cache manager
3. ✅ `lib/core/utils/image_cache_manager.dart` - Updated to use custom cache

### Settings & State Management
4. ✅ `lib/providers/providers.dart` - Cache disable provider
5. ✅ `lib/ui/screens/settings_screen.dart` - Disable cache toggle
6. ✅ `lib/main.dart` - Initialize cache on startup

### Removed Size Parameter (Request Original Images)
7. ✅ `lib/ui/screens/library_screen.dart` - Album grid, artist list, song list, playlist list
8. ✅ `lib/ui/screens/songs_screen.dart` - Album cover in song screen

### Dependencies
9. ✅ `pubspec.yaml` - Added `synchronized` package for locks

## Changes Summary

### 1. Custom Cache Manager (NEW)
**SonicCacheManager** - Fully custom implementation
- **Storage**: App-specific directory (`%APPDATA%/SonicPlayer/cache/images/`)
- **Size Limit**: 500MB max, 10MB per file
- **Policy**: LRU (Least Recently Used) eviction
- **Concurrency**: File locks prevent simultaneous writes
- **No Memory Cache**: Disk-only for simplicity

**Cache Entry Metadata:**
```json
{
  "fileName": "album_abc123.jpg",
  "originalUrl": "https://server/getCoverArt?id=al-abc123...",
  "size": 15420,
  "createdAt": "2026-02-10T15:30:00Z",
  "validTill": "2026-03-12T15:30:00Z",
  "lastAccessed": "2026-02-10T16:00:00Z",
  "accessCount": 5
}
```

### 2. JSON Error Handling
- **Detection**: Checks if data starts with `{`
- **Action**: Immediately deletes invalid cache
- **Retry**: Next request fetches fresh image
- **No Auto-Retry**: Prevents thread issues

### 3. Concurrency Control
- **File Locks**: Prevents simultaneous writes to same file
- **Download Queue**: Tracks in-progress downloads
- **Wait Mechanism**: Subsequent requests wait for ongoing download

### 4. Image Size Configuration
**Default Size:** 600px (configurable)
```dart
getCoverArtUrl(coverArt!, itemId: id)  // Uses default size 600
getCoverArtUrl(coverArt!, itemId: id, size: 800)  // Custom size
```

**File Size Limits:**
- Single file: 50MB max
- Total cache: 500MB max

**Rationale:**
- 600px provides good quality for most displays
- Prevents downloading extremely large original files (30MB+)
- Reduces memory usage and loading time

### 5. Cache Disable Option
- Location: Settings → "Don't use image cache"
- Effect: Downloads to temp files, no persistence
- Persistence: Saved to SharedPreferences

## Benefits

1. ✅ **Auto-recovery** - JSON cache errors automatically fixed
2. ✅ **Better debugging** - Detailed error logging
3. ✅ **User control** - Option to disable caching
4. ✅ **Consistent caching** - Size-independent cache keys
5. ✅ **No manual intervention** - Problems fix themselves

## Notes

- Retry mechanism triggers on "Invalid image data" errors
- Each retry uses a new cache key to avoid conflicts
- Original image (no size parameter) requested on retry
- Maximum 2 retries before showing error placeholder
