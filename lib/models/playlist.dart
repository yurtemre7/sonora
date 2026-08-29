class Playlist {
  final String id;
  final String name;
  final List<int> songIds;
  final String? coverImagePath;
  final String? description;

  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    this.coverImagePath,
    this.description,
  });

  // Pre-normalized lowercase key computed once at construction time
  late final String nameLower = name.toLowerCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'song_ids': songIds,
    'cover_image_path': coverImagePath,
    'description': description,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      songIds: List<int>.from(json['song_ids'] as List<dynamic>),
      coverImagePath: json['cover_image_path'] as String?,
      description: json['description'] as String?,
    );
  }

  Playlist copyWith({
    String? id,
    String? name,
    List<int>? songIds,
    String? coverImagePath,
    bool clearCoverImage = false,
    String? description,
    bool clearDescription = false,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      coverImagePath: clearCoverImage
          ? null
          : (coverImagePath ?? this.coverImagePath),
      description: clearDescription
          ? null
          : (description ?? this.description),
    );
  }
}
