import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/models/song_activity.dart';

class _StatsData {
  var completeSongListens = 0;
  var firstPlayedSongId = -1;
  String? firstPlayedDate;
  final songPlayCounts = <int, int>{};
  final playlistPlayCounts = <String, int>{};
  final weeklyPlayCounts = <int, int>{};
  var shuffleSessionStarts = 0;
  final songSkipCounts = <int, int>{};
  final songRestartCounts = <int, int>{};
  final songLastPlayedAtMs = <int, int>{};
}

class StatsService extends ChangeNotifier {
  StatsService._();
  static final _instance = StatsService._();
  factory StatsService() => _instance;

  final _data = _StatsData();
  Timer? _debounceTimer;
  var _dirty = false;

  Future<void>? _loadFuture;

  Future<void> ensureLoaded() => _loadFuture ??= _loadAndNotify();

  Future<void> _loadAndNotify() async {
    await _load();
    notifyListeners();
  }

  /// Counts one complete listen of [songId].
  ///
  /// The player calls this once per playthrough, when playback is still
  /// running at the 80% mark of the song. The [playlistId] is optional – when
  /// provided, that playlist receives a play too.
  void recordCompleteListen(int songId, {String? playlistId}) {
    var now = DateTime.now();
    _data.songPlayCounts.update(songId, (v) => v + 1, ifAbsent: () => 1);
    _data.completeSongListens++;
    _data.weeklyPlayCounts.update(
      now.weekday % 7,
      (v) => v + 1,
      ifAbsent: () => 1,
    );

    if (_data.firstPlayedSongId < 0) {
      _data.firstPlayedSongId = songId;
      _data.firstPlayedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    if (playlistId != null) {
      _data.playlistPlayCounts.update(
        playlistId,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }

    _markDirty();
    notifyListeners();
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

  /// Records a meaningful playback session for Recent activity.
  ///
  /// This is intentionally separate from completed-listen counts: a song can
  /// become recent before enough listening time has accrued for a full listen.
  void recordSongPlayed(int songId, {DateTime? at}) {
    var timestamp = (at ?? DateTime.now()).millisecondsSinceEpoch;
    _data.songLastPlayedAtMs[songId] = timestamp;
    _markDirty();
    notifyListeners();
  }

  /// Resets all statistics to zero and persists immediately.
  Future<void> reset() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _data.completeSongListens = 0;
    _data.firstPlayedSongId = -1;
    _data.firstPlayedDate = null;
    _data.songPlayCounts.clear();
    _data.playlistPlayCounts.clear();
    _data.weeklyPlayCounts.clear();
    _data.shuffleSessionStarts = 0;
    _data.songSkipCounts.clear();
    _data.songRestartCounts.clear();
    _data.songLastPlayedAtMs.clear();
    _dirty = true;
    await _save();
    notifyListeners();
  }

  /// Returns a copy of all statistics in their on-disk JSON shape, keyed by
  /// the song ids of this device. Used by the backup export.
  Future<Map<String, dynamic>> exportSnapshot() async {
    await ensureLoaded();
    return jsonDecode(jsonEncode(_toJson())) as Map<String, dynamic>;
  }

  /// Replaces all statistics with [json] (same shape as [exportSnapshot]),
  /// persists them immediately and notifies listeners.
  Future<void> replaceWithSnapshot(Map<String, dynamic> json) async {
    // Let a pending initial load finish first so it cannot overwrite the
    // restored data afterwards.
    await ensureLoaded();
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _applyJson(json);
    _dirty = true;
    await _save();
    notifyListeners();
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_dirty) {
      await _save();
    }
  }

  // ── Getters ─────────────────────────────────────────────────────────────

  int get completeSongListens => _data.completeSongListens;

  int get shuffleSessionStarts => _data.shuffleSessionStarts;

  int get totalSkips => _data.songSkipCounts.values.fold(0, (a, b) => a + b);

  int get totalRestarts =>
      _data.songRestartCounts.values.fold(0, (a, b) => a + b);

  int songSkipCount(int id) => _data.songSkipCounts[id] ?? 0;

  int songRestartCount(int id) => _data.songRestartCounts[id] ?? 0;

  int songPlayCount(int id) => _data.songPlayCounts[id] ?? 0;

  DateTime? songLastPlayedAt(int id) {
    var timestamp = _data.songLastPlayedAtMs[id];
    return timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  List<({Song song, DateTime lastPlayedAt, int listenCount})> recentSongs(
    List<Song> library, {
    int? limit,
  }) {
    if (_data.songLastPlayedAtMs.isEmpty || library.isEmpty) return const [];
    var result =
        library
            .where((song) => _data.songLastPlayedAtMs.containsKey(song.id))
            .map(
              (song) => (
                song: song,
                lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
                  _data.songLastPlayedAtMs[song.id]!,
                ),
                listenCount: _data.songPlayCounts[song.id] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            var comparison = b.lastPlayedAt.compareTo(a.lastPlayedAt);
            return comparison != 0 ? comparison : _compareSongs(a.song, b.song);
          });
    if (limit != null && result.length > limit) {
      return result.take(limit).toList();
    }
    return result;
  }

  List<Song> applyActivityView(List<Song> songs, SongActivityView view) {
    if (view == SongActivityView.all || songs.isEmpty) return songs;

    var result = view == SongActivityView.recentlyPlayed
        ? songs
              .where((song) => _data.songLastPlayedAtMs.containsKey(song.id))
              .toList()
        : List<Song>.from(songs);

    switch (view) {
      case SongActivityView.mostPlayed:
        result.sort((a, b) {
          var countA = _data.songPlayCounts[a.id] ?? 0;
          var countB = _data.songPlayCounts[b.id] ?? 0;
          var comparison = countB.compareTo(countA);
          return comparison != 0 ? comparison : _compareSongs(a, b);
        });
      case SongActivityView.leastPlayed:
        result.sort((a, b) {
          var countA = _data.songPlayCounts[a.id] ?? 0;
          var countB = _data.songPlayCounts[b.id] ?? 0;
          var comparison = countA.compareTo(countB);
          return comparison != 0 ? comparison : _compareSongs(a, b);
        });
      case SongActivityView.recentlyPlayed:
        result.sort((a, b) {
          var timeA = _data.songLastPlayedAtMs[a.id] ?? 0;
          var timeB = _data.songLastPlayedAtMs[b.id] ?? 0;
          var comparison = timeB.compareTo(timeA);
          return comparison != 0 ? comparison : _compareSongs(a, b);
        });
      case SongActivityView.all:
        break;
    }
    return result;
  }

  int _compareSongs(Song a, Song b) {
    var comparison = a.titleLower.compareTo(b.titleLower);
    if (comparison == 0) {
      comparison = a.artistLower.compareTo(b.artistLower);
    }
    if (comparison == 0) comparison = a.id.compareTo(b.id);
    return comparison;
  }

  Map<int, Song> _buildSongMap(List<Song> library) => {
    for (var s in library) s.id: s,
  };

  /// Maps each library song to its album in one pass. Pass the player's
  /// [cachedAlbums] to avoid regrouping the whole library on every call.
  Map<int, AlbumGroup> _albumBySongId(
    List<Song> library,
    List<AlbumGroup>? cachedAlbums,
  ) => {
    for (var group in cachedAlbums ?? buildAlbumGroups(library))
      for (var song in group.songs) song.id: group,
  };

  int albumListenCount(List<Song> library, {List<AlbumGroup>? cachedAlbums}) {
    var albumBySongId = _albumBySongId(library, cachedAlbums);
    var listenedAlbums = <String>{};
    for (var songId in _data.songPlayCounts.keys) {
      var group = albumBySongId[songId];
      if (group != null) {
        listenedAlbums.add('${group.nameLower}|||${group.artistLower}');
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
  topAlbums(int limit, List<Song> library, {List<AlbumGroup>? cachedAlbums}) {
    var albumBySongId = _albumBySongId(library, cachedAlbums);
    var albumCounts = <AlbumGroup, int>{};
    for (var entry in _data.songPlayCounts.entries) {
      var group = albumBySongId[entry.key];
      if (group != null) {
        albumCounts.update(
          group,
          (v) => v + entry.value,
          ifAbsent: () => entry.value,
        );
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
      _applyJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      _clearData();
    }
  }

  void _clearData() {
    _data.completeSongListens = 0;
    _data.firstPlayedSongId = -1;
    _data.firstPlayedDate = null;
    _data.songPlayCounts.clear();
    _data.playlistPlayCounts.clear();
    _data.weeklyPlayCounts.clear();
    _data.shuffleSessionStarts = 0;
    _data.songSkipCounts.clear();
    _data.songRestartCounts.clear();
    _data.songLastPlayedAtMs.clear();
  }

  void _applyJson(Map<String, dynamic> json) {
    _clearData();
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

    var plCounts = json['playlist_play_counts'] as Map<String, dynamic>?;
    if (plCounts != null) {
      _data.playlistPlayCounts.clear();
      for (var e in plCounts.entries) {
        _data.playlistPlayCounts[e.key] = e.value as int;
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

    var lastPlayed = json['song_last_played_at_ms'];
    if (lastPlayed is Map<String, dynamic>) {
      _data.songLastPlayedAtMs.clear();
      for (var entry in lastPlayed.entries) {
        var songId = int.tryParse(entry.key);
        var timestamp = entry.value;
        if (songId != null && timestamp is int && timestamp > 0) {
          _data.songLastPlayedAtMs[songId] = timestamp;
        }
      }
    }
  }

  Map<String, dynamic> _toJson() => {
    'complete_song_listens': _data.completeSongListens,
    'first_played_song_id': _data.firstPlayedSongId,
    'first_played_date': _data.firstPlayedDate,
    'song_play_counts': _data.songPlayCounts.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'playlist_play_counts': Map<String, int>.of(_data.playlistPlayCounts),
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
    'song_last_played_at_ms': _data.songLastPlayedAtMs.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
  };

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
        var json = _toJson();

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
