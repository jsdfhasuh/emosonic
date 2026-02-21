import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../providers/providers.dart';
import '../screens/player_screen.dart';
import 'audio_waveform.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withAlpha(242),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withAlpha(26),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to full player screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PlayerScreen(),
                settings: const RouteSettings(name: '/player'),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Cover Art
                ClipRRect(
                  key: ValueKey(currentSong.id), // Force rebuild when song changes
                  borderRadius: BorderRadius.circular(8),
                  child: ImageCacheManager().getCachedImage(
                    imageUrl: currentSong.coverArt != null
                        ? ref.read(apiClientProvider).getCoverArtUrl(currentSong.coverArt!, itemId: currentSong.albumId)
                        : '',
                    width: 48,
                    height: 48,
                    cacheKey: 'album_${currentSong.albumId}',
                    placeholder: _buildPlaceholder(),
                    errorWidget: _buildPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                // Song Info with Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSong.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentSong.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withAlpha(179),
                              ),
                            ),
                          ),
                          // Progress indicator
                          StreamBuilder<Duration>(
                            stream: audioService.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration = currentSong.duration != null
                                  ? Duration(seconds: currentSong.duration!)
                                  : Duration.zero;
                              return Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withAlpha(128),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Progress bar
                      StreamBuilder<Duration>(
                        stream: audioService.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = currentSong.duration != null
                              ? Duration(seconds: currentSong.duration!)
                              : Duration.zero;
                          
                          // Validate to avoid NaN or Infinity
                          final positionMs = position.inMilliseconds.toDouble();
                          final durationMs = duration.inMilliseconds.toDouble();
                          double progress = 0.0;
                          
                          if (durationMs.isFinite && durationMs > 0 && positionMs.isFinite) {
                            progress = positionMs / durationMs;
                          }
                          
                          return Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26),
                              borderRadius: BorderRadius.circular(1),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B8DD6),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 24),
                      onPressed: () async {
                        // Get next song info first
                        final queue = audioService.queue;
                        final currentIndex = audioService.currentIndex;
                        if (currentIndex > 0) {
                          final prevSong = queue[currentIndex - 1];
                          // Update state immediately
                          ref.read(currentSongProvider.notifier).state = prevSong;
                        }
                        // Then play
                        await audioService.playPrevious();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                        color: const Color(0xFF6B8DD6),
                      ),
                      onPressed: () async {
                        if (isPlaying) {
                          await audioService.pause();
                          // Note: isPlayingProvider is now synced via onPlayingStateChanged callback
                        } else {
                          await audioService.play();
                          // Note: isPlayingProvider is now synced via onPlayingStateChanged callback
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 24),
                      onPressed: () async {
                        // Get next song info first
                        final queue = audioService.queue;
                        final currentIndex = audioService.currentIndex;
                        if (currentIndex < queue.length - 1) {
                          final nextSong = queue[currentIndex + 1];
                          // Update state immediately
                          ref.read(currentSongProvider.notifier).state = nextSong;
                        }
                        // Then play
                        await audioService.playNext();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.queue_music, size: 24),
                      onPressed: () {
                        _showPlaylistQueue(context, ref, audioService);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFF2D3B4E),
      child: const Icon(Icons.music_note, color: Colors.white54),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showPlaylistQueue(BuildContext context, WidgetRef ref, audioService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final queue = audioService.queue;
        final currentSong = ref.watch(currentSongProvider);
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '播放队列',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final song = queue[index];
                    final isCurrent = currentSong?.id == song.id;
                    
                    return ListTile(
                      leading: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF6B8DD6) : Colors.white54,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF6B8DD6) : Colors.white,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        song.artistName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(179),
                        ),
                      ),
                      trailing: isCurrent
                          ? const AudioWaveform(
                              color: Color(0xFF6B8DD6),
                              height: 20,
                              width: 24,
                              barCount: 4,
                            )
                          : null,
                      onTap: () async {
                        await audioService.playQueue(queue, startIndex: index);
                        ref.read(currentSongProvider.notifier).state = song;
                        // Note: isPlayingProvider is now synced via onPlayingStateChanged callback
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
