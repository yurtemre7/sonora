import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/stats_service.dart';

/// Why a backup file could not be restored.
enum BackupErrorKind {
  /// The file is not valid JSON.
  invalidJson,

  /// The file is JSON but not a Sonora backup.
  notABackup,

  /// The file was written by a newer (or unknown) backup format version.
  unsupportedVersion,

  /// The file claims to be a Sonora backup but a section is malformed.
  malformed,
}

/// Thrown when a backup file fails validation. Nothing has been written when
/// this is thrown.
class BackupException implements Exception {
  final BackupErrorKind kind;
  final String message;

  const BackupException(this.kind, this.message);

  @override
  String toString() => 'BackupException(${kind.name}): $message';
}

/// Summary of a finished restore.
class BackupRestoreResult {
  /// Number of playlists written from the backup (created or replaced).
  final int playlistsRestored;

  /// Number of favorite songs from the backup that matched the library.
  final int favoriteSongsRestored;

  /// Number of favorite albums and artists in the backup.
  final int favoriteAlbumsAndArtistsRestored;

  /// Number of distinct backed-up songs that matched nothing in the current
  /// library. References to them were dropped.
  final int unmatchedSongs;

  /// Number of settings written.
  final int settingsRestored;

  /// Whether listening statistics were replaced.
  final bool statsRestored;

  /// The library cache after the restore (favorite flags applied).
  final List<Song> songs;

  const BackupRestoreResult({
    required this.playlistsRestored,
    required this.favoriteSongsRestored,
    required this.favoriteAlbumsAndArtistsRestored,
    required this.unmatchedSongs,
    required this.settingsRestored,
    required this.statsRestored,
    required this.songs,
  });
}

enum _PrefType { boolean, integer, decimal, string, stringList }

/// A song as it was identified on the device that wrote the backup.
class BackupSongRef {
  final int id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;

  const BackupSongRef({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
  });

  factory BackupSongRef.fromSong(Song song) => BackupSongRef(
    id: song.id,
    path: song.filePath,
    title: song.title,
    artist: song.artist,
    album: song.album,
    durationMs: song.duration.inMilliseconds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
  };
}

class BackupPlaylist {
  final String id;
  final String name;
  final String? description;
  final List<int> songIds;

  const BackupPlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.songIds,
  });
}

class BackupStats {
  final int completeSongListens;
  final int firstPlayedSongId;
  final String? firstPlayedDate;
  final int shuffleSessionStarts;
  final Map<int, int> songPlayCounts;
  final Map<String, int> playlistPlayCounts;
  final Map<int, int> weeklyPlayCounts;
  final Map<int, int> songSkipCounts;
  final Map<int, int> songRestartCounts;
  final Map<int, int> songLastPlayedAtMs;

  const BackupStats({
    required this.completeSongListens,
    required this.firstPlayedSongId,
    required this.firstPlayedDate,
    required this.shuffleSessionStarts,
    required this.songPlayCounts,
    required this.playlistPlayCounts,
    required this.weeklyPlayCounts,
    required this.songSkipCounts,
    required this.songRestartCounts,
    required this.songLastPlayedAtMs,
  });

  Iterable<int> get songIds sync* {
    if (firstPlayedSongId >= 0) yield firstPlayedSongId;
    yield* songPlayCounts.keys;
    yield* songSkipCounts.keys;
    yield* songRestartCounts.keys;
    yield* songLastPlayedAtMs.keys;
  }
}

/// A fully parsed and validated backup. Sections that are `null` were not in
/// the file and are left untouched by a restore.
class BackupDocument {
  final DateTime createdAt;
  final String appVersion;
  final Map<int, BackupSongRef> songs;
  final Map<String, Object> settings;
  final List<BackupPlaylist>? playlists;
  final Map<int, int?>? favoriteSongs;
  final Map<String, int>? favoriteAlbums;
  final Map<String, int>? favoriteArtists;
  final BackupStats? stats;

  const BackupDocument({
    required this.createdAt,
    required this.appVersion,
    required this.songs,
    required this.settings,
    required this.playlists,
    required this.favoriteSongs,
    required this.favoriteAlbums,
    required this.favoriteArtists,
    required this.stats,
  });

  /// Every song id the sections refer to.
  Set<int> get referencedSongIds => {
    for (var playlist in playlists ?? const <BackupPlaylist>[])
      ...playlist.songIds,
    ...?favoriteSongs?.keys,
    ...?stats?.songIds,
  };
}

