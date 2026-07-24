import 'package:flutter/material.dart';
import 'package:sonora/utils/l10n_extension.dart';

/// A reusable confirm-before-delete (destructive action) dialog.
///
/// Shows a themed [AlertDialog] with a red destructive confirm button and a
/// cancel button. Returns `true` if the user confirms, `false` or `null` if
/// they dismiss or cancel.
///
/// Usage:
/// ```dart
/// final confirmed = await ConfirmDeleteDialog.show(
///   context,
///   title: 'Delete Playlist?',
///   message: 'This cannot be undone.',
/// );
/// if (confirmed == true) { /* proceed */ }
/// ```
class ConfirmDeleteDialog {
  const ConfirmDeleteDialog._();

  /// Shows the dialog and returns `true` when the user presses the destructive
  /// action button, or `false` / `null` otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(message, style: theme.textTheme.bodyMedium),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel ?? context.l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel ?? context.l10n.delete),
            ),
          ],
        );
      },
    );
  }
}
