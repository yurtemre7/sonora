import 'dart:io';

class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});
}

class LyricsService {
  LyricsService._();

  static Future<List<LyricLine>?> parseLyricsForSong(String songFilePath) async {
    try {
      var lastDot = songFilePath.lastIndexOf('.');
      if (lastDot == -1) return null;
      var lrcPath = '${songFilePath.substring(0, lastDot)}.lrc';
      var file = File(lrcPath);
      if (!file.existsSync()) {
        return null;
      }

      var lines = await file.readAsLines();
      var lyrics = <LyricLine>[];

      // Regex matching time tags: [mm:ss.xx] or [mm:ss]
      var regExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]');

      for (var line in lines) {
        var trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        var matches = regExp.allMatches(trimmed);
        if (matches.isEmpty) continue;

        var text = trimmed.replaceAll(regExp, '').trim();

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

      lyrics.sort((a, b) => a.time.compareTo(b.time));
      return lyrics;
    } catch (_) {
      return null;
    }
  }
}