/// Exports the user's personal data (settings, playlists, favorites and
/// listening statistics) to one JSON document and restores it again.
///
/// Song references are stored together with their path and tags so they can
/// be remapped onto the library of another device, where song ids differ.
class BackupService {
  BackupService({
    MusicScanner? scanner,
    StatsService? stats,
    SharedPreferencesAsync? prefs,
  }) : _scanner = scanner ?? MusicScanner(),
       _stats = stats ?? StatsService(),
       _prefs = prefs ?? SharedPreferencesAsync();

  final MusicScanner _scanner;
  final StatsService _stats;
  final SharedPreferencesAsync _prefs;

  static const format = 'sonora-backup';
  static const version = 1;

  /// Durations closer than this count as the same song when matching by tags.
  static const _durationToleranceMs = 2000;

  /// User preferences that are worth carrying to another install. Caches,
  /// session state, sync bookkeeping and device-specific paths are left out.
  static const _settingKeys = <String, _PrefType>{
    // Appearance
    'theme_mode': _PrefType.string,
    'use_dynamic_theme': _PrefType.boolean,
    'use_material_you': _PrefType.boolean,
    'amoled_dark': _PrefType.boolean,
    'dynamic_theme_color': _PrefType.integer,
    'default_theme_color': _PrefType.integer,
    'now_playing_style': _PrefType.string,
    'show_visualizer': _PrefType.boolean,
    'immersive_mode': _PrefType.boolean,
    'prefer_local_artist_images': _PrefType.boolean,
    'app_locale': _PrefType.string,
    'default_start_page': _PrefType.integer,
    'user_name': _PrefType.string,
    'use_greeting_title': _PrefType.boolean,
    // Sleep timer
    'sleep_timer_default_minutes': _PrefType.integer,
    'sleep_timer_fade_out_seconds': _PrefType.integer,
    'sleep_timer_finish_song': _PrefType.boolean,
    // Sorting
    'song_sort_by': _PrefType.string,
    'song_sort_ascending': _PrefType.boolean,
    'album_sort_by': _PrefType.string,
    'album_sort_ascending': _PrefType.boolean,
    'artist_sort_by': _PrefType.string,
    'artist_sort_ascending': _PrefType.boolean,
    'playlist_sort_by': _PrefType.string,
    'playlist_sort_ascending': _PrefType.boolean,
    'favorites_sort_by': _PrefType.string,
    'favorites_sort_ascending': _PrefType.boolean,
    'song_activity_view': _PrefType.string,
    'sort_by': _PrefType.string,
    'sort_ascending': _PrefType.boolean,
    'sort_by_songs': _PrefType.string,
    'sort_ascending_songs': _PrefType.boolean,
    // Behavior
    'keep_playing_on_close': _PrefType.boolean,
    'restore_last_played_song': _PrefType.boolean,
    'pause_on_duck': _PrefType.boolean,
    'replay_gain_mode': _PrefType.string,
    'pause_on_disconnect': _PrefType.boolean,
    'resume_on_connect': _PrefType.boolean,
    'filter_title_features': _PrefType.boolean,
    'filter_title_artist': _PrefType.boolean,
    'auto_check_updates': _PrefType.boolean,
    // Playback and effects
    'volume': _PrefType.decimal,
    'speed': _PrefType.decimal,
    'mfx_preset_name': _PrefType.string,
    'mfx_preset': _PrefType.decimal,
    'mfx_isSlowed': _PrefType.boolean,
    'mfx_isSuperSlowed': _PrefType.boolean,
    'mfx_isSpedUp': _PrefType.boolean,
    'mfx_isSuperSpedUp': _PrefType.boolean,
    'mfx_isNightcore': _PrefType.boolean,
    'mfx_isReverbEnabled': _PrefType.boolean,
    'mfx_isLofiEnabled': _PrefType.boolean,
    'mfx_isBassBoostEnabled': _PrefType.boolean,
    'mfx_isCustomEqEnabled': _PrefType.boolean,
    'mfx_bluetoothMfxPatch': _PrefType.boolean,
    'mfx_customEqGains': _PrefType.stringList,
    'eq_current_preset': _PrefType.string,
    'eq_custom_gains': _PrefType.stringList,
    'eq_enabled': _PrefType.boolean,
  };

  /// Suggested file name for a backup written on [date].
  static String defaultFileName(DateTime date) {
    var month = date.month.toString().padLeft(2, '0');
    var day = date.day.toString().padLeft(2, '0');
    return 'sonora-backup-${date.year}-$month-$day.json';
  }

