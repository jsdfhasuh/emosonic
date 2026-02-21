import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../utils/logger.dart';
import 'cache_entry.dart';
import 'audio_cache_entry.dart';

export 'audio_cache_entry.dart' show CachedSongInfo;

/// Audio cache manager for Sonic Player
/// Features:
/// - App-specific directory storage (getApplicationSupportDirectory()/audio)
/// - Configurable cache size (default 2GB, min 100MB, max 10GB)
/// - LRU eviction policy + time-based expiration
/// - Favorite songs get longer retention (90 days vs 30 days)
/// - Metadata tracking with JSON file
class AudioCacheManager {
  static final AudioCacheManager _instance = AudioCacheManager._internal();
  factory AudioCacheManager() => _instance;
  AudioCacheManager._internal();

  final Logger _logger = Logger('AudioCacheManager');

  // Configuration
  static const String _cacheDirName = 'audio';
  static const String _metadataFileName = 'audio_metadata.json';
  static const int _defaultMaxCacheSizeMB = 2048; // 2GB
  static const int _minCacheSizeMB = 100; // 100MB
  static const int _maxAllowedCacheSizeMB = 10240; // 10GB
  static const Duration _defaultValidity = Duration(days: 30);
  static const Duration _favoriteValidity = Duration(days: 90);

  // State
  Directory? _cacheDirectory;
  CacheMetadata? _metadata;
  final Map<String, Lock> _fileLocks = {};
  final _initLock = Lock();
  bool _initialized = false;
  int _maxCacheSizeMB = _defaultMaxCacheSizeMB;

  /// Initialize cache manager
  Future<void> initialize() async {
    if (_initialized) return;

    await _initLock.synchronized(() async {
      if (_initialized) return;

      try {
        // Always use app-specific directory - no permission needed
        final appDir = await getApplicationSupportDirectory();
        _cacheDirectory = Directory('${appDir.path}/$_cacheDirName');
        _logger.info('Using app-specific directory for audio cache: ${_cacheDirectory!.path}');

        if (!await _cacheDirectory!.exists()) {
          await _cacheDirectory!.create(recursive: true);
        }

        await _loadMetadata();
        await _cleanupExpired();

        _initialized = true;
        _logger.info('AudioCacheManager initialized at ${_cacheDirectory!.path}');
      } catch (e) {
        _logger.error('Failed to initialize audio cache manager: $e');
        rethrow;
      }
    });
  }

  /// Set maximum cache size in MB
  /// Valid range: 100MB - 10GB
  Future<void> setMaxCacheSizeMB(int size) async {
    if (size < _minCacheSizeMB) {
      _logger.warning('Cache size $size MB below minimum $_minCacheSizeMB MB, using minimum');
      _maxCacheSizeMB = _minCacheSizeMB;
    } else if (size > _maxAllowedCacheSizeMB) {
      _logger.warning('Cache size $size MB exceeds maximum $_maxAllowedCacheSizeMB MB, using maximum');
      _maxCacheSizeMB = _maxAllowedCacheSizeMB;
    } else {
      _maxCacheSizeMB = size;
      _logger.info('Max cache size set to $_maxCacheSizeMB MB');
    }

    // Trigger eviction if needed
    await initialize();
    await _evictIfNecessary();
  }

  /// Get cache directory
  Directory? get cacheDirectory => _cacheDirectory;

  /// Get cached file path by song ID
  /// Returns null if not cached or expired
  Future<String?> getCachedFilePath(String songId) async {
    await initialize();

    try {
      final entry = _metadata?.entries[songId];
      if (entry == null) return null;

      if (entry.isExpired) {
        _logger.debug('Audio cache entry expired: $songId');
        await _removeEntry(songId);
        return null;
      }

      final file = File('${_cacheDirectory!.path}/${entry.fileName}');
      if (!await file.exists()) {
        _logger.debug('Audio cache file missing: ${entry.fileName}');
        await _removeEntry(songId);
        return null;
      }

      // Update access stats
      entry.recordAccess();
      await _saveMetadata();

      _logger.debug('Audio cache hit: $songId');
      return file.path;
    } catch (e) {
      _logger.error('Error getting cached audio file: $e');
      return null;
    }
  }

  /// Check if a song is cached and not expired
  Future<bool> isCached(String songId) async {
    final path = await getCachedFilePath(songId);
    return path != null;
  }

