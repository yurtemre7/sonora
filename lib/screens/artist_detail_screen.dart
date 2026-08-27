import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/routing/app_navigation.dart';
import 'package:sonora/screens/album_detail_screen.dart';
import 'package:sonora/utils/format_utils.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/album_art.dart';
import 'package:sonora/widgets/animated_favorite_button.dart';
import 'package:sonora/widgets/artist_avatar.dart';
import 'package:sonora/widgets/multi_select_action_bar.dart';
import 'package:sonora/widgets/song_tile.dart';

class ArtistDetailScreen extends StatefulWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artist,
    required this.playerProvider,
    this.allSongs = const [],
    this.allAlbums = const [],
  });

  final ArtistGroup artist;
  final PlayerProvider playerProvider;
  final List<Song> allSongs;
  final List<AlbumGroup> allAlbums;

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
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
    String? imagePath;
    if (widget.artist.localImagePath != null &&
        File(widget.artist.localImagePath!).existsSync()) {
      imagePath = widget.artist.localImagePath;
    } else {
      for (var song in widget.artist.songs) {
        if (song.artworkPath != null && File(song.artworkPath!).existsSync()) {
          imagePath = song.artworkPath;
          break;
        }
      }
    }

    var selectedSongsList = widget.artist.songs
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
            if (imagePath != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: ResizeImage(
                          FileImage(File(imagePath)),
                          width: 120,
                        ),
                        fit: BoxFit.cover,
                        opacity: 0.1,
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
                  expandedHeight: 280,
                  flexibleSpace: FlexibleSpaceBar(
                    background: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          ArtistAvatar(
                            artist: widget.artist,
                            radius: 70,
                            iconSize: 80,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Text(
                              widget.artist.name,
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
                          Text(
                            '${context.l10n.albumCount(widget.artist.albums.length)} • ${context.l10n.songCount(widget.artist.songs.length)} • ${formatTotalDuration(widget.artist.songs)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
                              if (widget.artist.songs.isNotEmpty) {
                                widget.playerProvider.playSong(
                                  widget.artist.songs.first,
                                  widget.artist.songs,
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
                              if (widget.artist.songs.isNotEmpty) {
                                widget.playerProvider.quickShuffle(
                                  widget.artist.songs,
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
                            var key = widget.artist.nameLower;
                            var isFav = widget
                                .playerProvider
                                .favoriteArtists
                                .containsKey(key);
                            return AnimatedFavoriteButton(
                              isFavorite: isFav,
                              onToggle: () => widget
                                  .playerProvider
                                  .toggleFavoriteArtist(key),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Albums Horizontal List (if > 0)
                if (widget.artist.albums.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        top: 16.0,
                        bottom: 8.0,
                      ),
                      child: Text(
                        context.l10n.albums,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 170,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        itemCount: widget.artist.albums.length,
                        itemBuilder: (context, index) {
                          var album = widget.artist.albums[index];
                          var albumArtSong = album.songs.first;
                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(
                                      album: album,
                                      playerProvider: widget.playerProvider,
                                      allSongs: widget.allSongs,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AlbumArt(
                                    artworkPath: albumArtSong.artworkPath,
                                    size: 110,
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      album.name,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      context.l10n.trackCount(
                                        album.songs.length,
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Popular Tracks Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24.0,
                      right: 24.0,
                      top: 24.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      context.l10n.songs,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),

                // Tracks List
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 120),
                  sliver: ListenableBuilder(
                    listenable: widget.playerProvider,
                    builder: (context, _) {
                      var currentSong = widget.playerProvider.currentSong;
                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          var song = widget.artist.songs[index];
                          var isCurrent =
                              currentSong != null && currentSong.id == song.id;
                          var isSelecting = _selectedSongIds.isNotEmpty;
                          var isSelected = _selectedSongIds.contains(song.id);
                          return SongTile(
                            song: song,
                            playerProvider: widget.playerProvider,
                            isCurrent: isCurrent,
                            showDivider: index < widget.artist.songs.length - 1,
                            isSelecting: isSelecting,
                            isSelected: isSelected,
                            onSelect: () => _toggleSongSelection(song),
                            onLongPress: () => _onLongPressSong(song),
                            onTap: () => widget.playerProvider.playSong(
                              song,
                              widget.artist.songs,
                            ),
                          );
                        }, childCount: widget.artist.songs.length),
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
                  allAvailableSongs: widget.artist.songs,
                  playerProvider: widget.playerProvider,
                  onClearSelection: _clearSongSelection,
                  onSelectAll: () => _selectAllSongs(widget.artist.songs),
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
