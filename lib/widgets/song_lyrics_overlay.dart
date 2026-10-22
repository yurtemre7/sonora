import 'package:material_ui/material_ui.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/services/lyrics_service.dart';
import 'package:sonora/utils/l10n_extension.dart';

/// Lyrics view for the current song: synced `.lrc` lines with auto-scroll,
/// active-line highlight and tap-to-seek, or plain text.
class SongLyricsOverlay extends StatefulWidget {
  const SongLyricsOverlay({
    super.key,
    required this.song,
    required this.playerProvider,
  });

  final Song song;
  final PlayerProvider playerProvider;

  @override
  State<SongLyricsOverlay> createState() => _SongLyricsOverlayState();
}

class _SongLyricsOverlayState extends State<SongLyricsOverlay> {
  List<LyricLine>? _lyricsLines;
  var _isSynchronized = false;
  var _isLoading = false;
  late ScrollController _scrollController;
  var _activeIndex = -1;
  DateTime? _lastUserScrollTime;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(SongLyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.song.id != oldWidget.song.id) {
      _loadLyrics();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    setState(() {
      _isLoading = true;
      _lyricsLines = null;
      _isSynchronized = false;
      _activeIndex = -1;
    });

    var lyricsResult = await LyricsService.parseLyricsForSong(
      widget.song.filePath,
    );

    if (!mounted) return;
    setState(() {
      if (lyricsResult != null) {
        _lyricsLines = lyricsResult.lines;
        _isSynchronized = lyricsResult.isSynchronized;
      }
      _isLoading = false;
    });
  }

  void _scrollToActiveIndex(
    int index,
    double viewportHeight, {
    bool immediate = false,
  }) {
    if (index < 0 || _lyricsLines == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      const itemHeight = 64.0;
      var targetScroll = index * itemHeight;

      if (immediate) {
        _scrollController.jumpTo(
          targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      } else {
        _scrollController.animateTo(
          targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    var lyricsList = _lyricsLines;
    if (lyricsList == null || lyricsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.noLyricsFound,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.placeLrcFile,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    var isDark = theme.brightness == Brightness.dark;
    var activeTextColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    if (!_isSynchronized) {
      // Unsynchronized plain text lyrics: freely scrollable
      return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: lyricsList.length,
        itemBuilder: (context, index) {
          var line = lyricsList[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              line.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: activeTextColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      );
    }

    // Synchronized lyrics: locked scroll centering
    return LayoutBuilder(
      builder: (context, constraints) {
        var viewportHeight = constraints.maxHeight;

        return StreamBuilder<Duration>(
          stream: widget.playerProvider.positionStream,
          builder: (context, snapshot) {
            var position = snapshot.data ?? Duration.zero;

            var activeIndex = -1;
            for (var i = 0; i < lyricsList.length; i++) {
              if (position >= lyricsList[i].time) {
                activeIndex = i;
              } else {
                break;
              }
            }

            if (activeIndex != _activeIndex) {
              _activeIndex = activeIndex;
              var allowAutoScroll =
                  _lastUserScrollTime == null ||
                  DateTime.now().difference(_lastUserScrollTime!) >
                      const Duration(seconds: 4);
              if (allowAutoScroll) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToActiveIndex(activeIndex, viewportHeight);
                });
              }
            }

            var inactiveTextColor = isDark
                ? Colors.white.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface.withValues(alpha: 0.4);

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _lastUserScrollTime = DateTime.now();
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  vertical: viewportHeight / 2 - 32,
                  horizontal: 20,
                ),
                itemCount: lyricsList.length,
                itemBuilder: (context, index) {
                  var isCurrent = index == activeIndex;
                  var line = lyricsList[index];

                  return GestureDetector(
                    onTap: () {
                      _lastUserScrollTime = null;
                      widget.playerProvider.seek(line.time);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 64.0,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: isCurrent
                              ? theme.textTheme.titleMedium!.copyWith(
                                  color: activeTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                )
                              : theme.textTheme.bodyMedium!.copyWith(
                                  color: inactiveTextColor,
                                  fontSize: 15,
                                ),
                          textAlign: TextAlign.center,
                          child: Text(
                            line.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
