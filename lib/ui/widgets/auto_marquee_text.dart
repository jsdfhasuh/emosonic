import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// A text widget that automatically switches between normal text and marquee
/// based on whether the text overflows the available width.
class AutoMarqueeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double height;
  final double velocity;
  final Duration pauseAfterRound;
  final double blankSpace;

  const AutoMarqueeText({
    super.key,
    required this.text,
    this.style,
    required this.height,
    this.velocity = 30.0,
    this.pauseAfterRound = const Duration(seconds: 1),
    this.blankSpace = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate text width
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final textWidth = textPainter.width;
        final availableWidth = constraints.maxWidth;

        // If text fits, show normal text
        if (textWidth <= availableWidth) {
          return SizedBox(
            height: height,
            child: Text(
              text,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          );
        }

        // If text overflows, show marquee
        return SizedBox(
          height: height,
          child: Marquee(
            text: text,
            style: style,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            blankSpace: blankSpace,
            velocity: velocity,
            pauseAfterRound: pauseAfterRound,
            showFadingOnlyWhenScrolling: true,
            fadingEdgeStartFraction: 0.1,
            fadingEdgeEndFraction: 0.1,
          ),
        );
      },
    );
  }
}