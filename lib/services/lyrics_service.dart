import 'dart:io';

class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});
}

class SongLyrics {
  final List<LyricLine> lines;
  final bool isSynchronized;

  SongLyrics({required this.lines, required this.isSynchronized});
}

class LyricsService {
  LyricsService._();

  static Future<SongLyrics?> parseLyricsForSong(String songFilePath) async {
    try {
      var lastDot = songFilePath.lastIndexOf('.');
      if (lastDot == -1) return null;
      
      var lrcPath = '${songFilePath.substring(0, lastDot)}.lrc';
      var file = File(lrcPath);
      if (!file.existsSync()) {
        var txtPath = '${songFilePath.substring(0, lastDot)}.txt';
        file = File(txtPath);
        if (!file.existsSync()) {
          return null;
        }
      }

      var lines = await file.readAsLines();
      var lyrics = <LyricLine>[];
      var regExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]');
      var hasAnyTimestamp = false;

      for (var line in lines) {
        var trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        var matches = regExp.allMatches(trimmed);
        if (matches.isNotEmpty) {
          hasAnyTimestamp = true;
          var text = trimmed.replaceAll(regExp, '').trim();
          if (text.isEmpty) continue;
          for (var match in matches) {
            var min = int.parse(match.group(1)!);
            var sec = int.parse(match.group(2)!);
            var ms = 0;
            var msGroup = match.group(3);
            if (msGroup != null) {
              if (msGroup.length == 2) {
                ms = int.parse(msGroup) * 10;
              } else {
                ms = int.parse(msGroup);
              }
            }
            var time = Duration(
              minutes: min,
              seconds: sec,
              milliseconds: ms,
            );
            lyrics.add(LyricLine(time: time, text: text));
          }
        }
      }

      if (hasAnyTimestamp) {
        lyrics.sort((a, b) => a.time.compareTo(b.time));
        return SongLyrics(lines: lyrics, isSynchronized: true);
      } else {
        // Unsynchronized plain text lyrics: read all lines as text
        var plainLines = <LyricLine>[];
        for (var line in lines) {
          var trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          // Only strip known LRC metadata tags ([ti:], [ar:], [al:], [by:], [offset:])
          // but preserve section headers like [Verse 1], [Chorus], etc.
          if (_isMetadataTag(trimmed)) {
            continue;
          }
          plainLines.add(LyricLine(time: Duration.zero, text: trimmed));
        }
        return SongLyrics(lines: plainLines, isSynchronized: false);
      }
    } catch (_) {
      return null;
    }
  }

  static final _lrcMetadataTag = RegExp(r'^\[(ti|ar|al|by|offset|re|ve|length):', caseSensitive: false);

  /// Returns true for known LRC metadata tags (e.g. [ti:Title], [ar:Artist])
  /// but preserves section headers like [Verse 1], [Chorus], [Bridge].
  static bool _isMetadataTag(String line) {
    return _lrcMetadataTag.hasMatch(line);
  }
}
