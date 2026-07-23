import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';

class FormattingSettingsScreen extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const FormattingSettingsScreen({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.libraryFormatting),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: settingsProvider,
        builder: (context, _) {
          // Fake song to demonstrate formatting
          var fakeSong = Song(
            id: -1,
            title: 'Awesome Artist - The Greatest Hit (feat. Someone)',
            artist: 'Awesome Artist',
            album: 'The Greatest Album',
            duration: const Duration(minutes: 3, seconds: 45),
            filePath: '/path/to/song.mp3',
          );

          var displayTitle = fakeSong.displayTitle;

          return ListView(
            padding: EdgeInsets.only(
              top: 16.0,
              bottom: 16.0 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  context.l10n.preview,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.originalMetadata,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fakeSong.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.displayedAs,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  context.l10n.titleFilters,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(context.l10n.filterTitleFeatures),
                subtitle: Text(context.l10n.filterTitleFeaturesSubtitle),
                value: settingsProvider.filterTitleFeatures,
                onChanged: (val) =>
                    settingsProvider.setFilterTitleFeatures(val),
              ),
              SwitchListTile(
                title: Text(context.l10n.filterTitleArtist),
                subtitle: Text(context.l10n.filterTitleArtistSubtitle),
                value: settingsProvider.filterTitleArtist,
                onChanged: (val) => settingsProvider.setFilterTitleArtist(val),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  context.l10n.language,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(context.l10n.appLanguage),
                subtitle: Text(
                  switch (settingsProvider.appLocale) {
                    'en' => context.l10n.languageEnglish,
                    'de' => context.l10n.languageGerman,
                    'ja' => context.l10n.languageJapanese,
                    _ => context.l10n.languageSystem,
                  },
                ),
                leading: const Icon(Icons.language_rounded),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => SimpleDialog(
                      title: Text(context.l10n.selectLanguage),
                      children: [
                        for (var option in [
                          ('system', context.l10n.languageSystem),
                          ('en', context.l10n.languageEnglish),
                          ('de', context.l10n.languageGerman),
                          ('ja', context.l10n.languageJapanese),
                        ])
                          ListTile(
                            leading: Icon(
                              settingsProvider.appLocale == option.$1
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: settingsProvider.appLocale == option.$1
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(option.$2),
                            onTap: () {
                              settingsProvider.setAppLocale(option.$1);
                              Navigator.pop(dialogContext);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
