import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';

void showSleepTimerBottomSheet(
  BuildContext context,
  PlayerProvider playerProvider,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SleepTimerBottomSheet(playerProvider: playerProvider),
  );
}

class SleepTimerBottomSheet extends StatefulWidget {
  const SleepTimerBottomSheet({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<SleepTimerBottomSheet> createState() => _SleepTimerBottomSheetState();
}

class _SleepTimerBottomSheetState extends State<SleepTimerBottomSheet> {
  late double _selectedMinutes;

  static const _presetMinutes = [5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    var defaultMin = SettingsProvider.instance.sleepTimerDefaultMinutes
        .toDouble();
    _selectedMinutes = defaultMin.clamp(1.0, 60.0);
  }

  String _formatDuration(Duration d) {
    var hours = d.inHours;
    var minutes = d.inMinutes.remainder(60);
    var seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      var minStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minStr:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.playerProvider,
      builder: (context, _) {
        var activeTimerDuration = widget.playerProvider.sleepTimerDuration;
        var isTimerActive = activeTimerDuration != null;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bedtime_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.sleepTimer,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (isTimerActive) ...[
                      // Active Timer State
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Music stops in',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(activeTimerDuration),
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                widget.playerProvider.stopSleepTimer();
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                foregroundColor: theme.colorScheme.error,
                              ),
                              child: Text(context.l10n.cancelTimer),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () {
                                widget.playerProvider.extendSleepTimer(
                                  const Duration(minutes: 1),
                                );
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(context.l10n.plusOneMin),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Interactive Draggable Timer Slider State (1 - 60 minutes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${_selectedMinutes.round()} min',
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Drag to set timer (1 to 60 minutes)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 1 - 60 Minutes Slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: theme.colorScheme.primary,
                                inactiveTrackColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.2),
                                thumbColor: theme.colorScheme.primary,
                                overlayColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: _selectedMinutes,
                                min: 1,
                                max: 60,
                                divisions: 59, // 1 min increments from 1 to 60
                                label: '${_selectedMinutes.round()} min',
                                onChanged: (val) {
                                  setState(() {
                                    _selectedMinutes = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Preset Tiles [5, 10, 15, 20, 30, 45, 60] with White Selected Marker
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _presetMinutes.map((min) {
                            var isSelected = _selectedMinutes.round() == min;
                            var isDefault =
                                min ==
                                SettingsProvider
                                    .instance
                                    .sleepTimerDefaultMinutes;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('$min min'),
                                selected: isSelected,
                                showCheckmark: true,
                                checkmarkColor: theme.colorScheme.onPrimary,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedMinutes = min.toDouble();
                                  });
                                },
                                side: isSelected
                                    ? BorderSide(
                                        color: theme.colorScheme.onPrimary,
                                        width: 2.0,
                                      )
                                    : (isDefault
                                          ? BorderSide(
                                              color: theme.colorScheme.primary,
                                              width: 1.5,
                                            )
                                          : null),
                                labelStyle: TextStyle(
                                  fontWeight: isSelected || isDefault
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : (isDefault
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface),
                                ),
                                selectedColor: theme.colorScheme.primary,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Start Timer Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            var duration = Duration(
                              minutes: _selectedMinutes.round(),
                            );
                            widget.playerProvider.startSleepTimer(duration);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            '${context.l10n.startTimer} (${_selectedMinutes.round()} min)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
