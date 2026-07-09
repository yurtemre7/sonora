import 'dart:typed_data';

class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String filePath;
  Uint8List? artworkBytes;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.filePath,
    this.artworkBytes,
  });

  String get durationFormatted {
    var minutes = duration.inMinutes;
    var seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
