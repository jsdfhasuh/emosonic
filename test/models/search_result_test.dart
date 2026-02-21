import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_player/data/models/search_result.dart';

void main() {
  group('SearchResult', () {
    test('should create SearchResult from JSON with all fields', () {
      final json = {
        'artist': [
          {'id': '1', 'name': 'Artist 1'},
        ],
        'album': [
          {
            'id': '2',
            'name': 'Album 1',
            'artistId': '1',
            'artist': 'Artist 1',
          },
        ],
        'song': [
          {
            'id': '3',
            'title': 'Song 1',
            'albumId': '2',
            'album': 'Album 1',
            'artistId': '1',
            'artist': 'Artist 1',
          },
        ],
      };

      final result = SearchResult.fromJson(json);

      expect(result.artists.length, 1);
      expect(result.albums.length, 1);
      expect(result.songs.length, 1);
      expect(result.artists.first.name, 'Artist 1');
      expect(result.albums.first.name, 'Album 1');
      expect(result.songs.first.title, 'Song 1');
    });

    test('should handle empty results', () {
      final json = <String, dynamic>{};

      final result = SearchResult.fromJson(json);

      expect(result.artists, isEmpty);
      expect(result.albums, isEmpty);
      expect(result.songs, isEmpty);
    });

    test('should handle null fields', () {
      final json = {
        'artist': null,
        'album': null,
        'song': null,
      };

      final result = SearchResult.fromJson(json);

      expect(result.artists, isEmpty);
      expect(result.albums, isEmpty);
      expect(result.songs, isEmpty);
    });

    test('should handle partial results (only songs)', () {
      final json = {
        'song': [
          {
            'id': '1',
            'title': 'Song 1',
            'albumId': '2',
            'album': 'Album 1',
            'artistId': '1',
            'artist': 'Artist 1',
          },
        ],
      };

      final result = SearchResult.fromJson(json);

      expect(result.artists, isEmpty);
      expect(result.albums, isEmpty);
      expect(result.songs.length, 1);
      expect(result.songs.first.title, 'Song 1');
    });

    test('should handle invalid data gracefully', () {
      final json = {
        'artist': [
          {'invalid': 'data'},
        ],
        'song': [
          {
            'id': '1',
            'title': 'Valid Song',
            'albumId': '2',
            'album': 'Album 1',
            'artistId': '1',
            'artist': 'Artist 1',
          },
        ],
      };

      final result = SearchResult.fromJson(json);

      // Invalid artist should be skipped
      expect(result.artists, isEmpty);
      // Valid song should be parsed
      expect(result.songs.length, 1);
      expect(result.songs.first.title, 'Valid Song');
    });
  });
}
