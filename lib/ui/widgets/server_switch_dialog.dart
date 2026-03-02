import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class ServerSwitchDialog extends ConsumerWidget {
  final String serverName;
  final VoidCallback onConfirm;

  const ServerSwitchDialog({
    super.key,
    required this.serverName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorTheme = ref.watch(colorThemeProvider);
    return AlertDialog(
      backgroundColor: colorTheme.surfaceColor,
      title: const Text('切换服务器'),
      content: Text(
        '确定要切换到服务器 "$serverName" 吗？\n\n'
        '注意：切换服务器将清除当前播放队列。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            // Stop playback and clear queue before switching
            final audioService = ref.read(audioPlayerServiceProvider);
            await audioService.stop();
            await audioService.clearQueue();
            
            if (context.mounted) {
              Navigator.pop(context);
              onConfirm();
            }
          },
          child: const Text('确认切换'),
        ),
      ],
    );
  }
}
