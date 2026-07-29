import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/services/music_scanner.dart';
import 'package:sonora/utils/l10n_extension.dart';

class DebugCachesScreen extends StatefulWidget {
  const DebugCachesScreen({
    super.key,
    required this.playerProvider,
    required this.settingsProvider,
  });

  final PlayerProvider playerProvider;
  final SettingsProvider settingsProvider;

  @override
  State<DebugCachesScreen> createState() => _DebugCachesScreenState();
}

class _DebugCachesScreenState extends State<DebugCachesScreen> {
  var _isLoading = false;
  String? _lastSyncTime;
  int? _lastSyncTs;
  Map<String, String> _localArtistImages = {};
  List<String> _physicalFiles = [];

  @override
  void initState() {
    super.initState();
    _loadDebugCaches();
  }

  Future<void> _loadDebugCaches() async {
    setState(() {
      _isLoading = true;
    });

    var scanner = MusicScanner();
    var lastSyncTime = await scanner.getLastSyncTime();
    var lastSyncTs = await scanner.getLastSyncTimestamp();
    var artistImages = await scanner.loadLocalArtistImages();

    var folderPath = widget.settingsProvider.scanFolder;
    var filesList = <String>[];
    if (folderPath != null) {
      try {
        filesList = await Isolate.run<List<String>>(() {
          var list = <String>[];
          var dir = Directory(folderPath);
          if (dir.existsSync()) {
            for (var entity in dir.listSync(
              recursive: true,
              followLinks: false,
            )) {
              if (entity is File) {
                list.add(entity.path);
              }
            }
          }
          return list;
        });
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _lastSyncTime = lastSyncTime;
        _lastSyncTs = lastSyncTs;
        _localArtistImages = Map.from(artistImages);
        _physicalFiles = filesList;
        _isLoading = false;
      });
    }
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    var theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16, right: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, List<Widget> children) {
    var theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyValueRow(
    BuildContext context,
    String label,
    String value, {
    bool isCode = false,
  }) {
    var theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontFamily: isCode ? 'monospace' : null,
                color: isCode
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var allSongs = widget.playerProvider.allSongs;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.debugCacheInfo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDebugCaches,
            tooltip: context.l10n.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Environment & Build Info
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'Environment & Build',
                    Icons.developer_mode_rounded,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildGroupCard(context, [
                    _buildKeyValueRow(
                      context,
                      'kDebugMode',
                      '$kDebugMode',
                      isCode: true,
                    ),
                    _buildKeyValueRow(
                      context,
                      'kReleaseMode',
                      '$kReleaseMode',
                      isCode: true,
                    ),
                    _buildKeyValueRow(
                      context,
                      'kProfileMode',
                      '$kProfileMode',
                      isCode: true,
                    ),
                  ]),
                ),

                // 2. Scanner & Storage Cache State
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'MusicScanner & Sync State',
                    Icons.sync_rounded,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildGroupCard(context, [
                    _buildKeyValueRow(
                      context,
                      'Scan Folder',
                      widget.settingsProvider.scanFolder ?? 'Not configured',
                      isCode: true,
                    ),
                    _buildKeyValueRow(
                      context,
                      'Last Sync Time',
                      _lastSyncTime ?? 'Never',
                    ),
                    _buildKeyValueRow(
                      context,
                      'Last Sync Epoch',
                      '${_lastSyncTs ?? "None"}',
                      isCode: true,
                    ),
                  ]),
                ),

                // 3. In-Memory Player Counts & Statistics
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'In-Memory Player Caches',
                    Icons.storage_rounded,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildGroupCard(context, [
                    _buildKeyValueRow(
                      context,
                      'Total Songs Loaded',
                      '${allSongs.length}',
                    ),
                    _buildKeyValueRow(
                      context,
                      'Cached Albums',
                      '${widget.playerProvider.cachedAlbums.length}',
                    ),
                    _buildKeyValueRow(
                      context,
                      'Cached Artists',
                      '${widget.playerProvider.cachedArtists.length}',
                    ),
                    _buildKeyValueRow(
                      context,
                      'Active Queue Length',
                      '${widget.playerProvider.queue.length}',
                    ),
                    _buildKeyValueRow(
                      context,
                      'User Playlists',
                      '${widget.playerProvider.playlists.length}',
                    ),
                    _buildKeyValueRow(
                      context,
                      'Favorite Albums Count',
                      '${widget.playerProvider.favoriteAlbums.length}',
                    ),
                    _buildKeyValueRow(
                      context,
                      'Favorite Artists Count',
                      '${widget.playerProvider.favoriteArtists.length}',
                    ),
                  ]),
                ),

                // 4. Local Artist Image Mappings
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'Detected Artist Cover Images (${_localArtistImages.length})',
                    Icons.image_search_rounded,
                  ),
                ),
                if (_localArtistImages.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildGroupCard(context, [
                      Text(
                        'No local artist image mappings detected in cache.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                  )
                else
                  SliverList.builder(
                    itemCount: _localArtistImages.length,
                    itemBuilder: (context, index) {
                      var entry = _localArtistImages.entries.elementAt(index);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry.key,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry.value,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: theme.colorScheme.tertiary,
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

                // 5. Complete Scanned Music Files List (Virtualized Lazy Slivers)
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'All Scanned Music Files (${allSongs.length})',
                    Icons.library_music_rounded,
                  ),
                ),
                if (allSongs.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildGroupCard(context, [
                      Text(
                        'No music files scanned in current session.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                  )
                else
                  SliverList.builder(
                    itemCount: allSongs.length,
                    itemBuilder: (context, index) {
                      return _SongCacheTile(song: allSongs[index]);
                    },
                  ),

                // 6. All Physical Discovered Files on Disk (Virtualized Lazy Slivers)
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'All Physical Files Discovered in Root (${_physicalFiles.length})',
                    Icons.folder_open_rounded,
                  ),
                ),
                if (_physicalFiles.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildGroupCard(context, [
                      Text(
                        'No physical files found in root scan directory.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                  )
                else
                  SliverList.builder(
                    itemCount: _physicalFiles.length,
                    itemBuilder: (context, index) {
                      var filePath = _physicalFiles[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            filePath,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: theme.colorScheme.tertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }
}

class _SongCacheTile extends StatelessWidget {
  const _SongCacheTile({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${song.displayTitle} (#${song.id})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  song.durationFormatted,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${song.artist} • ${song.album}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              song.filePath,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.tertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
