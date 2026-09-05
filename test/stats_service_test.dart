import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';
import 'package:sonora/services/stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsService stats;

  var sampleSongs = [
    Song(
      id: 1,
      title: 'Lose Yourself',
      artist: 'Eminem',
      album: '8 Mile',
      duration: const Duration(seconds: 300),
      filePath: '/music/eminem_8mile.mp3',
      artworkPath: '/music/8mile.jpg',
    ),
    Song(
      id: 2,
      title: 'Love The Way You Lie (feat. Rihanna)',
      artist: 'Eminem feat. Rihanna',
      album: 'Recovery',
      duration: const Duration(seconds: 240),
      filePath: '/music/eminem_recovery.mp3',
      artworkPath: '/music/recovery.jpg',
    ),
    Song(
      id: 3,
      title: 'Diamonds',
      artist: 'Rihanna',
      album: 'Unapologetic',
      duration: const Duration(seconds: 200),
      filePath: '/music/rihanna_diamonds.mp3',
      artworkPath: '/music/unapologetic.jpg',
    ),
  ];

  setUp(() async {
    stats = StatsService();
    await stats.reset();
  });

  group('StatsService Tests', () {
    test(
      'recent-play qualification threshold is bounded for short and long songs',
      () {
        expect(
          qualifyingRecentPlayThreshold(const Duration(seconds: 5)),
          const Duration(seconds: 5),
        );
        expect(
          qualifyingRecentPlayThreshold(const Duration(seconds: 20)),
          const Duration(seconds: 10),
        );
        expect(
          qualifyingRecentPlayThreshold(const Duration(minutes: 5)),
          const Duration(seconds: 30),
        );
      },
    );

    test('addListeningTime accumulates and records full play upon reaching duration', () {
      expect(stats.completeSongListens, 0);
      expect(stats.totalListeningTimeMs, 0);

      // Add 200 seconds of listening to song 2 (duration is 240s)
      stats.addListeningTime(200000, 2, 240000);
      expect(stats.totalListeningTimeMs, 200000);
      expect(stats.completeSongListens, 0);
      expect(stats.songCumulativeListenMs(2), 200000);

      // Add 50 more seconds -> total 250s >= 240s -> 1 complete listen, 10s carryover
      stats.addListeningTime(50000, 2, 240000);
      expect(stats.completeSongListens, 1);
      expect(stats.songCumulativeListenMs(2), 10000);

      var topSongs = stats.topSongs(5, sampleSongs);
      expect(topSongs.length, 1);
      expect(topSongs.first.song.id, 2);
      expect(topSongs.first.count, 1);
    });

    test('topSongs filters against active library without wiping persistent counts', () {
      stats.addListeningTime(300000, 1, 300000);
      stats.recordSongSkip(1);
      stats.recordSongRestart(1);

      expect(stats.topSongs(5, sampleSongs).length, 1);
      expect(stats.songSkipCount(1), 1);
      expect(stats.songRestartCount(1), 1);

      // Querying with empty or partial library filters gracefully
      expect(stats.topSongs(5, []).length, 0);

      // Querying with active library restores top songs
      expect(stats.topSongs(5, sampleSongs).length, 1);
      expect(stats.songSkipCount(1), 1);
      expect(stats.songRestartCount(1), 1);
    });

    test('topAlbums resolves correct artworkPath and binds AlbumGroup', () {
      // 2 plays for song 2 (Recovery)
      stats.addListeningTime(240000 * 2, 2, 240000);
      // 1 play for song 1 (8 Mile)
      stats.addListeningTime(300000, 1, 300000);

      var topAlbums = stats.topAlbums(5, sampleSongs);
      expect(topAlbums.length, 2);
      expect(topAlbums[0].album, 'Recovery');
      expect(topAlbums[0].count, 2);
      expect(topAlbums[0].group.name, 'Recovery');

      expect(topAlbums[1].album, '8 Mile');
      expect(topAlbums[1].count, 1);
    });

    test('topArtists parses individual artists from featured artist strings and binds ArtistGroup', () {
      // Song 2 has artist "Eminem feat. Rihanna" -> counts towards both Eminem and Rihanna
      stats.addListeningTime(240000, 2, 240000);
      // Song 3 has artist "Rihanna"
      stats.addListeningTime(200000, 3, 200000);

      var topArtists = stats.topArtists(5, sampleSongs);
      expect(topArtists.length, 2);

      // Rihanna has 2 plays total (1 from collab + 1 solo), Eminem has 1 play
      expect(topArtists[0].artist, 'Rihanna');
      expect(topArtists[0].count, 2);
      expect(topArtists[0].group.nameLower, 'rihanna');

      expect(topArtists[1].artist, 'Eminem');
      expect(topArtists[1].count, 1);
      expect(topArtists[1].group.nameLower, 'eminem');
    });

    test('topPlaylists ranks playlists with correct play count and song association', () {
      var playlists = [
        Playlist(id: 'pl_1', name: 'Workout Mix', songIds: [1, 2]),
        Playlist(id: 'pl_2', name: 'Chill Vibes', songIds: [3]),
      ];

      // Play song 1 inside pl_1
      stats.addListeningTime(300000, 1, 300000, playlistId: 'pl_1');
      stats.addListeningTime(300000, 1, 300000, playlistId: 'pl_1');

      // Play song 3 inside pl_2
      stats.addListeningTime(200000, 3, 200000, playlistId: 'pl_2');

      var top = stats.topPlaylists(5, playlists);
      expect(top.length, 2);
      expect(top[0].playlist.id, 'pl_1');
      expect(top[0].count, 2);
      expect(top[1].playlist.id, 'pl_2');
      expect(top[1].count, 1);
    });

    test(
      'albumListenCount and artistListenCount compute unique counts accurately',
      () {
        stats.addListeningTime(300000, 1, 300000);
        stats.addListeningTime(240000, 2, 240000);
        stats.addListeningTime(200000, 3, 200000);

        expect(stats.albumListenCount(sampleSongs), 3);
        expect(stats.artistListenCount(sampleSongs), 2); // Eminem and Rihanna
      },
    );

    test('recentSongs returns unique active songs in latest-first order', () {
      stats.recordSongPlayed(1, at: DateTime(2025, 1, 1, 12));
      stats.recordSongPlayed(2, at: DateTime(2025, 1, 2, 12));
      stats.recordSongPlayed(1, at: DateTime(2025, 1, 3, 12));
      stats.recordSongPlayed(99, at: DateTime(2025, 1, 4, 12));

      var recent = stats.recentSongs(sampleSongs);

      expect(recent.map((entry) => entry.song.id), [1, 2]);
      expect(recent.first.lastPlayedAt, DateTime(2025, 1, 3, 12));
      expect(stats.songLastPlayedAt(99), DateTime(2025, 1, 4, 12));
    });

    test('recent activity excludes songs without a qualifying play', () {
      stats.recordSongPlayed(2, at: DateTime(2025, 1, 2));

      var songs = stats.applyActivityView(
        sampleSongs,
        SongActivityView.recentlyPlayed,
      );

      expect(songs.map((song) => song.id), [2]);
    });

    test('most played orders by completed listens descending', () {
      stats.addListeningTime(300000, 1, 300000);
      stats.addListeningTime(240000 * 3, 2, 240000);

      var songs = stats.applyActivityView(
        sampleSongs,
        SongActivityView.mostPlayed,
      );

      expect(songs.map((song) => song.id), [2, 1, 3]);
      expect(stats.songPlayCount(2), 3);
    });

    test('least played puts never-played songs first', () {
      stats.addListeningTime(300000 * 2, 1, 300000);
      stats.addListeningTime(240000, 2, 240000);

      var songs = stats.applyActivityView(
        sampleSongs,
        SongActivityView.leastPlayed,
      );

      expect(songs.map((song) => song.id), [3, 2, 1]);
    });

    test('activity ordering uses deterministic title and ID tie breakers', () {
      var tiedSongs = [
        Song(
          id: 2,
          title: 'Same',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 1),
          filePath: '/music/2.mp3',
        ),
        Song(
          id: 1,
          title: 'Same',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 1),
          filePath: '/music/1.mp3',
        ),
      ];

      var songs = stats.applyActivityView(
        tiedSongs,
        SongActivityView.leastPlayed,
      );

      expect(songs.map((song) => song.id), [1, 2]);
    });

    test('reset clears recently played timestamps', () async {
      stats.recordSongPlayed(1, at: DateTime(2025));

      await stats.reset();

      expect(stats.songLastPlayedAt(1), isNull);
      expect(stats.recentSongs(sampleSongs), isEmpty);
    });

    testWidgets(
      'formatRelativePlayDate handles today, future skew, yesterday, this week, and DST transitions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                var now = DateTime(2025, 6, 15, 14, 30);
                // Same day
                expect(
                  formatRelativePlayDate(
                    context,
                    DateTime(2025, 6, 15, 9),
                    now: now,
                  ),
                  'Today',
                );
                // Clock skew / slightly in future
                expect(
                  formatRelativePlayDate(
                    context,
                    DateTime(2025, 6, 15, 15),
                    now: now,
                  ),
                  'Today',
                );
                // Yesterday
                expect(
                  formatRelativePlayDate(
                    context,
                    DateTime(2025, 6, 14, 20),
                    now: now,
                  ),
                  'Yesterday',
                );
                // 3 days ago (This Week)
                expect(
                  formatRelativePlayDate(
                    context,
                    DateTime(2025, 6, 12, 10),
                    now: now,
                  ),
                  'This Week',
                );
                // 30 days ago (Month Year)
                expect(
                  formatRelativePlayDate(
                    context,
                    DateTime(2025, 5, 1, 10),
                    now: now,
                  ),
                  'May 2025',
                );

                // DST edge case: 23 hours apart across spring forward transition
                var springNow = DateTime(2025, 3, 31, 1);
                var springPlayed = DateTime(2025, 3, 30, 2);
                expect(
                  formatRelativePlayDate(context, springPlayed, now: springNow),
                  'Yesterday',
                );

                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
    );
  });
}
