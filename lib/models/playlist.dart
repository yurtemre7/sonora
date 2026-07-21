class Playlist {
  final String id;
  final String name;
  final List<int> songIds;
  final String? coverImagePath;

  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    this.coverImagePath,
  });

  // Pre-normalized lowercase key computed once at construction time
  late final String nameLower = name.toLowerCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'song_ids': songIds,
    'cover_image_path': coverImagePath,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      songIds: List<int>.from(json['song_ids'] as List<dynamic>),
      coverImagePath: json['cover_image_path'] as String?,
    );
  }
}
