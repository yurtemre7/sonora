import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';
import 'package:sonora/widgets/theme_color_selector.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({
    super.key,
    required this.themeProvider,
    required this.playerProvider,
    required this.settingsProvider,
  });

  final ThemeProvider themeProvider;
  final PlayerProvider playerProvider;
  final SettingsProvider settingsProvider;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appearance),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            // ── Theme Mode (Unified Segmented Button) ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 6.0,
              ),
              child: Text(
                context.l10n.themeMode,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 6.0,
              ),
              child: ListenableBuilder(
                listenable: themeProvider,
                builder: (context, _) {
                  return SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_rounded),
                        label: Text(context.l10n.systemDefault),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_rounded),
                        label: Text(context.l10n.light),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_rounded),
                        label: Text(context.l10n.dark),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (newSelection) {
                      HapticFeedback.selectionClick();
                      themeProvider.setThemeMode(newSelection.first);
                    },
                  );
                },
              ),
            ),

            const Divider(height: 28),

            // ── Color Source & Accent (Unified Segmented Button) ──────────
            ListenableBuilder(
              listenable: Listenable.merge([playerProvider, settingsProvider]),
              builder: (context, _) {
                var uniqueColors = playerProvider.getUniqueThemeColors();
                var currentSource = settingsProvider.themeColorSource;
                var wallpaperColor = settingsProvider.dynamicWallpaperColor;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 6.0,
                      ),
                      child: Text(
                        context.l10n.themeColorsHeader,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Unified 3-way Segmented Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      child: SegmentedButton<ThemeColorSource>(
                        segments: [
                          ButtonSegment(
                            value: ThemeColorSource.materialYou,
                            icon: const Icon(Icons.palette_outlined),
                            label: Text(context.l10n.colorSourceMaterialYou),
                          ),
                          ButtonSegment(
                            value: ThemeColorSource.albumArt,
                            icon: const Icon(Icons.album_rounded),
                            label: Text(context.l10n.colorSourceAlbumArt),
                          ),
                          ButtonSegment(
                            value: ThemeColorSource.custom,
                            icon: const Icon(Icons.colorize_rounded),
                            label: Text(context.l10n.colorSourceCustom),
                          ),
                        ],
                        selected: {currentSource},
                        onSelectionChanged: (newSelection) {
                          HapticFeedback.selectionClick();
                          settingsProvider.setThemeColorSource(
                            newSelection.first,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Mode description card & palette context
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: switch (currentSource) {
                          ThemeColorSource.materialYou => Row(
                            children: [
                              if (wallpaperColor != null) ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: wallpaperColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: wallpaperColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (wallpaperColor != null)
                                      Text(
                                        context.l10n.wallpaperColorActive,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                    Text(
                                      context.l10n.colorSourceMaterialYouDesc,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          ThemeColorSource.albumArt => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.colorSourceAlbumArtDesc,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.l10n.fallbackColorHeader,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ThemeColorSelector(
                                colors: uniqueColors,
                                selectedColor: playerProvider.defaultThemeColor,
                                onColorSelected: (color) {
                                  playerProvider.setDefaultThemeColor(color);
                                },
                              ),
                            ],
                          ),
                          ThemeColorSource.custom => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.colorSourceCustomDesc,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.l10n.customColorHeader,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ThemeColorSelector(
                                colors: uniqueColors,
                                selectedColor: playerProvider.defaultThemeColor,
                                onColorSelected: (color) {
                                  playerProvider.setDefaultThemeColor(color);
                                },
                              ),
                            ],
                          ),
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            const Divider(height: 28),

            // ── Display & Contrast ──────────────────────────────────────
            ListenableBuilder(
              listenable: settingsProvider,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 6.0,
                      ),
                      child: Text(
                        context.l10n.displayAndContrast,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: Text(context.l10n.amoledDark),
                      subtitle: Text(context.l10n.amoledDarkSubtitle),
                      value: settingsProvider.amoledDark,
                      onChanged: (val) => settingsProvider.setAmoledDark(val),
                    ),
                  ],
                );
              },
            ),

            const Divider(height: 28),

            // ── Player Screen Aesthetics ────────────────────────────────
            ListenableBuilder(
              listenable: settingsProvider,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 6.0,
                      ),
                      child: Text(
                        context.l10n.playerScreenAesthetics,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.art_track_rounded),
                      title: Text(context.l10n.nowPlayingStyle),
                      subtitle: Text(context.l10n.nowPlayingStyleSubtitle),
                      trailing: DropdownButton<String>(
                        value: ['modern', 'vinyl', 'minimalist'].contains(
                          settingsProvider.nowPlayingStyle,
                        )
                            ? settingsProvider.nowPlayingStyle
                            : 'modern',
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: 'modern',
                            child: Text(context.l10n.styleModern),
                          ),
                          DropdownMenuItem(
                            value: 'vinyl',
                            child: Text(context.l10n.styleVinyl),
                          ),
                          DropdownMenuItem(
                            value: 'minimalist',
                            child: Text(context.l10n.styleMinimalist),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            settingsProvider.setNowPlayingStyle(val);
                          }
                        },
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.account_box_outlined),
                      title: Text(context.l10n.preferLocalArtistImages),
                      subtitle: Text(
                        context.l10n.preferLocalArtistImagesSubtitle,
                      ),
                      value: settingsProvider.preferLocalArtistImages,
                      onChanged: (val) =>
                          settingsProvider.setPreferLocalArtistImages(val),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.bar_chart_rounded),
                      title: Text(context.l10n.showAudioVisualizer),
                      subtitle: Text(context.l10n.showAudioVisualizerSubtitle),
                      value: settingsProvider.showVisualizer,
                      onChanged: (val) =>
                          settingsProvider.setShowVisualizer(val),
                    ),
                  ],
                );
              },
            ),

            const Divider(height: 28),

            // ── Personalization ─────────────────────────────────────────
            ListenableBuilder(
              listenable: settingsProvider,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 6.0,
                      ),
                      child: Text(
                        context.l10n.personalization,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.wb_sunny_rounded),
                      title: Text(context.l10n.useGreetingTitle),
                      subtitle: Text(context.l10n.useGreetingTitleSubtitle),
                      value: settingsProvider.useGreetingTitle,
                      onChanged: (val) {
                        settingsProvider.setUseGreetingTitle(val);
                      },
                    ),
                    if (settingsProvider.useGreetingTitle)
                      ListTile(
                        leading: const Icon(Icons.badge_rounded),
                        title: Text(context.l10n.yourName),
                        subtitle: Text(settingsProvider.userName),
                        onTap: () async {
                          var newName = await showDialog<String>(
                            context: context,
                            builder: (context) => _UserNameDialogContent(
                              initialName: settingsProvider.userName,
                            ),
                          );
                          if (newName != null) {
                            settingsProvider.setUserName(newName);
                          }
                        },
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _UserNameDialogContent extends StatefulWidget {
  const _UserNameDialogContent({required this.initialName});

  final String initialName;

  @override
  State<_UserNameDialogContent> createState() => _UserNameDialogContentState();
}

class _UserNameDialogContentState extends State<_UserNameDialogContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.enterYourName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: context.l10n.yourName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            var text = _controller.text.trim();
            Navigator.pop(context, text.isEmpty ? 'User' : text);
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
