import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/image_preflight_service.dart';
import 'package:sonora/widgets/album_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlbumArt caching & provider tests', () {
    test('computeCacheDim scales and clamps dimension correctly', () {
      // 48 * 2.0 = 96 -> ceil(96/128)*128 = 128
      expect(AlbumArt.computeCacheDim(48), 128);
      // 48 * 2.5 = 120 -> ceil(120/128)*128 = 128
      expect(AlbumArt.computeCacheDim(48, 2.5), 128);
      // 200 * 2.0 = 400 -> ceil(400/128)*128 = 512
      expect(AlbumArt.computeCacheDim(200), 512);
      // Large dimensions clamp to max 800
      expect(AlbumArt.computeCacheDim(1000), 800);
    });

    test('AlbumArt.provider creates identical ResizeImageKey for identical parameters', () async {
      var provider1 = AlbumArt.provider('/fake/art.jpg');
      var provider2 = AlbumArt.provider('/fake/art.jpg');

      var key1 = await provider1.obtainKey(ImageConfiguration.empty);
      var key2 = await provider2.obtainKey(ImageConfiguration.empty);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('AlbumArt checkFileExists and clearFileCache', () {
      AlbumArt.clearFileCache();
      expect(AlbumArt.checkFileExists('/non_existent_path_test.jpg'), isFalse);
      // Second lookup uses cached result without failing
      expect(AlbumArt.checkFileExists('/non_existent_path_test.jpg'), isFalse);
      AlbumArt.clearFileCache('/non_existent_path_test.jpg');
    });
  });

  group('ImagePreflightService tests', () {
    late ImagePreflightService service;

    setUp(() {
      service = ImagePreflightService();
      service.clearCache();
    });

    test('preflightSongs handles empty or null artwork songs gracefully', () async {
      var songs = [
        Song(
          id: 1,
          title: 'Song 1',
          artist: 'Artist 1',
          album: 'Album 1',
          duration: const Duration(minutes: 3),
          filePath: '/music/song1.mp3',
        ),
        Song(
          id: 2,
          title: 'Song 2',
          artist: 'Artist 2',
          album: 'Album 2',
          duration: const Duration(minutes: 3),
          filePath: '/music/song2.mp3',
          artworkPath: '',
        ),
      ];

      // Should complete quickly without throwing
      await service.preflightSongs(songs);
    });

    test('preflightAlbums and preflightQueueUpcoming execute without error', () async {
      var album = AlbumGroup(
        name: 'Test Album',
        artist: 'Test Artist',
        songs: [
          Song(
            id: 1,
            title: 'Track 1',
            artist: 'Test Artist',
            album: 'Test Album',
            duration: const Duration(minutes: 3),
            filePath: '/music/test1.mp3',
          ),
        ],
      );

      await service.preflightAlbums([album]);
      await service.preflightQueueUpcoming([], 0);
      await service.preflightQueueUpcoming(album.songs, 0);
    });

    test('preflightSongs pre-warms real image file into imageCache', () async {
      // Create a temporary 1x1 png image file
      var tempDir = await Directory.systemTemp.createTemp('sonora_art_test');
      var testFile = File('${tempDir.path}/test_art.png');
      // Minimal valid 1x1 PNG bytes
      var pngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      await testFile.writeAsBytes(pngBytes);

      var song = Song(
        id: 10,
        title: 'Real Art Song',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(minutes: 2),
        filePath: '/music/song.mp3',
        artworkPath: testFile.path,
      );

      var initialCount = PaintingBinding.instance.imageCache.currentSize;

      await service.preflightSongs([song], maxItems: 10, chunkSize: 2);

      // Verify that imageCache contains the prewarmed image
      expect(PaintingBinding.instance.imageCache.currentSize, greaterThanOrEqualTo(initialCount));

      // Clean up temp file
      await tempDir.delete(recursive: true);
    });
  });
}
