import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class VolumeControl extends ConsumerWidget {
  const VolumeControl({super.key});

  void _showVolumeBottomSheet(BuildContext context, WidgetRef ref, double currentVolume) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    '音量调节',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Volume icon and percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          currentVolume == 0 
                              ? Icons.volume_off 
                              : currentVolume < 0.3 
                                  ? Icons.volume_mute 
                                  : currentVolume < 0.7 
                                      ? Icons.volume_down 
                                      : Icons.volume_up,
                          size: 32,
                          color: currentVolume == 0 ? Colors.white54 : const Color(0xFF6B8DD6),
                        ),
                        onPressed: () {
                          final audioService = ref.read(audioPlayerServiceProvider);
                          if (currentVolume > 0) {
                            audioService.setVolume(0);
                            setState(() {});
                          } else {
                            audioService.setVolume(0.5);
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      StreamBuilder<double>(
                        stream: ref.watch(audioPlayerServiceProvider).volumeStream,
                        initialData: currentVolume,
                        builder: (context, snapshot) {
                          final volume = snapshot.data ?? currentVolume;
                          return Text(
                            '${(volume * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B8DD6),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Large slider
                  StreamBuilder<double>(
                    stream: ref.watch(audioPlayerServiceProvider).volumeStream,
                    initialData: currentVolume,
                    builder: (context, snapshot) {
                      final volume = snapshot.data ?? currentVolume;
                      return Slider(
                        value: volume,
                        min: 0,
                        max: 1,
                        divisions: 100,
                        activeColor: const Color(0xFF6B8DD6),
                        inactiveColor: Colors.white.withAlpha(26),
                        thumbColor: const Color(0xFF6B8DD6),
                        onChanged: (value) {
                          final audioService = ref.read(audioPlayerServiceProvider);
                          audioService.setVolume(value);
                          setState(() {});
                        },
                      );
                    },
                  ),
                  
                  // Quick volume buttons
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickVolumeButton(context, ref, 0, '静音'),
                      _buildQuickVolumeButton(context, ref, 0.25, '25%'),
                      _buildQuickVolumeButton(context, ref, 0.5, '50%'),
                      _buildQuickVolumeButton(context, ref, 0.75, '75%'),
                      _buildQuickVolumeButton(context, ref, 1.0, '100%'),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickVolumeButton(BuildContext context, WidgetRef ref, double volume, String label) {
    return TextButton(
      onPressed: () {
        final audioService = ref.read(audioPlayerServiceProvider);
        audioService.setVolume(volume);
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: Colors.white.withAlpha(26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeAsync = ref.watch(volumeProvider);

    return volumeAsync.when(
      data: (volume) {
        return IconButton(
          icon: Icon(
            volume == 0 
                ? Icons.volume_off 
                : volume < 0.3 
                    ? Icons.volume_mute 
                    : volume < 0.7 
                        ? Icons.volume_down 
                        : Icons.volume_up,
            size: 28,
            color: volume == 0 ? Colors.white54 : Colors.white,
          ),
          onPressed: () => _showVolumeBottomSheet(context, ref, volume),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, __) => const SizedBox.shrink(),
    );
  }
}
