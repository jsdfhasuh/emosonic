/// Represents a single line of lyrics with timestamp
class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({
    required this.time,
    required this.text,
  });

  @override
  String toString() => 'LyricLine(time: $time, text: $text)';
}
