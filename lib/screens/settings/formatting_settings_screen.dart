import 'package:flutter/material.dart';
import 'package:sonora/models/song.dart';
import 'package:sonora/providers/settings_provider.dart';

class FormattingSettingsScreen extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const FormattingSettingsScreen({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Formatting'),
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
                  'Preview',
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
                        'Original Metadata:',
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
                        'Displayed As:',
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
                  'Title Filters',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Remove (feat.) from titles'),
                subtitle: const Text(
                  'Hides featured artists from the song title if present.',
                ),
                value: settingsProvider.filterTitleFeatures,
                onChanged: (val) =>
                    settingsProvider.setFilterTitleFeatures(val),
              ),
              SwitchListTile(
                title: const Text('Remove artist from titles'),
                subtitle: const Text(
                  'Hides "Artist - " from the beginning of song titles.',
                ),
                value: settingsProvider.filterTitleArtist,
                onChanged: (val) => settingsProvider.setFilterTitleArtist(val),
              ),
            ],
          );
        },
      ),
    );
  }
}
