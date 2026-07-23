import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/services/music_scanner.dart';

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

    var filesList = <String>[];
    var folderPath = widget.settingsProvider.scanFolder;
    if (folderPath != null) {
      try {
        var dir = Directory(folderPath);
        if (dir.existsSync()) {
          for (var entity in dir.listSync(recursive: true, followLinks: false)) {
            if (entity is File) {
              filesList.add(entity.path);
            }
          }
        }
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
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
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
    return Card(
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Debug Cache Info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDebugCaches,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SelectionArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // 1. Environment & Build Info
                  _buildSectionHeader(
                    context,
                    'Environment & Build',
                    Icons.developer_mode_rounded,
                  ),
                  _buildGroupCard(context, [
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

                  // 2. Scanner & Storage Cache State
                  _buildSectionHeader(
                    context,
                    'MusicScanner & Sync State',
                    Icons.sync_rounded,
                  ),
                  _buildGroupCard(context, [
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

                  // 3. In-Memory Player Counts & Statistics
                  _buildSectionHeader(
                    context,
                    'In-Memory Player Caches',
                    Icons.storage_rounded,
                  ),
                  _buildGroupCard(context, [
                    _buildKeyValueRow(
                      context,
                      'Total Songs Loaded',
                      '${widget.playerProvider.allSongs.length}',
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

                  // 4. Local Artist Image Mappings
                  _buildSectionHeader(
                    context,
                    'Detected Artist Cover Images',
                    Icons.image_search_rounded,
                  ),
                  _buildGroupCard(
                    context,
                    _localArtistImages.isEmpty
                        ? [
                            Text(
                              'No local artist image mappings detected in cache.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ]
                        : _localArtistImages.entries.map((entry) {
                            return _buildKeyValueRow(
                              context,
                              entry.key,
                              entry.value,
                              isCode: true,
                            );
                          }).toList(),
                  ),

                  // 5. Complete Scanned Music Files List
                  _buildSectionHeader(
                    context,
                    'All Scanned Music Files (${widget.playerProvider.allSongs.length})',
                    Icons.library_music_rounded,
                  ),
                  if (widget.playerProvider.allSongs.isEmpty)
                    _buildGroupCard(context, [
                      Text(
                        'No music files scanned in current session.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ])
                  else
                    ...widget.playerProvider.allSongs.map((song) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildGroupCard(context, [
                          _buildKeyValueRow(
                            context,
                            'Title / ID',
                            '${song.title} (#${song.id})',
                          ),
                          _buildKeyValueRow(context, 'Artist', song.artist),
                          _buildKeyValueRow(context, 'Album', song.album),
                          _buildKeyValueRow(
                            context,
                            'File Path',
                            song.filePath,
                            isCode: true,
                          ),
                          _buildKeyValueRow(
                            context,
                            'Artwork Path',
                            song.artworkPath ?? 'None (No embedded artwork)',
                            isCode: true,
                          ),
                        ]),
                      );
                    }),
                  // 6. All Physical Discovered Files on Disk
                  _buildSectionHeader(
                    context,
                    'All Physical Files Discovered in Root (${_physicalFiles.length})',
                    Icons.folder_open_rounded,
                  ),
                  if (_physicalFiles.isEmpty)
                    _buildGroupCard(context, [
                      Text(
                        'No physical files found in root scan directory.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ])
                  else
                    _buildGroupCard(
                      context,
                      _physicalFiles.map((path) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: SelectableText(
                            path,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
