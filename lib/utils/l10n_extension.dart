import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sonora/l10n/app_localizations.dart';

extension BuildContextL10nExtension on BuildContext {
  /// Access localized string resources cleanly via [context.l10n].
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Localizations for code without a [BuildContext], e.g. notifications.
/// Uses [preferred] (the app language setting), else the device locale, and
/// falls back to the default locale when that language is not supported.
AppLocalizations localizationsFor(Locale? preferred) {
  var locale = preferred ?? PlatformDispatcher.instance.locale;
  return lookupAppLocalizations(
    basicLocaleListResolution([locale], AppLocalizations.supportedLocales),
  );
}
