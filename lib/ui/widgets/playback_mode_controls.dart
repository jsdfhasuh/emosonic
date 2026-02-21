import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/providers.dart';

class PlaybackModeControls extends ConsumerWidget {
  const PlaybackModeControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loopModeAsync = ref.watch(loopModeProvider);
    final shuffleModeAsync = ref.watch(shuffleModeProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shuffle button
        shuffleModeAsync.when(
          data: (isShuffled) {
            return IconButton(
              icon: Icon(
                Icons.shuffle,
                color: isShuffled 
                    ? const Color(0xFF6B8DD6) 
                    : Colors.white54,
              ),
              tooltip: isShuffled ? '随机播放: 开启' : '随机播放: 关闭',
              onPressed: () {
                final audioService = ref.read(audioPlayerServiceProvider);
                audioService.setShuffleModeEnabled(!isShuffled);
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        
        // Loop mode button
        loopModeAsync.when(
          data: (loopMode) {
            IconData icon;
            String tooltip;
            
            switch (loopMode) {
              case LoopMode.off:
                icon = Icons.repeat;
                tooltip = '列表循环: 关闭';
                break;
              case LoopMode.one:
                icon = Icons.repeat_one;
                tooltip = '单曲循环';
                break;
              case LoopMode.all:
                icon = Icons.repeat;
                tooltip = '列表循环';
                break;
            }
            
            return IconButton(
              icon: Icon(
                icon,
                color: loopMode == LoopMode.off 
                    ? Colors.white54 
                    : const Color(0xFF6B8DD6),
              ),
              tooltip: tooltip,
              onPressed: () {
                final audioService = ref.read(audioPlayerServiceProvider);
                LoopMode nextMode;
                switch (loopMode) {
                  case LoopMode.off:
                    nextMode = LoopMode.all;
                    break;
                  case LoopMode.all:
                    nextMode = LoopMode.one;
                    break;
                  case LoopMode.one:
                    nextMode = LoopMode.off;
                    break;
                }
                audioService.setLoopMode(nextMode);
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
