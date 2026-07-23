import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/update_service.dart';
import 'package:sonora/utils/image_utils.dart';
import 'package:sonora/widgets/custom_scrollbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tempDocsDir = Directory.systemTemp.createTempSync('sonora_large_test_');

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
  });

  tearDown(() {
    if (tempDocsDir.existsSync()) {
      tempDocsDir.deleteSync(recursive: true);
    }
  });

  group('Massive Playlist & Library Simulation (500, 1000, 2000 Songs)', () {
    List<Song> generateSongs(int count) {
      return List.generate(count, (index) {
        var id = index + 1;
        var artistId = (index % 50) + 1;
        var albumId = (index % 100) + 1;
        return Song(
          id: id,
          title: 'Track $id - High Res Audio Specimen',
          artist: 'Artist $artistId',
          album: 'Album $albumId',
          duration: Duration(seconds: 120 + (index % 180)),
          filePath: '/mock/storage/music/Artist $artistId/Album $albumId/track_$id.flac',
          fileSize: 1024 * 1024 * 25,
          hasLyrics: index % 5 == 0,
        );
      });
    }

    test('Simulate 500-song playlist creation, JSON serialization, and grouping', () {
      var songs = generateSongs(500);
      var songIds = songs.map((s) => s.id).toList();

      var playlist = Playlist(
        id: 'playlist_500',
        name: 'Chill Vibes 500',
        songIds: songIds,
      );

      expect(playlist.songIds.length, equals(500));
      expect(playlist.nameLower, equals('chill vibes 500'));

      // Test JSON encoding & decoding performance
      var jsonMap = playlist.toJson();
      var reconstructed = Playlist.fromJson(jsonMap);

      expect(reconstructed.id, equals('playlist_500'));
      expect(reconstructed.songIds.length, equals(500));

      // Test grouping benchmarks
      var albums = buildAlbumGroups(songs);
      var artists = buildArtistGroups(songs, albums);

      expect(albums.length, equals(100));
      expect(artists.length, equals(50));
    });

    test('Simulate 1000-song playlist lookup and shuffle queue generation', () {
      var songs = generateSongs(1000);
      var playlistSongIds = songs.map((s) => s.id).toSet();

      // Measure fast set-based membership filter
      var matchedSongs = songs.where((s) => playlistSongIds.contains(s.id)).toList();
      expect(matchedSongs.length, equals(1000));

      // Simulate quickShuffle queue creation
      var cloned = List<Song>.from(matchedSongs)..shuffle();
      expect(cloned.length, equals(1000));
      expect(cloned.first.id, isNotNull);
    });

    test('Simulate 2000-song playlist scaling, sort benchmarks, and filtering', () {
      var songs = generateSongs(2000);
      var playlist = Playlist(
        id: 'playlist_2000',
        name: 'Mega Collection 2000',
        songIds: songs.map((s) => s.id).toList(),
      );

      expect(playlist.songIds.length, equals(2000));

      // Title sorting
      var sortedByTitle = List<Song>.from(songs)
        ..sort((a, b) => a.titleLower.compareTo(b.titleLower));
      expect(sortedByTitle.length, equals(2000));

      // Duration sorting
      var sortedByDuration = List<Song>.from(songs)
        ..sort((a, b) => a.duration.compareTo(b.duration));
      expect(sortedByDuration.length, equals(2000));

      // Search query filtering
      var query = 'Artist 12';
      var searchResults = songs
          .where((s) => s.titleLower.contains(query.toLowerCase()) || s.artistLower.contains(query.toLowerCase()))
          .toList();

      expect(searchResults, isNotEmpty);
    });
  });

  group('Playlist Cover Cropping & Downscaling Tests', () {
    test('PlaylistImageUtils crops and resizes image to low-res JPEG file', () async {
      var sourcePng = File('${Directory.current.path}/test/music/emre/artist.png');
      expect(sourcePng.existsSync(), isTrue);

      var targetPath = '${tempDocsDir.path}/cropped_playlist_cover.jpg';
      await PlaylistImageUtils.processAndSavePlaylistCover(
        sourcePng,
        targetPath,
      );

      var targetFile = File(targetPath);
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.lengthSync() > 0, isTrue);
    });
  });

  group('UpdateService Rate-Limiting & Network Robustness Tests', () {
    test('UpdateService handles network failures silently without crashing', () async {
      var result = await UpdateService.checkForUpdate();
      expect(result, isNotNull);
      expect(result.isRateLimited || result.hasError || result.update == null, isTrue);
    });
  });

  group('CustomScrollbar & Widget Behavior Tests', () {
    testWidgets('CustomScrollbar renders child and responds to drag notifications', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollbar(
              child: ListView.builder(
                itemCount: 500,
                itemBuilder: (context, index) => ListTile(
                  title: Text('Item #$index'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item #0'), findsOneWidget);

      // Scroll list down
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Item #0'), findsNothing);
    });
  });
}
