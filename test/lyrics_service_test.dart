import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/services/lyrics_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sonora_lyrics_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LyricsService LRC & TXT Parsing Tests', () {
    test('Parses synchronized LRC file with standard and centisecond timestamps', () async {
      var songPath = '${tempDir.path}/track1.mp3';
      var lrcPath = '${tempDir.path}/track1.lrc';

      var lrcContent = '''
[ti:Midnight Drive]
[ar:Synthwave Collective]
[al:Neon Nights]
[by:Sonora]
[00:15.30]Driving through the neon glow
[00:22.50]City lights begin to fade
[01:05.123]Guitar solo starts right here
''';
      await File(lrcPath).writeAsString(lrcContent);

      var lyrics = await LyricsService.parseLyricsForSong(songPath);
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynchronized, isTrue);
      expect(lyrics.lines.length, equals(3));

      // Line 1: 15 seconds + 300 ms
      expect(lyrics.lines[0].time, equals(const Duration(seconds: 15, milliseconds: 300)));
      expect(lyrics.lines[0].text, equals('Driving through the neon glow'));

      // Line 2: 22 seconds + 500 ms
      expect(lyrics.lines[1].time, equals(const Duration(seconds: 22, milliseconds: 500)));
      expect(lyrics.lines[1].text, equals('City lights begin to fade'));

      // Line 3: 1 min 5 sec + 123 ms
      expect(lyrics.lines[2].time, equals(const Duration(minutes: 1, seconds: 5, milliseconds: 123)));
      expect(lyrics.lines[2].text, equals('Guitar solo starts right here'));
    });

    test('Parses multiple timestamps on a single line and sorts chronologically', () async {
      var songPath = '${tempDir.path}/track2.flac';
      var lrcPath = '${tempDir.path}/track2.lrc';

      var lrcContent = '''
[01:30.00][00:30.00]This is the catchy chorus line
[00:10.00]Intro verse line
''';
      await File(lrcPath).writeAsString(lrcContent);

      var lyrics = await LyricsService.parseLyricsForSong(songPath);
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynchronized, isTrue);
      expect(lyrics.lines.length, equals(3));

      // Check chronological order
      expect(lyrics.lines[0].time, equals(const Duration(seconds: 10)));
      expect(lyrics.lines[0].text, equals('Intro verse line'));

      expect(lyrics.lines[1].time, equals(const Duration(seconds: 30)));
      expect(lyrics.lines[1].text, equals('This is the catchy chorus line'));

      expect(lyrics.lines[2].time, equals(const Duration(minutes: 1, seconds: 30)));
      expect(lyrics.lines[2].text, equals('This is the catchy chorus line'));
    });

    test('Parses unsynchronized TXT file and preserves song headers while filtering metadata', () async {
      var songPath = '${tempDir.path}/track3.m4a';
      var txtPath = '${tempDir.path}/track3.txt';

      var txtContent = '''
[ti:Acoustic Melody]
[ar:Solo Guitarist]
[Verse 1]
Strumming softly in the morning breeze
Watching leaves fall from the trees

[Chorus]
Singing high, singing low
Where the gentle waters flow
''';
      await File(txtPath).writeAsString(txtContent);

      var lyrics = await LyricsService.parseLyricsForSong(songPath);
      expect(lyrics, isNotNull);
      expect(lyrics!.isSynchronized, isFalse);
      expect(lyrics.lines.length, equals(6));

      expect(lyrics.lines[0].text, equals('[Verse 1]'));
      expect(lyrics.lines[1].text, equals('Strumming softly in the morning breeze'));
      expect(lyrics.lines[2].text, equals('Watching leaves fall from the trees'));
      expect(lyrics.lines[3].text, equals('[Chorus]'));
      expect(lyrics.lines[4].text, equals('Singing high, singing low'));
      expect(lyrics.lines[5].text, equals('Where the gentle waters flow'));
    });

    test('Returns null when no lyrics file exists or file path is invalid', () async {
      var songPath = '${tempDir.path}/nonexistent.mp3';
      var lyrics = await LyricsService.parseLyricsForSong(songPath);
      expect(lyrics, isNull);

      var invalidPath = 'invalid_without_dot';
      var lyricsInvalid = await LyricsService.parseLyricsForSong(invalidPath);
      expect(lyricsInvalid, isNull);
    });
  });
}
