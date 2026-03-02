import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../providers/providers.dart';
import '../widgets/playlist_drawer.dart';
import '../widgets/volume_control.dart';
import '../widgets/playback_mode_controls.dart';
import '../widgets/star_button.dart';
import '../widgets/player_more_menu.dart';
import '../widgets/lyrics_display.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);
    final currentTab = ref.watch(playerTabProvider);

    if (currentSong == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('正在播放'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 100, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '没有正在播放的歌曲',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: MediaQuery.of(context).size.width >= 400
            ? const Text('正在播放')
            : null,
        actions: [
          const PlaybackModeControls(),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              final screenWidth = MediaQuery.of(context).size.width;
              final isNarrow = screenWidth < 400;
              showPlayerMoreMenu(context, ref, showVolumeEntry: isNarrow);
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.queue_music),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: const PlaylistDrawer(),
      body: Column(
        children: [
          // Tab selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<PlayerTab>(
              segments: const [
                ButtonSegment(
                  value: PlayerTab.album,
                  label: Text('专辑'),
                  icon: Icon(Icons.album),
                ),
                ButtonSegment(
                  value: PlayerTab.lyrics,
                  label: Text('歌词'),
                  icon: Icon(Icons.lyrics),
                ),
              ],
              selected: {currentTab},
              onSelectionChanged: (Set<PlayerTab> newSelection) {
                ref.read(playerTabProvider.notifier).state = newSelection.first;
              },
            ),
          ),
          // Content area
          Expanded(
            child: currentTab == PlayerTab.album
                ? _buildAlbumPage(context, ref, currentSong, isPlaying, audioService)
                : LyricsDisplay(
                    song: currentSong,
                    audioService: audioService,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumPage(
    BuildContext context,
    WidgetRef ref,
    currentSong,
    bool isPlaying,
    audioService,
  ) {
    final albumId = ref.watch(
      currentSongProvider.select((song) => song?.albumId),
    );
    final colorTheme = ref.watch(colorThemeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;
        
        final coverSize = (availableHeight * 0.5).clamp(200.0, 350.0);
        final horizontalPadding = availableWidth * 0.08;
        
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Cover Art
              Flexible(
                flex: 5,
                child: Container(
                  width: coverSize,
                  height: coverSize,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    key: ValueKey(albumId),
                    borderRadius: BorderRadius.circular(16),
                    child: ImageCacheManager().getCachedImage(
                      imageUrl: currentSong.albumId != null
                          ? ref.read(apiClientProvider).getCoverArtUrl(
                              currentSong.coverArt ?? '',
                              itemId: currentSong.albumId,
                            )
                          : '',
                      width: coverSize,
                      height: coverSize,
                      cacheKey: 'album_${currentSong.albumId}',
                      placeholder: Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.album, size: 100, color: Colors.grey),
                      ),
                      errorWidget: Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.album, size: 100, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Song Info
              Flexible(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            currentSong.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StarButton(songId: currentSong.id, size: 28),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentSong.artistName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentSong.albumName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Progress Bar
              Flexible(
                flex: 2,
                child: StreamBuilder<Duration>(
                  stream: audioService.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    return StreamBuilder<Duration?>(
                      stream: audioService.durationStream,
                      builder: (context, durationSnapshot) {
                        final metadataDuration = currentSong.duration != null 
                            ? Duration(seconds: currentSong.duration!)
                            : Duration.zero;
                        final duration = durationSnapshot.data ?? metadataDuration;
                        
                        final positionMs = position.inMilliseconds.toDouble();
                        final durationMs = duration.inMilliseconds.toDouble();
                        final validDuration = durationMs.isFinite && durationMs > 0 ? durationMs : 1.0;
                        final validPosition = positionMs.isFinite ? positionMs.clamp(0.0, validDuration) : 0.0;
                        
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Slider(
                              value: validPosition,
                              max: validDuration,
                              activeColor: colorTheme.accentColor,
                              inactiveColor: Colors.white.withAlpha(51),
                              onChanged: (value) {},
                              onChangeEnd: (value) {
                                if (value.isFinite) {
                                  audioService.seek(Duration(milliseconds: value.toInt()));
                                  audioService.onSeekPerformed();
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(179),
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(179),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              
              // Controls
              Flexible(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 400;
                        final smallSpacing = isNarrow ? 12.0 : 24.0;
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isNarrow) ...[
                              const PlaybackModeControls(),
                              const SizedBox(width: 8),
                            ],
                            IconButton(
                              iconSize: isNarrow ? 32 : 40,
                              icon: const Icon(Icons.skip_previous),
                              onPressed: () async {
                                await audioService.playPrevious();
                              },
                            ),
                            SizedBox(width: smallSpacing),
                            IconButton(
                              iconSize: isNarrow ? 48 : 64,
                              icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                              onPressed: () async {
                                if (isPlaying) {
                                  await audioService.pause();
                                } else {
                                  await audioService.play();
                                }
                              },
                            ),
                            SizedBox(width: smallSpacing),
                            IconButton(
                              iconSize: isNarrow ? 32 : 40,
                              icon: const Icon(Icons.skip_next),
                              onPressed: () async {
                                await audioService.playNext();
                              },
                            ),
                            if (!isNarrow) ...[
                              const SizedBox(width: 8),
                              const VolumeControl(),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
