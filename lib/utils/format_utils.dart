import 'package:sonora/models/song.dart';

String formatTotalDuration(List<Song> songs) {
  if (songs.isEmpty) return '0m 0s';

  var totalDuration = songs.fold<Duration>(
    Duration.zero,
    (prev, song) => prev + song.duration,
  );

  var days = totalDuration.inDays;
  var hours = totalDuration.inHours.remainder(24);
  var minutes = totalDuration.inMinutes.remainder(60);
  var seconds = totalDuration.inSeconds.remainder(60);

  var parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  // Always include minutes if we have no days or hours, or if we have minutes
  if (minutes > 0 || (days == 0 && hours == 0)) parts.add('${minutes}m');
  parts.add('${seconds}s');

  return parts.join(' ');
}
