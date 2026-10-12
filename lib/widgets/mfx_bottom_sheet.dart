import 'package:material_ui/material_ui.dart';
import 'package:sonora/models/mfx_preset.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/custom_equalizer_widget.dart';
import 'package:sonora/widgets/preset_card.dart';
import 'package:sonora/widgets/speed_slider.dart';

void showMfxBottomSheet(BuildContext context, PlayerProvider playerProvider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MfxBottomSheet(playerProvider: playerProvider),
  );
}

class _MfxBottomSheet extends StatefulWidget {
  const _MfxBottomSheet({required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<_MfxBottomSheet> createState() => _MfxBottomSheetState();
}

class _MfxBottomSheetState extends State<_MfxBottomSheet> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      int selectedIndex = _getSelectedIndex(widget.playerProvider);
      _scrollToIndex(selectedIndex, animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getSelectedIndex(PlayerProvider player) {
    var preset = player.mfxPreset;
    if (preset == null || preset.isNormal) {
      return MfxPreset.values.indexOf(MfxPreset.normal);
    }
    var index = MfxPreset.values.indexOf(preset);
    return index >= 0 ? index : MfxPreset.values.indexOf(MfxPreset.normal);
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) return;

    var screenWidth = MediaQuery.of(context).size.width;
    var itemWidth = 140.0;
    var itemMargin = 12.0;
    var horizontalPadding = 16.0;

    var itemCenterOffset =
        horizontalPadding +
        (index * (itemWidth + itemMargin)) +
        (itemWidth / 2);
    var targetOffset = itemCenterOffset - (screenWidth / 2);

    var clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }

  String _formatDuration(Duration d) {
    var minutes = d.inMinutes;
    var seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var player = widget.playerProvider;
        return LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 16),
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                context.l10n.musicEffects,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  context.l10n.experimental,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              if (player.currentSong != null &&
                                  player.currentSong!.duration.inMilliseconds >
                                      0)
                                Container(
                                  margin: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timelapse_rounded,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${context.l10n.durationLabel}: ',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        player.effectiveSpeed != 1.0
                                            ? '${_formatDuration(player.currentSong!.duration)} (orig.)'
                                            : _formatDuration(
                                                player.currentSong!.duration,
                                              ),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  player.effectiveSpeed != 1.0
                                                  ? theme
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                  : theme.colorScheme.primary,
                                              fontWeight:
                                                  player.effectiveSpeed != 1.0
                                                  ? FontWeight.normal
                                                  : FontWeight.bold,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                      ),
                                      if (player.effectiveSpeed != 1.0) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_formatDuration(player.effectiveDuration)} (${player.effectiveSpeed.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '').replaceAll(RegExp(r'\.0$'), '')}x)',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context.l10n.presetSpeedAndPitch,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (player.isMfxPresetActive)
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: () {
                                          player.resetAllMfx();
                                          _scrollToIndex(
                                            MfxPreset.values.indexOf(
                                              MfxPreset.normal,
                                            ),
                                          );
                                        },
                                        child: Text(context.l10n.resetAll),
                                      )
                                    else
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: null,
                                        child: const Text(''),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (var preset in MfxPreset.values) ...[
                                        Builder(
                                          builder: (context) {
                                            var isSelected =
                                                player.isPreset(preset);
                                            return PresetCard(
                                              title: preset.getTitle(context),
                                              subtitle:
                                                  preset.getSubtitle(context),
                                              icon: preset.icon,
                                              isSelected: isSelected,
                                              onTap: () {
                                                player.setMfxPreset(preset);
                                                _scrollToIndex(
                                                  MfxPreset.values.indexOf(
                                                    preset,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: Text(context.l10n.mfxWarmth),
                                subtitle: Text(context.l10n.mfxWarmthSubtitle),
                                secondary: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: player.isReverbEnabled
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                value: player.isReverbEnabled,
                                onChanged: player.setReverbEnabled,
                              ),
                              SwitchListTile(
                                title: Text(context.l10n.mfxLoFi),
                                subtitle: Text(context.l10n.mfxLoFiSubtitle),
                                secondary: Icon(
                                  Icons.radio_rounded,
                                  color: player.isLofiEnabled
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                value: player.isLofiEnabled,
                                onChanged: player.setLofiEnabled,
                              ),
                              SwitchListTile(
                                title: Text(context.l10n.mfxBassBoosted),
                                subtitle: Text(
                                  context.l10n.mfxBassBoostedSubtitle,
                                ),
                                secondary: Icon(
                                  Icons.speaker_group_rounded,
                                  color: player.isBassBoostEnabled
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                value: player.isBassBoostEnabled,
                                onChanged: player.setBassBoostEnabled,
                              ),
                              const Divider(height: 32),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  context.l10n.customSpeed,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Opacity(
                                opacity: player.isMfxPresetActive ? 0.5 : 1.0,
                                child: IgnorePointer(
                                  ignoring: player.isMfxPresetActive,
                                  child: SpeedSlider(
                                    speed: player.speed,
                                    onChanged: player.setSpeed,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 32),
                              CustomEqualizerWidget(playerProvider: player),
                              const SizedBox(height: 32),
                              SafeArea(
                                child: Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      player.resetAllMfx();
                                      _scrollToIndex(6);
                                    },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text(context.l10n.mfxResetAll),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
