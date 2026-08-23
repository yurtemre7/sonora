import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';

class _StatsData {
  var totalListeningTimeMs = 0;
  var completeSongListens = 0;
  var firstPlayedSongId = -1;
  String? firstPlayedDate;
  final songPlayCounts = <int, int>{};
  final songCumulativeListenMs = <int, int>{};
  final playlistPlayCounts = <String, int>{};
  final dailyListeningMs = <String, int>{};
  final weeklyPlayCounts = <int, int>{};
  var shuffleSessionStarts = 0;
  final songSkipCounts = <int, int>{};
  final songRestartCounts = <int, int>{};
}

class StatsService {
  StatsService._();
  static final _instance = StatsService._();
  factory StatsService() => _instance;

  final _data = _StatsData();
  Timer? _debounceTimer;
  var _dirty = false;

  var _loadGuard = false;

  Future<void> ensureLoaded() async {
    if (_loadGuard) return;
    _loadGuard = true;
    await _load();
  }

  /// Records [ms] of listening time attributed to the given [songId].
  ///
  /// When the cumulative tracked time for that song reaches or exceeds its
  /// [songDurationMs], a full listen is counted and [songDurationMs] is
  /// subtracted from the running total (carry-over). The [playlistId] is
  /// optional – when provided and a full listen is registered, that playlist
  /// receives a play too.
  void addListeningTime(
    int ms,
    int songId,
    int songDurationMs, {
    String? playlistId,
  }) {
    if (ms <= 0) return;
    _data.totalListeningTimeMs += ms;

    var now = DateTime.now();
    var dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _data.dailyListeningMs.update(dateKey, (v) => v + ms, ifAbsent: () => ms);

    // Accumulate per-song listening time and check for full listen(s)
    var cumulative = (_data.songCumulativeListenMs[songId] ?? 0) + ms;

    while (songDurationMs > 0 && cumulative >= songDurationMs) {
      // Full listen achieved – increment counts and carry over the remainder
      _data.songPlayCounts.update(songId, (v) => v + 1, ifAbsent: () => 1);
      _data.completeSongListens++;

      var weekday = now.weekday % 7;
      _data.weeklyPlayCounts.update(weekday, (v) => v + 1, ifAbsent: () => 1);

      if (_data.firstPlayedSongId < 0) {
        _data.firstPlayedSongId = songId;
        _data.firstPlayedDate = dateKey;
      }

      if (playlistId != null) {
        _data.playlistPlayCounts.update(
          playlistId,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }

      cumulative -= songDurationMs;
    }

    _data.songCumulativeListenMs[songId] = cumulative;

    _markDirty();
  }

  void recordShuffleSessionStart() {
    _data.shuffleSessionStarts++;
    _markDirty();
  }

  void recordSongSkip(int songId) {
    _data.songSkipCounts.update(songId, (v) => v + 1, ifAbsent: () => 1);
    _markDirty();
  }

  void recordSongRestart(int songId) {
    _data.songRestartCounts.update(songId, (v) => v + 1, ifAbsent: () => 1);
    _markDirty();
  }

  /// Resets all statistics to zero and persists immediately.
  Future<void> reset() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _data.totalListeningTimeMs = 0;
    _data.completeSongListens = 0;
    _data.firstPlayedSongId = -1;
    _data.firstPlayedDate = null;
    _data.songPlayCounts.clear();
    _data.songCumulativeListenMs.clear();
    _data.playlistPlayCounts.clear();
    _data.dailyListeningMs.clear();
    _data.weeklyPlayCounts.clear();
    _data.shuffleSessionStarts = 0;
    _data.songSkipCounts.clear();
    _data.songRestartCounts.clear();
    _dirty = true;
    await _save();
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_dirty) {
      await _save();
    }
  }

  // ── Getters ─────────────────────────────────────────────────────────────

  String get totalListeningTimeFormatted {
    var totalSeconds = (_data.totalListeningTimeMs / 1000).round();
    var hours = totalSeconds ~/ 3600;
    var minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '< 1m';
  }

  String get totalListeningTimeFull {
    var totalSeconds = (_data.totalListeningTimeMs / 1000).round();
    var hours = totalSeconds ~/ 3600;
    var minutes = (totalSeconds % 3600) ~/ 60;
    var seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  int get completeSongListens => _data.completeSongListens;

  int get shuffleSessionStarts => _data.shuffleSessionStarts;

  int get totalSkips => _data.songSkipCounts.values.fold(0, (a, b) => a + b);

  int get totalRestarts =>
      _data.songRestartCounts.values.fold(0, (a, b) => a + b);

  int songSkipCount(int id) => _data.songSkipCounts[id] ?? 0;

  int songRestartCount(int id) => _data.songRestartCounts[id] ?? 0;

  int songCumulativeListenMs(int id) => _data.songCumulativeListenMs[id] ?? 0;

  Map<int, Song> _buildSongMap(List<Song> library) => {
    for (var s in library) s.id: s,
  };

  int albumListenCount(List<Song> library) {
    var songMap = _buildSongMap(library);
    var albumGroups = buildAlbumGroups(library);
    var listenedAlbums = <String>{};
    for (var entry in _data.songPlayCounts.entries) {
      var song = songMap[entry.key];
      if (song != null) {
        var group = albumGroups
            .where((a) => a.songs.any((s) => s.id == song.id))
            .firstOrNull;
        if (group != null) {
          listenedAlbums.add('${group.nameLower}|||${group.artistLower}');
        }
      }
    }
    return listenedAlbums.length;
  }

  int artistListenCount(List<Song> library) {
    var songMap = _buildSongMap(library);
    var artists = <String>{};
    for (var entry in _data.songPlayCounts.entries) {
      var song = songMap[entry.key];
      if (song != null) {
        for (var a in parseIndividualArtists(song.artist)) {
          artists.add(a.toLowerCase());
        }
      }
    }
    return artists.length;
  }

  int get playlistListenCount => _data.playlistPlayCounts.length;

  int get totalUniqueSongsPlayed => _data.songPlayCounts.length;

  String? get firstPlayedDate => _data.firstPlayedDate;

  Song? firstPlayedSong(List<Song> library) {
    if (_data.firstPlayedSongId < 0) return null;
    return _buildSongMap(library)[_data.firstPlayedSongId];
  }

  int get totalListeningTimeMs => _data.totalListeningTimeMs;

  String get mostActiveDay {
    if (_data.weeklyPlayCounts.isEmpty) return '\u2014';
    var dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    var maxEntry = _data.weeklyPlayCounts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return dayNames[maxEntry.key % 7];
  }

  // ── Top lists ────────────────────────────────────────────────────────────

  List<({Song song, int count})> topSongs(int limit, List<Song> library) {
    var songMap = _buildSongMap(library);
    var sorted = _data.songPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var result = <({Song song, int count})>[];
    for (var entry in sorted) {
      var song = songMap[entry.key];
      if (song != null) {
        result.add((song: song, count: entry.value));
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  List<
    ({
      String album,
      String artist,
      int count,
      String? artworkPath,
      AlbumGroup group,
    })
  >
  topAlbums(int limit, List<Song> library) {
    var songMap = _buildSongMap(library);
    var albumGroups = buildAlbumGroups(library);
    var albumCounts = <AlbumGroup, int>{};
    for (var entry in _data.songPlayCounts.entries) {
      var song = songMap[entry.key];
      if (song != null) {
        var group = albumGroups
            .where((a) => a.songs.any((s) => s.id == song.id))
            .firstOrNull;
        if (group != null) {
          albumCounts.update(
            group,
            (v) => v + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }
    }
    var sorted = albumCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) {
      String? artworkPath;
      for (var s in e.key.songs) {
        if (s.artworkPath != null && s.artworkPath!.isNotEmpty) {
          artworkPath = s.artworkPath;
          break;
        }
      }
      return (
        album: e.key.name,
        artist: e.key.artist,
        count: e.value,
        artworkPath: artworkPath,
        group: e.key,
      );
    }).toList();
  }

  List<({String artist, int count, ArtistGroup group})> topArtists(
    int limit,
    List<Song> library, {
    List<ArtistGroup>? cachedArtists,
    Map<String, String>? localArtistImages,
  }) {
    var songMap = _buildSongMap(library);
    var artistCounts = <String, ({String displayName, int count})>{};
    for (var entry in _data.songPlayCounts.entries) {
      var song = songMap[entry.key];
      if (song != null) {
        for (var artistName in parseIndividualArtists(song.artist)) {
          var lower = artistName.toLowerCase();
          var current = artistCounts[lower];
          if (current == null) {
            artistCounts[lower] = (displayName: artistName, count: entry.value);
          } else {
            artistCounts[lower] = (
              displayName: current.displayName,
              count: current.count + entry.value,
            );
          }
        }
      }
    }
    var sorted = artistCounts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    var artistGroups =
        cachedArtists ??
        buildArtistGroups(
          library,
          buildAlbumGroups(library),
          localArtistImages,
        );
    var groupMap = {for (var g in artistGroups) g.nameLower: g};

    return sorted.take(limit).map((e) {
      var group =
          groupMap[e.displayName.toLowerCase()] ??
          buildArtistGroup(e.displayName, library, localArtistImages);
      return (artist: e.displayName, count: e.count, group: group);
    }).toList();
  }

  List<({Playlist playlist, int count})> topPlaylists(
    int limit,
    List<Playlist> allPlaylists,
  ) {
    var result = <({Playlist playlist, int count})>[];
    var sorted = _data.playlistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sorted) {
      var playlist = allPlaylists.where((p) => p.id == entry.key).firstOrNull;
      if (playlist != null) {
        result.add((playlist: playlist, count: entry.value));
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      var appDir = await getApplicationDocumentsDirectory();

      var tempFile = File('${appDir.path}/listening_stats.json.tmp');
      if (tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      var file = File('${appDir.path}/listening_stats.json');
      if (!file.existsSync()) return;

      var content = await file.readAsString();
      var json = jsonDecode(content) as Map<String, dynamic>;

      _data.totalListeningTimeMs = json['total_listening_time_ms'] as int? ?? 0;
      _data.completeSongListens = json['complete_song_listens'] as int? ?? 0;
      _data.firstPlayedSongId = json['first_played_song_id'] as int? ?? -1;
      _data.firstPlayedDate = json['first_played_date'] as String?;

      var playCounts = json['song_play_counts'] as Map<String, dynamic>?;
      if (playCounts != null) {
        _data.songPlayCounts.clear();
        for (var e in playCounts.entries) {
          _data.songPlayCounts[int.parse(e.key)] = e.value as int;
        }
      }

      var cumulative =
          json['song_cumulative_listen_ms'] as Map<String, dynamic>?;
      if (cumulative != null) {
        _data.songCumulativeListenMs.clear();
        for (var e in cumulative.entries) {
          _data.songCumulativeListenMs[int.parse(e.key)] = e.value as int;
        }
      }

      var plCounts = json['playlist_play_counts'] as Map<String, dynamic>?;
      if (plCounts != null) {
        _data.playlistPlayCounts.clear();
        for (var e in plCounts.entries) {
          _data.playlistPlayCounts[e.key] = e.value as int;
        }
      }

      var daily = json['daily_listening_ms'] as Map<String, dynamic>?;
      if (daily != null) {
        _data.dailyListeningMs.clear();
        for (var e in daily.entries) {
          _data.dailyListeningMs[e.key] = e.value as int;
        }
      }

      var weekly = json['weekly_play_counts'] as Map<String, dynamic>?;
      if (weekly != null) {
        _data.weeklyPlayCounts.clear();
        for (var e in weekly.entries) {
          _data.weeklyPlayCounts[int.parse(e.key)] = e.value as int;
        }
      }

      _data.shuffleSessionStarts = json['shuffle_session_starts'] as int? ?? 0;

      var skips = json['song_skip_counts'] as Map<String, dynamic>?;
      if (skips != null) {
        _data.songSkipCounts.clear();
        for (var e in skips.entries) {
          _data.songSkipCounts[int.parse(e.key)] = e.value as int;
        }
      }

      var restarts = json['song_restart_counts'] as Map<String, dynamic>?;
      if (restarts != null) {
        _data.songRestartCounts.clear();
        for (var e in restarts.entries) {
          _data.songRestartCounts[int.parse(e.key)] = e.value as int;
        }
      }
    } catch (_) {
      _data.totalListeningTimeMs = 0;
      _data.completeSongListens = 0;
      _data.firstPlayedSongId = -1;
      _data.firstPlayedDate = null;
      _data.songPlayCounts.clear();
      _data.songCumulativeListenMs.clear();
      _data.playlistPlayCounts.clear();
      _data.dailyListeningMs.clear();
      _data.weeklyPlayCounts.clear();
      _data.shuffleSessionStarts = 0;
      _data.songSkipCounts.clear();
      _data.songRestartCounts.clear();
    }
  }

  var _isSaving = false;
  var _hasPendingSave = false;

  Future<void> _save() async {
    if (_isSaving) {
      _hasPendingSave = true;
      return;
    }
    _isSaving = true;
    try {
      do {
        _hasPendingSave = false;
        var appDir = await getApplicationDocumentsDirectory();
        var json = <String, dynamic>{
          'total_listening_time_ms': _data.totalListeningTimeMs,
          'complete_song_listens': _data.completeSongListens,
          'first_played_song_id': _data.firstPlayedSongId,
          'first_played_date': _data.firstPlayedDate,
          'song_play_counts': _data.songPlayCounts.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
          'song_cumulative_listen_ms': _data.songCumulativeListenMs.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
          'playlist_play_counts': _data.playlistPlayCounts,
          'daily_listening_ms': _data.dailyListeningMs,
          'weekly_play_counts': _data.weeklyPlayCounts.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
          'shuffle_session_starts': _data.shuffleSessionStarts,
          'song_skip_counts': _data.songSkipCounts.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
          'song_restart_counts': _data.songRestartCounts.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
        };

        var file = File('${appDir.path}/listening_stats.json');
        await file.writeAsString(jsonEncode(json), flush: true);
        _dirty = false;
      } while (_hasPendingSave);
    } catch (_) {}
    _isSaving = false;
  }

  void _markDirty() {
    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 30), _save);
  }
}
