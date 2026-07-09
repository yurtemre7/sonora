import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/screens/home_screen.dart';
import 'package:sonora/screens/now_playing_screen.dart';
import 'package:sonora/screens/settings_screen.dart';
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

class _SonoraAppState extends State<SonoraApp> with WidgetsBindingObserver {
  late final PlayerProvider _playerProvider;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  List<Song> _songs = [];
  var _isLoading = true;
  var _hasPermission = true;
  String? _scanFolder;
  var _isSyncing = false;
  List<Playlist> _playlists = [];
  final _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playerProvider = PlayerProvider(audioHandler: widget.audioHandler);
    _playerProvider.addListener(_onPlayerProviderChanged);
    _loadSongs();
  }

  @override
  void dispose() {
    _playerProvider.removeListener(_onPlayerProviderChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onPlayerProviderChanged() async {
    var scanner = MusicScanner();
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _songs = _playerProvider.allSongs;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSongsSilently();
    }
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    var permissionService = PermissionService();
    var granted = await permissionService.requestAllPermissions();

    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      if (!granted) {
        _isLoading = false;
        return;
      }
    });

    if (!granted) return;

    var scanner = MusicScanner();
    
    // Instantly load cached library references and playlists
    var folder = await scanner.getScanFolder();
    var scannedSongs = await scanner.scanAllSongs();
    var playlists = await scanner.getPlaylists();
    
    if (!mounted) return;
    setState(() {
      _scanFolder = folder;
      _songs = scannedSongs;
      _playlists = playlists;
      _isLoading = false;
    });
    
    _playerProvider.updateSongs(scannedSongs);

    // Run directory background scan asynchronously after visual render
    _syncSongsSilently();
  }

  Future<void> _syncSongsSilently() async {
    if (_isSyncing || !_hasPermission) return;
    _isSyncing = true;

    try {
      var scanner = MusicScanner();
      var updatedSongs = await scanner.syncLibrary();
      if (!mounted) return;
      setState(() {
        _songs = updatedSongs;
      });
      _playerProvider.updateSongs(updatedSongs);
    } catch (_) {
    } finally {
      _isSyncing = false;
    }
  }

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => NowPlayingScreen(playerProvider: _playerProvider),
    );
  }

  Future<void> _configureScanFolder() async {
    var scanner = MusicScanner();
    var folderPath = await FilePicker.getDirectoryPath();
    if (folderPath != null) {
      await scanner.setScanFolder(folderPath);
      
      // Run initial scan in place
      var newSongs = await scanner.importFromFolder(folderPath);
      var updatedSongs = await scanner.scanAllSongs();
      
      if (!mounted) return;
      setState(() {
        _scanFolder = folderPath;
        _songs = updatedSongs;
        _hasPermission = true;
      });
      _playerProvider.updateSongs(updatedSongs);

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            newSongs.isNotEmpty
                ? 'Sync folder configured. Imported ${newSongs.length} new ${newSongs.length == 1 ? 'song' : 'songs'}!'
                : 'Sync folder configured successfully!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onCreatePlaylist(String name) async {
    var scanner = MusicScanner();
    await scanner.createPlaylist(name);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
    });
  }

  Future<void> _onDeletePlaylist(String playlistId) async {
    var scanner = MusicScanner();
    await scanner.deletePlaylist(playlistId);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
    });
  }

  Future<void> _onAddSongToPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.addSongToPlaylist(playlistId, songId);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
    });
  }

  Future<void> _onRemoveSongFromPlaylist(String playlistId, int songId) async {
    var scanner = MusicScanner();
    await scanner.removeSongFromPlaylist(playlistId, songId);
    var playlists = await scanner.getPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
    });
  }

  Future<void> _onReorderPlaylistSongs(String playlistId, List<int> reorderedIds) async {
    var scanner = MusicScanner();
    var playlists = await scanner.getPlaylists();
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
    await scanner.savePlaylists(playlists);
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
    });
  }



  Future<void> _resetApp() async {
    var appDir = await getApplicationDocumentsDirectory();
    var jsonFile = File('${appDir.path}/imported_songs.json');
    if (jsonFile.existsSync()) {
      jsonFile.deleteSync();
    }
    var settingsFile = File('${appDir.path}/settings.json');
    if (settingsFile.existsSync()) {
      settingsFile.deleteSync();
    }
    var playlistsFile = File('${appDir.path}/playlists.json');
    if (playlistsFile.existsSync()) {
      playlistsFile.deleteSync();
    }

    if (!mounted) return;
    setState(() {
      _scanFolder = null;
      _songs = [];
      _playlists = [];
    });
    _playerProvider.updateSongs([]);

    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Library and settings cleared successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          onConfigureFolder: _configureScanFolder,
          onResetApp: _resetApp,
          onRetriggerSync: _syncSongsSilently,
          themeProvider: _themeProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          scaffoldMessengerKey: _scaffoldMessengerKey,
          title: 'Sonora',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child,
            );
          },
          home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : !_hasPermission
              ? Scaffold(
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
                )
              : Builder(
                  builder: (context) => HomeScreen(
                    playerProvider: _playerProvider,
                    songs: _songs,
                    playlists: _playlists,
                    onOpenNowPlaying: () => _openNowPlaying(context),
                    onOpenSettings: () => _openSettings(context),
                    scanFolder: _scanFolder,
                    onConfigureFolder: _configureScanFolder,
                    onCreatePlaylist: _onCreatePlaylist,
                    onDeletePlaylist: _onDeletePlaylist,
                    onAddSongToPlaylist: _onAddSongToPlaylist,
                    onRemoveSongFromPlaylist: _onRemoveSongFromPlaylist,
                    onReorderPlaylistSongs: _onReorderPlaylistSongs,
                    isSyncing: _isSyncing,
                  ),
                ),
      );
    });
  }
}
