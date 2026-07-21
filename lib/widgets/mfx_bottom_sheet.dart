import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/widgets/speed_slider.dart';

void showMfxBottomSheet(BuildContext context, PlayerProvider playerProvider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MfxBottomSheet(playerProvider: playerProvider),
  );
}

class _MfxBottomSheet extends StatelessWidget {
  const _MfxBottomSheet({required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: playerProvider,
      builder: (context, _) {
        var player = playerProvider;
        return LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.5,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
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
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
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
                          SwitchListTile(
                            title: const Text('Slowed'),
                            subtitle: const Text('0.85x Speed and Pitch'),
                            secondary: Icon(
                              Icons.fast_rewind_rounded,
                              color: player.isSlowed
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            value: player.isSlowed,
                            onChanged: player.setSlowed,
                          ),
                          SwitchListTile(
                            title: const Text('Sped Up'),
                            subtitle: const Text('1.25x Speed and Pitch'),
                            secondary: Icon(
                              Icons.fast_forward_rounded,
                              color: player.isSpedUp
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            value: player.isSpedUp,
                            onChanged: player.setSpedUp,
                          ),
                          SwitchListTile(
                            title: const Text('Warmth (Reverb)'),
                            subtitle: const Text(
                              'Simulated via EQ (Bass boost, High cut)',
                            ),
                            secondary: Icon(
                              Icons.graphic_eq_rounded,
                              color: player.isReverbEnabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            value: player.isReverbEnabled,
                            onChanged: player.setReverbEnabled,
                          ),
                          const Divider(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Custom Speed',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: (player.isSlowed || player.isSpedUp)
                                ? 0.5
                                : 1.0,
                            child: IgnorePointer(
                              ignoring: player.isSlowed || player.isSpedUp,
                              child: SpeedSlider(
                                speed: player.speed,
                                onChanged: player.setSpeed,
                              ),
                            ),
                          ),
                        ],
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
}
