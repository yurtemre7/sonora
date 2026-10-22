import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/utils/l10n_extension.dart';

/// Shows the sort options sheet for a home tab.
///
/// [tabIndex] picks the option set: 0 songs, 1 albums, 2 artists,
/// 3 playlists. [sortBy] and [ascending] are read again after every change
/// so the sheet always shows the caller's current state.
void showSortBottomSheet(
  BuildContext context, {
  required int tabIndex,
  required String Function() sortBy,
  required bool Function() ascending,
  required ValueChanged<String> onSortBySelected,
  required ValueChanged<bool> onAscendingSelected,
}) {
  var theme = Theme.of(context);

  String title;
  switch (tabIndex) {
    case 1:
      title = context.l10n.sortAlbumsBy;
    case 2:
      title = context.l10n.sortArtistsBy;
    case 3:
      title = context.l10n.sortPlaylistsBy;
    default:
      title = context.l10n.sortSongsBy;
  }

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          var currentGroupValue = sortBy();

          List<(String, String, IconData)> options;
          switch (tabIndex) {
            case 1:
              options = [
                (context.l10n.sortByAlbumName, 'name', Icons.album_rounded),
                (context.l10n.sortByArtist, 'artist', Icons.person_rounded),
                (
                  context.l10n.sortByTrackCount,
                  'tracks',
                  Icons.format_list_numbered_rounded,
                ),
                (
                  context.l10n.sortByRecentlyAdded,
                  'recent',
                  Icons.calendar_today_rounded,
                ),
              ];
            case 2:
              options = [
                (context.l10n.sortByArtistName, 'name', Icons.person_rounded),
                (context.l10n.sortByAlbumCount, 'albums', Icons.album_rounded),
                (
                  context.l10n.sortBySongCount,
                  'songs',
                  Icons.music_note_rounded,
                ),
              ];
            case 3:
              options = [
                (
                  context.l10n.sortByPlaylistName,
                  'name',
                  Icons.playlist_play_rounded,
                ),
                (
                  context.l10n.sortBySongCount,
                  'songs',
                  Icons.music_note_rounded,
                ),
              ];
            default:
              var isPlaysSelected = currentGroupValue == 'plays';
              var playsLabel = isPlaysSelected && ascending()
                  ? context.l10n.leastPlayed
                  : context.l10n.mostPlayed;
              var playsIcon = isPlaysSelected && ascending()
                  ? Icons.trending_down_rounded
                  : Icons.trending_up_rounded;

              options = [
                (
                  context.l10n.sortByTitle,
                  'title',
                  Icons.sort_by_alpha_rounded,
                ),
                (context.l10n.sortByArtist, 'artist', Icons.person_rounded),
                (
                  context.l10n.sortByDuration,
                  'duration',
                  Icons.schedule_rounded,
                ),
                (
                  context.l10n.sortByRecentlyAdded,
                  'recent',
                  Icons.calendar_today_rounded,
                ),
                (playsLabel, 'plays', playsIcon),
              ];
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.sort_rounded,
                          size: 20,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < options.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 52,
                              endIndent: 16,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.2),
                            ),
                          _SortOptionTile(
                            icon: options[i].$3,
                            label: options[i].$1,
                            isSelected: currentGroupValue == options[i].$2,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSortBySelected(options[i].$2);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      context.l10n.sort,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: (tabIndex == 0 && currentGroupValue == 'plays')
                          ? [
                              ButtonSegment<bool>(
                                value: false,
                                icon: const Icon(
                                  Icons.trending_up_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.l10n.mostPlayed,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                icon: const Icon(
                                  Icons.trending_down_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.l10n.leastPlayed,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]
                          : [
                              ButtonSegment<bool>(
                                value: true,
                                icon: const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.l10n.sortAscending,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                icon: const Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.l10n.sortDescending,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                      selected: {ascending()},
                      onSelectionChanged: (newSelection) {
                        HapticFeedback.selectionClick();
                        onAscendingSelected(newSelection.first);
                        setSheetState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}
