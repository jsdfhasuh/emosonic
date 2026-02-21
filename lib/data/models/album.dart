import 'package:freezed_annotation/freezed_annotation.dart';

part 'album.freezed.dart';
part 'album.g.dart';

@freezed
class Album with _$Album {
  // ignore: invalid_annotation_target
  const factory Album({
    required String id,
    required String name,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'artistId') required String artistId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'artist') required String artistName,
    String? coverArt,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _yearFromJson) int? year,
    String? genre,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _intFromJson) int? songCount,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _intFromJson) int? duration,
  }) = _Album;

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
}

int? _yearFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) {
    // Handle cases like "2016, 2017" by taking the first year
    final firstYear = value.split(',').first.trim();
    return int.tryParse(firstYear);
  }
  return null;
}

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
