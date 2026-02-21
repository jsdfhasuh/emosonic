import 'package:freezed_annotation/freezed_annotation.dart';

part 'song.freezed.dart';
part 'song.g.dart';

@freezed
class Song with _$Song {
  // ignore: invalid_annotation_target
  const factory Song({
    required String id,
    required String title,
    required String albumId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'album') required String albumName,
    required String artistId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'artist') required String artistName,
    String? coverArt,
    int? duration,
    int? track,
    int? year,
    String? genre,
    String? contentType,
    int? bitRate,
  }) = _Song;

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
}