  // ── Export ──────────────────────────────────────────────────────────────

  /// Builds the backup document as a JSON-encodable map.
  Future<Map<String, dynamic>> buildBackup({
    required String appVersion,
    DateTime? now,
  }) async {
    var library = await _scanner.readLibrarySongs();
    var songById = {for (var s in library) s.id: s};
    var referenced = <int>{};

    bool keep(int id) {
      if (!songById.containsKey(id)) return false;
      referenced.add(id);
      return true;
    }

    var settings = <String, dynamic>{};
    for (var entry in _settingKeys.entries) {
      var value = await _readPref(entry.key, entry.value);
      if (value != null) settings[entry.key] = value;
    }

    var playlists = [
      for (var playlist in await _scanner.getPlaylists())
        {
          'id': playlist.id,
          'name': playlist.name,
          'description': playlist.description,
          'songIds': [
            for (var id in playlist.songIds)
              if (keep(id)) id,
          ],
        },
    ];

    var favoriteSongs = [
      for (var song in library)
        if (song.isFavorite && keep(song.id))
          {'id': song.id, 'favoriteDateMs': song.favoriteDateMs},
    ];

    var stats = await _stats.exportSnapshot();
    for (var key in const [
      'song_play_counts',
      'song_skip_counts',
      'song_restart_counts',
      'song_last_played_at_ms',
    ]) {
      var counts = stats[key];
      if (counts is Map<String, dynamic>) {
        counts.removeWhere((id, _) => !keep(int.tryParse(id) ?? -1));
      }
    }
    var firstPlayed = stats['first_played_song_id'];
    if (firstPlayed is int && firstPlayed >= 0 && !keep(firstPlayed)) {
      stats['first_played_song_id'] = -1;
    }

    return {
      'format': format,
      'version': version,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'appVersion': appVersion,
      'songs': [
        for (var id in referenced)
          BackupSongRef.fromSong(songById[id]!).toJson(),
      ],
      'settings': settings,
      'playlists': playlists,
      'favorites': {
        'songs': favoriteSongs,
        'albums': await _readFavoriteMap('favorite_albums_map'),
        'artists': await _readFavoriteMap('favorite_artists_map'),
      },
      'stats': stats,
    };
  }

