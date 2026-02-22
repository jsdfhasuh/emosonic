import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/starred_songs_provider.dart';

/// Star button widget for toggling favorite status
class StarButton extends ConsumerWidget {
  final String songId;
  final double size;

  const StarButton({
    super.key,
    required this.songId,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStarred = ref.watch(isSongStarredProvider(songId));
    final toggleStar = ref.read(toggleStarProvider(songId));

    return IconButton(
      icon: Icon(
        isStarred ? Icons.favorite : Icons.favorite_border,
        color: isStarred ? Colors.red : Colors.white54,
        size: size,
      ),
      onPressed: () async {
        try {
          await toggleStar();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isStarred ? '已取消收藏' : '已添加到收藏'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('操作失败: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }
}