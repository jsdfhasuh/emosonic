import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../providers/providers.dart';
import '../screens/player_screen.dart';
import 'audio_waveform.dart';
import 'auto_marquee_text.dart';
import 'star_button.dart';

/// Custom painter for circular progress ring
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(51)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);
    // Use Selector to listen to albumId changes for cover update
    final albumId = ref.watch(
      currentSongProvider.select((song) => song?.albumId),
    );

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWide = screenWidth >= 380; // Threshold for showing prev/next buttons

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
                    // Circular cover with progress ring and center play button
                    StreamBuilder<Duration>(
                      stream: audioService.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = currentSong.duration != null
                            ? Duration(seconds: currentSong.duration!)
                            : Duration.zero;
                        
                        double progress = 0.0;
                        if (duration.inMilliseconds > 0) {
                          progress = position.inMilliseconds / duration.inMilliseconds;
                          progress = progress.clamp(0.0, 1.0);
                        }

                        return SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Progress ring
                              CustomPaint(
                                size: const Size(52, 52),
                                painter: CircularProgressPainter(
                                  progress: progress,
                                  strokeWidth: 2,
                                  color: const Color(0xFF6B8DD6),
                                ),
                              ),
                              // Circular cover with ValueKey to force rebuild on album change
                              ClipOval(
                                key: ValueKey(albumId),
                                child: ImageCacheManager().getCachedImage(
                                  imageUrl: currentSong.coverArt != null
                                      ? ref.read(apiClientProvider).getCoverArtUrl(
                                          currentSong.coverArt!,
                                          itemId: currentSong.albumId,
                                        )
                                      : '',
                                  width: 48,
                                  height: 48,
                                  cacheKey: 'album_${currentSong.albumId}',
                                  placeholder: _buildPlaceholder(),
                                  errorWidget: _buildPlaceholder(),
                                ),
                              ),
                              // Center play/pause button (transparent)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    if (isPlaying) {
                                      await audioService.pause();
                                    } else {
                                      await audioService.play();
                                    }
                                  },
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      size: 24,
                                      color: Colors.white.withAlpha(204),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    // Song Info with marquee
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title with auto marquee
                          SizedBox(
                            height: 20,
                            child: AutoMarqueeText(
                              text: currentSong.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              height: 20,
                              velocity: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                              blankSpace: 20.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Artist with auto marquee
                          SizedBox(
                            height: 18,
                            child: AutoMarqueeText(
                              text: currentSong.artistName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withAlpha(179),
                              ),
                              height: 18,
                              velocity: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                              blankSpace: 20.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Controls - Responsive based on screen width
                    Container(
                      width: isWide ? 140 : 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (isWide) ...[
                            // Wide screen: prev, star, next
                            IconButton(
                              icon: const Icon(Icons.skip_previous, size: 22),
                              onPressed: () async {
                                final queue = audioService.queue;
                                final currentIndex = audioService.currentIndex;
                                if (currentIndex > 0) {
                                  final prevSong = queue[currentIndex - 1];
                                  ref.read(currentSongProvider.notifier).state = prevSong;
                                }
                                await audioService.playPrevious();
                              },
                            ),
                            StarButton(songId: currentSong.id, size: 22),
                            IconButton(
                              icon: const Icon(Icons.skip_next, size: 22),
                              onPressed: () async {
                                final queue = audioService.queue;
                                final currentIndex = audioService.currentIndex;
                                if (currentIndex < queue.length - 1) {
                                  final nextSong = queue[currentIndex + 1];
                                  ref.read(currentSongProvider.notifier).state = nextSong;
                                }
                                await audioService.playNext();
                              },
                            ),
                          ] else ...[
                            // Narrow screen: only star
                            StarButton(songId: currentSong.id, size: 24),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
}
