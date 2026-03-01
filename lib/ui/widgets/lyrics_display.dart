import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lyric_line.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../services/audio_player_service.dart';

/// Lyrics display widget with sync scrolling
class LyricsDisplay extends ConsumerStatefulWidget {
  final Song song;
  final AudioPlayerService audioService;

  const LyricsDisplay({
    super.key,
    required this.song,
    required this.audioService,
  });

  @override
  ConsumerState<LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends ConsumerState<LyricsDisplay> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;
  bool _isUserScrolling = false;
  Timer? _resumeAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _setupPositionListener();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupPositionListener() {
    _positionSubscription = widget.audioService.positionStream.listen((position) {
      if (!_isUserScrolling) {
        _updateCurrentLine(position);
      }
    });
  }

  void _updateCurrentLine(Duration position) {
    final lyricsAsync = ref.read(lyricsProvider(widget.song));
    
    lyricsAsync.whenData((lyrics) {
      if (lyrics.isEmpty) return;

      // Find current line
      int currentIndex = 0;
      for (int i = 0; i < lyrics.length; i++) {
        if (position >= lyrics[i].time) {
          currentIndex = i;
        } else {
          break;
        }
      }

      // Update provider
      ref.read(currentLyricIndexProvider.notifier).state = currentIndex;

      // Auto scroll to current line
      _scrollToLine(currentIndex);
    });
  }

  void _scrollToLine(int index) {
    if (!_scrollController.hasClients) return;

    const itemHeight = 48.0;
    final targetOffset = index * itemHeight - 100; // Center the line
    
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onUserScroll() {
    _isUserScrolling = true;
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 3), () {
      _isUserScrolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.song));
    final currentIndex = ref.watch(currentLyricIndexProvider);

    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return const Center(
            child: Text(
              '暂无歌词',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _onUserScroll();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 100),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final line = lyrics[index];
              final isCurrent = index == currentIndex;
              final isPast = index < currentIndex;

              return Container(
                height: 48,
                alignment: Alignment.center,
                child: Text(
                  line.text,
                  style: TextStyle(
                    fontSize: isCurrent ? 18 : 16,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? Colors.white
                        : isPast
                            ? Colors.grey[600]
                            : Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text(
          '加载歌词失败',
          style: TextStyle(
            color: Colors.red[300],
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
