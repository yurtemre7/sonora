import 'package:flutter/material.dart';
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

  String _themeModeName(BuildContext context, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => context.l10n.systemDefault,
      ThemeMode.light => context.l10n.light,
      ThemeMode.dark => context.l10n.dark,
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
            builder: (ctx, _) {
              var currentMode = themeProvider.themeMode;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      ctx.l10n.chooseTheme,
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
                          title: Text(ctx.l10n.systemDefault),
                          subtitle: Text(ctx.l10n.systemSubtitle),
                          secondary: const Icon(Icons.brightness_auto_rounded),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: Text(ctx.l10n.light),
                          subtitle: Text(ctx.l10n.lightSubtitle),
                          secondary: const Icon(Icons.light_mode_rounded),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: Text(ctx.l10n.dark),
                          subtitle: Text(ctx.l10n.darkSubtitle),
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
        title: Text(context.l10n.appearance),
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
                  title: Text(context.l10n.themeMode),
                  subtitle: Text(_themeModeName(context, mode)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showThemeModeSheet(context),
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([playerProvider, settingsProvider]),
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
                        context.l10n.defaultAppColor,
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
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: Text(context.l10n.amoledDark),
                      subtitle: Text(context.l10n.amoledDarkSubtitle),
                      value: settingsProvider.amoledDark,
                      onChanged: (val) => settingsProvider.setAmoledDark(val),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.color_lens_outlined),
                      title: Text(context.l10n.dynamicTheme),
                      subtitle: Text(context.l10n.dynamicThemeSubtitle),
                      value: settingsProvider.useDynamicTheme,
                      onChanged: (val) =>
                          settingsProvider.setDynamicTheme(val),
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
                      subtitle: Text(
                        context.l10n.showAudioVisualizerSubtitle,
                      ),
                      value: settingsProvider.showVisualizer,
                      onChanged: (val) =>
                          settingsProvider.setShowVisualizer(val),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        context.l10n.personalization,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                          var controller = TextEditingController(
                            text: settingsProvider.userName,
                          );
                          var newName = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(context.l10n.enterYourName),
                              content: TextField(
                                controller: controller,
                                autofocus: true,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: context.l10n.yourName,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(context.l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    var text = controller.text.trim();
                                    Navigator.pop(
                                      context,
                                      text.isEmpty ? 'User' : text,
                                    );
                                  },
                                  child: Text(context.l10n.save),
                                ),
                              ],
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
          ],
        ),
      ),
    );
  }
}
