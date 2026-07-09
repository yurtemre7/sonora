import 'package:flutter/material.dart';

import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/screens/playlist_detail_screen.dart';
import 'package:sonora/widgets/mini_player.dart';
import 'package:sonora/widgets/song_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.playerProvider,
    required this.songs,
    required this.playlists,
    required this.onOpenNowPlaying,
    required this.onOpenSettings,
    required this.scanFolder,
    required this.onConfigureFolder,
    required this.onCreatePlaylist,
    required this.onDeletePlaylist,
    required this.onAddSongToPlaylist,
    required this.onRemoveSongFromPlaylist,
    required this.onReorderPlaylistSongs,
    required this.onShowInFolder,
    required this.isSyncing,
  });

  final PlayerProvider playerProvider;
  final List<Song> songs;
  final List<Playlist> playlists;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onOpenSettings;
  final String? scanFolder;
  final VoidCallback onConfigureFolder;
  final Future<void> Function(String name) onCreatePlaylist;
  final Future<void> Function(String playlistId) onDeletePlaylist;
  final Future<void> Function(String playlistId, int songId) onAddSongToPlaylist;
  final Future<void> Function(String playlistId, int songId) onRemoveSongFromPlaylist;
  final Future<void> Function(String playlistId, List<int> reorderedIds) onReorderPlaylistSongs;
  final Future<void> Function(Song song) onShowInFolder;
  final bool isSyncing;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  var _searchQuery = '';
  var _sortBy = 'title';
  var _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  List<Song> _getFilteredSongs() {
    var filtered = widget.songs.where((song) {
      if (_searchQuery.isEmpty) return true;
      var query = _searchQuery.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.album.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      if (_sortBy == 'artist') {
        comparison = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      } else if (_sortBy == 'duration') {
        comparison = a.duration.compareTo(b.duration);
      } else {
        comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _showSortBottomSheet() {
    var theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort Songs By',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Title'),
                    value: 'title',
                    // ignore: deprecated_member_use
                    groupValue: _sortBy,
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      setState(() => _sortBy = val!);
                      setSheetState(() {});
                      Navigator.pop(context);
                    },
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Artist'),
                    value: 'artist',
                    // ignore: deprecated_member_use
                    groupValue: _sortBy,
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      setState(() => _sortBy = val!);
                      setSheetState(() {});
                      Navigator.pop(context);
                    },
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Duration'),
                    value: 'duration',
                    // ignore: deprecated_member_use
                    groupValue: _sortBy,
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      setState(() => _sortBy = val!);
                      setSheetState(() {});
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Sort Ascending'),
                    value: _sortAscending,
                    onChanged: (val) {
                      setState(() => _sortAscending = val);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSongInfoBottomSheet(Song song) {
    var theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Song Information',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Title', song.title, theme),
              _buildInfoRow('Artist', song.artist, theme),
              _buildInfoRow('Album', song.album, theme),
              _buildInfoRow('Duration', song.durationFormatted, theme),
              _buildInfoRow('File Path', song.filePath, theme, isPath: true),
              if (song.format != null) _buildInfoRow('Format', song.format!.toUpperCase(), theme),
              if (song.bitrate != null) _buildInfoRow('Bitrate', '${(song.bitrate! / 1000).toStringAsFixed(0)} kbps', theme),
              if (song.samplerate != null) _buildInfoRow('Sample Rate', '${(song.samplerate! / 1000).toStringAsFixed(1)} kHz', theme),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: isPath ? 'monospace' : null,
              fontSize: isPath ? 12 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterHeader(ThemeData theme) {
    var count = _getFilteredSongs().length;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.shuffle_rounded),
                onPressed: () {
                  widget.playerProvider.quickShuffle(_getFilteredSongs());
                },
                tooltip: 'Shuffle Play',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.sort_rounded),
                onPressed: _showSortBottomSheet,
                tooltip: 'Sort Songs',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count ${count == 1 ? 'song' : 'songs'} found',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    var textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              var name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext);
                await widget.onCreatePlaylist(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(Song song) {
    var theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add "${song.title}" to:'),
        content: widget.playlists.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No playlists found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showCreatePlaylistDialog();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Playlist'),
                  ),
                ],
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.playlists.length,
                  itemBuilder: (context, index) {
                    var playlist = widget.playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(playlist.name),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await widget.onAddSongToPlaylist(playlist.id, song.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "${playlist.name}".'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                backgroundColor: theme.colorScheme.surface,
                elevation: 0,
                scrolledUnderElevation: 0,
                expandedHeight: 120,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: widget.onOpenSettings,
                    tooltip: 'Settings',
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                  title: Text(
                    'Sonora',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(widget.isSyncing ? 50 : 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isSyncing)
                        const LinearProgressIndicator(minHeight: 2),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Songs'),
                          Tab(text: 'Playlists'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Songs
                    widget.songs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.scanFolder == null ? Icons.folder_open_rounded : Icons.music_off_rounded,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.scanFolder == null ? 'Set Music Directory' : 'No music files found',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.scanFolder == null
                                        ? 'Choose a folder directory on your device to scan and play music from.'
                                        : 'Please put some audio files (e.g. .mp3, .m4a) in the folder:\n\n${widget.scanFolder}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: widget.onConfigureFolder,
                                    icon: Icon(widget.scanFolder == null
                                        ? Icons.folder_copy_rounded
                                        : Icons.create_new_folder_rounded),
                                    label: Text(widget.scanFolder == null ? 'Set Sync Folder' : 'Change Folder'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              _buildSearchAndFilterHeader(theme),
                              Expanded(
                                child: _getFilteredSongs().isEmpty
                                    ? Center(
                                        child: Text(
                                          'No matching songs found',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.only(bottom: 100),
                                        itemCount: _getFilteredSongs().length,
                                        itemBuilder: (context, index) {
                                          var filteredSongs = _getFilteredSongs();
                                          var song = filteredSongs[index];
                                          return SongTile(
                                            song: song,
                                            onTap: () => widget.playerProvider.playSong(song, filteredSongs),
                                            onPlayNext: () => widget.playerProvider.playNext(song),
                                            onAddToQueue: () => widget.playerProvider.addToQueue(song),
                                            onShowInFolder: () => widget.onShowInFolder(song),
                                            onAddToPlaylist: () => _showAddToPlaylistDialog(song),
                                            onShowInfo: () => _showSongInfoBottomSheet(song),
                                            onToggleFavorite: () => widget.playerProvider.toggleFavorite(song.id),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),

                    // Tab 2: Playlists
                    Stack(
                      children: [
                        widget.playlists.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.queue_music_rounded,
                                        size: 64,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No playlists yet',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Create custom playlists to group and organize your synced music files.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      FilledButton.icon(
                                        onPressed: _showCreatePlaylistDialog,
                                        icon: const Icon(Icons.playlist_add_rounded),
                                        label: const Text('Create Playlist'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: widget.playlists.length,
                                itemBuilder: (context, index) {
                                  var playlist = widget.playlists[index];
                                  var songCount = widget.songs
                                      .where((s) => playlist.songIds.contains(s.id))
                                      .length;

                                  return ListTile(
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.primaryContainer,
                                            theme.colorScheme.secondaryContainer,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                       child: Icon(
                                        playlist.id == 'favorites'
                                            ? Icons.favorite_rounded
                                            : Icons.music_note_rounded,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    title: Text(playlist.name),
                                    subtitle: Text('$songCount ${songCount == 1 ? 'song' : 'songs'}'),
                                    trailing: playlist.id == 'favorites'
                                        ? null
                                        : PopupMenuButton<int>(
                                            icon: const Icon(Icons.more_vert_rounded),
                                            onSelected: (val) async {
                                              if (val == 1) {
                                                await widget.onDeletePlaylist(playlist.id);
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Playlist "${playlist.name}" deleted.'),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 1,
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PlaylistDetailScreen(
                                            playlist: playlist,
                                            songs: widget.songs,
                                            playerProvider: widget.playerProvider,
                                            onRemoveSong: widget.onRemoveSongFromPlaylist,
                                            onReorderSongs: widget.onReorderPlaylistSongs,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                        if (widget.playlists.isNotEmpty)
                          Positioned(
                            right: 16,
                            bottom: 84,
                            child: FloatingActionButton(
                              onPressed: _showCreatePlaylistDialog,
                              child: const Icon(Icons.playlist_add_rounded),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: widget.playerProvider,
              builder: (context, _) {
                var song = widget.playerProvider.currentSong;
                if (song == null) return const SizedBox.shrink();

                return StreamBuilder<Duration>(
                  stream: widget.playerProvider.audioHandler.player.positionStream,
                  builder: (context, snapshot) {
                    var position = snapshot.data ?? Duration.zero;
                    var totalMs = song.duration.inMilliseconds;
                    var progress = totalMs > 0
                        ? position.inMilliseconds / totalMs
                        : 0.0;

                    return MiniPlayer(
                      currentSong: song,
                      isPlaying: widget.playerProvider.audioHandler.player.playing,
                      progress: progress,
                      onTap: widget.onOpenNowPlaying,
                      onPlayPause: widget.playerProvider.playPause,
                      onNext: widget.playerProvider.next,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
