import 'package:sonora/models/song.dart';

class AlbumGroup {
  final String name;
  final String artist;
  final List<Song> songs;

  AlbumGroup({required this.name, required this.artist, required this.songs});

  // Pre-normalized lowercase keys computed once at construction time
  late final String nameLower = name.toLowerCase();
  late final String artistLower = artist.toLowerCase();
  late final int latestModifiedMs = songs.fold<int>(
    0,
    (max, s) => (s.lastModifiedMs ?? 0) > max ? (s.lastModifiedMs ?? 0) : max,
  );
}

class ArtistGroup {
  final String name;
  final List<Song> songs;
  final List<AlbumGroup> albums;
  final String? localImagePath;

  ArtistGroup({
    required this.name,
    required this.songs,
    required this.albums,
    this.localImagePath,
  });

  // Pre-normalized lowercase key computed once at construction time
  late final String nameLower = name.toLowerCase();
}

/// Helper function to parse individual artist names from a combined artist tag string.
///
/// Splits by common delimiters (`,`, `;`, `/`, `&`, `\`, `feat.`, `ft.`, `featuring`, `vs.`, `with`, `x`, `+`)
/// and returns a deduplicated list of clean artist names.
List<String> parseIndividualArtists(String artistString) {
  var trimmed = artistString.trim();
  if (trimmed.isEmpty) return ['Unknown Artist'];

  var rawList = trimmed.split(
    RegExp(
      r'[,;/&\\]|\s+(?:feat\.?|ft\.?|featuring|vs\.?|with|[xX\+])\s+',
      caseSensitive: false,
    ),
  );

  var result = <String>[];
  var seen = <String>{};

  for (var name in rawList) {
    var clean = name.trim();
    clean = clean.replaceAll(RegExp(r'^[(\[\s]+|[)\]\s]+$'), '').trim();
    if (clean.isNotEmpty) {
      var lower = clean.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        result.add(clean);
      }
    }
  }

  return result.isEmpty ? ['Unknown Artist'] : result;
}

List<Song> _sortAlbumSongs(List<Song> songs) {
  var sorted = List<Song>.from(songs);
  sorted.sort((a, b) {
    int discA = a.discNumber ?? 1;
    int discB = b.discNumber ?? 1;
    if (discA != discB) {
      return discA.compareTo(discB);
    }
    int trackA = a.trackNumber ?? 0;
    int trackB = b.trackNumber ?? 0;
    if (trackA != trackB) {
      return trackA.compareTo(trackB);
    }
    if (trackA == 0 && trackB == 0) {
      return a.filePath.compareTo(b.filePath);
    }
    return a.titleLower.compareTo(b.titleLower);
  });
  return sorted;
}

/// Builds the unified list of [AlbumGroup]s from [allSongs].
///
/// Songs sharing the same album name are grouped together into a single album,
/// resolving the primary artist even if individual track artist tags contain
/// different featured artist combinations.
List<AlbumGroup> buildAlbumGroups(List<Song> allSongs) {
  var rawAlbumMap = <String, List<Song>>{};

  for (var song in allSongs) {
    var primaryArtist = parseIndividualArtists(song.artist).first;
    var albumName = song.album.trim().isEmpty
        ? 'Unknown Album'
        : song.album.trim();
    if (primaryArtist == 'Unknown Artist' ||
        albumName.toLowerCase() == 'unknown album') {
      var key = 'unknown album|||unknown artist';
      rawAlbumMap.putIfAbsent(key, () => []).add(song);
    } else {
      var key = albumName.toLowerCase();
      rawAlbumMap.putIfAbsent(key, () => []).add(song);
    }
  }

  var albumGroups = <AlbumGroup>[];

  for (var entry in rawAlbumMap.entries) {
    var songs = entry.value;
    if (songs.isEmpty) continue;

    var firstSongAlbumName = songs.first.album.trim().isEmpty
        ? 'Unknown Album'
        : songs.first.album.trim();

    if (entry.key.startsWith('unknown album|||')) {
      var artistName = parseIndividualArtists(songs.first.artist).first;
      albumGroups.add(
        AlbumGroup(
          name: 'Unknown Album',
          artist: artistName,
          songs: _sortAlbumSongs(songs),
        ),
      );
      continue;
    }

    var artistCounts = <String, int>{};
    var artistCased = <String, String>{};

    for (var song in songs) {
      var artists = parseIndividualArtists(song.artist);
      var primary = artists.first;
      var lower = primary.toLowerCase();
      artistCounts[lower] = (artistCounts[lower] ?? 0) + 1;
      artistCased[lower] = primary;
    }

    // Check if all songs in this album share at least one common artist
    var commonArtists = <String>{};
    if (songs.isNotEmpty) {
      var firstArtists = parseIndividualArtists(songs.first.artist)
          .map((a) => a.toLowerCase())
          .toSet();
      commonArtists.addAll(firstArtists);
      for (var s in songs.skip(1)) {
        var sArtists = parseIndividualArtists(s.artist)
            .map((a) => a.toLowerCase())
            .toSet();
        commonArtists.retainAll(sArtists);
      }
    }

    String? dominantArtistLower;
    var maxCount = 0;
    artistCounts.forEach((lower, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantArtistLower = lower;
      }
    });

    if (commonArtists.isNotEmpty) {
      var albumArtistLower = commonArtists.first;
      var displayArtist = parseIndividualArtists(songs.first.artist).firstWhere(
        (a) => a.toLowerCase() == albumArtistLower,
        orElse: () => artistCased[albumArtistLower] ?? 'Various Artists',
      );

      albumGroups.add(
        AlbumGroup(
          name: firstSongAlbumName,
          artist: displayArtist,
          songs: _sortAlbumSongs(songs),
        ),
      );
    } else if (dominantArtistLower != null && maxCount > (songs.length / 2)) {
      var displayArtist = artistCased[dominantArtistLower]!;
      albumGroups.add(
        AlbumGroup(
          name: firstSongAlbumName,
          artist: displayArtist,
          songs: _sortAlbumSongs(songs),
        ),
      );
    } else if (artistCounts.length == 1) {
      var displayArtist = artistCased.values.first;
      albumGroups.add(
        AlbumGroup(
          name: firstSongAlbumName,
          artist: displayArtist,
          songs: _sortAlbumSongs(songs),
        ),
      );
    } else {
      // Split into separate albums if there are distinct main artists
      var subGroups = <String, List<Song>>{};
      for (var song in songs) {
        var primaryLower = parseIndividualArtists(song.artist).first
            .toLowerCase();
        subGroups.putIfAbsent(primaryLower, () => []).add(song);
      }

      for (var subEntry in subGroups.entries) {
        var subSongs = subEntry.value;
        var displayArtist = parseIndividualArtists(subSongs.first.artist).first;
        albumGroups.add(
          AlbumGroup(
            name: firstSongAlbumName,
            artist: displayArtist,
            songs: _sortAlbumSongs(subSongs),
          ),
        );
      }
    }
  }

  albumGroups.sort((a, b) => a.nameLower.compareTo(b.nameLower));
  return albumGroups;
}

