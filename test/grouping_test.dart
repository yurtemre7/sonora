import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';

void main() {
  test('buildAlbumGroups and buildArtistGroups derive stable snapshots', () {
    var songs = [
      Song(
        id: 1,
        title: 'First Song',
        artist: 'Alice',
        album: 'Album One',
        duration: const Duration(minutes: 1),
        filePath: '/tmp/a1.mp3',
      ),
      Song(
        id: 2,
        title: 'Second Song',
        artist: 'Alice',
        album: 'Album One',
        duration: const Duration(minutes: 2),
        filePath: '/tmp/a2.mp3',
      ),
      Song(
        id: 3,
        title: 'Third Song',
        artist: 'Bob',
        album: 'Album Two',
        duration: const Duration(minutes: 3),
        filePath: '/tmp/b1.mp3',
      ),
    ];

    var albums = buildAlbumGroups(songs);
    var artists = buildArtistGroups(songs, albums);

    expect(albums.map((album) => album.name).toList(), ['Album One', 'Album Two']);
    expect(albums.first.artist, 'Alice');
    expect(albums.first.songs.length, 2);
    expect(artists.map((artist) => artist.name).toList(), ['Alice', 'Bob']);
    expect(artists.first.albums.single.name, 'Album One');
    expect(artists.first.songs.length, 2);
  });

  test('buildAlbumGroups splits albums with the same name by different artists', () {
    var songs = [
      Song(
        id: 1,
        title: 'Song A',
        artist: 'Queen',
        album: 'Greatest Hits',
        duration: const Duration(minutes: 3),
        filePath: '/tmp/q1.mp3',
      ),
      Song(
        id: 2,
        title: 'Song B',
        artist: 'Guns N Roses',
        album: 'Greatest Hits',
        duration: const Duration(minutes: 4),
        filePath: '/tmp/g1.mp3',
      ),
    ];

    var albums = buildAlbumGroups(songs);
    expect(albums.length, 2);
    expect(albums.any((a) => a.name == 'Greatest Hits' && a.artist == 'Queen'), isTrue);
    expect(albums.any((a) => a.name == 'Greatest Hits' && a.artist == 'Guns N Roses'), isTrue);

    var queenAlbum = albums.firstWhere((a) => a.artist == 'Queen');
    var gnrAlbum = albums.firstWhere((a) => a.artist == 'Guns N Roses');
    expect(queenAlbum.songs.single.title, 'Song A');
    expect(gnrAlbum.songs.single.title, 'Song B');
  });

  test('Unknown artist songs are bundled into consolidated Unknown Artist / Unknown Album', () {
    var songs = [
      Song(
        id: 1,
        title: 'Song 1',
        artist: '',
        album: 'Some Album',
        duration: const Duration(minutes: 3),
        filePath: '/tmp/u1.mp3',
      ),
      Song(
        id: 2,
        title: 'Song 2',
        artist: 'Unknown Artist',
        album: '',
        duration: const Duration(minutes: 4),
        filePath: '/tmp/u2.mp3',
      ),
    ];

    var albums = buildAlbumGroups(songs);
    // Both songs should go into Artist: 'Unknown Artist', Album: 'Unknown Album'
    expect(albums.length, 1);
    expect(albums.first.name, 'Unknown Album');
    expect(albums.first.artist, 'Unknown Artist');
    expect(albums.first.songs.length, 2);

    var artists = buildArtistGroups(songs, albums);
    expect(artists.length, 1);
    expect(artists.first.name, 'Unknown Artist');
    expect(artists.first.albums.single.name, 'Unknown Album');
  });
}