  /// Builds the backup and encodes it as pretty-printed JSON.
  Future<String> exportToJson({required String appVersion}) async {
    var backup = await buildBackup(appVersion: appVersion);
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<Object?> _readPref(String key, _PrefType type) async {
    try {
      return switch (type) {
        _PrefType.boolean => await _prefs.getBool(key),
        _PrefType.integer => await _prefs.getInt(key),
        _PrefType.decimal => await _prefs.getDouble(key),
        _PrefType.string => await _prefs.getString(key),
        _PrefType.stringList => await _prefs.getStringList(key),
      };
    } catch (_) {
      // Stored under another type by an old version; not worth backing up.
      return null;
    }
  }

  Future<Map<String, int>> _readFavoriteMap(String key) async {
    try {
      var raw = await _prefs.getString(key);
      if (raw == null) return {};
      return Map<String, int>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  // ── Parse and validate ──────────────────────────────────────────────────

  /// Parses and validates a whole backup file. Throws [BackupException] on
  /// any problem; never writes anything.
  static BackupDocument parse(String content) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw BackupException(BackupErrorKind.invalidJson, e.message);
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
      throw const BackupException(
        BackupErrorKind.notABackup,
        'Missing "format": "sonora-backup"',
      );
    }
    var fileVersion = decoded['version'];
    if (fileVersion != version) {
      throw BackupException(
        BackupErrorKind.unsupportedVersion,
        'Unsupported backup version: $fileVersion',
      );
    }

    var createdAt = DateTime.tryParse(
      _string(decoded['createdAt'], 'createdAt'),
    );
    if (createdAt == null) {
      throw const BackupException(BackupErrorKind.malformed, 'createdAt');
    }

    var songs = <int, BackupSongRef>{};
    for (var (i, raw) in _list(decoded['songs'] ?? [], 'songs').indexed) {
      var path = 'songs[$i]';
      var map = _map(raw, path);
      var ref = BackupSongRef(
        id: _int(map['id'], '$path.id'),
        path: _string(map['path'], '$path.path'),
        title: _string(map['title'], '$path.title'),
        artist: _string(map['artist'], '$path.artist'),
        album: _string(map['album'], '$path.album'),
        durationMs: _int(map['durationMs'], '$path.durationMs'),
      );
      songs[ref.id] = ref;
    }

    var settings = <String, Object>{};
    var rawSettings = decoded['settings'];
    if (rawSettings != null) {
      for (var entry in _map(rawSettings, 'settings').entries) {
        var type = _settingKeys[entry.key];
        // Keys this version does not know about are ignored, not rejected,
        // so a backup from a newer build still restores what it can.
        if (type == null || entry.value == null) continue;
        settings[entry.key] = _settingValue(
          entry.value,
          type,
          'settings.${entry.key}',
        );
      }
    }

    List<BackupPlaylist>? playlists;
    var rawPlaylists = decoded['playlists'];
    if (rawPlaylists != null) {
      playlists = [];
      for (var (i, raw) in _list(rawPlaylists, 'playlists').indexed) {
        var path = 'playlists[$i]';
        var map = _map(raw, path);
        var description = map['description'];
        if (description != null && description is! String) {
          throw BackupException(BackupErrorKind.malformed, '$path.description');
        }
        playlists.add(
          BackupPlaylist(
            id: _string(map['id'], '$path.id'),
            name: _string(map['name'], '$path.name'),
            description: description as String?,
            songIds: [
              for (var (j, id) in _list(
                map['songIds'],
                '$path.songIds',
              ).indexed)
                _int(id, '$path.songIds[$j]'),
            ],
          ),
        );
      }
    }

    Map<int, int?>? favoriteSongs;
    Map<String, int>? favoriteAlbums;
    Map<String, int>? favoriteArtists;
    var rawFavorites = decoded['favorites'];
    if (rawFavorites != null) {
      var favorites = _map(rawFavorites, 'favorites');
      favoriteSongs = {};
      for (var (i, raw) in _list(
        favorites['songs'] ?? [],
        'favorites.songs',
      ).indexed) {
        var path = 'favorites.songs[$i]';
        var map = _map(raw, path);
        var date = map['favoriteDateMs'];
        favoriteSongs[_int(map['id'], '$path.id')] = date == null
            ? null
            : _int(date, '$path.favoriteDateMs');
      }
      favoriteAlbums = _intMap(favorites['albums'] ?? {}, 'favorites.albums');
      favoriteArtists = _intMap(
        favorites['artists'] ?? {},
        'favorites.artists',
      );
    }

    BackupStats? stats;
    var rawStats = decoded['stats'];
    if (rawStats != null) {
      var map = _map(rawStats, 'stats');
      var firstDate = map['first_played_date'];
      if (firstDate != null && firstDate is! String) {
        throw const BackupException(
          BackupErrorKind.malformed,
          'stats.first_played_date',
        );
      }
      int optionalInt(String key, int fallback) =>
          map[key] == null ? fallback : _int(map[key], 'stats.$key');
      Map<int, int> idMap(String key) => _idKeyedMap(map[key], 'stats.$key');
      stats = BackupStats(
        completeSongListens: optionalInt('complete_song_listens', 0),
        firstPlayedSongId: optionalInt('first_played_song_id', -1),
        firstPlayedDate: firstDate as String?,
        shuffleSessionStarts: optionalInt('shuffle_session_starts', 0),
        songPlayCounts: idMap('song_play_counts'),
        playlistPlayCounts: _intMap(
          map['playlist_play_counts'] ?? {},
          'stats.playlist_play_counts',
        ),
        weeklyPlayCounts: idMap('weekly_play_counts'),
        songSkipCounts: idMap('song_skip_counts'),
        songRestartCounts: idMap('song_restart_counts'),
        songLastPlayedAtMs: idMap('song_last_played_at_ms'),
      );
    }

    return BackupDocument(
      createdAt: createdAt,
      appVersion: decoded['appVersion'] is String
          ? decoded['appVersion'] as String
          : '',
      songs: songs,
      settings: settings,
      playlists: playlists,
      favoriteSongs: favoriteSongs,
      favoriteAlbums: favoriteAlbums,
      favoriteArtists: favoriteArtists,
      stats: stats,
    );
  }

  static Never _malformed(String path) =>
      throw BackupException(BackupErrorKind.malformed, path);

  static Map<String, dynamic> _map(Object? value, String path) =>
      value is Map<String, dynamic> ? value : _malformed(path);

  static List<dynamic> _list(Object? value, String path) =>
      value is List<dynamic> ? value : _malformed(path);

  static String _string(Object? value, String path) =>
      value is String ? value : _malformed(path);

  static int _int(Object? value, String path) =>
      value is int ? value : _malformed(path);

  static Map<String, int> _intMap(Object? value, String path) => {
    for (var entry in _map(value, path).entries)
      entry.key: _int(entry.value, '$path.${entry.key}'),
  };

  static Map<int, int> _idKeyedMap(Object? value, String path) {
    if (value == null) return {};
    return {
      for (var entry in _map(value, path).entries)
        (int.tryParse(entry.key) ?? _malformed('$path.${entry.key}')): _int(
          entry.value,
          '$path.${entry.key}',
        ),
    };
  }

  static Object _settingValue(Object? value, _PrefType type, String path) {
    switch (type) {
      case _PrefType.boolean:
        if (value is bool) return value;
      case _PrefType.integer:
        if (value is int) return value;
      case _PrefType.decimal:
        if (value is num) return value.toDouble();
      case _PrefType.string:
        if (value is String) return value;
      case _PrefType.stringList:
        if (value is List && value.every((e) => e is String)) {
          return List<String>.from(value);
        }
    }
    _malformed(path);
  }

  // ── Restore ─────────────────────────────────────────────────────────────

  /// Validates [content] completely, then restores it.
  ///
  /// Settings in the backup replace the stored ones (others are kept),
  /// playlists are merged by id with the backup winning, favorites are
  /// united with the existing ones and statistics are replaced. Running the
  /// same restore twice leaves the same state as running it once.
  Future<BackupRestoreResult> restore(String content) async {
    var document = parse(content);
    return await restoreDocument(document);
  }

  Future<BackupRestoreResult> restoreDocument(BackupDocument doc) async {
    var library = await _scanner.readLibrarySongs();
    var idMap = matchSongs(doc.songs.values, library);
    var unmatched = doc.referencedSongIds
        .where((id) => !idMap.containsKey(id))
        .length;

    // Settings: replace only the keys that are in the backup.
    for (var entry in doc.settings.entries) {
      await _writePref(entry.key, entry.value);
    }

    // Playlists: merge by id, backup wins, others are kept.
    var playlistsRestored = 0;
    if (doc.playlists case var backupPlaylists?) {
      var current = await _scanner.getPlaylists();
      var indexById = {
        for (var (i, playlist) in current.indexed) playlist.id: i,
      };
      for (var backup in backupPlaylists) {
        var songIds = _remapIds(backup.songIds, idMap);
        var existingIndex = indexById[backup.id];
        var restored = Playlist(
          id: backup.id,
          name: backup.name,
          songIds: songIds,
          description: backup.description,
          // Cover images are files on this device and are not backed up.
          coverImagePath: existingIndex == null
              ? null
              : current[existingIndex].coverImagePath,
        );
        if (existingIndex == null) {
          indexById[backup.id] = current.length;
          current.add(restored);
        } else {
          current[existingIndex] = restored;
        }
        playlistsRestored++;
      }
      if (backupPlaylists.isNotEmpty) {
        await _scanner.savePlaylists(current);
      }
    }

    // Favorites: union with what is already there.
    var favoriteSongsRestored = 0;
    var favoriteGroupsRestored = 0;
    if (doc.favoriteSongs case var favoriteSongs?) {
      var dates = <int, int?>{};
      for (var entry in favoriteSongs.entries) {
        var newId = idMap[entry.key];
        if (newId == null) continue;
        var existing = dates[newId];
        var date = entry.value;
        // Two backed-up songs mapped onto one: keep the earlier date.
        dates[newId] = existing == null || (date != null && date < existing)
            ? date
            : existing;
      }
      favoriteSongsRestored = dates.length;
      library = await _scanner.mergeFavoriteSongs(dates);
    }
    if (doc.favoriteAlbums case var albums?) {
      await _mergeFavoriteMap('favorite_albums_map', albums);
      favoriteGroupsRestored += albums.length;
    }
    if (doc.favoriteArtists case var artists?) {
      await _mergeFavoriteMap('favorite_artists_map', artists);
      favoriteGroupsRestored += artists.length;
    }

    // Stats: replace.
    if (doc.stats case var stats?) {
      await _stats.replaceWithSnapshot(_remapStats(stats, idMap));
    }

    return BackupRestoreResult(
      playlistsRestored: playlistsRestored,
      favoriteSongsRestored: favoriteSongsRestored,
      favoriteAlbumsAndArtistsRestored: favoriteGroupsRestored,
      unmatchedSongs: unmatched,
      settingsRestored: doc.settings.length,
      statsRestored: doc.stats != null,
      songs: library,
    );
  }

  Future<void> _writePref(String key, Object value) async {
    switch (value) {
      case bool v:
        await _prefs.setBool(key, v);
      case int v:
        await _prefs.setInt(key, v);
      case double v:
        await _prefs.setDouble(key, v);
      case String v:
        await _prefs.setString(key, v);
      case List<String> v:
        await _prefs.setStringList(key, v);
    }
  }

  Future<void> _mergeFavoriteMap(String key, Map<String, int> backup) async {
    if (backup.isEmpty) return;
    var current = await _readFavoriteMap(key);
    // Existing entries keep their date so a second restore changes nothing.
    var merged = {...backup, ...current};
    if (merged.length != current.length) {
      await _prefs.setString(key, jsonEncode(merged));
    }
  }

  static List<int> _remapIds(List<int> ids, Map<int, int> idMap) {
    var seen = <int>{};
    return [
      for (var id in ids)
        if (idMap[id] case var newId? when seen.add(newId)) newId,
    ];
  }

  static Map<String, dynamic> _remapStats(
    BackupStats stats,
    Map<int, int> idMap,
  ) {
    Map<String, int> remap(Map<int, int> source, int Function(int, int) join) {
      var result = <String, int>{};
      for (var entry in source.entries) {
        var newId = idMap[entry.key];
        if (newId == null) continue;
        result.update(
          newId.toString(),
          (current) => join(current, entry.value),
          ifAbsent: () => entry.value,
        );
      }
      return result;
    }

    int sum(int a, int b) => a + b;
    int latest(int a, int b) => a > b ? a : b;

    return {
      'complete_song_listens': stats.completeSongListens,
      'first_played_song_id': idMap[stats.firstPlayedSongId] ?? -1,
      'first_played_date': stats.firstPlayedDate,
      'song_play_counts': remap(stats.songPlayCounts, sum),
      'playlist_play_counts': Map<String, int>.of(stats.playlistPlayCounts),
      'weekly_play_counts': stats.weeklyPlayCounts.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'shuffle_session_starts': stats.shuffleSessionStarts,
      'song_skip_counts': remap(stats.songSkipCounts, sum),
      'song_restart_counts': remap(stats.songRestartCounts, sum),
      'song_last_played_at_ms': remap(stats.songLastPlayedAtMs, latest),
    };
  }

  // ── Song matching ───────────────────────────────────────────────────────

  /// Maps backed-up song ids onto ids in [library].
  ///
  /// Tries, in order: the exact file path, the same title, artist and album
  /// with a near-equal duration, and finally the same file name inside the
  /// same folder name (a library moved to another root). Songs that match
  /// nothing are left out of the result.
  static Map<int, int> matchSongs(
    Iterable<BackupSongRef> refs,
    List<Song> library,
  ) {
    var byPath = <String, Song>{};
    var byTags = <String, List<Song>>{};
    var byTail = <String, List<Song>>{};
    for (var song in library) {
      byPath[song.filePath] = song;
      byTags
          .putIfAbsent(_tagKey(song.title, song.artist, song.album), () => [])
          .add(song);
      byTail.putIfAbsent(_pathTail(song.filePath), () => []).add(song);
    }

    var result = <int, int>{};
    for (var ref in refs) {
      var match =
          byPath[ref.path] ??
          _closestByDuration(
            byTags[_tagKey(ref.title, ref.artist, ref.album)],
            ref.durationMs,
          ) ??
          _closestByDuration(byTail[_pathTail(ref.path)], ref.durationMs);
      if (match != null) result[ref.id] = match.id;
    }
    return result;
  }

  static String _tagKey(String title, String artist, String album) =>
      '${title.trim().toLowerCase()}\u0000'
      '${artist.trim().toLowerCase()}\u0000'
      '${album.trim().toLowerCase()}';

  /// The last folder plus the file name, separator- and case-insensitive.
  static String _pathTail(String path) {
    var segments = path
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    var start = segments.length > 2 ? segments.length - 2 : 0;
    return segments.sublist(start).join('/').toLowerCase();
  }

  static Song? _closestByDuration(List<Song>? candidates, int durationMs) {
    if (candidates == null) return null;
    Song? best;
    var bestDiff = _durationToleranceMs + 1;
    for (var song in candidates) {
      var diff = (song.duration.inMilliseconds - durationMs).abs();
      if (diff < bestDiff) {
        best = song;
        bestDiff = diff;
      }
    }
    return best;
  }
}
