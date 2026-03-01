import '../../data/models/lyric_line.dart';

/// Parser for LRC (LyRiCs) format
class LrcParser {
  /// Parse LRC text into list of LyricLine
  /// Supports [mm:ss.xx] and [mm:ss] formats
  static List<LyricLine> parse(String lrcText) {
    final lines = <LyricLine>[];
    final linePattern = RegExp(r'^(\[\d{2}:\d{2}(\.\d{2,3})?\])+(.+)$');
    final timePattern = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\]');

    for (final line in lrcText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = linePattern.firstMatch(trimmed);
      if (match == null) continue;

      // Extract all timestamps from the line
      final timeMatches = timePattern.allMatches(trimmed);
      final text = match.group(3)?.trim() ?? '';

      if (text.isEmpty) continue;

      // Create a LyricLine for each timestamp
      for (final timeMatch in timeMatches) {
        final minutes = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        final millisStr = timeMatch.group(3) ?? '0';
        
        // Handle different millisecond formats (2 or 3 digits)
        int milliseconds;
        if (millisStr.length == 2) {
          milliseconds = int.tryParse(millisStr) ?? 0;
          milliseconds *= 10; // Convert from centiseconds to milliseconds
        } else {
          milliseconds = int.tryParse(millisStr) ?? 0;
        }

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        lines.add(LyricLine(time: duration, text: text));
      }
    }

    // Sort by time
    lines.sort((a, b) => a.time.compareTo(b.time));

    return lines;
  }
}
