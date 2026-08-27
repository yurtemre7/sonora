import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/animated_favorite_button.dart';
import 'package:sonora/widgets/multi_select_action_bar.dart';
import 'package:sonora/widgets/song_tile.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.playerProvider,
    this.allSongs = const [],
  });

  final AlbumGroup album;
  final PlayerProvider playerProvider;
  final List<Song> allSongs;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final Set<int> _selectedSongIds = {};

  void _toggleSongSelection(Song song) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSongIds.contains(song.id)) {
        _selectedSongIds.remove(song.id);
      } else {
        _selectedSongIds.add(song.id);
      }
    });
  }

  void _onLongPressSong(Song song) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedSongIds.add(song.id);
    });
  }

  void _selectAllSongs(List<Song> songs) {
    setState(() {
      _selectedSongIds.addAll(songs.map((s) => s.id));
    });
  }

  void _clearSongSelection() {
    setState(() {
      _selectedSongIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var firstSong = widget.album.songs.first;
    var selectedSongsList = widget.album.songs
        .where((s) => _selectedSongIds.contains(s.id))
        .toList();

    return PopScope(
      canPop: _selectedSongIds.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _clearSongSelection();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Blurred background
            if (firstSong.artworkPath != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: ResizeImage(
                          FileImage(File(firstSong.artworkPath!)),
                          width: 120,
                        ),
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
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  expandedHeight: 340,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: kToolbarHeight + 12),
                        Hero(
                          tag: 'album_art_${widget.album.name}',
                          child: AlbumArt(
                            artworkPath: firstSong.artworkPath,
                            size: 160,
                            borderRadius: 24,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            widget.album.name,
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
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            widget.album.artist,
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
                          '${context.l10n.trackCount(widget.album.songs.length)} • ${formatTotalDuration(widget.album.songs)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Play/Shuffle actions bar
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
                              if (widget.album.songs.isNotEmpty) {
                                widget.playerProvider.playSong(
                                  widget.album.songs.first,
                                  widget.album.songs,
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(context.l10n.play),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (widget.album.songs.isNotEmpty) {
                                widget.playerProvider.quickShuffle(
                                  widget.album.songs,
                                );
                              }
                            },
                            icon: const Icon(Icons.shuffle_rounded),
                            label: Text(context.l10n.shuffle),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ListenableBuilder(
                          listenable: widget.playerProvider,
                          builder: (context, _) {
                            var key =
                                '${widget.album.nameLower}|||${widget.album.artistLower}';
                            var isFav = widget
                                .playerProvider
                                .favoriteAlbums
                                .containsKey(key);
                            return AnimatedFavoriteButton(
                              isFavorite: isFav,
                              onToggle: () => widget
                                  .playerProvider
                                  .toggleFavoriteAlbum(key),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Tracks List
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 120),
                  sliver: ListenableBuilder(
                    listenable: widget.playerProvider,
                    builder: (context, _) {
                      var currentSong = widget.playerProvider.currentSong;
                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          var song = widget.album.songs[index];
                          var isCurrent =
                              currentSong != null && currentSong.id == song.id;
                          var isSelecting = _selectedSongIds.isNotEmpty;
                          var isSelected = _selectedSongIds.contains(song.id);
                          return SongTile(
                            song: song,
                            playerProvider: widget.playerProvider,
                            isCurrent: isCurrent,
                            showDivider: index < widget.album.songs.length - 1,
                            isSelecting: isSelecting,
                            isSelected: isSelected,
                            onSelect: () => _toggleSongSelection(song),
                            onLongPress: () => _onLongPressSong(song),
                            onTap: () => widget.playerProvider.playSong(
                              song,
                              widget.album.songs,
                            ),
                          );
                        }, childCount: widget.album.songs.length),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_selectedSongIds.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MultiSelectActionBar(
                  selectedSongs: selectedSongsList,
                  allAvailableSongs: widget.album.songs,
                  playerProvider: widget.playerProvider,
                  onClearSelection: _clearSongSelection,
                  onSelectAll: () => _selectAllSongs(widget.album.songs),
                  bottomPadding:
                      widget.playerProvider.currentSong != null ? 80.0 : 16.0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
