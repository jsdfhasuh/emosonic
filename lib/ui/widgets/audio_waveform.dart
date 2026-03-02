import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioWaveform extends StatefulWidget {
  final Color? color;
  final double height;
  final double width;
  final int barCount;

  const AudioWaveform({
    super.key,
    this.color,
    this.height = 24,
    this.width = 24,
    this.barCount = 4,
  });

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create staggered animations for each bar
    for (int i = 0; i < widget.barCount; i++) {
      final animation = Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            i * 0.1,
            0.6 + i * 0.1,
            curve: Curves.easeInOut,
          ),
        ),
      );
      _animations.add(animation);
    }

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          widget.barCount,
          (index) => AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: 3,
                height: widget.height * _animations[index].value,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Alternative: Equalizer-style waveform with random heights
class AudioEqualizer extends StatefulWidget {
  final Color? color;
  final double height;
  final double width;
  final int barCount;

  const AudioEqualizer({
    super.key,
    this.color,
    this.height = 24,
    this.width = 24,
    this.barCount = 5,
  });

  @override
  State<AudioEqualizer> createState() => _AudioEqualizerState();
}

class _AudioEqualizerState extends State<AudioEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _random = math.Random();
  late List<double> _heights;

  @override
  void initState() {
    super.initState();
    _heights = List.generate(widget.barCount, (_) => 0.5);
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _controller.addListener(() {
      if (_controller.isCompleted) {
        setState(() {
          _heights = List.generate(
            widget.barCount,
            (_) => 0.2 + _random.nextDouble() * 0.8,
          );
        });
        _controller.forward(from: 0);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          widget.barCount,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 3,
            height: widget.height * _heights[index],
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      ),
    );
  }
}
