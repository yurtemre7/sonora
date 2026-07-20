import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/theme_provider.dart';
import 'package:sonora/widgets/theme_color_selector.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({
    super.key,
    required this.themeProvider,
    required this.playerProvider,
  });

  final ThemeProvider themeProvider;
  final PlayerProvider playerProvider;

  String _themeModeName(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System Default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  IconData _themeModeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
  }

  void _showThemeModeSheet(BuildContext context) {
    var theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      useRootNavigator: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListenableBuilder(
            listenable: themeProvider,
            builder: (context, _) {
              var currentMode = themeProvider.themeMode;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      'Choose Theme',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: currentMode,
                    onChanged: (value) {
                      if (value == null) return;
                      themeProvider.setThemeMode(value);
                      Navigator.pop(sheetContext);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          title: const Text('System Default'),
                          subtitle: const Text('Follows your device theme'),
                          secondary: const Icon(Icons.brightness_auto_rounded),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: const Text('Light'),
                          subtitle: const Text('Always use light theme'),
                          secondary: const Icon(Icons.light_mode_rounded),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: const Text('Dark'),
                          subtitle: const Text('Always use dark theme'),
                          secondary: const Icon(Icons.dark_mode_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: themeProvider,
              builder: (context, _) {
                var mode = themeProvider.themeMode;
                return ListTile(
                  leading: Icon(_themeModeIcon(mode)),
                  title: const Text('Theme Mode'),
                  subtitle: Text(_themeModeName(mode)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showThemeModeSheet(context),
                );
              },
            ),
            ListenableBuilder(
              listenable: playerProvider,
              builder: (context, _) {
                var uniqueColors = playerProvider.getUniqueThemeColors();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        'Default App Color',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ThemeColorSelector(
                      colors: uniqueColors,
                      selectedColor: playerProvider.defaultThemeColor,
                      onColorSelected: (color) {
                        playerProvider.setDefaultThemeColor(color);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.color_lens_outlined),
                      title: const Text('Dynamic Theme (Material You)'),
                      subtitle: const Text(
                        'Automatically theme the app using active album art',
                      ),
                      value: playerProvider.useDynamicTheme,
                      onChanged: (val) =>
                          playerProvider.toggleDynamicTheme(val),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.account_box_outlined),
                      title: const Text('Prefer Local Artist Images'),
                      subtitle: const Text(
                        'Use local artist.jpg files from your music folders when available',
                      ),
                      value: playerProvider.preferLocalArtistImages,
                      onChanged: (val) =>
                          playerProvider.togglePreferLocalArtistImages(val),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.bar_chart_rounded),
                      title: const Text('Show Audio Visualizer'),
                      subtitle: const Text(
                        'Animate audio wave visualizer inside player screen',
                      ),
                      value: playerProvider.showVisualizer,
                      onChanged: (val) => playerProvider.toggleVisualizer(val),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
