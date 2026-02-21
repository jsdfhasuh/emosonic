import 'models.dart';

class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  const SearchResult({
    required this.artists,
    required this.albums,
    required this.songs,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final artists = <Artist>[];
    final albums = <Album>[];
    final songs = <Song>[];

    if (json['artist'] != null && json['artist'] is List) {
      for (final artist in json['artist']) {
        try {
          artists.add(Artist.fromJson(artist));
        } catch (e) {
          // Skip invalid artist data
        }
      }
    }

    if (json['album'] != null && json['album'] is List) {
      for (final album in json['album']) {
        try {
          albums.add(Album.fromJson(album));
        } catch (e) {
          // Skip invalid album data
        }
      }
    }

    if (json['song'] != null && json['song'] is List) {
      for (final song in json['song']) {
        try {
          songs.add(Song.fromJson(song));
        } catch (e) {
          // Skip invalid song data
        }
      }
    }

    return SearchResult(
      artists: artists,
      albums: albums,
      songs: songs,
    );
  }

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
