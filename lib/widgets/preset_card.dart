import 'package:flutter/material.dart';

class PresetCard extends StatelessWidget {
  const PresetCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Card(
      elevation: isSelected ? 0 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(right: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        )
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
