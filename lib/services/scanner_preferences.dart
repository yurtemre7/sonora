part of 'music_scanner.dart';

/// Scan folder, sync bookkeeping and sort preferences.
extension ScannerPreferences on MusicScanner {
  /// Reads the configured scan folder path from shared preferences.
  Future<String?> getScanFolder() async {
    try {
      return await _prefs.getString('scan_folder_path');
    } catch (_) {
      return null;
    }
  }

  /// Writes the configured scan folder path to shared preferences.
  Future<void> setScanFolder(String? path) async {
    try {
      if (path == null) {
        await _prefs.remove('scan_folder_path');
      } else {
        await _prefs.setString('scan_folder_path', path);
      }
    } catch (_) {}
  }

  /// Reads the last sync time from shared preferences.
  Future<String?> getLastSyncTime() async {
    try {
      return await _prefs.getString('last_sync_time');
    } catch (_) {
      return null;
    }
  }

  /// Writes the last sync time to shared preferences.
  Future<void> setLastSyncTime(String? timestamp) async {
    try {
      if (timestamp == null) {
        await _prefs.remove('last_sync_time');
      } else {
        await _prefs.setString('last_sync_time', timestamp);
      }
    } catch (_) {}
  }

  /// Reads the last sync epoch milliseconds timestamp.
  Future<int?> getLastSyncTimestamp() async {
    try {
      return await _prefs.getInt('last_sync_timestamp');
    } catch (_) {
      return null;
    }
  }

  /// Writes the last sync epoch milliseconds timestamp.
  Future<void> setLastSyncTimestamp(int? timestamp) async {
    try {
      if (timestamp == null) {
        await _prefs.remove('last_sync_timestamp');
      } else {
        await _prefs.setInt('last_sync_timestamp', timestamp);
      }
    } catch (_) {}
  }

  /// Reads the sorting configuration from shared preferences.
  Future<Map<String, dynamic>> getSortSettings() async {
    try {
      var sortBy = await _prefs.getString('sort_by') ?? 'title';
      var sortAscending = await _prefs.getBool('sort_ascending') ?? true;
      return {'sortBy': sortBy, 'sortAscending': sortAscending};
    } catch (_) {
      return {'sortBy': 'title', 'sortAscending': true};
    }
  }

  /// Writes the sorting configuration to shared preferences.
  Future<void> saveSortSettings(String sortBy, bool sortAscending) async {
    try {
      await _prefs.setString('sort_by', sortBy);
      await _prefs.setBool('sort_ascending', sortAscending);
    } catch (_) {}
  }

  /// Reads per-tab sorting configuration from shared preferences.
  Future<Map<String, dynamic>> getTabSortSettings(String tab) async {
    try {
      var defaultBy = tab == 'songs'
          ? 'title'
          : tab == 'albums'
          ? 'name'
          : 'name';
      var sortBy = await _prefs.getString('sort_by_$tab') ?? defaultBy;
      var sortAscending = await _prefs.getBool('sort_ascending_$tab') ?? true;
      return {'sortBy': sortBy, 'sortAscending': sortAscending};
    } catch (_) {
      return {'sortBy': 'title', 'sortAscending': true};
    }
  }

  /// Writes per-tab sorting configuration to shared preferences.
  Future<void> saveTabSortSettings(
    String tab,
    String sortBy,
    bool sortAscending,
  ) async {
    try {
      await _prefs.setString('sort_by_$tab', sortBy);
      await _prefs.setBool('sort_ascending_$tab', sortAscending);
    } catch (_) {}
  }

  /// Helper to sort list of songs by specified sort configurations.
  void sortSongs(List<Song> songs, String sortBy, bool sortAscending) {
    songs.sort((a, b) {
      int comparison;
      if (sortBy == 'artist') {
        comparison = a.artistLower.compareTo(b.artistLower);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'duration') {
        comparison = a.duration.compareTo(b.duration);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'recent') {
        var aTime = a.lastModifiedMs ?? 0;
        var bTime = b.lastModifiedMs ?? 0;
        comparison = bTime.compareTo(aTime);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else {
        comparison = a.titleLower.compareTo(b.titleLower);
      }

      if (comparison == 0) {
        comparison = a.id.compareTo(b.id);
      }
      return sortAscending ? comparison : -comparison;
    });
  }

  Future<String> getSyncMethod() async {
    return await _prefs.getString('sync_method') ?? 'parallel';
  }

  Future<void> setSyncMethod(String method) async {
    await _prefs.setString('sync_method', method);
  }

  Future<int?> getLastSyncDuration(String method) async {
    return await _prefs.getInt('last_sync_duration_$method');
  }

  Future<void> setLastSyncDuration(String method, int durationMs) async {
    await _prefs.setInt('last_sync_duration_$method', durationMs);
  }
}