/// Builds individual [ArtistGroup]s from [allSongs] and [allAlbums].
///
/// Multi-artist tags are split so every artist gets their own dedicated entry
/// without combination duplicate entries.
List<ArtistGroup> buildArtistGroups(
  List<Song> allSongs,
  List<AlbumGroup> allAlbums, [
  Map<String, String>? localArtistImages,
]) {
  var albumsByArtistMap = <String, List<AlbumGroup>>{};
  for (var album in allAlbums) {
    var albumArtistSet = <String>{};
    for (var song in album.songs) {
      for (var a in parseIndividualArtists(song.artist)) {
        albumArtistSet.add(a.toLowerCase());
      }
    }
    for (var a in parseIndividualArtists(album.artist)) {
      albumArtistSet.add(a.toLowerCase());
    }
    for (var lowerArtist in albumArtistSet) {
      albumsByArtistMap.putIfAbsent(lowerArtist, () => []).add(album);
    }
  }

  var artistSongsMap = <String, MapEntry<String, List<Song>>>{};

  for (var song in allSongs) {
    var artists = parseIndividualArtists(song.artist);
    for (var artistName in artists) {
      var lower = artistName.toLowerCase();
      if (!artistSongsMap.containsKey(lower)) {
        artistSongsMap[lower] = MapEntry(artistName, []);
      }
      artistSongsMap[lower]!.value.add(song);
    }
  }

  var list = artistSongsMap.entries.map((entry) {
    var lowerName = entry.key;
    var displayName = entry.value.key;
    var songs = entry.value.value;

    var artistAlbums = albumsByArtistMap[lowerName] ?? [];
    var localImage = localArtistImages?[lowerName];

    return ArtistGroup(
      name: displayName,
      songs: songs,
      albums: artistAlbums,
      localImagePath: localImage,
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
  var allAlbums = buildAlbumGroups(allSongs);
  var targetNormAlbum = albumName.trim().toLowerCase();
  var targetNormArtist = artistName.trim().toLowerCase();

  for (var album in allAlbums) {
    if (album.nameLower == targetNormAlbum &&
        (album.artistLower == targetNormArtist ||
            parseIndividualArtists(album.artist)
                .any((a) => a.toLowerCase() == targetNormArtist))) {
      return album;
    }
  }

  var matchByAlbum = allAlbums
      .where((a) => a.nameLower == targetNormAlbum)
      .firstOrNull;
  if (matchByAlbum != null) return matchByAlbum;

  return AlbumGroup(name: albumName, artist: artistName, songs: []);
}

ArtistGroup buildArtistGroup(
  String artistName,
  List<Song> allSongs, [
  Map<String, String>? localArtistImages,
]) {
  var allAlbums = buildAlbumGroups(allSongs);
  var allArtists = buildArtistGroups(allSongs, allAlbums, localArtistImages);

  var targetLower = artistName.trim().toLowerCase();
  for (var artist in allArtists) {
    if (artist.nameLower == targetLower) {
      return artist;
    }
  }

  return ArtistGroup(name: artistName, songs: [], albums: []);
}
