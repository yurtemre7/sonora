import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/utils/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('formatTotalDuration Tests', () {
    test('Formats empty songs list as 0m 0s', () {
      expect(formatTotalDuration([]), equals('0m 0s'));
    });

    test('Formats duration with only seconds and minutes', () {
      var songs = [
        Song(
          id: 1,
          title: 'Song 1',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3, seconds: 25),
          filePath: '/mock/1.mp3',
        ),
        Song(
          id: 2,
          title: 'Song 2',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 2, seconds: 15),
          filePath: '/mock/2.mp3',
        ),
      ];

      expect(formatTotalDuration(songs), equals('5m 40s'));
    });

    test('Formats duration with hours, minutes, and seconds', () {
      var songs = [
        Song(
          id: 1,
          title: 'Long Track 1',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(hours: 1, minutes: 15, seconds: 30),
          filePath: '/mock/1.mp3',
        ),
        Song(
          id: 2,
          title: 'Long Track 2',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(hours: 2, minutes: 45, seconds: 10),
          filePath: '/mock/2.mp3',
        ),
      ];

      expect(formatTotalDuration(songs), equals('4h 40s'));

      var songsWithMinutes = [
        Song(
          id: 1,
          title: 'Track A',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(hours: 1, minutes: 20, seconds: 10),
          filePath: '/mock/1.mp3',
        ),
      ];
      expect(formatTotalDuration(songsWithMinutes), equals('1h 20m 10s'));
    });

    test('Formats duration with days, hours, minutes, and seconds', () {
      var songs = [
        Song(
          id: 1,
          title: 'Epic Track',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(days: 2, hours: 5, minutes: 12, seconds: 4),
          filePath: '/mock/1.mp3',
        ),
      ];

      expect(formatTotalDuration(songs), equals('2d 5h 12m 4s'));
    });
  });

  group('Song Model Tests', () {
    test('durationFormatted pads single digit seconds', () {
      var song1 = Song(
        id: 1,
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(minutes: 4, seconds: 5),
        filePath: '/mock/1.mp3',
      );
      expect(song1.durationFormatted, equals('4:05'));

      var song2 = Song(
        id: 2,
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(seconds: 59),
        filePath: '/mock/2.mp3',
      );
      expect(song2.durationFormatted, equals('0:59'));
    });

    test('copyWith preserves existing fields and overrides specified ones', () {
      var original = Song(
        id: 42,
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
        duration: const Duration(minutes: 3),
        filePath: '/path/song.mp3',
        bitrate: 320,
        genre: 'Synthwave',
      );

      var modified = original.copyWith(
        title: 'New Title',
        isFavorite: true,
        dominantColor: 0xFF123456,
      );

      expect(modified.id, equals(42));
      expect(modified.title, equals('New Title'));
      expect(modified.artist, equals('Original Artist'));
      expect(modified.album, equals('Original Album'));
      expect(modified.duration, equals(const Duration(minutes: 3)));
      expect(modified.filePath, equals('/path/song.mp3'));
      expect(modified.isFavorite, isTrue);
      expect(modified.bitrate, equals(320));
      expect(modified.genre, equals('Synthwave'));
      expect(modified.dominantColor, equals(0xFF123456));
    });

    test('displayTitle respects filterTitleFeatures and filterTitleArtist settings', () async {
      var settings = SettingsProvider();
      await settings.setFilterTitleFeatures(true);
      await settings.setFilterTitleArtist(true);

      var song = Song(
        id: 1,
        title: 'Cosmos - Starlight (feat. Stellar)',
        artist: 'Cosmos',
        album: 'Galaxy',
        duration: const Duration(minutes: 3),
        filePath: '/mock/1.mp3',
      );

      expect(song.displayTitle, equals('Starlight'));
    });
  });

  group('Playlist Model Serialization Tests', () {
    test('toJson and fromJson preserve all fields including optional metadata', () {
      var playlist = Playlist(
        id: 'pl_rock_99',
        name: 'Classic Rock Anthems',
        songIds: [10, 20, 30, 40],
        coverImagePath: '/covers/rock.jpg',
        description: 'Best guitar riffs of the 80s',
      );

      var jsonMap = playlist.toJson();
      expect(jsonMap['id'], equals('pl_rock_99'));
      expect(jsonMap['name'], equals('Classic Rock Anthems'));
      expect(jsonMap['song_ids'], equals([10, 20, 30, 40]));
      expect(jsonMap['cover_image_path'], equals('/covers/rock.jpg'));
      expect(jsonMap['description'], equals('Best guitar riffs of the 80s'));

      var reconstructed = Playlist.fromJson(jsonMap);
      expect(reconstructed.id, equals(playlist.id));
      expect(reconstructed.name, equals(playlist.name));
      expect(reconstructed.songIds, equals(playlist.songIds));
      expect(reconstructed.coverImagePath, equals(playlist.coverImagePath));
      expect(reconstructed.description, equals(playlist.description));

      var modified = playlist.copyWith(
        name: 'Modern Rock',
        songIds: [40, 30, 20, 10],
      );
      expect(modified.id, equals(playlist.id));
      expect(modified.name, equals('Modern Rock'));
      expect(modified.songIds, equals([40, 30, 20, 10]));
      expect(modified.coverImagePath, equals(playlist.coverImagePath));
      expect(modified.description, equals(playlist.description));

      var cleared = playlist.copyWith(
        clearCoverImage: true,
        clearDescription: true,
      );
      expect(cleared.coverImagePath, isNull);
      expect(cleared.description, isNull);
    });
  });

  group('Grouping Models (AlbumGroup & ArtistGroup) Tests', () {
    test('AlbumGroup computes total duration and song list', () {
      var songs = [
        Song(
          id: 1,
          title: 'Track A',
          artist: 'Band',
          album: 'Album 1',
          duration: const Duration(minutes: 3),
          filePath: '/mock/a.mp3',
        ),
        Song(
          id: 2,
          title: 'Track B',
          artist: 'Band',
          album: 'Album 1',
          duration: const Duration(minutes: 4),
          filePath: '/mock/b.mp3',
        ),
      ];

      var album = AlbumGroup(
        name: 'Album 1',
        artist: 'Band',
        songs: songs,
      );

      expect(album.songs.length, equals(2));
      expect(album.name, equals('Album 1'));
      expect(album.artist, equals('Band'));
      expect(album.nameLower, equals('album 1'));
    });

    test('ArtistGroup aggregates albums and tracks', () {
      var songs = [
        Song(
          id: 1,
          title: 'Track 1',
          artist: 'Solo Artist',
          album: 'Debut',
          duration: const Duration(minutes: 3),
          filePath: '/mock/1.mp3',
        ),
      ];

      var albums = [
        AlbumGroup(name: 'Debut', artist: 'Solo Artist', songs: songs),
      ];

      var artist = ArtistGroup(
        name: 'Solo Artist',
        albums: albums,
        songs: songs,
      );

      expect(artist.name, equals('Solo Artist'));
      expect(artist.nameLower, equals('solo artist'));
      expect(artist.albums.length, equals(1));
      expect(artist.songs.length, equals(1));
    });
  });
}
