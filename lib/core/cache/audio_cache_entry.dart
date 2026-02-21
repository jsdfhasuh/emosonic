import 'cache_entry.dart';

/// Extended cache entry for audio files with song metadata
class AudioCacheEntry extends CacheEntry {
  final String? title;
  final String? artist;
  final String? album;
  final String? albumId; // 专辑ID，用于构建封面URL
  final int? duration;
  final String? coverArt;
  final String? coverArtLocalPath; // 本地封面路径

  AudioCacheEntry({
    required super.fileName,
    required super.originalUrl,
    required super.size,
    required super.createdAt,
    required super.validTill,
    required super.lastAccessed,
    super.accessCount,
    this.title,
    this.artist,
    this.album,
    this.albumId,
    this.duration,
    this.coverArt,
    this.coverArtLocalPath,
  });

  factory AudioCacheEntry.fromJson(Map<String, dynamic> json) {
    return AudioCacheEntry(
      fileName: json['fileName'] as String,
      originalUrl: json['originalUrl'] as String,
      size: json['size'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      validTill: DateTime.parse(json['validTill'] as String),
      lastAccessed: DateTime.parse(json['lastAccessed'] as String),
      accessCount: json['accessCount'] as int? ?? 0,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      albumId: json['albumId'] as String?,
      duration: json['duration'] as int?,
      coverArt: json['coverArt'] as String?,
      coverArtLocalPath: json['coverArtLocalPath'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'title': title,
      'artist': artist,
      'album': album,
      'albumId': albumId,
      'duration': duration,
      'coverArt': coverArt,
      'coverArtLocalPath': coverArtLocalPath,
    });
    return json;
  }

  /// Get display title
  String get displayTitle => title ?? fileName;

  /// Get display subtitle
  String get displaySubtitle {
    if (artist != null && album != null) {
      return '$artist - $album';
    } else if (artist != null) {
      return artist!;
    } else if (album != null) {
      return album!;
    }
    return '';
  }

  /// Format duration as mm:ss
  String? get formattedDuration {
    if (duration == null) return null;
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Information about a cached song for UI display
class CachedSongInfo {
  final String songId;
  final String fileName;
  final String filePath;
  final int size;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final bool isExpired;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumId; // 专辑ID，用于构建封面URL
  final int? duration;
  final String? coverArt;
  final String? coverArtLocalPath; // 本地封面路径

  CachedSongInfo({
    required this.songId,
    required this.fileName,
    required this.filePath,
    required this.size,
    required this.createdAt,
    required this.lastAccessed,
    required this.isExpired,
    this.title,
    this.artist,
    this.album,
    this.albumId,
    this.duration,
    this.coverArt,
    this.coverArtLocalPath,
  });

  /// Get file size in MB
  double get sizeMB => size / (1024 * 1024);

  /// Get formatted file size string
  String get formattedSize {
    final mb = sizeMB;
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    } else if (mb >= 1) {
      return '${mb.toStringAsFixed(2)} MB';
    } else {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    }
  }

  /// Get formatted creation date
  String get formattedCreatedAt {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }

  /// Get formatted last accessed date
  String get formattedLastAccessed {
    return '${lastAccessed.year}-${lastAccessed.month.toString().padLeft(2, '0')}-${lastAccessed.day.toString().padLeft(2, '0')}';
  }

  /// Get display title
  String get displayTitle => title ?? fileName;

  /// Get display subtitle
  String get displaySubtitle {
    if (artist != null && album != null) {
      return '$artist - $album';
    } else if (artist != null) {
      return artist!;
    } else if (album != null) {
      return album!;
    }
    return '';
  }

  /// Format duration as mm:ss
  String? get formattedDuration {
    if (duration == null) return null;
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
