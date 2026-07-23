import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/widgets/artist_avatar.dart';
import 'package:sonora/widgets/song_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var tempDocsDir = Directory.systemTemp.createTempSync('sonora_test_docs_');

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

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

  var musicDir = Directory('${Directory.current.path}/test/music');
  var artistDir = Directory('${musicDir.path}/emre');
  var audioDir = Directory('${artistDir.path}/audio');
  var audioMp3 = File('${audioDir.path}/audio.mp3');
  var audioCoverMp3 = File('${audioDir.path}/audio_cover.mp3');
  var artistPng = File('${artistDir.path}/artist.png');

  group('MusicScanner & Metadata Extraction Tests (test/music target)', () {
    test('Directory structure exists for scanner tests', () {
      expect(
        musicDir.existsSync(),
        isTrue,
        reason: 'test/music directory should exist',
      );
      expect(
        artistDir.existsSync(),
        isTrue,
        reason: 'emre artist folder should exist',
      );
      expect(
        audioDir.existsSync(),
        isTrue,
        reason: 'emre/audio folder should exist',
      );
      expect(audioMp3.existsSync(), isTrue, reason: 'audio.mp3 should exist');
      expect(
        audioCoverMp3.existsSync(),
        isTrue,
        reason: 'audio_cover.mp3 should exist',
      );
      expect(artistPng.existsSync(), isTrue, reason: 'artist.png should exist');
    });

    test(
      'MusicScanner importFromFolder scans audio files and extracts metadata correctly',
      () async {
        var scanner = MusicScanner();
        var songs = await scanner.importFromFolder(musicDir.path);

        expect(
          songs,
          isNotEmpty,
          reason: 'Scanner should discover audio files in test/music',
        );
        expect(songs.length, equals(2));

        var songPlain = songs.firstWhere((s) => s.filePath == audioMp3.path);
        var songWithCover = songs.firstWhere(
          (s) => s.filePath == audioCoverMp3.path,
        );

        // Verify metadata parsing for audio files
        expect(songPlain.title, isNotEmpty);
        expect(songPlain.artist, isNotNull);
        expect(songPlain.album, isNotNull);
        expect(songPlain.fileSize, equals(audioMp3.statSync().size));

        expect(songWithCover.title, isNotEmpty);
        expect(songWithCover.filePath, equals(audioCoverMp3.path));

        // Verify local artist image extraction mapping (artist.png in emre directory)
        var artistImages = scanner.localArtistImages;
        expect(
          artistImages.keys.any(
            (k) =>
                k.contains('emre') ||
                k.contains(songPlain.artist.toLowerCase()),
          ),
          isTrue,
          reason: 'Artist emre image should be detected',
        );
        var artistImagePath =
            artistImages['emre'] ??
            artistImages[songPlain.artist.toLowerCase()] ??
            artistImages.values.firstWhere((v) => v.contains('artist.png'));
        expect(artistImagePath, equals(artistPng.path));
      },
    );

    test(
      'Grouping functions construct AlbumGroup and ArtistGroup with extracted songs',
      () async {
        var scanner = MusicScanner();
        var songs = await scanner.importFromFolder(musicDir.path);
        var albums = buildAlbumGroups(songs);
        var artists = buildArtistGroups(
          songs,
          albums,
          scanner.localArtistImages,
        );

        expect(albums, isNotEmpty);
        expect(artists, isNotEmpty);

        var emreArtist = artists.firstWhere(
          (a) =>
              a.name.toLowerCase().contains('emre') ||
              a.name == songs.first.artist,
        );
        expect(
          emreArtist.localImagePath,
          equals(artistPng.path),
          reason: 'ArtistGroup should map artist.png from artist directory',
        );
        expect(emreArtist.songs.length, equals(2));
      },
    );
  });

  group('Widget Tests using Scanned Music Data', () {
    testWidgets('SongTile renders title, artist, and trailing menu', (
      WidgetTester tester,
    ) async {
      var sampleSong = Song(
        id: 1,
        title: 'Test Track',
        artist: 'Emre',
        album: 'Test Album',
        duration: const Duration(minutes: 3, seconds: 20),
        filePath: audioCoverMp3.path,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongTile(song: sampleSong, onTap: () {}),
          ),
        ),
      );

      expect(find.text('Test Track'), findsOneWidget);
      expect(find.textContaining('Emre'), findsOneWidget);
      expect(find.text('3:20'), findsOneWidget);
    });

    testWidgets(
      'ArtistAvatar renders real scanned artist cover image when localImagePath is detected',
      (WidgetTester tester) async {
        var emreArtist = ArtistGroup(
          name: 'emre',
          songs: [],
          albums: [],
          localImagePath: artistPng.path,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ArtistAvatar(artist: emreArtist, radius: 40)),
          ),
        );

        // Verify ArtistAvatar renders CircleAvatar with FileImage using localImagePath
        var avatarFinder = find.byType(CircleAvatar);
        expect(avatarFinder, findsOneWidget);

        CircleAvatar avatarWidget = tester.widget(avatarFinder);
        expect(avatarWidget.backgroundImage, isA<ResizeImage>());
        var resizeImage = avatarWidget.backgroundImage as ResizeImage;
        expect(resizeImage.imageProvider, isA<FileImage>());
        var fileImage = resizeImage.imageProvider as FileImage;
        expect(fileImage.file.path, equals(artistPng.path));
      },
    );

    testWidgets(
      'ArtistAvatar falls back cleanly when no local cover image exists',
      (WidgetTester tester) async {
        var fallbackArtist = ArtistGroup(
          name: 'Unknown Artist',
          songs: [],
          albums: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ArtistAvatar(artist: fallbackArtist, radius: 30),
            ),
          ),
        );

        expect(find.byType(ArtistAvatar), findsOneWidget);
        expect(
          find.byIcon(Icons.person_rounded),
          findsOneWidget,
          reason:
              'Fallback icon should render when no cover image is available',
        );
      },
    );
  });
}
