import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    hide GlobalMaterialLocalizations, RepeatMode;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/screens/playlist_detail_screen.dart';
import 'package:sonora/screens/queue_screen.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/animated_favorite_button.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/edit_playlist_description_dialog.dart';
import 'package:sonora/widgets/home/playlists_tab.dart';
import 'package:sonora/widgets/rename_playlist_dialog.dart';
import 'package:sonora/widgets/song_info_bottom_sheet.dart';
import 'package:sonora/widgets/speed_slider.dart';

Widget testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  group('ConfirmDeleteDialog Tests', () {
    testWidgets('Returns true when destructive action is confirmed', (tester) async {
      bool? result;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmDeleteDialog.show(
                    context,
                    title: 'Delete Playlist?',
                    message: 'This cannot be undone.',
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Playlist?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      // Tap delete (confirm button)
      var deleteButton = find.byType(FilledButton);
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('Returns null/false when cancel button is tapped', (tester) async {
      bool? result;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmDeleteDialog.show(
                    context,
                    title: 'Delete Song?',
                    message: 'Remove from device?',
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap cancel button
      var cancelButton = find.byType(TextButton);
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('RenamePlaylistDialog Tests', () {
    testWidgets('Loads initial playlist name and invokes onRename with new name', (tester) async {
      var playlist = Playlist(
        id: 'pl_123',
        name: 'Roadtrip 2026',
        songIds: [1, 2, 3],
      );

      String? renamedId;
      String? renamedTitle;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  RenamePlaylistDialog.show(
                    context,
                    playlist: playlist,
                    onRename: (id, newName) async {
                      renamedId = id;
                      renamedTitle = newName;
                    },
                  );
                },
                child: const Text('Rename'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Roadtrip 2026'), findsOneWidget);

      // Enter new name
      await tester.enterText(find.byType(TextField), 'Summer Vibes');
      await tester.pump();

      // Tap Save
      var saveButton = find.byType(FilledButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(renamedId, equals('pl_123'));
      expect(renamedTitle, equals('Summer Vibes'));
    });
  });

  group('EditPlaylistDescriptionDialog Tests', () {
    testWidgets('Loads current description and submits updated text', (tester) async {
      var playlist = Playlist(
        id: 'pl_desc',
        name: 'Chill Beats',
        songIds: [5],
        description: 'Old Description',
      );

      String? savedDescription;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  EditPlaylistDescriptionDialog.show(
                    context,
                    playlist: playlist,
                    onEdit: (newDesc) {
                      savedDescription = newDesc;
                    },
                  );
                },
                child: const Text('Edit Description'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Edit Description'));
      await tester.pumpAndSettle();

      expect(find.text('Old Description'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Relaxing lofi tracks for study');
      await tester.pump();

      var saveButton = find.byType(FilledButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedDescription, equals('Relaxing lofi tracks for study'));
    });
  });

  group('AnimatedFavoriteButton Tests', () {
    testWidgets('Renders favorite border icon and calls onToggle on tap', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        testApp(
          AnimatedFavoriteButton(
            isFavorite: false,
            onToggle: () => toggled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byType(AnimatedFavoriteButton));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('Renders filled favorite icon when isFavorite is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          AnimatedFavoriteButton(
            isFavorite: true,
            onToggle: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('SpeedSlider Widget Tests', () {
    testWidgets('Renders reset button and triggers onChanged when reset is tapped', (tester) async {
      double? changedSpeed;

      await tester.pumpWidget(
        testApp(
          SpeedSlider(
            speed: 1.5,
            onChanged: (val) => changedSpeed = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.speed_rounded));
      await tester.pump();

      expect(changedSpeed, equals(1.0));
    });
  });

  group('PlaylistsTab & PlaylistDetailScreen Tests', () {
    testWidgets('PlaylistsTab renders first song artwork as default cover when coverImagePath is null', (tester) async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );

      var songA = Song(
        id: 101,
        title: 'Song One',
        artist: 'Artist A',
        album: 'Album A',
        duration: const Duration(minutes: 3),
        filePath: '/music/song1.mp3',
        artworkPath: '/covers/song1.jpg',
      );

      var songB = Song(
        id: 102,
        title: 'Song Two',
        artist: 'Artist B',
        album: 'Album B',
        duration: const Duration(minutes: 4),
        filePath: '/music/song2.mp3',
      );

      var playlistWithSongs = Playlist(
        id: 'pl_1',
        name: 'My Roadtrip Mix',
        songIds: [101, 102],
      );

      playerProvider.updatePlaylists([playlistWithSongs]);

      await tester.pumpWidget(
        testApp(
          PlaylistsTab(
            allSongs: [songA, songB],
            filteredPlaylists: [playlistWithSongs],
            playerProvider: playerProvider,
            onUnfocusSearch: () {},
            onCreatePlaylistDialog: () {},
            onDeletePlaylist: (_) async {},
            onRenamePlaylist: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Roadtrip Mix'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
      // Verify AlbumArt resolved with songA's artworkPath
      var albumArt = tester.widget<AlbumArt>(find.byType(AlbumArt));
      expect(albumArt.artworkPath, equals('/covers/song1.jpg'));
    });

    testWidgets('PlaylistDetailScreen shows drag handle and enables track reordering', (tester) async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );

      var song1 = Song(
        id: 1,
        title: 'First Track',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: const Duration(minutes: 3),
        filePath: '/music/1.mp3',
      );
      var song2 = Song(
        id: 2,
        title: 'Second Track',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: const Duration(minutes: 4),
        filePath: '/music/2.mp3',
      );

      var playlist = Playlist(
        id: 'pl_reorder',
        name: 'Reorder Test',
        songIds: [1, 2],
      );

      playerProvider.updatePlaylists([playlist]);

      await tester.pumpWidget(
        testApp(
          PlaylistDetailScreen(
            playlist: playlist,
            songs: [song1, song2],
            playerProvider: playerProvider,
            onRemoveSong: (_, _) async {},
            onReorderSongs: (_, _) async {},
            playlists: [playlist],
            onAddSongToPlaylist: (_, _) async {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Reorder Test'), findsOneWidget);
      expect(find.text('First Track'), findsOneWidget);
      expect(find.text('Second Track'), findsOneWidget);

      // Verify drag handle icons exist for each track
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    });
  });

  group('SongInfoBottomSheet Tests', () {
    testWidgets('renders metadata and provides copy and share actions', (
      tester,
    ) async {
      var song = Song(
        id: 42,
        title: 'Masterpiece',
        artist: 'The Sonora Band',
        album: 'Acoustic Sessions',
        duration: const Duration(minutes: 3, seconds: 45),
        filePath: '/music/test/masterpiece.mp3',
        format: 'mp3',
        bitrate: 320,
        samplerate: 44100,
      );

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showSongInfoBottomSheet(context, song),
                child: const Text('Open Info'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Info'));
      await tester.pumpAndSettle();

      expect(find.text('Masterpiece'), findsOneWidget);
      expect(find.text('The Sonora Band'), findsOneWidget);
      expect(find.text('Acoustic Sessions'), findsOneWidget);

      await tester.scrollUntilVisible(find.byType(SelectableText), 100);
      expect(find.byType(SelectableText), findsOneWidget);

      // Verify Copy Path action exists
      expect(find.byIcon(Icons.copy_rounded), findsWidgets);
      expect(find.text('Copy Path'), findsOneWidget);

      // Tap metadata row to trigger copy
      await tester.tap(find.text('Masterpiece'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('QueueScreen & Playback Ergonomics Tests', () {
    testWidgets('renders queue and scroll to current track button', (
      tester,
    ) async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );

      var songs = List.generate(
        10,
        (i) => Song(
          id: i + 1,
          title: 'Track ${i + 1}',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
          filePath: '/music/track_${i + 1}.mp3',
        ),
      );
      playerProvider.updateSongs(songs);
      playerProvider.queue = List.from(songs);
      playerProvider.currentIndex = 0;

      await tester.pumpWidget(
        testApp(
          QueueScreen(playerProvider: playerProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.my_location_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      playerProvider.dispose();
    });

    test('Playback toggles cycle with haptic triggers', () async {
      var audioHandler = SonoraAudioHandler();
      var settingsProvider = SettingsProvider();
      var playerProvider = PlayerProvider(
        audioHandler: audioHandler,
        settingsProvider: settingsProvider,
      );

      await playerProvider.cycleRepeatMode();
      expect(playerProvider.repeatMode, equals(RepeatMode.all));

      await playerProvider.cycleRepeatMode();
      expect(playerProvider.repeatMode, equals(RepeatMode.one));

      await playerProvider.cycleRepeatMode();
      expect(playerProvider.repeatMode, equals(RepeatMode.off));

      playerProvider.dispose();
    });
  });
}
