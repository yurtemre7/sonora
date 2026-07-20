import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/playlist_selector.dart';
import 'package:sonora/widgets/song_info_bottom_sheet.dart';
import 'package:sonora/widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.songs,
    required this.playerProvider,
    required this.onRemoveSong,
    required this.onReorderSongs,
    required this.playlists,
    required this.onAddSongToPlaylist,
    this.onDeletePlaylist,
  });

  final Playlist playlist;
  final List<Song> songs;
  final PlayerProvider playerProvider;
  final Future<void> Function(String playlistId, int songId) onRemoveSong;
  final Future<void> Function(String playlistId, List<int> reorderedIds)
  onReorderSongs;
  final List<Playlist> playlists;
  final Future<void> Function(String playlistId, int songId)
  onAddSongToPlaylist;
  final Future<void> Function(String playlistId)? onDeletePlaylist;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<Song> _playlistSongs;
  late List<Key> _itemKeys;
  final _scrollController = ScrollController();
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _updatePlaylistSongs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playlist = widget.playlist;
    _updatePlaylistSongs();
  }

  void _updatePlaylistSongs() {
    var songMap = {for (var s in widget.songs) s.id: s};
    _playlistSongs = _playlist.songIds
        .map((id) => songMap[id])
        .whereType<Song>()
        .toList();
    _itemKeys = List.generate(_playlistSongs.length, (i) => UniqueKey());
  }

  void _showAddToPlaylistDialog(Song song) {
    PlaylistSelectorBottomSheet.show(context, song, widget.playerProvider);
  }

  /// Confirms and performs playlist deletion, then closes this screen.
  Future<void> _deletePlaylist() async {
    if (widget.onDeletePlaylist == null) return;
    var confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Playlist?',
      message: 'Delete "${_playlist.name}"? This cannot be undone.',
    );
    if (confirmed != true || !mounted) return;
    // Close the detail screen first so go_router never tries to
    // resolve the now-deleted playlist route.
    closeRoute(context);
    await widget.onDeletePlaylist!(_playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var providerPlaylists = widget.playerProvider.playlists;
        var matchingPlaylist = providerPlaylists
            .where((p) => p.id == widget.playlist.id)
            .firstOrNull;
        if (matchingPlaylist != null) {
          _playlist = matchingPlaylist;
        } else if (_playlist.id == 'favorites') {
          var favoriteIds = widget.playerProvider.allSongs
              .where((s) => s.isFavorite)
              .map((s) => s.id)
              .toList();
          _playlist = Playlist(
            id: 'favorites',
            name: 'Favorites',
            songIds: favoriteIds,
          );
        }
        _updatePlaylistSongs();

        var firstSong = _playlistSongs.isNotEmpty ? _playlistSongs.first : null;
        var creatorLabel = _playlist.id == 'favorites'
            ? 'Your favorites'
            : 'Your own playlist';

        return Scaffold(
          body: Stack(
            children: [
              if (firstSong?.artworkPath != null)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(File(firstSong!.artworkPath!)),
                          fit: BoxFit.cover,
                          opacity: 0.15,
                        ),
                      ),
                    ),
                  ),
                ),
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => closeRoute(context),
                    ),
                    actions: [
                      // Only non-favorites playlists can be deleted.
                      if (_playlist.id != 'favorites' &&
                          widget.onDeletePlaylist != null)
                        PopupMenuButton<int>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (val) {
                            if (val == 1) _deletePlaylist();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 1,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete Playlist',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    expandedHeight: 320,
                    flexibleSpace: FlexibleSpaceBar(
                      background: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Hero(
                              tag: 'playlist_art_${_playlist.id}',
                              child: firstSong != null
                                  ? AlbumArt(
                                      artworkPath: firstSong.artworkPath,
                                      size: 180,
                                      borderRadius: 24,
                                    )
                                  : Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.primaryContainer,
                                            theme
                                                .colorScheme
                                                .secondaryContainer,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Icon(
                                        _playlist.id == 'favorites'
                                            ? Icons.favorite_rounded
                                            : Icons.music_note_rounded,
                                        size: 64,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Text(
                                _playlist.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Text(
                                creatorLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_playlistSongs.length} ${_playlistSongs.length == 1 ? 'song' : 'songs'}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Play/Shuffle actions bar
                  if (_playlistSongs.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  if (_playlistSongs.isNotEmpty) {
                                    widget.playerProvider.playSong(
                                      _playlistSongs.first,
                                      _playlistSongs,
                                      playlistId: widget.playlist.id,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (_playlistSongs.isNotEmpty) {
                                    widget.playerProvider.quickShuffle(
                                      _playlistSongs,
                                      playlistId: widget.playlist.id,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.shuffle_rounded),
                                label: const Text('Shuffle'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Tracks List
                  if (_playlistSongs.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.queue_music_rounded,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Playlist is empty',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Go to the Songs list and use the song menu to add music to this playlist.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 120),
                      sliver: SliverReorderableList(
                        itemCount: _playlistSongs.length,
                        onReorderItem: (int oldIndex, int newIndex) {
                          setState(() {
                            var item = _playlistSongs.removeAt(oldIndex);
                            _playlistSongs.insert(newIndex, item);
                            var key = _itemKeys.removeAt(oldIndex);
                            _itemKeys.insert(newIndex, key);
                          });
                          widget.onReorderSongs(
                            _playlist.id,
                            _playlistSongs.map((s) => s.id).toList(),
                          );
                        },
                        itemBuilder: (context, index) {
                          var song = _playlistSongs[index];
                          var isCurrent =
                              widget.playerProvider.currentSong?.id == song.id;

                          return ReorderableDelayedDragStartListener(
                            key: _itemKeys[index],
                            index: index,
                            child: Dismissible(
                              key: ValueKey('dismiss_${_itemKeys[index].hashCode}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                color: theme.colorScheme.errorContainer,
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              onDismissed: (direction) async {
                                if (_playlist.id == 'favorites') {
                                  await widget.playerProvider.toggleFavorite(
                                    song.id,
                                  );
                                } else {
                                  await widget.onRemoveSong(
                                    _playlist.id,
                                    song.id,
                                  );
                                }
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Removed "${song.displayTitle}" from playlist.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: SongTile(
                                song: song,
                                playerProvider: widget.playerProvider,
                                isCurrent: isCurrent,
                                showDivider: index < _playlistSongs.length - 1,
                                onTap: () {
                                  widget.playerProvider.playSong(
                                    song,
                                    _playlistSongs,
                                    playlistId: widget.playlist.id,
                                  );
                                },
                                onPlayNext: () =>
                                    widget.playerProvider.playNext(song),
                                onAddToQueue: () =>
                                    widget.playerProvider.addToQueue(song),
                                onAddToPlaylist: () =>
                                    _showAddToPlaylistDialog(song),
                                onRemoveFromPlaylist: () async {
                                  if (_playlist.id == 'favorites') {
                                    await widget.playerProvider.toggleFavorite(
                                      song.id,
                                    );
                                  } else {
                                    await widget.onRemoveSong(
                                      _playlist.id,
                                      song.id,
                                    );
                                  }
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Removed "${song.displayTitle}" from playlist.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                onShowInfo: () =>
                                    showSongInfoBottomSheet(context, song),
                                onToggleFavorite: () => widget.playerProvider
                                    .toggleFavorite(song.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
