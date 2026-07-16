import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/services/music_scanner.dart';

class _BenchmarkResult {
  final int size;
  final Duration initialScan;
  final Duration noChangeSync;
  final Duration partialSync;

  _BenchmarkResult({
    required this.size,
    required this.initialScan,
    required this.noChangeSync,
    required this.partialSync,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;
  late Directory tempScanDir;

  setUpAll(() {
    // Create temporary directories once for all tests
    tempDocsDir = Directory.systemTemp.createTempSync('sonora_docs');
    tempScanDir = Directory.systemTemp.createTempSync('sonora_scan');

    // Mock PathProvider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDocsDir.path;
        }
        return null;
      },
    );

    // Mock SharedPreferencesAsync platform instance once
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      'scan_folder_path': tempScanDir.path,
    });
  });

  tearDownAll(() {
    // Clean up temporary directories once at the end
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
    var dummyBytes = Uint8List(100 * 1024); // 100 KB
    // Generate subdirectories to simulate artist/album structure
    for (var i = 0; i < count; i++) {
      var artistId = i ~/ 10;
      var albumId = i ~/ 5;
      var artistDir = Directory('${root.path}/Artist_$artistId/Album_$albumId');
      if (!artistDir.existsSync()) {
        artistDir.createSync(recursive: true);
      }
      var songFile = File('${artistDir.path}/song_$i.mp3');
      songFile.writeAsBytesSync(dummyBytes);
    }
  }

  test('Discovery & Sync Benchmark Runner', () async {
    const testSizes = [50, 250, 500, 1000, 5000];
    final results = <_BenchmarkResult>[];

    var scanner = MusicScanner();

    for (var n in testSizes) {
      // Clean directories before generating new size to avoid interference
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

      // Generate synthetic files
      generateSyntheticFiles(tempScanDir, n);

      // --- SCENARIO A: Initial Scan (Empty Cache) ---
      var sw = Stopwatch()..start();
      var initialSongs = await scanner.syncLibrary();
      sw.stop();
      var initialTime = sw.elapsed;
      expect(initialSongs.length, equals(n));

      // --- SCENARIO B: No-Change Sync (All Cached) ---
      sw = Stopwatch()..reset()..start();
      var cachedSongs = await scanner.syncLibrary();
      sw.stop();
      var cachedTime = sw.elapsed;
      expect(cachedSongs.length, equals(n));

      // --- SCENARIO C: Partial Update (10 songs modified) ---
      var allFiles = tempScanDir.listSync(recursive: true).whereType<File>().toList();
      var numToModify = allFiles.length > 10 ? 10 : allFiles.length;
      for (var i = 0; i < numToModify; i++) {
        var file = allFiles[i];
        file.writeAsStringSync('modified content');
      }

      sw = Stopwatch()..reset()..start();
      var partialSongs = await scanner.syncLibrary();
      sw.stop();
      var partialTime = sw.elapsed;
      expect(partialSongs.length, equals(n));

      results.add(_BenchmarkResult(
        size: n,
        initialScan: initialTime,
        noChangeSync: cachedTime,
        partialSync: partialTime,
      ));
    }

    // Print consolidated summary table at the end of the parent run
    // ignore: avoid_print
    print('\n========================================================================');
    // ignore: avoid_print
    print('                      DISCOVERY BENCHMARK RESULTS                       ');
    // ignore: avoid_print
    print('========================================================================');
    // ignore: avoid_print
    print('| Library Size | Initial Scan | No-Change Sync | Partial Sync (10 mod) |');
    // ignore: avoid_print
    print('| ------------ | ------------ | -------------- | --------------------- |');
    for (var r in results) {
      // ignore: avoid_print
      print(
        '| ${r.size.toString().padRight(12)} '
        '| ${'${r.initialScan.inMilliseconds}ms'.padRight(12)} '
        '| ${'${r.noChangeSync.inMilliseconds}ms'.padRight(14)} '
        '| ${'${r.partialSync.inMilliseconds}ms'.padRight(21)} |'
      );
    }
    // ignore: avoid_print
    print('========================================================================\n');
  });
}
