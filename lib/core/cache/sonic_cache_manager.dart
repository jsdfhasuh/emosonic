import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import '../utils/logger.dart';
import 'cache_entry.dart';

/// Custom cache manager for Sonic Player
/// Features:
/// - App-specific directory storage
/// - 500MB max cache size
/// - LRU eviction policy
/// - Concurrency control with file locks
/// - No memory cache (disk only)
class SonicCacheManager {
  static final SonicCacheManager _instance = SonicCacheManager._internal();
  factory SonicCacheManager() => _instance;
  SonicCacheManager._internal();

  final Logger _logger = Logger('SonicCacheManager');
  
  // Configuration
  static const String _cacheDirName = 'images';
  static const String _metadataFileName = 'metadata.json';
  static const int maxCacheSizeMB = 500;
  static const int maxFileSizeMB = 50;
  static const Duration defaultValidity = Duration(days: 30);
  
  // State
  Directory? _cacheDirectory;
  CacheMetadata? _metadata;
  final Map<String, Lock> _fileLocks = {};
  final Set<String> _downloading = {};
  final _initLock = Lock();
  bool _initialized = false;

  /// Initialize cache manager
  Future<void> initialize() async {
    if (_initialized) return;

    await _initLock.synchronized(() async {
      if (_initialized) return;

      try {
        // Always use app-specific directory - no permission needed
        final appDir = await getApplicationSupportDirectory();
        _cacheDirectory = Directory('${appDir.path}/$_cacheDirName');
        _logger.info('Using app-specific directory for cache: ${_cacheDirectory!.path}');

        if (!await _cacheDirectory!.exists()) {
          await _cacheDirectory!.create(recursive: true);
        }

        await _loadMetadata();
        await _cleanupExpired();

        _initialized = true;
        _logger.info('SonicCacheManager initialized at ${_cacheDirectory!.path}');
      } catch (e) {
        _logger.error('Failed to initialize cache manager: $e');
        rethrow;
      }
    });
  }

  /// Get cache file by key
  Future<File?> getFile(String cacheKey) async {
    await initialize();
    
    try {
      final entry = _metadata?.entries[cacheKey];
      if (entry == null) return null;
      
      if (entry.isExpired) {
        _logger.debug('Cache entry expired: $cacheKey');
        await _removeEntry(cacheKey);
        return null;
      }
      
      final file = File('${_cacheDirectory!.path}/${entry.fileName}');
      if (!await file.exists()) {
        _logger.debug('Cache file missing: ${entry.fileName}');
        await _removeEntry(cacheKey);
        return null;
      }
      
      // Update access stats
      entry.recordAccess();
      await _saveMetadata();
      
      _logger.debug('Cache hit: $cacheKey');
      return file;
    } catch (e) {
      _logger.error('Error getting cache file: $e');
      return null;
    }
  }

  /// Put file into cache
  Future<void> putFile(
    String cacheKey,
    Uint8List data,
    String originalUrl, {
    String? extension,
  }) async {
    await initialize();
    
    // Check file size
    final dataSizeMB = data.length / (1024 * 1024);
    if (dataSizeMB > maxFileSizeMB) {
      throw Exception('File too large: ${dataSizeMB.toStringAsFixed(2)}MB > $maxFileSizeMB MB');
    }
    
    final lock = _getLock(cacheKey);
    await lock.synchronized(() async {
      try {
        // Generate filename
        final ext = extension ?? _getExtensionFromData(data);
        final fileName = '$cacheKey.$ext';
        final file = File('${_cacheDirectory!.path}/$fileName');
        
        // Write file
        await file.writeAsBytes(data);
        
        // Update metadata
        final entry = CacheEntry(
          fileName: fileName,
          originalUrl: originalUrl,
          size: data.length,
          createdAt: DateTime.now(),
          validTill: DateTime.now().add(defaultValidity),
          lastAccessed: DateTime.now(),
          accessCount: 1,
        );
        
        // Remove old entry if exists
        await _removeEntry(cacheKey, deleteFile: false);
        
        _metadata!.addEntry(cacheKey, entry);
        await _saveMetadata();
        
        _logger.debug('Cache saved: $cacheKey (${data.length} bytes)');
        
        // Check cache size and evict if necessary
        await _evictIfNecessary();
      } catch (e) {
        _logger.error('Error saving cache file: $e');
        rethrow;
      }
    });
  }