  /// Get list of all cached song IDs
  Future<List<String>> getCachedSongIds() async {
    await initialize();

    try {
      final ids = _metadata?.entries.keys.toList() ?? [];
      _logger.debug('Retrieved ${ids.length} cached song IDs');
      return ids;
    } catch (e) {
      _logger.error('Error getting cached song IDs: $e');
      return [];
    }
  }

  /// Get detailed information about all cached songs
  Future<List<CachedSongInfo>> getCachedSongsInfo() async {
    await initialize();

    try {
      final entries = _metadata?.entries ?? {};
      final List<CachedSongInfo> songs = [];
      
      _logger.info('Loading cached songs info at ${DateTime.now()}, total entries: ${entries.length}');

      for (final entry in entries.entries) {
        final songId = entry.key;
        final cacheEntry = entry.value;
        final file = File('${_cacheDirectory!.path}/${cacheEntry.fileName}');

        if (await file.exists()) {
          // Check if it's an AudioCacheEntry with metadata
          if (cacheEntry is AudioCacheEntry) {
            _logger.info('Loaded AudioCacheEntry at ${DateTime.now()}: ${cacheEntry.title ?? cacheEntry.fileName}, hasCover: ${cacheEntry.coverArtLocalPath != null}');
            songs.add(CachedSongInfo(
              songId: songId,
              fileName: cacheEntry.fileName,
              filePath: file.path,
              size: cacheEntry.size,
              createdAt: cacheEntry.createdAt,
              lastAccessed: cacheEntry.lastAccessed,
              isExpired: cacheEntry.isExpired,
              title: cacheEntry.title,
              artist: cacheEntry.artist,
              album: cacheEntry.album,
              albumId: cacheEntry.albumId,
              duration: cacheEntry.duration,
              coverArt: cacheEntry.coverArt,
              coverArtLocalPath: cacheEntry.coverArtLocalPath,
            ));
          } else {
            // Fallback for legacy entries without metadata
            _logger.info('Loaded legacy CacheEntry at ${DateTime.now()}: ${cacheEntry.fileName}');
            songs.add(CachedSongInfo(
              songId: songId,
              fileName: cacheEntry.fileName,
              filePath: file.path,
              size: cacheEntry.size,
              createdAt: cacheEntry.createdAt,
              lastAccessed: cacheEntry.lastAccessed,
              isExpired: cacheEntry.isExpired,
            ));
          }
        } else {
          _logger.warning('Cached file missing for entry: $songId');
        }
      }

      // Sort by last accessed time (most recent first)
      songs.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

      _logger.info('Retrieved ${songs.length} cached songs info at ${DateTime.now()}, AudioCacheEntry: ${songs.where((s) => s.title != null).length}, legacy: ${songs.where((s) => s.title == null).length}');
      return songs;
    } catch (e) {
      _logger.error('Error getting cached songs info: $e');
      return [];
    }
  }

  /// Put file into cache
  /// Copies the file from sourcePath to cache directory
  Future<void> putFile(
    String songId,
    String sourcePath,
    String originalUrl, {
    bool isFavorite = false,
    String? title,
    String? artist,
    String? album,
    String? albumId,
    int? duration,
    String? coverArt,
  }) async {
    await initialize();

    final lock = _getLock(songId);
    await lock.synchronized(() async {
      try {
        final sourceFile = File(sourcePath);
        if (!await sourceFile.exists()) {
          throw Exception('Source file does not exist: $sourcePath');
        }

        final fileSize = await sourceFile.length();
        final fileSizeMB = fileSize / (1024 * 1024);

        // Check if file size exceeds cache limit
        if (fileSizeMB > _maxCacheSizeMB) {
          throw Exception(
            'File too large: ${fileSizeMB.toStringAsFixed(2)}MB > $_maxCacheSizeMB MB',
          );
        }

        // Generate filename with extension
        final ext = _getExtensionFromPath(sourcePath);
        final fileName = '$songId.$ext';
        final destFile = File('${_cacheDirectory!.path}/$fileName');

        // Copy file to cache
        await sourceFile.copy(destFile.path);

        // Download and cache cover image if provided and enabled
        String? coverArtLocalPath;
        if (coverArt != null && coverArt.isNotEmpty) {
          // Check if cover caching is enabled
          final prefs = await SharedPreferences.getInstance();
          final cacheCoverEnabled = prefs.getBool('cache_cover_image') ?? true;
          
          if (cacheCoverEnabled) {
            try {
              coverArtLocalPath = await _downloadCoverArt(songId, coverArt);
            } catch (e) {
              _logger.warning('Failed to cache cover art for $songId: $e');
            }
          }
        }

        // Calculate validity period
        final validity = isFavorite ? _favoriteValidity : _defaultValidity;

        // Update metadata with song info
        final entry = AudioCacheEntry(
          fileName: fileName,
          originalUrl: originalUrl,
          size: fileSize,
          createdAt: DateTime.now(),
          validTill: DateTime.now().add(validity),
          lastAccessed: DateTime.now(),
          accessCount: 1,
          title: title,
          artist: artist,
          album: album,
          albumId: albumId,
          duration: duration,
          coverArt: coverArt,
          coverArtLocalPath: coverArtLocalPath,
        );

        // Remove old entry if exists
        await _removeEntry(songId, deleteFile: false);

        _metadata!.addEntry(songId, entry);
        await _saveMetadata();

        _logger.debug(
          'Audio cached: $songId (${fileSizeMB.toStringAsFixed(2)} MB, favorite: $isFavorite, cover: ${coverArtLocalPath != null})',
        );

        // Check cache size and evict if necessary
        await _evictIfNecessary();
      } catch (e) {
        _logger.error('Error caching audio file: $e');
        rethrow;
      }
    });
  }

