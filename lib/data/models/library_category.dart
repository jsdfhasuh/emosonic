enum LibraryCategory {
  genres('流派'),
  albums('专辑'),
  artists('歌手'),
  songs('单曲'),
  playlists('歌单'),
  cached('已缓存');

  final String label;
  const LibraryCategory(this.label);
}
