import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Privacy & Permissions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 8 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildCard(
            theme,
            icon: Icons.security_rounded,
            title: 'Your Data is Yours',
            content:
                'This app operates entirely offline and communicates with no servers, '
                'with the exception of checking GitHub for app updates. '
                'All of your library statistics, preferences, and playtime data stay '
                'strictly on your device and are never sent anywhere. '
                '\n\nYou can trust that your listening habits remain private.',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Permissions Explained',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildCard(
            theme,
            icon: Icons.folder_open_rounded,
            title: 'Storage, Audio & Cover Images',
            content:
                'Used to scan your selected music folder for audio tracks and local artist/album artwork '
                '(e.g., artist.jpg or cover.png).\n\n'
                'Transparent Privacy Guarantee: Although Android prompts for "Photos & Media" access, '
                'Sonora strictly scans files inside your designated music directory. '
                'We NEVER read, inspect, or access your personal photo gallery, camera roll, or private images.',
          ),
          const SizedBox(height: 12),
          _buildCard(
            theme,
            icon: Icons.notifications_active_rounded,
            title: 'Notifications & Foreground Service',
            content:
                'Used to display the media player controls in your notification shade '
                'and lock screen. A foreground service is required to keep the music '
                'playing continuously in the background when the app is closed.',
          ),
          const SizedBox(height: 12),
          _buildCard(
            theme,
            icon: Icons.battery_charging_full_rounded,
            title: 'Wake Lock',
            content:
                'Prevents your device from sleeping and abruptly stopping the '
                'music playback while you are listening.',
          ),
          const SizedBox(height: 12),
          _buildCard(
            theme,
            icon: Icons.public_rounded,
            title: 'Internet',
            content:
                'Only used to fetch the latest release version and changelog from '
                'GitHub to notify you of available updates.',
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Data Management',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildCard(
            theme,
            icon: Icons.delete_sweep_rounded,
            title: 'Delete All Data',
            content:
                'You have full control. You can wipe all app settings, statistics, '
                'and caches instantly at any time from the Danger Zone located at '
                'the bottom of the Info & Support tab.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
