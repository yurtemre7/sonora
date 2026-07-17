import 'package:sonora/models/song.dart';

class AlbumGroup {
  final String name;
  final String artist;
  final List<Song> songs;

  AlbumGroup({required this.name, required this.artist, required this.songs});

  // Pre-normalized lowercase keys computed once at construction time
  late final String nameLower = name.toLowerCase();
  late final String artistLower = artist.toLowerCase();
}

class ArtistGroup {
  final String name;
  final List<Song> songs;
  final List<AlbumGroup> albums;

  ArtistGroup({required this.name, required this.songs, required this.albums});

  // Pre-normalized lowercase key computed once at construction time
  late final String nameLower = name.toLowerCase();
}

List<AlbumGroup> buildAlbumGroups(List<Song> allSongs) {
  var albumsMap = <String, List<Song>>{};
  for (var song in allSongs) {
    var artistName = song.artist.trim().isEmpty ? 'Unknown Artist' : song.artist.trim();
    var albumName = song.album.trim().isEmpty ? 'Unknown Album' : song.album.trim();

    if (artistName == 'Unknown Artist') {
      albumName = 'Unknown Album';
    }

    var key = '$albumName|||$artistName';
    albumsMap.putIfAbsent(key, () => []).add(song);
  }

  var list = albumsMap.entries.map((entry) {
    var parts = entry.key.split('|||');
    var albumName = parts[0];
    var artistName = parts[1];

    return AlbumGroup(
      name: albumName,
      artist: artistName,
      songs: entry.value,
    );
  }).toList();

  list.sort((a, b) => a.nameLower.compareTo(b.nameLower));
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
        : song.artist.trim();
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

  list.sort((a, b) => a.nameLower.compareTo(b.nameLower));
  return list;
}

AlbumGroup buildAlbumGroup(
  String albumName,
  String artistName,
  List<Song> allSongs,
) {
  var normalizedArtist = artistName.trim().isEmpty ? 'Unknown Artist' : artistName.trim();
  var normalizedAlbum = albumName.trim().isEmpty ? 'Unknown Album' : albumName.trim();
  if (normalizedArtist == 'Unknown Artist') {
    normalizedAlbum = 'Unknown Album';
  }

  var songs = allSongs.where((s) {
    var sArtist = s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist.trim();
    var sAlbum = s.album.trim().isEmpty ? 'Unknown Album' : s.album.trim();
    if (sArtist == 'Unknown Artist') {
      sAlbum = 'Unknown Album';
    }
    return sAlbum == normalizedAlbum && sArtist == normalizedArtist;
  }).toList();

  return AlbumGroup(
    name: normalizedAlbum,
    artist: normalizedArtist,
    songs: songs,
  );
}

ArtistGroup buildArtistGroup(String artistName, List<Song> allSongs) {
  var normalizedArtist = artistName.trim().isEmpty ? 'Unknown Artist' : artistName.trim();
  var songs = allSongs.where((s) {
    var sArtist = s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist.trim();
    return sArtist == normalizedArtist;
  }).toList();

  var albumMap = <String, List<Song>>{};
  for (var song in songs) {
    var sArtist = song.artist.trim().isEmpty ? 'Unknown Artist' : song.artist.trim();
    var albumName = song.album.trim().isEmpty ? 'Unknown Album' : song.album.trim();
    if (sArtist == 'Unknown Artist') {
      albumName = 'Unknown Album';
    }
    albumMap.putIfAbsent(albumName, () => []).add(song);
  }

  var albums = albumMap.entries.map((e) {
    return AlbumGroup(name: e.key, artist: normalizedArtist, songs: e.value);
  }).toList();

  return ArtistGroup(name: normalizedArtist, songs: songs, albums: albums);
}
