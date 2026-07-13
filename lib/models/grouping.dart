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

AlbumGroup buildAlbumGroup(String albumName, String artistName, List<Song> allSongs) {
  var normalizedAlbum = albumName;
  var normalizedArtist = artistName;
  var songs = allSongs.where((s) {
    var sAlbum = s.album.trim().isEmpty ? 'Unknown Album' : s.album;
    var sArtist = s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist;
    return sAlbum == normalizedAlbum && sArtist == normalizedArtist;
  }).toList();
  return AlbumGroup(name: normalizedAlbum, artist: normalizedArtist, songs: songs);
}

ArtistGroup buildArtistGroup(String artistName, List<Song> allSongs) {
  var normalizedArtist = artistName;
  var songs = allSongs.where((s) {
    return (s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist) == normalizedArtist;
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