  /// Remove file from cache
  Future<void> removeFile(String cacheKey) async {
    await initialize();
    await _removeEntry(cacheKey);
  }

  /// Check if currently downloading
  bool isDownloading(String cacheKey) => _downloading.contains(cacheKey);

  /// Mark as downloading
  void markDownloading(String cacheKey) {
    _downloading.add(cacheKey);
  }

  /// Unmark downloading
  void unmarkDownloading(String cacheKey) {
    _downloading.remove(cacheKey);
  }

  /// Wait for download to complete
  Future<void> waitForDownload(String cacheKey) async {
    while (_downloading.contains(cacheKey)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
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
      
      _logger.info('Cache cleared');
    } catch (e) {
      _logger.error('Error clearing cache: $e');
      rethrow;
    }
  }

  /// Get cache size in MB
  Future<double> getCacheSizeMB() async {
    await initialize();
    return (_metadata?.totalSize ?? 0) / (1024 * 1024);
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
        _metadata = CacheMetadata.fromJson(json);
      } else {
        _metadata = CacheMetadata(entries: {}, totalSize: 0);
      }
    } catch (e) {
      _logger.error('Error loading metadata: $e');
      _metadata = CacheMetadata(entries: {}, totalSize: 0);
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final metadataFile = File('${_cacheDirectory!.path}/$_metadataFileName');
      final jsonStr = jsonEncode(_metadata!.toJson());
      await metadataFile.writeAsString(jsonStr);
    } catch (e) {
      _logger.error('Error saving metadata: $e');
    }
  }

  Future<void> _removeEntry(String cacheKey, {bool deleteFile = true}) async {
    final entry = _metadata?.entries[cacheKey];
    if (entry != null) {
      if (deleteFile) {
        try {
          final file = File('${_cacheDirectory!.path}/${entry.fileName}');
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          _logger.error('Error deleting cache file: $e');
        }
      }
      _metadata!.removeEntry(cacheKey);
      await _saveMetadata();
    }
  }

  Future<void> _cleanupExpired() async {
    final expiredKeys = _metadata?.getExpiredKeys() ?? [];
    for (final key in expiredKeys) {
      _logger.debug('Removing expired cache: $key');
      await _removeEntry(key);
    }
  }

  Future<void> _evictIfNecessary() async {
    final currentSizeMB = (_metadata?.totalSize ?? 0) / (1024 * 1024);
    if (currentSizeMB <= maxCacheSizeMB) return;
    
    _logger.info('Cache size ($currentSizeMB MB) exceeds limit ($maxCacheSizeMB MB), evicting...');
    
    final sorted = _metadata!.getSortedByLRU();
    var evictedSize = 0;
    var evictedCount = 0;
    final targetSize = (maxCacheSizeMB * 0.8 * 1024 * 1024).toInt(); // Target 80% of max
    
    for (final entry in sorted) {
      if ((_metadata!.totalSize - evictedSize) <= targetSize) break;
      
      await _removeEntry(entry.key);
      evictedSize += entry.value.size;
      evictedCount++;
    }
    
    _logger.info('Evicted $evictedCount files (${(evictedSize / 1024 / 1024).toStringAsFixed(2)} MB)');
  }

  String _getExtensionFromData(Uint8List data) {
    if (data.length >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
      return 'jpg';
    }
    if (data.length >= 4 && data[0] == 0x89 && data[1] == 0x50) {
      return 'png';
    }
    if (data.length >= 4 && data[0] == 0x47 && data[1] == 0x49) {
      return 'gif';
    }
    if (data.length >= 12 && data[8] == 0x57 && data[9] == 0x45) {
      return 'webp';
    }
    return 'bin';
  }
}
