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
  final bool hasLyrics;
  final int? dominantColor;

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
    this.hasLyrics = false,
    this.dominantColor,
  });

  /// Pre-normalized lowercase keys — computed once on first access and cached.
  /// Use these instead of calling [String.toLowerCase] in sort comparators or
  /// search filters to avoid repeated string allocations per comparison.
  late final String titleLower = title.toLowerCase();
  late final String artistLower = artist.toLowerCase();
  late final String albumLower = album.toLowerCase();

  String get durationFormatted {
    var minutes = duration.inMinutes;
    var seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? filePath,
    String? artworkPath,
    String? format,
    int? bitrate,
    int? samplerate,
    bool? isFavorite,
    int? lastModifiedMs,
    int? fileSize,
    bool? hasLyrics,
    int? dominantColor,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      artworkPath: artworkPath ?? this.artworkPath,
      format: format ?? this.format,
      bitrate: bitrate ?? this.bitrate,
      samplerate: samplerate ?? this.samplerate,
      isFavorite: isFavorite ?? this.isFavorite,
      lastModifiedMs: lastModifiedMs ?? this.lastModifiedMs,
      fileSize: fileSize ?? this.fileSize,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      dominantColor: dominantColor ?? this.dominantColor,
    );
  }

  String get displayTitle {
    var cleaned = title.replaceAll(
      RegExp(
        r'\s*[\(\[](?:feat|featuring|ft)\.?\s+[^\]\)]+[\)\]]',
        caseSensitive: false,
      ),
      '',
    );

    if (artist.isEmpty) return cleaned.trim().isEmpty ? title : cleaned.trim();

    var escaped = RegExp.escape(artist);
    var artistRemoved = cleaned.replaceFirst(
      RegExp(r'\s*[—–-]\s*' + escaped + r'\s*$'),
      '',
    );
    if (artistRemoved == cleaned) {
      artistRemoved = cleaned.replaceFirst(
        RegExp(r'^\s*' + escaped + r'\s*[—–-]\s*'),
        '',
      );
    }
    artistRemoved = artistRemoved.trim();
    return artistRemoved.isEmpty ? cleaned.trim() : artistRemoved;
  }
}
