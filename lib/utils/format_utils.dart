import 'package:sonora/models/song.dart';

String formatTotalDuration(List<Song> songs) {
  if (songs.isEmpty) return '0m listening time';
  
  var totalDuration = songs.fold<Duration>(
    Duration.zero,
    (prev, song) => prev + song.duration,
  );
  
  var hours = totalDuration.inHours;
  var minutes = totalDuration.inMinutes.remainder(60);
  
  if (hours > 0) {
    return '${hours}h ${minutes}m listening time';
  } else if (minutes > 0) {
    return '${minutes}m listening time';
  } else {
    return '< 1m listening time';
  }
}
