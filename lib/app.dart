import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/routing/app_router.dart';
import 'package:sonora/screens/home_screen.dart';
import 'package:sonora/screens/onboarding_screen.dart';
import 'package:sonora/services/audio_handler.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/services/permission_service.dart';
import 'package:sonora/theme/app_theme.dart';

class SonoraApp extends StatefulWidget {
  const SonoraApp({super.key, required this.audioHandler});

  final SonoraAudioHandler audioHandler;

  @override
  State<SonoraApp> createState() => _SonoraAppState();
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class _SonoraAppState extends State<SonoraApp> {
  late final PlayerProvider _playerProvider;
  late final _RouterRefreshNotifier _routerRefreshNotifier;
  late final SonoraAppRouter _appRouter;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  List<Song> _songs = [];
  var _isLoading = true;
  var _hasPermission = true;
  String? _scanFolder;
  var _isSyncing = false;
  final _themeProvider = ThemeProvider();
  final _settingsProvider = SettingsProvider();
  var _showOnboarding = false;
  var _showSyncPrompt = false;

  // Sentinel values so the first _syncRouterState() always fires a refresh.
  var _prevIsLoading = false;
  var _prevShowOnboarding = true;
  var _prevHasPermission = false;

  @override
  void initState() {
    super.initState();
    _playerProvider = PlayerProvider(
      audioHandler: widget.audioHandler,
      settingsProvider: _settingsProvider,
    );
    _routerRefreshNotifier = _RouterRefreshNotifier();
    _appRouter = SonoraAppRouter(
      refreshListenable: _routerRefreshNotifier,
      loadingBuilder: _buildLoadingScreen,
      permissionBuilder: _buildPermissionScreen,
      playerProvider: _playerProvider,
      themeProvider: _themeProvider,
      settingsProvider: _settingsProvider,
      buildOnboarding: (context) =>
          OnboardingScreen(onComplete: _completeOnboarding),
      buildHome: (context) => HomeScreen(
        playerProvider: _playerProvider,
        songs: _songs,
        onOpenSettings: () => _openSettings(context),
        scanFolder: _scanFolder,
        onConfigureFolder: _configureScanFolder,
        onCreatePlaylist: _onCreatePlaylist,
        onDeletePlaylist: _onDeletePlaylist,
        onAddSongToPlaylist: _onAddSongToPlaylist,
        onRemoveSongFromPlaylist: _onRemoveSongFromPlaylist,
        onReorderPlaylistSongs: _onReorderPlaylistSongs,
        isSyncing: _isSyncing,
        showSyncPrompt: _showSyncPrompt,
        onResyncNow: _onResyncNow,
        onPostponeSync: _onPostponeSync,
      ),
      onConfigureFolder: _configureScanFolder,
      onResetApp: _resetApp,
      onRetriggerSync: _syncSongsSilently,
      onCreatePlaylist: _onCreatePlaylist,
      onDeletePlaylist: _onDeletePlaylist,
      onAddSongToPlaylist: _onAddSongToPlaylist,
      onRemoveSongFromPlaylist: _onRemoveSongFromPlaylist,
      onReorderPlaylistSongs: _onReorderPlaylistSongs,
    );
    _playerProvider.addListener(_syncFromProvider);
    _syncRouterState();
    _loadSongs();
  }

  @override
  void dispose() {
    _playerProvider.removeListener(_syncFromProvider);
    _playerProvider.dispose();
    _settingsProvider.dispose();
    _routerRefreshNotifier.dispose();
    super.dispose();
  }

  /// Syncs in-memory state from the provider. Called only on song/data changes
  /// (not on every position update) because `notifyListeners` in the provider
  /// is now decoupled from the playback position stream.
  void _syncFromProvider() {
    if (!mounted) return;
    setState(() {
      _songs = _playerProvider.allSongs;
    });
    _syncRouterState();
  }

  void _syncRouterState() {
    // Only wake go_router when the gate state actually changed — avoids
    // redundant redirect evaluations (and duplicate route logs) that would
    // fire on every PlayerProvider notifyListeners() call.
    if (_isLoading == _prevIsLoading &&
        _showOnboarding == _prevShowOnboarding &&
        _hasPermission == _prevHasPermission) {
      return;
    }
    _prevIsLoading = _isLoading;
    _prevShowOnboarding = _showOnboarding;
    _prevHasPermission = _hasPermission;

    _appRouter.updateGateState(
      isLoading: _isLoading,
      showOnboarding: _showOnboarding,
      hasPermission: _hasPermission,
    );
    _routerRefreshNotifier.refresh();
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    await _settingsProvider.loadSettings();

    // Check if onboarding is completed
    var prefs = SharedPreferencesAsync();
    var onboardingComplete =
        await prefs.getBool('onboarding_completed') ?? false;
    if (!onboardingComplete) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showOnboarding = true;
      });
      _syncRouterState();
      return;
    }

    var granted = await PermissionService().requestAllPermissions();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _isLoading = false;
        _hasPermission = false;
      });
      _syncRouterState();
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasPermission = true;
    });

    var scanner = MusicScanner();

    // Check if the scan folder is configured
    var folder = await scanner.getScanFolder();
    if (folder == null) {
      // No folder configured - show onboarding to select one
      if (!mounted) return;
      setState(() {
        _showOnboarding = true;
        _isLoading = false;
      });
      _syncRouterState();
      return;
    }

    if (!granted) return;

    var scanner2 = MusicScanner();

    // Instantly load cached library references, playlists, and sort settings
    var scannedSongs = await scanner2.scanAllSongs();
    var playlists = await scanner2.getPlaylists();

    // Load sort preferences before HomeScreen mounts so the first render
    // uses the saved order — avoids a visible sort flash.

    // Check if sync warning banner should be displayed
    var showSyncPrompt = false;
    var lastSyncTs = await prefs.getInt('last_sync_timestamp');
    var postponeUntil = await prefs.getInt('postpone_sync_until') ?? 0;
    var nowMs = DateTime.now().millisecondsSinceEpoch;

    if (nowMs >= postponeUntil && lastSyncTs != null) {
      var lastSyncDateTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTs);
      var oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      if (lastSyncDateTime.isBefore(oneMonthAgo)) {
        showSyncPrompt = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _scanFolder = folder;
      _songs = scannedSongs;
      _showSyncPrompt = showSyncPrompt;
      _isLoading = false;
    });
    _syncRouterState();

    _playerProvider.updatePlaylists(playlists);
    _playerProvider.updateSongs(scannedSongs);
  }

  Future<void> _completeOnboarding(String? selectedFolder) async {
    var prefs = SharedPreferencesAsync();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
    });
    _syncRouterState();

    if (selectedFolder != null) {
      setState(() {
        _isLoading = true;
      });
      _syncRouterState();
      var scanner = MusicScanner();
      await scanner.setScanFolder(selectedFolder);
      var newSongs = await scanner.importFromFolder(selectedFolder);
      var updatedSongs = await scanner.scanAllSongs();
      var playlists = await scanner.getPlaylists();

      if (!mounted) return;
      setState(() {
        _scanFolder = selectedFolder;
        _songs = updatedSongs;
        _hasPermission = true;
        _isLoading = false;
      });
      _syncRouterState();
      _playerProvider.updatePlaylists(playlists);
      _playerProvider.updateSongs(updatedSongs);
      _settingsProvider.refreshSyncStats();

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            newSongs.isNotEmpty
                ? 'Sync folder configured. Imported ${newSongs.length} new ${newSongs.length == 1 ? 'song' : 'songs'} (${_playerProvider.uniqueThemeCount} unique themes pre-computed)!'
                : 'Sync folder configured successfully (${_playerProvider.uniqueThemeCount} unique themes pre-computed)!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetApp() async {
    var prefs = SharedPreferencesAsync();
    await prefs.clear();
    if (!mounted) return;
    setState(() {
      _scanFolder = null;
      _songs = [];
      _showOnboarding = true;
    });
    _syncRouterState();
    _playerProvider.stop();
    _playerProvider.updateSongs([]);

    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Library and settings cleared successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildPermissionScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.audio_file_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Access to Music Files',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'To play local audio files, Sonora requires permission to access your device storage.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _loadSongs,
                icon: const Icon(Icons.security_rounded),
                label: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    openSettings(context);
  }

  Future<void> _configureScanFolder() async {
    var scanner = MusicScanner();
    var folderPath = await FilePicker.getDirectoryPath();
    if (folderPath != null) {
      await scanner.setScanFolder(folderPath);

      var newSongs = await scanner.importFromFolder(folderPath);
      var folder = await scanner.getScanFolder();
      if (!mounted) return;
      setState(() {
        _scanFolder = folder;
      });
      _settingsProvider.refreshSyncStats();
      var updatedSongs = await scanner.scanAllSongs();

      if (!mounted) return;
      setState(() {
        _songs = updatedSongs;
        _hasPermission = true;
      });
      _syncRouterState();
      _playerProvider.updateSongs(updatedSongs);

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            newSongs.isNotEmpty
                ? 'Sync folder configured. Imported ${newSongs.length} new ${newSongs.length == 1 ? 'song' : 'songs'} (${_playerProvider.uniqueThemeCount} unique themes pre-computed)!'
                : 'Sync folder configured successfully (${_playerProvider.uniqueThemeCount} unique themes pre-computed)!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _syncSongsSilently() async {
    if (_isSyncing || !_hasPermission) return;
    _isSyncing = true;

    try {
      var scanner = MusicScanner();
      var updatedSongs = await scanner.syncLibrary();
      await _settingsProvider.refreshSyncStats();
      if (!mounted) return;
      setState(() {
        _songs = updatedSongs;
      });
      _syncRouterState();
      _playerProvider.updateSongs(updatedSongs);
    } catch (_) {
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _onResyncNow() async {
    setState(() {
      _showSyncPrompt = false;
    });
    await _syncSongsSilently();
  }

  Future<void> _onPostponeSync() async {
    var prefs = SharedPreferencesAsync();
    var nextRemind = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await prefs.setInt('postpone_sync_until', nextRemind);

    if (!mounted) return;
    setState(() {
      _showSyncPrompt = false;
    });

    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Sync reminder postponed for 1 month.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onCreatePlaylist(String name) async {
    var scanner = MusicScanner();
    await scanner.createPlaylist(name);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    _playerProvider.updatePlaylists(playlists);
    _syncRouterState();
  }

  Future<void> _onDeletePlaylist(String playlistId) async {
    var scanner = MusicScanner();
    await scanner.deletePlaylist(playlistId);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    _playerProvider.updatePlaylists(playlists);
    _syncRouterState();
  }

  Future<void> _onAddSongToPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.addSongToPlaylist(playlistId, songId);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    _playerProvider.updatePlaylists(playlists);
    _syncRouterState();
  }

  Future<void> _onRemoveSongFromPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.removeSongFromPlaylist(playlistId, songId);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    _playerProvider.updatePlaylists(playlists);
    _syncRouterState();
  }

  Future<void> _onReorderPlaylistSongs(
    String playlistId,
    List<int> reorderedIds,
  ) async {
    var playlists = List<Playlist>.from(_playerProvider.playlists);
    for (var i = 0; i < playlists.length; i++) {
      if (playlists[i].id == playlistId) {
        playlists[i] = Playlist(
          id: playlists[i].id,
          name: playlists[i].name,
          songIds: reorderedIds,
        );
        break;
      }
    }

    // Optimistic UI update
    _playerProvider.updatePlaylists(playlists);

    var scanner = MusicScanner();
    await scanner.savePlaylists(playlists);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsProvider,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: _themeProvider,
          builder: (context, _) {
            return ValueListenableBuilder<Color>(
              valueListenable: _playerProvider.themeColorNotifier,
              builder: (context, activeSeedColor, _) {
                return MaterialApp.router(
                  scaffoldMessengerKey: _scaffoldMessengerKey,
                  title: 'Sonora',
                  theme: AppTheme.getTheme(
                    Brightness.light,
                    seedColor: activeSeedColor,
                  ),
                  darkTheme: AppTheme.getTheme(
                    Brightness.dark,
                    seedColor: activeSeedColor,
                  ),
                  themeMode: _themeProvider.themeMode,
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      child: child,
                    );
                  },
                  routerConfig: _appRouter.router,
                );
              },
            );
          },
        );
      },
    );
  }
}
