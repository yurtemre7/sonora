import 'package:flutter/material.dart';
import 'package:sonora/utils/l10n_extension.dart';

enum SongActivityView {
  all,
  recentlyPlayed,
  mostPlayed,
  leastPlayed;

  static SongActivityView fromStorage(String? value) {
    return SongActivityView.values.firstWhere(
      (view) => view.name == value,
      orElse: () => SongActivityView.all,
    );
  }
}

Duration qualifyingRecentPlayThreshold(Duration songDuration) {
  const minimum = Duration(seconds: 10);
  const maximum = Duration(seconds: 30);
  var quarterDurationMs = (songDuration.inMilliseconds * 0.25).round();
  var thresholdMs = quarterDurationMs.clamp(
    minimum.inMilliseconds,
    maximum.inMilliseconds,
  );
  return Duration(
    milliseconds: thresholdMs.clamp(0, songDuration.inMilliseconds),
  );
}

String formatRelativePlayDate(
  BuildContext context,
  DateTime playedAt, {
  DateTime? now,
}) {
  var currentTime = now ?? DateTime.now();
  var today = DateUtils.dateOnly(currentTime);
  var date = DateUtils.dateOnly(playedAt);
  var msDiff = today.millisecondsSinceEpoch - date.millisecondsSinceEpoch;
  var days = (msDiff / 86400000).round();
  if (days <= 0) return context.l10n.today;
  if (days == 1) return context.l10n.yesterday;
  if (days < 7) return context.l10n.thisWeek;
  return MaterialLocalizations.of(context).formatMonthYear(playedAt);
}
