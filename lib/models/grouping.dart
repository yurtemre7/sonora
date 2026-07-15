import 'package:sonora/models/song.dart';

class AlbumGroup {
  final String name;
  final String artist;
  final List<Song> songs;

  AlbumGroup({required this.name, required this.artist, required this.songs});
}

class ArtistGroup {
  final String name;
  final List<Song> songs;
  final List<AlbumGroup> albums;

  ArtistGroup({required this.name, required this.songs, required this.albums});
}

List<AlbumGroup> buildAlbumGroups(List<Song> allSongs) {
  var albumsMap = <String, List<Song>>{};
  for (var song in allSongs) {
    var albumName = song.album.trim().isEmpty ? 'Unknown Album' : song.album;
    albumsMap.putIfAbsent(albumName, () => []).add(song);
  }

  var list = albumsMap.entries.map((entry) {
    var artistCounts = <String, int>{};
    for (var song in entry.value) {
      artistCounts[song.artist] = (artistCounts[song.artist] ?? 0) + 1;
    }

    var albumArtist = 'Unknown Artist';
    var maxCount = 0;
    artistCounts.forEach((artist, count) {
      if (count > maxCount) {
        maxCount = count;
        albumArtist = artist;
      }
    });

    return AlbumGroup(
      name: entry.key,
      artist: albumArtist,
      songs: entry.value,
    );
  }).toList();

  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

List<ArtistGroup> buildArtistGroups(
  List<Song> allSongs,
  List<AlbumGroup> albumGroups,
) {
  var artistsMap = <String, List<Song>>{};
  for (var song in allSongs) {
    var artistName = song.artist.trim().isEmpty
        ? 'Unknown Artist'
        : song.artist;
    artistsMap.putIfAbsent(artistName, () => []).add(song);
  }

  var list = artistsMap.entries.map((entry) {
    var artistAlbums = albumGroups
        .where((album) => album.artist == entry.key)
        .toList();
    return ArtistGroup(
      name: entry.key,
      songs: entry.value,
      albums: artistAlbums,
    );
  }).toList();

  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

AlbumGroup buildAlbumGroup(
  String albumName,
  String artistName,
  List<Song> allSongs,
) {
  var normalizedAlbum = albumName;
  var normalizedArtist = artistName;
  var songs = allSongs.where((s) {
    var sAlbum = s.album.trim().isEmpty ? 'Unknown Album' : s.album;
    var sArtist = s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist;
    return sAlbum == normalizedAlbum && sArtist == normalizedArtist;
  }).toList();
  return AlbumGroup(
    name: normalizedAlbum,
    artist: normalizedArtist,
    songs: songs,
  );
}

ArtistGroup buildArtistGroup(String artistName, List<Song> allSongs) {
  var normalizedArtist = artistName;
  var songs = allSongs.where((s) {
    return (s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist) ==
        normalizedArtist;
  }).toList();

  var albumMap = <String, List<Song>>{};
  for (var song in songs) {
    var albumName = song.album.trim().isEmpty ? 'Unknown Album' : song.album;
    albumMap.putIfAbsent(albumName, () => []).add(song);
  }

  var albums = albumMap.entries.map((e) {
    return AlbumGroup(name: e.key, artist: normalizedArtist, songs: e.value);
  }).toList();

  return ArtistGroup(name: normalizedArtist, songs: songs, albums: albums);
}
