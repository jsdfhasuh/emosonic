/// Cache entry metadata
class CacheEntry {
  final String fileName;
  final String originalUrl;
  final int size;
  final DateTime createdAt;
  final DateTime validTill;
  DateTime lastAccessed;
  int accessCount;

  CacheEntry({
    required this.fileName,
    required this.originalUrl,
    required this.size,
    required this.createdAt,
    required this.validTill,
    required this.lastAccessed,
    this.accessCount = 0,
  });

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      fileName: json['fileName'] as String,
      originalUrl: json['originalUrl'] as String,
      size: json['size'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      validTill: DateTime.parse(json['validTill'] as String),
      lastAccessed: DateTime.parse(json['lastAccessed'] as String),
      accessCount: json['accessCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'originalUrl': originalUrl,
      'size': size,
      'createdAt': createdAt.toIso8601String(),
      'validTill': validTill.toIso8601String(),
      'lastAccessed': lastAccessed.toIso8601String(),
      'accessCount': accessCount,
    };
  }

  bool get isExpired => DateTime.now().isAfter(validTill);

  void recordAccess() {
    lastAccessed = DateTime.now();
    accessCount++;
  }
}

/// Cache metadata container
class CacheMetadata {
  final String version;
  final Map<String, CacheEntry> entries;
  int totalSize;

  CacheMetadata({
    this.version = '1.0',
    required this.entries,
    this.totalSize = 0,
  });

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    final entriesMap = (json['entries'] as Map<String, dynamic>? ?? {});
    final entries = entriesMap.map(
      (key, value) => MapEntry(key, CacheEntry.fromJson(value as Map<String, dynamic>)),
    );

    return CacheMetadata(
      version: json['version'] as String? ?? '1.0',
      entries: entries,
      totalSize: json['totalSize'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'entries': entries.map((key, value) => MapEntry(key, value.toJson())),
      'totalSize': totalSize,
    };
  }

  void addEntry(String key, CacheEntry entry) {
    entries[key] = entry;
    totalSize += entry.size;
  }

  void removeEntry(String key) {
    final entry = entries.remove(key);
    if (entry != null) {
      totalSize -= entry.size;
      if (totalSize < 0) totalSize = 0;
    }
  }

  List<MapEntry<String, CacheEntry>> getSortedByLRU() {
    final list = entries.entries.toList();
    list.sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    return list;
  }

  List<String> getExpiredKeys() {
    return entries.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
  }
}
