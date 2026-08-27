import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/library_search_index.dart';

void main() {
  group('LibrarySearchIndex', () {
    late LibrarySearchIndex searchIndex;
    late List<Song> sampleSongs;
    late List<AlbumGroup> sampleAlbums;
    late List<ArtistGroup> sampleArtists;

    setUp(() {
      searchIndex = LibrarySearchIndex();
      sampleSongs = [
        Song(
          id: 1,
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          duration: const Duration(minutes: 5, seconds: 55),
          filePath: '/music/queen_bohemian.mp3',
          lastModifiedMs: 1000,
        ),
        Song(
          id: 2,
          title: 'Don\'t Stop Me Now',
          artist: 'Queen',
          album: 'Jazz',
          duration: const Duration(minutes: 3, seconds: 29),
          filePath: '/music/queen_dont_stop.mp3',
          lastModifiedMs: 2000,
        ),
        Song(
          id: 3,
          title: 'Hotel California',
          artist: 'Eagles',
          album: 'Hotel California',
          duration: const Duration(minutes: 6, seconds: 30),
          filePath: '/music/eagles_hotel.mp3',
          lastModifiedMs: 3000,
        ),
        Song(
          id: 4,
          title: 'Stairway to Heaven',
          artist: 'Led Zeppelin',
          album: 'Led Zeppelin IV',
          duration: const Duration(minutes: 8, seconds: 2),
          filePath: '/music/led_stairway.mp3',
          lastModifiedMs: 4000,
        ),
        Song(
          id: 5,
          title: 'Imagine',
          artist: 'John Lennon',
          album: 'Imagine',
          duration: const Duration(minutes: 3, seconds: 4),
          filePath: '/music/john_imagine.mp3',
          lastModifiedMs: 5000,
        ),
      ];

      sampleAlbums = buildAlbumGroups(sampleSongs);
      sampleArtists = buildArtistGroups(sampleSongs, sampleAlbums);
      searchIndex.buildIndex(
        songs: sampleSongs,
        albums: sampleAlbums,
        artists: sampleArtists,
      );
    });

    test('returns all songs sorted by title ascending when query is empty', () {
      var results = searchIndex.searchSongs(
        '',
        sortBy: 'title',
        ascending: true,
      );
      expect(results.map((s) => s.title).toList(), [
        'Bohemian Rhapsody',
        'Don\'t Stop Me Now',
        'Hotel California',
        'Imagine',
        'Stairway to Heaven',
      ]);
    });

    test('returns all songs sorted by duration descending', () {
      var results = searchIndex.searchSongs(
        '',
        sortBy: 'duration',
        ascending: false,
      );
      expect(results.first.title, 'Stairway to Heaven');
      expect(results.last.title, 'Imagine');
    });

    test('searches by exact prefix match on song title', () {
      var results = searchIndex.searchSongs(
        'bohem',
        sortBy: 'title',
        ascending: true,
      );
      expect(results.length, 1);
      expect(results.first.title, 'Bohemian Rhapsody');
    });

    test('searches by artist prefix matching multiple tracks', () {
      var results = searchIndex.searchSongs(
        'queen',
        sortBy: 'title',
        ascending: true,
      );
      expect(results.length, 2);
      expect(results.map((s) => s.title).toList(), [
        'Bohemian Rhapsody',
        'Don\'t Stop Me Now',
      ]);
    });

    test('searches by album substring', () {
      var results = searchIndex.searchSongs(
        'opera',
        sortBy: 'title',
        ascending: true,
      );
      expect(results.length, 1);
      expect(results.first.title, 'Bohemian Rhapsody');
    });

    test('handles multi-term queries', () {
      var results = searchIndex.searchSongs(
        'eagles calif',
        sortBy: 'title',
        ascending: true,
      );
      expect(results.length, 1);
      expect(results.first.title, 'Hotel California');
    });

    test('returns empty list for non-matching queries', () {
      var results = searchIndex.searchSongs(
        'xyznotfound',
        sortBy: 'title',
        ascending: true,
      );
      expect(results, isEmpty);
    });

    test('searches and filters albums accurately', () {
      var albums = searchIndex.searchAlbums(
        'jazz',
        allAlbums: sampleAlbums,
        sortBy: 'name',
        ascending: true,
      );
      expect(albums.length, 1);
      expect(albums.first.name, 'Jazz');
    });

    test('searches and filters artists accurately', () {
      var artists = searchIndex.searchArtists(
        'lennon',
        allArtists: sampleArtists,
        sortBy: 'name',
        ascending: true,
      );
      expect(artists.length, 1);
      expect(artists.first.name, 'John Lennon');
    });
  });
}
