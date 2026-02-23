/// Cache for starred song IDs to quickly check if a song is starred
class StarredCache {
  final Set<String> _starredSongIds = {};
  DateTime _lastUpdate = DateTime.now();
  
  /// Check if a song is starred
  bool isStarred(String songId) => _starredSongIds.contains(songId);
  
  /// Update the cache with a list of starred song IDs
  void updateStarredSongs(List<String> songIds) {
    _starredSongIds.clear();
    _starredSongIds.addAll(songIds);
    _lastUpdate = DateTime.now();
  }
  
  /// Add a song to starred cache
  void addStarred(String songId) {
    _starredSongIds.add(songId);
  }
  
  /// Remove a song from starred cache
  void removeStarred(String songId) {
    _starredSongIds.remove(songId);
  }
  
  /// Check if cache is stale (older than 5 minutes)
  bool get isStale => 
    DateTime.now().difference(_lastUpdate) > const Duration(minutes: 5);
  
  /// Get all starred song IDs
  Set<String> get starredIds => Set.from(_starredSongIds);
}