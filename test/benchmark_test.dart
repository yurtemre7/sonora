import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';

// ---------------------------------------------------------------------------
// Synthetic library generator
//
// Produces a realistic distribution of songs:
//   - 80% of songs belong to one of ~(N/10) named artists with multiple albums
//   - 20% are "long tail" tracks with unique artist names (simulates singles,
//     obscure tracks, etc.)
//   - Album count is ~N/8 (roughly 8 songs per album on average)
//   - Songs have realistic title, artist, album strings
// ---------------------------------------------------------------------------

List<Song> generateLibrary(int count, {int seed = 42}) {
  var rng = Random(seed);

  var artistCount = max(1, count ~/ 10);
  var albumCount = max(1, count ~/ 8);

  var artists = List.generate(artistCount, (i) => 'Artist ${i + 1}');
  var albums = List.generate(
    albumCount,
    (i) => 'Album ${i + 1} by ${artists[i % artistCount]}',
  );

  return List.generate(count, (i) {
    var isLongTail = rng.nextDouble() < 0.20;
    var artist = isLongTail ? 'Solo Artist $i' : artists[i % artistCount];
    var album =
        isLongTail ? 'Single $i' : albums[i % albumCount];

    return Song(
      id: i + 1,
      title: 'Track ${i + 1} — $artist',
      artist: artist,
      album: album,
      duration: Duration(seconds: 120 + rng.nextInt(180)),
      filePath: '/music/$artist/$album/track_${i + 1}.mp3',
      lastModifiedMs:
          DateTime(2020).millisecondsSinceEpoch + rng.nextInt(100000000),
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers that replicate what home_screen.dart does per build frame
// ---------------------------------------------------------------------------

List<AlbumGroup> filteredAlbums(
  List<AlbumGroup> albums, {
  String query = '',
  String sortBy = 'name',
  bool ascending = true,
}) {
  var result = albums.where((a) {
    if (query.isEmpty) return true;
    return a.nameLower.contains(query) || a.artistLower.contains(query);
  }).toList();

  result.sort((a, b) {
    int cmp;
    if (sortBy == 'artist') {
      cmp = a.artistLower.compareTo(b.artistLower);
    } else if (sortBy == 'tracks') {
      cmp = a.songs.length.compareTo(b.songs.length);
    } else {
      cmp = a.nameLower.compareTo(b.nameLower);
    }
    return ascending ? cmp : -cmp;
  });
  return result;
}

List<ArtistGroup> filteredArtists(
  List<ArtistGroup> artists, {
  String query = '',
  String sortBy = 'name',
  bool ascending = true,
}) {
  var result = artists.where((a) {
    if (query.isEmpty) return true;
    return a.nameLower.contains(query);
  }).toList();

  result.sort((a, b) {
    int cmp;
    if (sortBy == 'albums') {
      cmp = a.albums.length.compareTo(b.albums.length);
    } else if (sortBy == 'songs') {
      cmp = a.songs.length.compareTo(b.songs.length);
    } else {
      cmp = a.nameLower.compareTo(b.nameLower);
    }
    return ascending ? cmp : -cmp;
  });
  return result;
}

// ---------------------------------------------------------------------------
// Benchmark runner
//
// Runs [fn] [iterations] times and reports min/avg/max wall-clock durations.
// ---------------------------------------------------------------------------

typedef _BenchFn = void Function();

({Duration min, Duration avg, Duration max}) _bench(
  _BenchFn fn, {
  int warmup = 3,
  int iterations = 20,
}) {
  for (var i = 0; i < warmup; i++) {
    fn();
  }

  var timings = <Duration>[];
  for (var i = 0; i < iterations; i++) {
    var sw = Stopwatch()..start();
    fn();
    sw.stop();
    timings.add(sw.elapsed);
  }

  timings.sort();
  var totalUs =
      timings.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
  return (
    min: timings.first,
    avg: Duration(microseconds: totalUs ~/ timings.length),
    max: timings.last,
  );
}

String _fmt(Duration d) {
  if (d.inMilliseconds >= 1) return '${d.inMilliseconds}ms';
  return '${d.inMicroseconds}µs';
}

void _printResult(
  String label,
  ({Duration min, Duration avg, Duration max}) r,
) {
  // ignore: avoid_print
  print(
    '  $label'
    '  min=${_fmt(r.min)}'
    '  avg=${_fmt(r.avg)}'
    '  max=${_fmt(r.max)}',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const sizes = [100, 500, 5000, 100000];

  group('Library grouping benchmarks', () {
    for (var n in sizes) {
      test('buildAlbumGroups + buildArtistGroups — $n songs', () {
        var songs = generateLibrary(n);

        var r = _bench(
          () {
            var albums = buildAlbumGroups(songs);
            buildArtistGroups(songs, albums);
          },
          iterations: n <= 500 ? 50 : n <= 5000 ? 20 : 5,
        );

        _printResult('[$n songs] grouping', r);

        // Correctness sanity checks
        var albums = buildAlbumGroups(songs);
        var artists = buildArtistGroups(songs, albums);
        expect(albums, isNotEmpty);
        expect(artists, isNotEmpty);
        expect(
          albums.fold<int>(0, (s, a) => s + a.songs.length),
          equals(n),
          reason: 'All songs must be in an album group',
        );
        expect(
          artists.fold<int>(0, (s, a) => s + a.songs.length),
          equals(n),
          reason: 'All songs must be in an artist group',
        );
      });
    }
  });

  group('Filtered album list benchmarks (per-frame cost)', () {
    for (var n in sizes) {
      test('filteredAlbums (no query) — $n songs', () {
        var songs = generateLibrary(n);
        var albums = buildAlbumGroups(songs);

        var r = _bench(
          () => filteredAlbums(albums),
          iterations: n <= 5000 ? 50 : 10,
        );

        _printResult('[$n songs] filter+sort albums (no query)', r);
        expect(filteredAlbums(albums), isNotEmpty);
      });

      test('filteredAlbums (search query "Artist 1") — $n songs', () {
        var songs = generateLibrary(n);
        var albums = buildAlbumGroups(songs);

        var r = _bench(
          () => filteredAlbums(albums, query: 'artist 1'),
          iterations: n <= 5000 ? 50 : 10,
        );

        _printResult('[$n songs] filter+sort albums (query)', r);
      });
    }
  });

  group('Filtered artist list benchmarks (per-frame cost)', () {
    for (var n in sizes) {
      test('filteredArtists (no query) — $n songs', () {
        var songs = generateLibrary(n);
        var albums = buildAlbumGroups(songs);
        var artists = buildArtistGroups(songs, albums);

        var r = _bench(
          () => filteredArtists(artists),
          iterations: n <= 5000 ? 50 : 10,
        );

        _printResult('[$n songs] filter+sort artists (no query)', r);
        expect(filteredArtists(artists), isNotEmpty);
      });

      test('filteredArtists (search query "Artist 1") — $n songs', () {
        var songs = generateLibrary(n);
        var albums = buildAlbumGroups(songs);
        var artists = buildArtistGroups(songs, albums);

        var r = _bench(
          () => filteredArtists(artists, query: 'artist 1'),
          iterations: n <= 5000 ? 50 : 10,
        );

        _printResult('[$n songs] filter+sort artists (query)', r);
      });
    }
  });

  group('Song list sort benchmarks (per-frame cost)', () {
    for (var n in sizes) {
      test('sort songs by title — $n songs', () {
        var songs = generateLibrary(n);

        var r = _bench(
          () {
            var copy = List<Song>.from(songs);
            copy.sort((a, b) => a.titleLower.compareTo(b.titleLower));
          },
          iterations: n <= 5000 ? 30 : 5,
        );

        _printResult('[$n songs] sort by title', r);
      });

      test('sort songs by artist — $n songs', () {
        var songs = generateLibrary(n);

        var r = _bench(
          () {
            var copy = List<Song>.from(songs);
            copy.sort((a, b) => a.artistLower.compareTo(b.artistLower));
          },
          iterations: n <= 5000 ? 30 : 5,
        );

        _printResult('[$n songs] sort by artist', r);
      });

      test('sort songs by recent — $n songs', () {
        var songs = generateLibrary(n);

        var r = _bench(
          () {
            var copy = List<Song>.from(songs);
            copy.sort((a, b) {
              var aTime = a.lastModifiedMs ?? 0;
              var bTime = b.lastModifiedMs ?? 0;
              return bTime.compareTo(aTime);
            });
          },
          iterations: n <= 5000 ? 30 : 5,
        );

        _printResult('[$n songs] sort by recent', r);
      });
    }
  });
}
