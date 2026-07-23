import 'package:flutter/material.dart';
import 'package:sonora/utils/l10n_extension.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(context.l10n.privacyPermissions),
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
            title: context.l10n.privacyCardDataTitle,
            content: context.l10n.privacyCardDataContent,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              context.l10n.permissionsExplained,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildCard(
            theme,
            icon: Icons.folder_open_rounded,
            title: context.l10n.privacyCardStorageTitle,
            content: context.l10n.privacyCardStorageContent,
          ),
          const SizedBox(height: 12),
          _buildCard(
            theme,
            icon: Icons.notifications_active_rounded,
            title: context.l10n.privacyCardNotificationsTitle,
            content: context.l10n.privacyCardNotificationsContent,
          ),
          const SizedBox(height: 12),
          _buildCard(
            theme,
            icon: Icons.battery_charging_full_rounded,
            title: context.l10n.privacyCardWakeLockTitle,
            content: context.l10n.privacyCardWakeLockContent,
          ),
          const SizedBox(height: 12),
          _buildCard(
            theme,
            icon: Icons.public_rounded,
            title: context.l10n.privacyCardInternetTitle,
            content: context.l10n.privacyCardInternetContent,
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              context.l10n.dataManagement,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildCard(
            theme,
            icon: Icons.delete_sweep_rounded,
            title: context.l10n.privacyCardDeleteDataTitle,
            content: context.l10n.privacyCardDeleteDataContent,
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
