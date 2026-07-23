import 'package:flutter/widgets.dart';
import 'package:sonora/l10n/app_localizations.dart';

extension BuildContextL10nExtension on BuildContext {
  /// Access localized string resources cleanly via [context.l10n].
  AppLocalizations get l10n => AppLocalizations.of(this);
}
