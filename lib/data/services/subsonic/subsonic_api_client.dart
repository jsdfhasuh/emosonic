import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../../models/models.dart';
import '../../models/search_result.dart';
import '../../../core/utils/logger.dart';

enum AlbumListType {
  random,
  newest,
  highest,
  frequent,
  recent,
  alphabeticalByName,
  alphabeticalByArtist,
  starred,
  byYear,
  byGenre,
}

extension AlbumListTypeExtension on AlbumListType {
  String get value {
    switch (this) {
      case AlbumListType.random:
        return 'random';
      case AlbumListType.newest:
        return 'newest';
      case AlbumListType.highest:
        return 'highest';
      case AlbumListType.frequent:
        return 'frequent';
      case AlbumListType.recent:
        return 'recent';
      case AlbumListType.alphabeticalByName:
        return 'alphabeticalByName';
      case AlbumListType.alphabeticalByArtist:
        return 'alphabeticalByArtist';
      case AlbumListType.starred:
        return 'starred';
      case AlbumListType.byYear:
        return 'byYear';
      case AlbumListType.byGenre:
        return 'byGenre';
    }
  }
}

class SubsonicApiClient {
  late final Dio _dio;
  ServerConfig? _config;
  static const String _apiVersion = '1.16.1';
  static const String _clientId = 'emosonic';
  final Logger _logger = Logger('SubsonicApiClient');

  SubsonicApiClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      // Enable both IPv4 and IPv6
      followRedirects: true,
      validateStatus: (status) => status != null && status < 500,
    ));
    _logger.info('SubsonicApiClient initialized');
  }

  void setConfig(ServerConfig config) {
    _config = config;
    _dio.options.baseUrl = config.url.endsWith('/')
        ? config.url.substring(0, config.url.length - 1)
        : config.url;
    _logger.info('Server config set: ${config.url}, user: ${config.username}');
  }

  Map<String, dynamic> _getAuthParams({bool useJson = true}) {
    if (_config == null) {
      throw Exception('Server config not set');
    }

    final salt = _generateSalt();
    final token = _generateToken(_config!.password, salt);

    final params = {
      'u': _config!.username,
      't': token,
      's': salt,
      'v': _apiVersion,
      'c': _clientId,
    };

    if (useJson) {
      params['f'] = 'json';
    }

    return params;
  }

  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(6, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _generateToken(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  String get _apiEndpoint => _config?.apiEndpoint ?? 'rest';

  Future<Map<String, dynamic>> _get(String endpoint, {Map<String, dynamic>? params}) async {
    final apiPath = _apiEndpoint;
    _logger.debug('API Request: GET /$apiPath/$endpoint, params: $params');
    final authParams = _getAuthParams();

    // Handle List type params - expand them into multiple entries
    if (params != null) {
      params.forEach((key, value) {
        if (value is List) {
          for (var item in value) {
            authParams[key] = item.toString();
          }
        } else {
          authParams[key] = value.toString();
        }
      });
    }

    try {
      final response = await _dio.get(
        '/$apiPath/$endpoint',
        queryParameters: authParams,
      );

      _logger.debug('API Response: ${response.statusCode}, data: ${response.data}');

      if (response.data['subsonic-response']['status'] == 'failed') {
        final error = response.data['subsonic-response']['error'];
        _logger.error('API Error: ${error['message']} (Code: ${error['code']})');
        throw Exception('Subsonic API Error: ${error['message']} (Code: ${error['code']})');
      }

      return response.data['subsonic-response'];
    } on DioException catch (e) {
      _logger.error('Network error: ${e.message}');
      _logger.error('Error type: ${e.type}');
      _logger.error('Request URL: ${e.requestOptions.uri}');
      if (e.error != null) {
        _logger.error('Underlying error: ${e.error}');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  Future<bool> ping() async {
    _logger.info('Pinging server...');
    try {
      await _get('ping');
      _logger.info('Ping successful');
      return true;
    } catch (e) {
      _logger.error('Ping failed: $e');
      return false;
    }
  }

  Future<List<Artist>> getArtists() async {
    _logger.info('Fetching artists...');
    final response = await _get('getArtists');
    final artists = <Artist>[];
    
    final artistsData = response['artists'];
    if (artistsData != null && artistsData['index'] != null) {
      for (final index in artistsData['index']) {
        if (index['artist'] != null) {
          for (final artist in index['artist']) {
            try {
              artists.add(Artist.fromJson(artist));
            } catch (e) {
              _logger.error('Error parsing artist: $e, data: $artist');
            }
          }
        }
      }
    }
    
    _logger.info('Fetched ${artists.length} artists');
    return artists;
  }

  Future<List<Album>> getAlbumsByArtist(String artistId) async {
    _logger.info('Fetching albums for artist: $artistId');
    final response = await _get('getArtist', params: {'id': artistId});
    final albums = <Album>[];
    
    final artistData = response['artist'];
    if (artistData != null && artistData['album'] != null) {
      for (final album in artistData['album']) {
        try {
          // Ensure required fields are present
          final albumMap = Map<String, dynamic>.from(album);
          albumMap['artistId'] = artistId;
          albumMap['artistName'] = artistData['name'] ?? 'Unknown Artist';
          
          _logger.debug('Parsing album: $albumMap');
          albums.add(Album.fromJson(albumMap));
        } catch (e, stackTrace) {
          _logger.error('Error parsing album: $e, data: $album, stackTrace: $stackTrace');
        }
      }
    }
    
    _logger.info('Fetched ${albums.length} albums');
    return albums;
  }

  Future<List<Song>> getSongsByAlbum(String albumId) async {
    _logger.info('Fetching songs for album: $albumId');
    final response = await _get('getAlbum', params: {'id': albumId});
    final songs = <Song>[];
    
    final albumData = response['album'];
    if (albumData != null && albumData['song'] != null) {
      for (final song in albumData['song']) {
        try {
          // Ensure required fields are present
          final songMap = Map<String, dynamic>.from(song);
          songMap['albumId'] = albumId;
          songMap['albumName'] = albumData['name'] ?? 'Unknown Album';
          songMap['artistId'] = albumData['artistId'] ?? '';
          songMap['artistName'] = albumData['artist'] ?? 'Unknown Artist';
          
          // Set coverArt from album if not present in song
          if (songMap['coverArt'] == null && albumData['coverArt'] != null) {
            songMap['coverArt'] = albumData['coverArt'];
          }
          
          _logger.debug('Parsing song: $songMap');
          songs.add(Song.fromJson(songMap));
        } catch (e, stackTrace) {
          _logger.error('Error parsing song: $e, data: $song, stackTrace: $stackTrace');
        }
      }
    }
    
    _logger.info('Fetched ${songs.length} songs');
    return songs;
  }

  String getStreamUrl(String songId) {
    final authParams = _getAuthParams();
    final queryString = authParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    final apiPath = _apiEndpoint;
    final url = '${_dio.options.baseUrl}/$apiPath/stream?id=$songId&$queryString';
    _logger.debug('Stream URL: $url');
    return url;
  }

  String getCoverArtUrl(String coverArtId, {int? size = 600, String? itemId}) {
    if (_config == null) {
      throw Exception('Server config not set');
    }

    final salt = _generateSalt();
    final token = _generateToken(_config!.password, salt);

    // Build auth params without f=json for binary image endpoint
    final authParams = {
      'u': _config!.username,
      't': token,
      's': salt,
      'v': _apiVersion,
      'c': _clientId,
    };

    final queryString = authParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    // Use al- prefix with album ID for album covers
    String id = coverArtId;
    if (itemId != null) {
      if (itemId.startsWith('ar-')) {
        id = itemId;  // Artist cover
      } else {
        id = 'al-$itemId';  // Album cover
      }
    }

    // Build URL with optional size parameter
    final sizeParam = size != null ? '&size=$size' : '';
    final apiPath = _apiEndpoint;
    final url = '${_dio.options.baseUrl}/$apiPath/getCoverArt?id=$id$sizeParam&$queryString';
    _logger.debug('CoverArt URL: $url');
    return url;
  }

  Future<SearchResult> search(String query) async {
    _logger.info('Searching for: $query');
    final response = await _get('search3', params: {
      'query': query,
      'artistCount': 20,
      'albumCount': 20,
      'songCount': 50,
    });

    final searchResult = response['searchResult3'];
    if (searchResult != null) {
      _logger.info('Search completed');
      return SearchResult.fromJson(searchResult);
    }

    _logger.info('Search returned empty results');
    return const SearchResult(artists: [], albums: [], songs: []);
  }

  Future<List<Genre>> getGenres() async {
    _logger.info('Fetching genres...');
    final response = await _get('getGenres');
    final genres = <Genre>[];

    final genresData = response['genres'];
    if (genresData != null && genresData['genre'] != null) {
      for (final genre in genresData['genre']) {
        try {
          genres.add(Genre.fromJson(genre));
        } catch (e) {
          _logger.error('Error parsing genre: $e, data: $genre');
        }
      }
    }

    _logger.info('Fetched ${genres.length} genres');
    return genres;
  }

  Future<List<Album>> getAlbumList({
    AlbumListType type = AlbumListType.newest,
    int size = 50,
    int offset = 0,
    String? genre,
    int? fromYear,
    int? toYear,
  }) async {
    _logger.info('Fetching album list: type=${type.value}, size=$size, offset=$offset');
    final params = <String, dynamic>{
      'type': type.value,
      'size': size,
      'offset': offset,
    };

    if (genre != null) {
      params['genre'] = genre;
    }
    if (fromYear != null) {
      params['fromYear'] = fromYear;
    }
    if (toYear != null) {
      params['toYear'] = toYear;
    }

    final response = await _get('getAlbumList2', params: params);
    final albums = <Album>[];

    final albumsData = response['albumList2'];
    if (albumsData != null && albumsData['album'] != null) {
      for (final album in albumsData['album']) {
        try {
          albums.add(Album.fromJson(album));
        } catch (e) {
          _logger.error('Error parsing album: $e, data: $album');
        }
      }
    }

    _logger.info('Fetched ${albums.length} albums');
    return albums;
  }

  Future<List<Playlist>> getPlaylists({String? username}) async {
    _logger.info('Fetching playlists...');
    final params = <String, dynamic>{};
    if (username != null) {
      params['username'] = username;
    }

    final response = await _get('getPlaylists', params: params.isEmpty ? null : params);
    final playlists = <Playlist>[];

    final playlistsData = response['playlists'];
    if (playlistsData != null && playlistsData['playlist'] != null) {
      final playlistList = playlistsData['playlist'];
      // Handle case where there's only one playlist (not in array)
      if (playlistList is List) {
        for (final playlist in playlistList) {
          try {
            playlists.add(Playlist.fromJson(playlist));
          } catch (e) {
            _logger.error('Error parsing playlist: $e, data: $playlist');
          }
        }
      } else if (playlistList is Map) {
        try {
          playlists.add(Playlist.fromJson(playlistList as Map<String, dynamic>));
        } catch (e) {
          _logger.error('Error parsing playlist: $e, data: $playlistList');
        }
      }
    }

    _logger.info('Fetched ${playlists.length} playlists');
    return playlists;
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    _logger.info('Fetching songs for playlist: $playlistId');
    final response = await _get('getPlaylist', params: {'id': playlistId});
    final songs = <Song>[];

    final playlistData = response['playlist'];
    if (playlistData != null && playlistData['entry'] != null) {
      for (final song in playlistData['entry']) {
        try {
          final songMap = Map<String, dynamic>.from(song);
          // Set coverArt from album if not present in song
          if (songMap['coverArt'] == null && songMap['albumId'] != null) {
            songMap['coverArt'] = 'al-${songMap['albumId']}';
          }
          songs.add(Song.fromJson(songMap));
        } catch (e) {
          _logger.error('Error parsing song: $e, data: $song');
        }
      }
    }

    _logger.info('Fetched ${songs.length} songs from playlist');
    return songs;
  }

  Future<String> createPlaylist({
    required String name,
    List<String>? songIds,
  }) async {
    final params = <String, dynamic>{
      'name': name,
      if (songIds != null && songIds.isNotEmpty) 'songId': songIds,
    };

    final response = await _get('createPlaylist', params: params);

    if (response['status'] == 'ok') {
      final playlistData = response['playlist'];
      if (playlistData != null && playlistData['id'] != null) {
        return playlistData['id'].toString();
      }
      throw Exception('创建歌单成功但未返回歌单ID');
    } else {
      final error = response['error'];
      throw Exception('创建歌单失败: ${error?['message'] ?? '未知错误'}');
    }
  }

  Future<void> updatePlaylist({
    required String playlistId,
    String? name,
    String? comment,
    bool? public,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    final params = <String, dynamic>{
      'playlistId': playlistId,
    };

    if (name != null) {
      params['name'] = name;
    }
    if (comment != null) {
      params['comment'] = comment;
    }
    if (public != null) {
      params['public'] = public.toString();
    }
    if (songIdsToAdd != null && songIdsToAdd.isNotEmpty) {
      params['songIdToAdd'] = songIdsToAdd;
    }
    if (songIndexesToRemove != null && songIndexesToRemove.isNotEmpty) {
      params['songIndexToRemove'] = songIndexesToRemove.map((e) => e.toString()).toList();
    }

    final response = await _get('updatePlaylist', params: params);

    if (response['status'] != 'ok') {
      final error = response['error'];
      throw Exception('更新歌单失败: ${error?['message'] ?? '未知错误'}');
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    final response = await _get(
      'deletePlaylist',
      params: {'id': playlistId},
    );

    if (response['status'] != 'ok') {
      final error = response['error'];
      throw Exception('删除歌单失败: ${error?['message'] ?? '未知错误'}');
    }
  }

  Future<List<Song>> getRandomSongs({
    int size = 50,
    String? genre,
    int? fromYear,
    int? toYear,
    String? musicFolderId,
  }) async {
    _logger.info('Fetching random songs: size=$size');
    final params = <String, dynamic>{
      'size': size,
    };

    if (genre != null) {
      params['genre'] = genre;
    }
    if (fromYear != null) {
      params['fromYear'] = fromYear;
    }
    if (toYear != null) {
      params['toYear'] = toYear;
    }
    if (musicFolderId != null) {
      params['musicFolderId'] = musicFolderId;
    }

    final response = await _get('getRandomSongs', params: params);
    final songs = <Song>[];

    final randomSongsData = response['randomSongs'];
    if (randomSongsData != null && randomSongsData['song'] != null) {
      for (final song in randomSongsData['song']) {
        try {
          final songMap = Map<String, dynamic>.from(song);
          // Set coverArt from album if not present in song
          if (songMap['coverArt'] == null && songMap['albumId'] != null) {
            songMap['coverArt'] = 'al-${songMap['albumId']}';
          }
          songs.add(Song.fromJson(songMap));
        } catch (e) {
          _logger.error('Error parsing song: $e, data: $song');
        }
      }
    }

    _logger.info('Fetched ${songs.length} random songs');
    return songs;
  }

  Future<List<Song>> getSongsByGenre(String genre, {int count = 500}) async {
    _logger.info('Fetching songs by genre: $genre, count=$count');
    final response = await _get('getSongsByGenre', params: {
      'genre': genre,
      'count': count,
    });
    final songs = <Song>[];

    final songsByGenreData = response['songsByGenre'];
    if (songsByGenreData != null && songsByGenreData['song'] != null) {
      for (final song in songsByGenreData['song']) {
        try {
          final songMap = Map<String, dynamic>.from(song);
          // Set coverArt from album if not present in song
          if (songMap['coverArt'] == null && songMap['albumId'] != null) {
            songMap['coverArt'] = 'al-${songMap['albumId']}';
          }
          songs.add(Song.fromJson(songMap));
        } catch (e) {
          _logger.error('Error parsing song: $e, data: $song');
        }
      }
    }

    _logger.info('Fetched ${songs.length} songs for genre: $genre');
    return songs;
  }

  /// Submit scrobble (play record) to server
  /// [trackId] - Track ID to scrobble
  /// [submission] - true for completed play, false for "now playing"
  /// [time] - Unix timestamp in milliseconds (optional)
  Future<void> scrobble(String trackId, {bool submission = true, int? time}) async {
    try {
      final params = <String, dynamic>{
        'id': trackId,
        'submission': submission,
      };
      
      if (time != null) {
        params['time'] = time;
      }

      _logger.debug('Submitting scrobble: trackId=$trackId, submission=$submission');
      await _get('scrobble', params: params);
      _logger.debug('Scrobble submitted successfully');
    } catch (e) {
      _logger.error('Failed to submit scrobble: $e');
      // Don't throw - scrobble failures shouldn't break playback
    }
  }

  /// Get starred items (songs, albums, artists) using getStarred2
  Future<Map<String, dynamic>> getStarred2({
    int? offset,
    int? limit,
  }) async {
    _logger.info('Fetching starred items');
    final params = <String, dynamic>{};
    if (offset != null) params['offset'] = offset;
    if (limit != null) params['limit'] = limit;
    
    final response = await _get('getStarred2', params: params);
    return response['starred2'] as Map<String, dynamic>;
  }

  /// Star (favorite) songs, albums, or artists
  Future<void> star({
    List<String>? songIds,
    List<String>? albumIds,
    List<String>? artistIds,
  }) async {
    final params = <String, dynamic>{};
    if (songIds != null && songIds.isNotEmpty) {
      params['id'] = songIds;
    }
    if (albumIds != null && albumIds.isNotEmpty) {
      params['albumId'] = albumIds;
    }
    if (artistIds != null && artistIds.isNotEmpty) {
      params['artistId'] = artistIds;
    }
    
    _logger.info('Starring items: songs=${songIds?.length ?? 0}, albums=${albumIds?.length ?? 0}, artists=${artistIds?.length ?? 0}');
    await _get('star', params: params);
  }

  /// Unstar (remove from favorites) songs, albums, or artists
  Future<void> unstar({
    List<String>? songIds,
    List<String>? albumIds,
    List<String>? artistIds,
  }) async {
    final params = <String, dynamic>{};
    if (songIds != null && songIds.isNotEmpty) {
      params['id'] = songIds;
    }
    if (albumIds != null && albumIds.isNotEmpty) {
      params['albumId'] = albumIds;
    }
    if (artistIds != null && artistIds.isNotEmpty) {
      params['artistId'] = artistIds;
    }
    
    _logger.info('Unstarring items: songs=${songIds?.length ?? 0}, albums=${albumIds?.length ?? 0}, artists=${artistIds?.length ?? 0}');
    await _get('unstar', params: params);
  }

  /// Get lyrics for a song
  /// Returns LRC text or null if not found
  Future<String?> getLyrics({required String artist, required String title, String? id}) async {
    if (_config == null) {
      throw Exception('Server config not set');
    }

    final params = <String, dynamic>{};
    if (id != null && id.isNotEmpty) {
      params['id'] = id;
    } else {
      // Fallback to artist+title if no id
      params['artist'] = artist;
      params['title'] = title;
    }

    _logger.debug('Fetching lyrics: artist=$artist, title=$title, id=$id');

    try {
      final response = await _dio.get(
        '/$_apiEndpoint/getLyrics',
        queryParameters: {
          ..._getAuthParams(useJson: false),
          ...params,
        },
        options: Options(responseType: ResponseType.plain),
      );

      final xmlString = response.data as String;
      final document = XmlDocument.parse(xmlString);
      final lyricsElement = document.findAllElements('lyrics').firstOrNull;

      if (lyricsElement == null) {
        _logger.debug('No lyrics element found in response');
        return null;
      }

      final lyricsText = lyricsElement.innerText;
      if (lyricsText.isEmpty) {
        _logger.debug('Empty lyrics text');
        return null;
      }

      _logger.info('Lyrics fetched successfully for: $title');
      return lyricsText;
    } catch (e) {
      _logger.error('Error fetching lyrics: $e');
      return null;
    }
  }
}
