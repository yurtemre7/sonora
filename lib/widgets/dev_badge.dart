import 'package:flutter/material.dart';

/// A sleek Material 3 badge indicating a development/debug build.
class DevBadge extends StatelessWidget {
  const DevBadge({super.key, this.fontSize = 10});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        'DEV',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
