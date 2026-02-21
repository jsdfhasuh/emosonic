import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import 'audio_waveform.dart';

class PlaylistDrawer extends ConsumerStatefulWidget {
  const PlaylistDrawer({super.key});

  @override
  ConsumerState<PlaylistDrawer> createState() => _PlaylistDrawerState();
}

class _PlaylistDrawerState extends ConsumerState<PlaylistDrawer> {
  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    
    // Use StreamBuilder to listen for queue changes
    return StreamBuilder<void>(
      stream: audioService.queueChangeStream,
      builder: (context, snapshot) {
        final queue = audioService.queue;
        final currentSong = audioService.currentSong;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withAlpha(26),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.queue_music),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '播放队列',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${queue.length} 首歌曲',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (queue.isNotEmpty)
                    Tooltip(
                      message: '下载所有歌曲到本地',
                      child: TextButton.icon(
                        icon: const Icon(Icons.download, size: 20),
                        label: const Text('下载', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          // Show progress dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('正在缓存歌曲...'),
                                ],
                              ),
                            ),
                          );

                          // Start pre-caching
                          await audioService.preCacheSongs(queue);

                          if (context.mounted) {
                            Navigator.pop(context); // Close progress dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('队列歌曲已缓存到本地'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (queue.isNotEmpty && queue.length > 1)
                    Tooltip(
                      message: '清空队列（保留当前歌曲）',
                      child: TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 20),
                        label: const Text('清空', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('清空队列'),
                              content: const Text('确定要清空播放队列吗？当前播放的歌曲将保留。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    audioService.clearQueueExceptCurrent();
                                    // Also update queueProvider
                                    final current = audioService.currentSong;
                                    if (current != null) {
                                      ref.read(queueProvider.notifier).setQueue([current]);
                                    } else {
                                      ref.read(queueProvider.notifier).clearQueue();
                                    }
                                  },
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            
            // Queue List
            Expanded(
              child: queue.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_off, size: 64, color: Colors.white54),
                          SizedBox(height: 16),
                          Text('队列为空', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isCurrent = currentSong?.id == song.id;
                        
                        return ListTile(
                          leading: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent 
                                  ? const Color(0xFF6B8DD6) 
                                  : Colors.white54,
                              fontWeight: isCurrent 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                          title: Text(
                            song.title,
                            style: TextStyle(
                              color: isCurrent 
                                  ? const Color(0xFF6B8DD6) 
                                  : Colors.white,
                              fontWeight: isCurrent 
                                  ? FontWeight.w600 
                                  : FontWeight.normal,
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
                              : IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () {
                                    ref.read(queueProvider.notifier).removeFromQueue(song);
                                    audioService.removeFromQueue(song);
                                  },
                                ),
                          onTap: () async {
                            await audioService.playQueue(queue, startIndex: index);
                            ref.read(currentSongProvider.notifier).state = song;
                            ref.read(isPlayingProvider.notifier).state = true;
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
