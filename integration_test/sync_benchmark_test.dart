import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/services/music_scanner.dart';

class _BenchmarkResult {
  final int size;
  final Duration initialP4;
  final Duration initialSeq;
  final Duration cachedP4;
  final Duration cachedSeq;
  final Duration partialP4;
  final Duration partialSeq;

  _BenchmarkResult({
    required this.size,
    required this.initialP4,
    required this.initialSeq,
    required this.cachedP4,
    required this.cachedSeq,
    required this.partialP4,
    required this.partialSeq,
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;
  late Directory tempScanDir;
  late Uint8List mp3Bytes;
  late Uint8List mp3CoverBytes;

  setUpAll(() async {
    var appDir = await getApplicationDocumentsDirectory();
    tempDocsDir = Directory('${appDir.path}/sonora_docs_test');
    tempScanDir = Directory('${appDir.path}/sonora_scan_test');

    if (!tempDocsDir.existsSync()) {
      tempDocsDir.createSync(recursive: true);
    }
    if (!tempScanDir.existsSync()) {
      tempScanDir.createSync(recursive: true);
    }

    // Set mock scan folder path in preferences
    var prefs = SharedPreferencesAsync();
    await prefs.setString('scan_folder_path', tempScanDir.path);

    // Load actual audio asset bytes from the packaged assets bundle
    var byteDataMp3 = await rootBundle.load('test/audio.mp3');
    mp3Bytes = byteDataMp3.buffer.asUint8List(
      byteDataMp3.offsetInBytes,
      byteDataMp3.lengthInBytes,
    );

    var byteDataCover = await rootBundle.load('test/audio_cover.mp3');
    mp3CoverBytes = byteDataCover.buffer.asUint8List(
      byteDataCover.offsetInBytes,
      byteDataCover.lengthInBytes,
    );
  });

  tearDownAll(() {
    try {
      if (tempDocsDir.existsSync()) {
        tempDocsDir.deleteSync(recursive: true);
      }
      if (tempScanDir.existsSync()) {
        tempScanDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  void generateSyntheticFiles(Directory root, int count) {
    for (var i = 0; i < count; i++) {
      var artistId = i ~/ 10;
      var albumId = i ~/ 5;
      var artistDir = Directory('${root.path}/Artist_$artistId/Album_$albumId');
      if (!artistDir.existsSync()) {
        artistDir.createSync(recursive: true);
      }
      var songFile = File('${artistDir.path}/song_$i.mp3');
      var bytes = (i % 2 == 0) ? mp3CoverBytes : mp3Bytes;
      songFile.writeAsBytesSync(bytes);

      // Simulate lyrics files for 50% of songs (alternating .lrc and .txt)
      if (i % 2 == 0) {
        var ext = (i % 4 == 0) ? 'lrc' : 'txt';
        var lrcFile = File('${artistDir.path}/song_$i.$ext');
        lrcFile.writeAsStringSync(
          '[00:12.00] Line 1 for song $i\n[00:24.00] Line 2',
        );
      }
    }
  }

  testWidgets('Comparative Discovery & Sync Integration Benchmark', (
    WidgetTester tester,
  ) async {
    const testSizes = [100, 500, 1000, 2000];
    var results = <_BenchmarkResult>[];

    var scanner = MusicScanner();

    for (var n in testSizes) {
      // --------------------------------------------------------
      // 1. MEASURE PARALLEL (4X)
      // --------------------------------------------------------
      if (tempScanDir.existsSync()) {
        for (var entity in tempScanDir.listSync()) {
          entity.deleteSync(recursive: true);
        }
      }
      if (tempDocsDir.existsSync()) {
        for (var entity in tempDocsDir.listSync()) {
          entity.deleteSync(recursive: true);
        }
      }
      generateSyntheticFiles(tempScanDir, n);

      var sw = Stopwatch()..start();
      var songsP4 = await scanner.syncLibrary();
      sw.stop();
      var initP4 = sw.elapsed;
      expect(songsP4.length, equals(n));

      sw = Stopwatch()
        ..reset()
        ..start();
      await scanner.syncLibrary();
      sw.stop();
      var cacheP4 = sw.elapsed;

      var allFiles = tempScanDir
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      var numToModify = allFiles.length > 10 ? 10 : allFiles.length;
      for (var i = 0; i < numToModify; i++) {
        var file = allFiles[i];
        file.writeAsStringSync('modified content');
      }

      sw = Stopwatch()
        ..reset()
        ..start();
      await scanner.syncLibrary();
      sw.stop();
      var partP4 = sw.elapsed;

      // --------------------------------------------------------
      // 2. MEASURE LEGACY SEQUENTIAL
      // --------------------------------------------------------
      if (tempScanDir.existsSync()) {
        for (var entity in tempScanDir.listSync()) {
          entity.deleteSync(recursive: true);
        }
      }
      if (tempDocsDir.existsSync()) {
        for (var entity in tempDocsDir.listSync()) {
          entity.deleteSync(recursive: true);
        }
      }
      generateSyntheticFiles(tempScanDir, n);

      sw = Stopwatch()
        ..reset()
        ..start();
      var songsSeq = await scanner.legacySyncLibrary();
      sw.stop();
      var initSeq = sw.elapsed;
      expect(songsSeq.length, equals(n));

      sw = Stopwatch()
        ..reset()
        ..start();
      await scanner.legacySyncLibrary();
      sw.stop();
      var cacheSeq = sw.elapsed;

      allFiles = tempScanDir
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      for (var i = 0; i < numToModify; i++) {
        var file = allFiles[i];
        file.writeAsStringSync('modified content');
      }

      sw = Stopwatch()
        ..reset()
        ..start();
      await scanner.legacySyncLibrary();
      sw.stop();
      var partSeq = sw.elapsed;

      results.add(
        _BenchmarkResult(
          size: n,
          initialP4: initP4,
          initialSeq: initSeq,
          cachedP4: cacheP4,
          cachedSeq: cacheSeq,
          partialP4: partP4,
          partialSeq: partSeq,
        ),
      );
    }

    // Print comparative Markdown table
    // ignore: avoid_print
    print(
      '\n==========================================================================================',
    );
    // ignore: avoid_print
    print(
      '                      ON-DEVICE DISCOVERY & SYNC BENCHMARK RUNNER                        ',
    );
    // ignore: avoid_print
    print(
      '                      Comparison: Parallel (4x) vs. Legacy Sequential                     ',
    );
    // ignore: avoid_print
    print(
      '==========================================================================================',
    );
    // ignore: avoid_print
    print(
      '| Size  | Initial (P4) | Initial (Seq) | Cache (P4) | Cache (Seq) | Part (P4) | Part (Seq) |',
    );
    // ignore: avoid_print
    print(
      '| ----- | ------------ | ------------- | ---------- | ----------- | --------- | ---------- |',
    );
    for (var r in results) {
      // ignore: avoid_print
      print(
        '| ${r.size.toString().padRight(5)} '
        '| ${'${r.initialP4.inMilliseconds}ms'.padRight(12)} '
        '| ${'${r.initialSeq.inMilliseconds}ms'.padRight(13)} '
        '| ${'${r.cachedP4.inMilliseconds}ms'.padRight(10)} '
        '| ${'${r.cachedSeq.inMilliseconds}ms'.padRight(11)} '
        '| ${'${r.partialP4.inMilliseconds}ms'.padRight(9)} '
        '| ${'${r.partialSeq.inMilliseconds}ms'.padRight(10)} |',
      );
    }
    // ignore: avoid_print
    print(
      '==========================================================================================\n',
    );
  });
}
