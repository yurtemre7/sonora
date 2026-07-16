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
  final Duration initialScanParallel;
  final Duration initialScanSequential;
  final Duration noChangeSyncParallel;
  final Duration noChangeSyncSequential;
  final Duration partialSyncParallel;
  final Duration partialSyncSequential;

  _BenchmarkResult({
    required this.size,
    required this.initialScanParallel,
    required this.initialScanSequential,
    required this.noChangeSyncParallel,
    required this.noChangeSyncSequential,
    required this.partialSyncParallel,
    required this.partialSyncSequential,
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;
  late Directory tempScanDir;
  late Uint8List mp3Bytes;
  late Uint8List mp3CoverBytes;

  setUpAll(() async {
    final appDir = await getApplicationDocumentsDirectory();
    tempDocsDir = Directory('${appDir.path}/sonora_docs_test');
    tempScanDir = Directory('${appDir.path}/sonora_scan_test');

    if (!tempDocsDir.existsSync()) {
      tempDocsDir.createSync(recursive: true);
    }
    if (!tempScanDir.existsSync()) {
      tempScanDir.createSync(recursive: true);
    }

    // Set mock scan folder path in preferences
    final prefs = SharedPreferencesAsync();
    await prefs.setString('scan_folder_path', tempScanDir.path);

    // Load actual audio asset bytes from the packaged assets bundle
    final byteDataMp3 = await rootBundle.load('test/audio.mp3');
    mp3Bytes = byteDataMp3.buffer.asUint8List(byteDataMp3.offsetInBytes, byteDataMp3.lengthInBytes);

    final byteDataCover = await rootBundle.load('test/audio_cover.mp3');
    mp3CoverBytes = byteDataCover.buffer.asUint8List(byteDataCover.offsetInBytes, byteDataCover.lengthInBytes);
  });

  tearDownAll(() async {
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
    }
  }

  testWidgets('Comparative Discovery & Sync Integration Benchmark', (WidgetTester tester) async {
    const testSizes = [50, 250, 500, 1000];
    var results = <_BenchmarkResult>[];

    var scanner = MusicScanner();

    for (var n in testSizes) {
      // --------------------------------------------------------
      // 1. MEASURE PARALLEL IMPLEMENTATION (NEW)
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

      // Scenario A: Initial Scan
      var sw = Stopwatch()..start();
      var initialSongsP = await scanner.syncLibrary();
      sw.stop();
      var initialTimeP = sw.elapsed;
      expect(initialSongsP.length, equals(n));

      // Scenario B: No-Change Sync
      sw = Stopwatch()..reset()..start();
      var cachedSongsP = await scanner.syncLibrary();
      sw.stop();
      var cachedTimeP = sw.elapsed;
      expect(cachedSongsP.length, equals(n));

      // Modify 10 files
      var allFiles = tempScanDir.listSync(recursive: true).whereType<File>().toList();
      var numToModify = allFiles.length > 10 ? 10 : allFiles.length;
      for (var i = 0; i < numToModify; i++) {
        var file = allFiles[i];
        file.writeAsStringSync('modified content');
      }

      // Scenario C: Partial Sync
      sw = Stopwatch()..reset()..start();
      var partialSongsP = await scanner.syncLibrary();
      sw.stop();
      var partialTimeP = sw.elapsed;
      expect(partialSongsP.length, equals(n));

      // --------------------------------------------------------
      // 2. MEASURE SEQUENTIAL IMPLEMENTATION (LEGACY)
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

      // Scenario A: Initial Scan
      sw = Stopwatch()..reset()..start();
      var initialSongsS = await scanner.legacySyncLibrary();
      sw.stop();
      var initialTimeS = sw.elapsed;
      expect(initialSongsS.length, equals(n));

      // Scenario B: No-Change Sync
      sw = Stopwatch()..reset()..start();
      var cachedSongsS = await scanner.legacySyncLibrary();
      sw.stop();
      var cachedTimeS = sw.elapsed;
      expect(cachedSongsS.length, equals(n));

      // Modify identical 10 files
      allFiles = tempScanDir.listSync(recursive: true).whereType<File>().toList();
      for (var i = 0; i < numToModify; i++) {
        var file = allFiles[i];
        file.writeAsStringSync('modified content');
      }

      // Scenario C: Partial Sync
      sw = Stopwatch()..reset()..start();
      var partialSongsS = await scanner.legacySyncLibrary();
      sw.stop();
      var partialTimeS = sw.elapsed;
      expect(partialSongsS.length, equals(n));

      results.add(_BenchmarkResult(
        size: n,
        initialScanParallel: initialTimeP,
        initialScanSequential: initialTimeS,
        noChangeSyncParallel: cachedTimeP,
        noChangeSyncSequential: cachedTimeS,
        partialSyncParallel: partialTimeP,
        partialSyncSequential: partialTimeS,
      ));
    }

    // Print consolidated summary comparison table at the end
    // ignore: avoid_print
    print('\n==========================================================================================');
    // ignore: avoid_print
    print('                      ON-DEVICE DISCOVERY & SYNC BENCHMARK RUNNER                        ');
    // ignore: avoid_print
    print('                      Comparison: Parallel vs. Legacy Sequential                          ');
    // ignore: avoid_print
    print('==========================================================================================');
    // ignore: avoid_print
    print('| Size  | Initial (P) | Initial (Seq) | No-Change (P) | No-Change (Seq) | Partial (P) | Partial (Seq) |');
    // ignore: avoid_print
    print('| ----- | ----------- | ------------- | ------------- | --------------- | ----------- | ------------- |');
    for (var r in results) {
      // ignore: avoid_print
      print(
        '| ${r.size.toString().padRight(5)} '
        '| ${'${r.initialScanParallel.inMilliseconds}ms'.padRight(11)} '
        '| ${'${r.initialScanSequential.inMilliseconds}ms'.padRight(13)} '
        '| ${'${r.noChangeSyncParallel.inMilliseconds}ms'.padRight(13)} '
        '| ${'${r.noChangeSyncSequential.inMilliseconds}ms'.padRight(15)} '
        '| ${'${r.partialSyncParallel.inMilliseconds}ms'.padRight(11)} '
        '| ${'${r.partialSyncSequential.inMilliseconds}ms'.padRight(13)} |'
      );
    }
    // ignore: avoid_print
    print('==========================================================================================\n');
  });
}
