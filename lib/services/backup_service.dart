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

  /// The music library is empty (not scanned yet), so songs cannot be
  /// exported or matched. Nothing was written.
  libraryEmpty,

  /// The backup refers to songs but none of them are in this library, which
  /// usually means the wrong music folder is selected. Nothing was written.
  noMatchingSongs,

  /// Current data (library or playlists) could not be read. Nothing was
  /// written.
  readFailed,

  /// Writing the restored data failed. Everything already written was
  /// rolled back as far as possible.
  writeFailed,
}

/// Thrown when a backup cannot be exported or restored. For every kind except
/// [BackupErrorKind.writeFailed] nothing has been written.
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

  /// Whether the file had a settings section at all.
  final bool hasSettings;
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
    this.hasSettings = true,
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
    var library = await _readLibrary();
    if (library.isEmpty) {
      throw const BackupException(
        BackupErrorKind.libraryEmpty,
        'The library is empty; scan the music folder first',
      );
    }
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
      for (var playlist in await _readPlaylists())
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
        'albums': await _readFavoriteMap(_favoriteAlbumsKey),
        'artists': await _readFavoriteMap(_favoriteArtistsKey),
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

  static const _favoriteAlbumsKey = 'favorite_albums_map';
  static const _favoriteArtistsKey = 'favorite_artists_map';

  /// Older versions stored favorite albums and artists as plain lists.
  static const _legacyFavoriteKeys = {
    _favoriteAlbumsKey: 'favorite_albums',
    _favoriteArtistsKey: 'favorite_artists',
  };

  /// Reads a favorite albums/artists map, falling back to the legacy list
  /// the player still migrates from (see `PlayerPersistence.loadSettings`).
  Future<Map<String, int>> _readFavoriteMap(String key) async {
    try {
      var raw = await _prefs.getString(key);
      if (raw != null) return Map<String, int>.from(jsonDecode(raw) as Map);
      var legacy = await _prefs.getStringList(_legacyFavoriteKeys[key]!);
      if (legacy == null) return {};
      var now = DateTime.now().millisecondsSinceEpoch;
      return {for (var k in legacy) k: now};
    } catch (_) {
      return {};
    }
  }

  Future<List<Song>> _readLibrary() async {
    try {
      return await _scanner.readLibrarySongs();
    } catch (e) {
      throw BackupException(BackupErrorKind.readFailed, 'library: $e');
    }
  }

  Future<List<Playlist>> _readPlaylists() async {
    try {
      return await _scanner.getPlaylistsStrict();
    } catch (e) {
      throw BackupException(BackupErrorKind.readFailed, 'playlists: $e');
    }
  }

  /// Strips a leading UTF-8 byte order mark, which some editors add.
  static String _stripBom(String content) =>
      content.startsWith('\uFEFF') ? content.substring(1) : content;

  /// Decodes the raw bytes of a picked backup file.
  static String decodeFile(List<int> bytes) =>
      _stripBom(utf8.decode(bytes, allowMalformed: false));

  // ── Parse and validate ──────────────────────────────────────────────────

  /// Parses and validates a whole backup file. Throws [BackupException] on
  /// any problem; never writes anything.
  static BackupDocument parse(String content) {
    Object? decoded;
    try {
      decoded = jsonDecode(_stripBom(content));
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
      hasSettings: rawSettings != null,
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

  /// Effect keys the player removes while effects are off. A backup made in
  /// that state does not contain them, so they are removed on restore too.
  static const _removedWhenAbsent = [
    'mfx_preset_name',
    'mfx_preset',
    'mfx_customEqGains',
  ];

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

  /// Restores an already parsed [doc].
  ///
  /// Everything is read and planned first; an empty library, a backup whose
  /// songs match nothing, or unreadable current data aborts before anything
  /// is written. If a write fails, everything written so far is rolled back
  /// and a [BackupErrorKind.writeFailed] exception is thrown.
  Future<BackupRestoreResult> restoreDocument(BackupDocument doc) async {
    _stats.pauseRecording();
    try {
      return await _restore(doc);
    } finally {
      _stats.resumeRecording();
    }
  }

  Future<BackupRestoreResult> _restore(BackupDocument doc) async {
    // ── Read and plan; nothing is written in this part. ──
    var library = await _readLibrary();
    if (library.isEmpty) {
      throw const BackupException(
        BackupErrorKind.libraryEmpty,
        'The library is empty; scan the music folder first',
      );
    }
    var idMap = matchSongs(doc.songs.values, library);
    var referenced = doc.referencedSongIds;
    if (referenced.isNotEmpty && !referenced.any(idMap.containsKey)) {
      throw const BackupException(
        BackupErrorKind.noMatchingSongs,
        'None of the backed-up songs are in this library',
      );
    }
    var unmatched = referenced.where((id) => !idMap.containsKey(id)).length;

    // Pref writes; a null value removes the key.
    var prefWrites = <String, Object?>{...doc.settings};
    if (doc.hasSettings) {
      for (var key in _removedWhenAbsent) {
        if (!doc.settings.containsKey(key)) prefWrites[key] = null;
      }
    }

    var favoriteGroupsRestored = 0;
    for (var (key, backup) in [
      (_favoriteAlbumsKey, doc.favoriteAlbums),
      (_favoriteArtistsKey, doc.favoriteArtists),
    ]) {
      if (backup == null) continue;
      favoriteGroupsRestored += backup.length;
      var current = await _readFavoriteMap(key);
      // Existing entries keep their date so a second restore changes nothing.
      var merged = {...backup, ...current};
      var stored = await _prefs.getString(key);
      if (merged.length != current.length ||
          (stored == null && merged.isNotEmpty)) {
        prefWrites[key] = jsonEncode(merged);
      }
    }

    List<Playlist>? playlistsBefore;
    List<Playlist>? playlistsAfter;
    var hadStoredPlaylists = false;
    var playlistsRestored = 0;
    if (doc.playlists case var backupPlaylists?
        when backupPlaylists.isNotEmpty) {
      playlistsBefore = await _readPlaylists();
      hadStoredPlaylists = await _prefs.containsKey('playlists_json');
      playlistsAfter = List<Playlist>.of(playlistsBefore);
      var indexById = {
        for (var (i, playlist) in playlistsAfter.indexed) playlist.id: i,
      };
      for (var backup in backupPlaylists) {
        var existingIndex = indexById[backup.id];
        var restored = Playlist(
          id: backup.id,
          name: backup.name,
          songIds: _remapIds(backup.songIds, idMap),
          description: backup.description,
          // Cover images are files on this device and are not backed up.
          coverImagePath: existingIndex == null
              ? null
              : playlistsAfter[existingIndex].coverImagePath,
        );
        if (existingIndex == null) {
          indexById[backup.id] = playlistsAfter.length;
          playlistsAfter.add(restored);
        } else {
          playlistsAfter[existingIndex] = restored;
        }
        playlistsRestored++;
      }
    }

    var favoriteDates = <int, int?>{
      for (var entry in (doc.favoriteSongs ?? const <int, int?>{}).entries)
        ?idMap[entry.key]: entry.value,
    };
    var needsFavoriteWrite = library.any(
      (s) => !s.isFavorite && favoriteDates.containsKey(s.id),
    );

    Map<String, dynamic>? statsAfter;
    Map<String, dynamic>? statsBefore;
    if (doc.stats case var stats?) {
      statsAfter = _remapStats(stats, idMap);
      statsBefore = await _stats.exportSnapshot();
    }

    var prefsBefore = await _prefs.getAll(allowList: prefWrites.keys.toSet());

    // ── Write, undoing every started step if one fails. ──
    var rollbacks = <Future<void> Function()>[];
    try {
      rollbacks.add(() => _restorePrefs(prefsBefore, prefWrites.keys));
      for (var entry in prefWrites.entries) {
        var value = entry.value;
        if (value == null) {
          await _prefs.remove(entry.key);
        } else {
          await _writePref(entry.key, value);
        }
      }

      if (playlistsAfter != null) {
        var before = playlistsBefore!;
        rollbacks.add(
          () => hadStoredPlaylists
              ? _scanner.savePlaylistsStrict(before)
              : _scanner.clearStoredPlaylistsStrict(),
        );
        await _scanner.savePlaylistsStrict(playlistsAfter);
      }

      if (needsFavoriteWrite) {
        var before = library;
        rollbacks.add(() => _scanner.writeLibrarySongs(before));
        library = await _scanner.mergeFavoriteSongs(favoriteDates);
      }

      if (statsAfter != null) {
        var before = statsBefore!;
        rollbacks.add(() => _stats.replaceWithSnapshot(before));
        await _stats.replaceWithSnapshot(statsAfter);
      }
    } catch (e) {
      for (var rollback in rollbacks.reversed) {
        try {
          await rollback();
        } catch (_) {}
      }
      throw BackupException(BackupErrorKind.writeFailed, '$e');
    }

    return BackupRestoreResult(
      playlistsRestored: playlistsRestored,
      favoriteSongsRestored: favoriteDates.length,
      favoriteAlbumsAndArtistsRestored: favoriteGroupsRestored,
      unmatchedSongs: unmatched,
      settingsRestored: doc.settings.length,
      statsRestored: statsAfter != null,
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
      case List<dynamic> v:
        await _prefs.setStringList(key, List<String>.from(v));
    }
  }

  /// Puts [keys] back to the values in [before], removing the ones that were
  /// not set.
  Future<void> _restorePrefs(
    Map<String, Object?> before,
    Iterable<String> keys,
  ) async {
    for (var key in keys) {
      var value = before[key];
      if (value == null) {
        await _prefs.remove(key);
      } else {
        await _writePref(key, value);
      }
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

  /// Maps backed-up song ids onto ids in [library], one to one.
  ///
  /// Runs three passes, each over the backed-up songs in id order: the exact
  /// file path; the same title, artist and album with a near-equal duration;
  /// and the same folder and file name (a library moved to another root)
  /// when the title or artist also agrees. A library song is claimed by the
  /// first match only, so a later backed-up song that would land on it stays
  /// unmatched. Ties go to the closest duration, then the lowest library id.
  static Map<int, int> matchSongs(
    Iterable<BackupSongRef> refs,
    List<Song> library,
  ) {
    var sortedRefs = refs.toList()..sort((a, b) => a.id.compareTo(b.id));
    var sortedLibrary = List<Song>.of(library)
      ..sort((a, b) => a.id.compareTo(b.id));

    var byPath = <String, Song>{};
    var byTags = <String, List<Song>>{};
    var byTail = <String, List<Song>>{};
    for (var song in sortedLibrary) {
      byPath.putIfAbsent(song.filePath, () => song);
      byTags
          .putIfAbsent(_tagKey(song.title, song.artist, song.album), () => [])
          .add(song);
      byTail.putIfAbsent(_pathTail(song.filePath), () => []).add(song);
    }

    var result = <int, int>{};
    var claimed = <int>{};

    void matchPass(Song? Function(BackupSongRef ref) find) {
      for (var ref in sortedRefs) {
        if (result.containsKey(ref.id)) continue;
        var song = find(ref);
        if (song != null && claimed.add(song.id)) result[ref.id] = song.id;
      }
    }

    matchPass((ref) => byPath[ref.path]);
    matchPass(
      (ref) => _closestByDuration(
        byTags[_tagKey(ref.title, ref.artist, ref.album)],
        ref.durationMs,
        claimed,
      ),
    );
    matchPass(
      (ref) => _closestByDuration(
        byTail[_pathTail(ref.path)]?.where(
          (song) =>
              _norm(song.title) == _norm(ref.title) ||
              _norm(song.artist) == _norm(ref.artist),
        ),
        ref.durationMs,
        claimed,
      ),
    );
    return result;
  }

  static String _norm(String value) => value.trim().toLowerCase();

  static String _tagKey(String title, String artist, String album) =>
      '${_norm(title)}\u0000${_norm(artist)}\u0000${_norm(album)}';

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

  /// The unclaimed candidate closest in duration (within tolerance); ties go
  /// to the first candidate, i.e. the lowest id.
  static Song? _closestByDuration(
    Iterable<Song>? candidates,
    int durationMs,
    Set<int> claimed,
  ) {
    if (candidates == null) return null;
    Song? best;
    var bestDiff = _durationToleranceMs + 1;
    for (var song in candidates) {
      if (claimed.contains(song.id)) continue;
      var diff = (song.duration.inMilliseconds - durationMs).abs();
      if (diff < bestDiff) {
        best = song;
        bestDiff = diff;
      }
    }
    return best;
  }
}
