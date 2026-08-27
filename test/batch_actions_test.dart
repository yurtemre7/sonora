import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/widgets/multi_select_action_bar.dart';
import 'package:sonora/widgets/song_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;

  setUp(() {
    tempDocsDir = Directory.systemTemp.createTempSync('sonora_batch_test_');
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

  tearDown(() {
    if (tempDocsDir.existsSync()) {
      tempDocsDir.deleteSync(recursive: true);
    }
  });

  group('MusicScanner Batch Operations', () {
    test('addSongsToPlaylist and removeSongsFromPlaylist', () async {
      var scanner = MusicScanner();
      await scanner.createPlaylist('Party');
      var playlists = await scanner.getPlaylists();
      expect(playlists.length, 1);
      var playlistId = playlists.first.id;

      // Add batch songs
      await scanner.addSongsToPlaylist(playlistId, [101, 102, 103]);
      playlists = await scanner.getPlaylists();
      expect(playlists.first.songIds, [101, 102, 103]);

      // Adding existing ignores duplicates
      await scanner.addSongsToPlaylist(playlistId, [102, 104]);
      playlists = await scanner.getPlaylists();
      expect(playlists.first.songIds, [101, 102, 103, 104]);

      // Remove batch songs
      await scanner.removeSongsFromPlaylist(playlistId, [101, 103]);
      playlists = await scanner.getPlaylists();
      expect(playlists.first.songIds, [102, 104]);
    });
  });

  group('SongTile Multi-Select Rendering', () {
    var song = Song(
      id: 1,
      title: 'Midnight Echoes',
      artist: 'Aurora',
      album: 'Nocturne',
      duration: const Duration(minutes: 3, seconds: 45),
      filePath: '/mock/midnight_echoes.mp3',
    );

    testWidgets('renders selection indicators and handles onSelect', (
      tester,
    ) async {
      var selectTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongTile(
              song: song,
              isSelecting: true,
              isSelected: true,
              onTap: () {},
              onSelect: () {
                selectTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.byType(SongTile));
      await tester.pump();
      expect(selectTapped, isTrue);
    });

    testWidgets('renders unselected checkbox state when isSelected is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongTile(
              song: song,
              isSelecting: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
    });
  });

  group('MusicScanner setFavoriteSongs Batch API', () {
    test('bulk favorites and unfavorites songs', () async {
      var scanner = MusicScanner();
      var testSongsJson = [
        {
          'id': 1,
          'title': 'Song 1',
          'artist': 'Artist',
          'album': 'Album',
          'duration_ms': 180000,
          'file_path': '/mock/1.mp3',
          'is_favorite': false,
        },
        {
          'id': 2,
          'title': 'Song 2',
          'artist': 'Artist',
          'album': 'Album',
          'duration_ms': 180000,
          'file_path': '/mock/2.mp3',
          'is_favorite': false,
        },
        {
          'id': 3,
          'title': 'Song 3',
          'artist': 'Artist',
          'album': 'Album',
          'duration_ms': 180000,
          'file_path': '/mock/3.mp3',
          'is_favorite': false,
        },
      ];

      var jsonFile = File('${tempDocsDir.path}/imported_songs.json');
      await jsonFile.writeAsString(jsonEncode(testSongsJson));

      var updated = await scanner.setFavoriteSongs([1, 2, 3], true);
      expect(updated.every((s) => s.isFavorite), isTrue);

      updated = await scanner.setFavoriteSongs([1, 3], false);
      expect(updated.firstWhere((s) => s.id == 1).isFavorite, isFalse);
      expect(updated.firstWhere((s) => s.id == 2).isFavorite, isTrue);
      expect(updated.firstWhere((s) => s.id == 3).isFavorite, isFalse);
    });
  });

  group('MultiSelectActionBar Widget Tests', () {
    var songs = [
      Song(
        id: 1,
        title: 'Song 1',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(minutes: 3),
        filePath: '/mock/1.mp3',
      ),
      Song(
        id: 2,
        title: 'Song 2',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(minutes: 4),
        filePath: '/mock/2.mp3',
      ),
    ];

    testWidgets('renders count, select all, deselect all, and action buttons', (
      tester,
    ) async {
      var cleared = false;
      var selectedAll = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiSelectActionBar(
              selectedSongs: [songs[0]],
              allAvailableSongs: songs,
              onClearSelection: () => cleared = true,
              onSelectAll: () => selectedAll = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check count indicator (1 song selected)
      expect(find.text('1 selected'), findsOneWidget);

      // Tap select all (when not all are selected)
      var selectAllBtn = find.byIcon(Icons.select_all_rounded);
      expect(selectAllBtn, findsOneWidget);
      await tester.tap(selectAllBtn);
      expect(selectedAll, isTrue);

      // Tap clear/close selection button
      var closeBtn = find.byIcon(Icons.close_rounded);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      expect(cleared, isTrue);

      // Verify action buttons exist
      expect(find.byIcon(Icons.playlist_play_rounded), findsOneWidget); // Play Next
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget); // Add to Queue
      expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget); // Add to Playlist
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget); // Favorite
      expect(find.byIcon(Icons.share_rounded), findsOneWidget); // Share
    });
  });
}
