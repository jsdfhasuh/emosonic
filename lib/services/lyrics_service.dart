import '../data/models/lyric_line.dart';
import '../data/models/models.dart';
import '../data/services/subsonic/subsonic_api_client.dart';
import '../core/utils/lrc_parser.dart';
import '../core/utils/logger.dart';

/// Service for fetching and caching lyrics
class LyricsService {
  final SubsonicApiClient _apiClient;
  final Logger _logger = Logger('LyricsService');
  
  // Cache: songId -> parsed lyrics
  final Map<String, List<LyricLine>> _cache = {};

  LyricsService(this._apiClient);

  /// Get lyrics for a song
  /// Returns empty list if no lyrics found
  Future<List<LyricLine>> getLyricsForSong(Song song) async {
    final songId = song.id;
    
    // Check cache first
    if (_cache.containsKey(songId)) {
      _logger.debug('Lyrics cache hit for song: ${song.title}');
      return _cache[songId]!;
    }

    _logger.info('Fetching lyrics for: ${song.title}');

    try {
      // Try to get lyrics using song id first
      String? lrcText = await _apiClient.getLyrics(
        artist: song.artistName,
        title: song.title,
        id: songId,
      );

      // If not found with id, try without id (fallback to artist+title)
      if (lrcText == null || lrcText.isEmpty) {
        _logger.debug('Lyrics not found with id, trying artist+title fallback');
        lrcText = await _apiClient.getLyrics(
          artist: song.artistName,
          title: song.title,
        );
      }

      if (lrcText == null || lrcText.isEmpty) {
        _logger.info('No lyrics found for: ${song.title}');
        _cache[songId] = [];
        return [];
      }

      // Parse LRC text
      final lyrics = LrcParser.parse(lrcText);
      
      if (lyrics.isEmpty) {
        _logger.warning('Parsed lyrics is empty for: ${song.title}');
        _cache[songId] = [];
        return [];
      }

      _logger.info('Lyrics loaded: ${lyrics.length} lines for ${song.title}');
      
      // Cache the result
      _cache[songId] = lyrics;
      
      return lyrics;
    } catch (e) {
      _logger.error('Error fetching lyrics for ${song.title}: $e');
      _cache[songId] = [];
      return [];
    }
  }

  /// Clear cache for a specific song
  void clearCache(String songId) {
    _cache.remove(songId);
    _logger.debug('Lyrics cache cleared for song: $songId');
  }

  /// Clear all cached lyrics
  void clearAllCache() {
    _cache.clear();
    _logger.info('All lyrics cache cleared');
  }
}
