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
}
