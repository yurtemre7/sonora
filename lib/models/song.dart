class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String filePath;
  final String? artworkPath;
  final String? format;
  final int? bitrate;
  final int? samplerate;
  final bool isFavorite;
  final int? lastModifiedMs;
  final int? fileSize;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.filePath,
    this.artworkPath,
    this.format,
    this.bitrate,
    this.samplerate,
    this.isFavorite = false,
    this.lastModifiedMs,
    this.fileSize,
  });

  String get durationFormatted {
    var minutes = duration.inMinutes;
    var seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
