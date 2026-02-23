import 'package:freezed_annotation/freezed_annotation.dart';
import '../song.dart';

part 'starred_songs_state.freezed.dart';

@freezed
class StarredSongsState with _$StarredSongsState {
  const factory StarredSongsState({
    @Default([]) List<Song> songs,
    @Default(false) bool isLoading,
    @Default(false) bool hasMore,
    String? error,
    @Default(0) int offset,
    @Default(50) int limit,
  }) = _StarredSongsState;
}