  /// Download and cache cover art image
  Future<String?> _downloadCoverArt(String songId, String coverArtUrl) async {
    try {
      // Create covers subdirectory
      final coversDir = Directory('${_cacheDirectory!.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // Generate cover filename
      final coverFileName = '${songId}_cover.jpg';
      final coverFile = File('${coversDir.path}/$coverFileName');

      // Check if already cached
      if (await coverFile.exists()) {
        _logger.debug('Cover art already cached: $coverFileName');
        return coverFile.path;
      }

      // Download cover image
      final response = await http.get(Uri.parse(coverArtUrl));
      if (response.statusCode == 200) {
        await coverFile.writeAsBytes(response.bodyBytes);
        _logger.debug('Cover art cached: $coverFileName');
        return coverFile.path;
      } else {
        _logger.warning('Failed to download cover art: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.error('Error downloading cover art: $e');
      return null;
    }
  }

  /// Mark a song as favorite (extends retention to 90 days)
  Future<void> markAsFavorite(String songId, bool isFavorite) async {
    await initialize();

    try {
      final entry = _metadata?.entries[songId];
      if (entry == null) {
        _logger.debug('Cannot mark favorite: song not in cache: $songId');
        return;
      }

      // Recalculate validity based on favorite status
      final validity = isFavorite ? _favoriteValidity : _defaultValidity;
      final newValidTill = entry.createdAt.add(validity);

      // Create updated entry
      final updatedEntry = CacheEntry(
        fileName: entry.fileName,
        originalUrl: entry.originalUrl,
        size: entry.size,
        createdAt: entry.createdAt,
        validTill: newValidTill,
        lastAccessed: entry.lastAccessed,
        accessCount: entry.accessCount,
      );

      _metadata!.addEntry(songId, updatedEntry);
      await _saveMetadata();

      _logger.debug(
        'Song $songId marked as ${isFavorite ? 'favorite' : 'regular'} (valid until: $newValidTill)',
      );
    } catch (e) {
      _logger.error('Error marking song as favorite: $e');
    }
  }

  /// Remove file from cache
  Future<void> removeFile(String songId) async {
    await initialize();
    await _removeEntry(songId);
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await initialize();

    try {
      if (await _cacheDirectory!.exists()) {
        await _cacheDirectory!.delete(recursive: true);
        await _cacheDirectory!.create();
      }

      _metadata = CacheMetadata(entries: {}, totalSize: 0);
      await _saveMetadata();

      _logger.info('Audio cache cleared');
    } catch (e) {
      _logger.error('Error clearing audio cache: $e');
      rethrow;
    }
  }

  /// Get current cache size in MB
  Future<double> getCacheSizeMB() async {
    await initialize();
    return (_metadata?.totalSize ?? 0) / (1024 * 1024);
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    await initialize();

    try {
      final count = _metadata?.entries.length ?? 0;
      final size = await getCacheSizeMB();
      final limit = _maxCacheSizeMB.toDouble();
      final usagePercent = limit > 0 ? (size / limit * 100).toStringAsFixed(1) : '0.0';

      return {
        'fileCount': count,
        'totalSizeMB': double.parse(size.toStringAsFixed(2)),
        'maxSizeMB': limit,
        'usagePercent': double.parse(usagePercent),
      };
    } catch (e) {
      _logger.error('Error getting cache stats: $e');
      return {
        'fileCount': 0,
        'totalSizeMB': 0.0,
        'maxSizeMB': _maxCacheSizeMB.toDouble(),
        'usagePercent': 0.0,
      };
    }
  }

  // Private methods

  Lock _getLock(String key) {
    return _fileLocks.putIfAbsent(key, () => Lock());
  }

  Future<void> _loadMetadata() async {
    try {
      final metadataFile = File('${_cacheDirectory!.path}/$_metadataFileName');
      if (await metadataFile.exists()) {
        final jsonStr = await metadataFile.readAsString();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _metadata = _parseMetadata(json);
        _logger.info('Loaded metadata with ${_metadata!.entries.length} entries at ${DateTime.now()}');
      } else {
        _metadata = CacheMetadata(entries: {}, totalSize: 0);
        _logger.info('No existing metadata, created new at ${DateTime.now()}');
      }
    } catch (e) {
      _logger.error('Error loading audio metadata: $e at ${DateTime.now()}');
      _metadata = CacheMetadata(entries: {}, totalSize: 0);
    }
  }

  /// Parse metadata JSON with support for AudioCacheEntry
  CacheMetadata _parseMetadata(Map<String, dynamic> json) {
    final entriesMap = (json['entries'] as Map<String, dynamic>? ?? {});
    final entries = entriesMap.map((key, value) {
      final valueMap = value as Map<String, dynamic>;
      // Check if this is an AudioCacheEntry by looking for audio-specific fields
      if (valueMap.containsKey('title') ||
          valueMap.containsKey('artist') ||
          valueMap.containsKey('album') ||
          valueMap.containsKey('coverArt')) {
        return MapEntry(key, AudioCacheEntry.fromJson(valueMap));
      }
      return MapEntry(key, CacheEntry.fromJson(valueMap));
    });

    return CacheMetadata(
      version: json['version'] as String? ?? '1.0',
      entries: entries,
      totalSize: json['totalSize'] as int? ?? 0,
    );
  }

  Future<void> _saveMetadata() async {
    try {
      final metadataFile = File('${_cacheDirectory!.path}/$_metadataFileName');
      final jsonStr = jsonEncode(_metadata!.toJson());
      await metadataFile.writeAsString(jsonStr);
    } catch (e) {
      _logger.error('Error saving audio metadata: $e');
    }
  }

  Future<void> _removeEntry(String songId, {bool deleteFile = true}) async {
    final entry = _metadata?.entries[songId];
    if (entry != null) {
      if (deleteFile) {
        try {
          // Delete audio file
          final file = File('${_cacheDirectory!.path}/${entry.fileName}');
          if (await file.exists()) {
            await file.delete();
          }
          
          // Delete cover art if exists
          if (entry is AudioCacheEntry && entry.coverArtLocalPath != null) {
            final coverFile = File(entry.coverArtLocalPath!);
            if (await coverFile.exists()) {
              await coverFile.delete();
              _logger.debug('Deleted cover art: ${entry.coverArtLocalPath}');
            }
          }
        } catch (e) {
          _logger.error('Error deleting audio cache file: $e');
        }
      }
      _metadata!.removeEntry(songId);
      await _saveMetadata();
    }
  }

  Future<void> _cleanupExpired() async {
    final expiredKeys = _metadata?.getExpiredKeys() ?? [];
    for (final key in expiredKeys) {
      _logger.debug('Removing expired audio cache: $key');
      await _removeEntry(key);
    }
  }

  Future<void> _evictIfNecessary() async {
    final currentSizeMB = (_metadata?.totalSize ?? 0) / (1024 * 1024);
    if (currentSizeMB <= _maxCacheSizeMB) return;

    _logger.info(
      'Audio cache size ($currentSizeMB MB) exceeds limit ($_maxCacheSizeMB MB), evicting...',
    );

    final sorted = _metadata!.getSortedByLRU();
    var evictedSize = 0;
    var evictedCount = 0;
    final targetSize = (_maxCacheSizeMB * 0.8 * 1024 * 1024).toInt(); // Target 80% of max

    for (final entry in sorted) {
      if ((_metadata!.totalSize - evictedSize) <= targetSize) break;

      await _removeEntry(entry.key);
      evictedSize += entry.value.size;
      evictedCount++;
    }

    _logger.info(
      'Evicted $evictedCount files (${(evictedSize / 1024 / 1024).toStringAsFixed(2)} MB)',
    );
  }

  String _getExtensionFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    const validExts = ['mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'wma', 'opus'];
    if (validExts.contains(ext)) {
      return ext;
    }
    return 'audio'; // Default extension
  }
}
