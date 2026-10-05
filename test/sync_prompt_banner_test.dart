import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide GlobalMaterialLocalizations;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/screens/home_screen.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/widgets/home/songs_tab.dart';

Widget testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SonoraAudioHandler audioHandler;
  late SettingsProvider settingsProvider;
  late PlayerProvider playerProvider;

  var sampleSong = Song(
    id: 1,
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: const Duration(minutes: 3),
    filePath: '/music/test.mp3',
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    audioHandler = SonoraAudioHandler();
    settingsProvider = SettingsProvider();
    playerProvider = PlayerProvider(
      audioHandler: audioHandler,
      settingsProvider: settingsProvider,
    );
    playerProvider.updateSongs([sampleSong]);
  });

  group('SongsTab syncPromptBanner Tests', () {
    testWidgets('Renders syncPromptBanner when showSyncPrompt is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SongsTab(
              allSongs: [sampleSong],
              filteredSongs: [sampleSong],
              playerProvider: playerProvider,
              scanFolder: '/music',
              showSyncPrompt: true,
              onConfigureFolder: () {},
              onUnfocusSearch: () {},
              syncPromptBanner: const Text('SYNC_PROMPT_BANNER_CONTENT'),
              activityView: SongActivityView.all,
            ),
          ),
        ),
      );

      expect(find.text('SYNC_PROMPT_BANNER_CONTENT'), findsOneWidget);
    });

    testWidgets('Hides syncPromptBanner when showSyncPrompt is false', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SongsTab(
              allSongs: [sampleSong],
              filteredSongs: [sampleSong],
              playerProvider: playerProvider,
              scanFolder: '/music',
              showSyncPrompt: false,
              onConfigureFolder: () {},
              onUnfocusSearch: () {},
              syncPromptBanner: const Text('SYNC_PROMPT_BANNER_CONTENT'),
              activityView: SongActivityView.all,
            ),
          ),
        ),
      );

      expect(find.text('SYNC_PROMPT_BANNER_CONTENT'), findsNothing);
    });
  });

  group('HomeScreen Sync Reminder Banner Action Tests', () {
    testWidgets('Tapping Remind Next Month dismisses banner and calls onPostponeSync', (tester) async {
      var postponeCalled = false;

      await tester.pumpWidget(
        testApp(
          HomeScreen(
            playerProvider: playerProvider,
            songs: [sampleSong],
            onOpenSettings: () {},
            scanFolder: '/music',
            onConfigureFolder: () {},
            onCreatePlaylist: (_) async {},
            onDeletePlaylist: (_) async {},
            onRenamePlaylist: (_, _) async {},
            onAddSongToPlaylist: (_, _) async {},
            onRemoveSongFromPlaylist: (_, _) async {},
            onReorderPlaylistSongs: (_, _) async {},
            isSyncing: false,
            showSyncPrompt: true,
            onResyncNow: () async {},
            onPostponeSync: () async {
              postponeCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remind Next Month'), findsOneWidget);

      await tester.tap(find.text('Remind Next Month'));
      await tester.pumpAndSettle();

      expect(postponeCalled, isTrue);
      expect(find.text('Remind Next Month'), findsNothing);
    });

    testWidgets('Tapping Sync Now dismisses banner, shows progress indicator, and calls onResyncNow', (tester) async {
      var syncCompleter = Completer<void>();
      var resyncCalled = false;

      await tester.pumpWidget(
        testApp(
          HomeScreen(
            playerProvider: playerProvider,
            songs: [sampleSong],
            onOpenSettings: () {},
            scanFolder: '/music',
            onConfigureFolder: () {},
            onCreatePlaylist: (_) async {},
            onDeletePlaylist: (_) async {},
            onRenamePlaylist: (_, _) async {},
            onAddSongToPlaylist: (_, _) async {},
            onRemoveSongFromPlaylist: (_, _) async {},
            onReorderPlaylistSongs: (_, _) async {},
            isSyncing: false,
            showSyncPrompt: true,
            onResyncNow: () async {
              resyncCalled = true;
              await syncCompleter.future;
            },
            onPostponeSync: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.tap(find.text('Sync Now'));
      await tester.pump();

      expect(resyncCalled, isTrue);
      // Banner should be immediately dismissed
      expect(find.text('Sync Now'), findsNothing);
      // Progress indicator should be visible while syncing
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Complete the sync
      syncCompleter.complete();
      await tester.pumpAndSettle();

      // Progress indicator should be gone after sync completion
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
