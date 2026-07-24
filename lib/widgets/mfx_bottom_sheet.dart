import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
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
    if (player.isSuperSlowed) return 0;
    if (player.isSlowed) return 1;
    if (player.isSpedUp) return 3;
    if (player.isNightcore) return 4;
    if (player.isSuperSpedUp) return 5;
    return 2; // Normal
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
                              'Music Effects',
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
                                'Experimental',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onTertiaryContainer,
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
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (player.isSuperSlowed ||
                                      player.isSlowed ||
                                      player.isSpedUp ||
                                      player.isSuperSpedUp ||
                                      player.isNightcore)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: () {
                                        player.resetAllMfx();
                                        _scrollToIndex(2);
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
                              child: Row(
                                children: [
                                  PresetCard(
                                    title: 'Super Slowed',
                                    subtitle: '0.70x Speed',
                                    icon: Icons.fast_rewind_rounded,
                                    isSelected: player.isSuperSlowed,
                                    onTap: () {
                                      player.setSuperSlowed(true);
                                      _scrollToIndex(0);
                                    },
                                  ),
                                  PresetCard(
                                    title: 'Slowed',
                                    subtitle: '0.85x Speed',
                                    icon: Icons.fast_rewind_rounded,
                                    isSelected: player.isSlowed,
                                    onTap: () {
                                      player.setSlowed(true);
                                      _scrollToIndex(1);
                                    },
                                  ),
                                  PresetCard(
                                    title: 'Normal',
                                    subtitle: '1.0x Speed',
                                    icon: Icons.play_arrow_rounded,
                                    isSelected:
                                        !player.isSuperSlowed &&
                                        !player.isSlowed &&
                                        !player.isSpedUp &&
                                        !player.isSuperSpedUp &&
                                        !player.isNightcore,
                                    onTap: () {
                                      player.setSuperSlowed(false);
                                      player.setSlowed(false);
                                      player.setSpedUp(false);
                                      player.setSuperSpedUp(false);
                                      player.setNightcore(false);
                                      _scrollToIndex(2);
                                    },
                                  ),
                                  PresetCard(
                                    title: 'Sped Up',
                                    subtitle: '1.25x Speed',
                                    icon: Icons.fast_forward_rounded,
                                    isSelected: player.isSpedUp,
                                    onTap: () {
                                      player.setSpedUp(true);
                                      _scrollToIndex(3);
                                    },
                                  ),
                                  PresetCard(
                                    title: 'Nightcore',
                                    subtitle: '1.30x Speed',
                                    icon: Icons.bolt_rounded,
                                    isSelected: player.isNightcore,
                                    onTap: () {
                                      player.setNightcore(true);
                                      _scrollToIndex(4);
                                    },
                                  ),
                                  PresetCard(
                                    title: 'Super Sped Up',
                                    subtitle: '1.50x Speed',
                                    icon: Icons.fast_forward_rounded,
                                    isSelected: player.isSuperSpedUp,
                                    onTap: () {
                                      player.setSuperSpedUp(true);
                                      _scrollToIndex(5);
                                    },
                                  ),
                                ],
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
                              subtitle: Text(context.l10n.mfxBassBoostedSubtitle),
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
                              opacity:
                                  (player.isSlowed ||
                                      player.isSpedUp ||
                                      player.isSuperSlowed ||
                                      player.isSuperSpedUp ||
                                      player.isNightcore)
                                  ? 0.5
                                  : 1.0,
                              child: IgnorePointer(
                                ignoring:
                                    player.isSlowed ||
                                    player.isSpedUp ||
                                    player.isSuperSlowed ||
                                    player.isSuperSpedUp ||
                                    player.isNightcore,
                                child: SpeedSlider(
                                  speed: player.speed,
                                  onChanged: player.setSpeed,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            SafeArea(
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    player.resetAllMfx();
                                    _scrollToIndex(2);
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
            );
          },
        );
      },
    );
  }
}
