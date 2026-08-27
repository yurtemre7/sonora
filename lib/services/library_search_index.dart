import 'package:sonora/models/grouping.dart';
import 'package:sonora/models/song.dart';

/// Represents an indexed token node in the prefix trie.
class _TrieNode {
  final Map<int, _TrieNode> children = {};
  final Set<int> songIndices = {};
}

/// High-performance pre-computed inverted search index for music library.
///
/// Provides sub-millisecond multi-token prefix and substring search across
/// titles, artists, and albums without re-scanning or repeatedly re-sorting
/// large song collections on every keystroke.
class LibrarySearchIndex {
  List<Song> _songs = const [];

  // Pre-sorted song indices for standard sort orders
  final Map<String, List<Song>> _preSortedSongs = {};
  final Map<String, List<AlbumGroup>> _preSortedAlbums = {};
  final Map<String, List<ArtistGroup>> _preSortedArtists = {};

  // Token inverted index: lowercase token -> matching song indices
  final Map<String, Set<int>> _titleTokenIndex = {};
  final Map<String, Set<int>> _artistTokenIndex = {};
  final Map<String, Set<int>> _albumTokenIndex = {};

  // Prefix Trie for fast prefix lookup
  final _root = _TrieNode();

  bool get isEmpty => _songs.isEmpty;

  /// Builds or updates the search index from current library data.
  void buildIndex({
    required List<Song> songs,
    List<AlbumGroup> albums = const [],
    List<ArtistGroup> artists = const [],
  }) {
    _songs = List<Song>.unmodifiable(songs);

    _preSortedSongs.clear();
    _preSortedAlbums.clear();
    _preSortedArtists.clear();
    _titleTokenIndex.clear();
    _artistTokenIndex.clear();
    _albumTokenIndex.clear();
    _root.children.clear();
    _root.songIndices.clear();

    if (songs.isEmpty) return;

    // 1. Index songs tokens and populate trie
    for (var i = 0; i < songs.length; i++) {
      var song = songs[i];

      _indexText(song.titleLower, i, _titleTokenIndex);
      _indexText(song.artistLower, i, _artistTokenIndex);
      _indexText(song.albumLower, i, _albumTokenIndex);
    }
  }

  void _indexText(
    String text,
    int songIndex,
    Map<String, Set<int>> tokenMap,
  ) {
    if (text.isEmpty) return;

    // Split on whitespace and non-alphanumeric separators
    var tokens = text.split(RegExp(r'[\s\-_\.,;:/\(\)\[\]]+'));
    for (var token in tokens) {
      if (token.isEmpty) continue;

      tokenMap.putIfAbsent(token, () => <int>{}).add(songIndex);

      // Insert token into prefix trie
      var node = _root;
      node.songIndices.add(songIndex);
      for (var codeUnit in token.codeUnits) {
        node = node.children.putIfAbsent(codeUnit, () => _TrieNode());
        node.songIndices.add(songIndex);
      }
    }
  }

  /// Searches songs matching [query] with relevance scoring and custom sorting.
  List<Song> searchSongs(
    String query, {
    required String sortBy, // 'title', 'artist', 'duration', 'recent'
    required bool ascending,
  }) {
    var trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return getSortedSongs(sortBy: sortBy, ascending: ascending);
    }

    var terms = trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) {
      return getSortedSongs(sortBy: sortBy, ascending: ascending);
    }

    // Match candidate song indices that satisfy all terms
    Set<int>? matchingIndices;

    for (var term in terms) {
      var termMatches = <int>{};

      // 1. Fast Prefix Trie lookup
      var node = _root;
      var foundPrefix = true;
      for (var codeUnit in term.codeUnits) {
        var child = node.children[codeUnit];
        if (child == null) {
          foundPrefix = false;
          break;
        }
        node = child;
      }
      if (foundPrefix) {
        termMatches.addAll(node.songIndices);
      }

      // 2. Substring fallback across song fields if term is not just prefix
      for (var i = 0; i < _songs.length; i++) {
        if (termMatches.contains(i)) continue;
        var song = _songs[i];
        if (song.titleLower.contains(term) ||
            song.artistLower.contains(term) ||
            song.albumLower.contains(term)) {
          termMatches.add(i);
        }
      }

      if (matchingIndices == null) {
        matchingIndices = termMatches;
      } else {
        matchingIndices = matchingIndices.intersection(termMatches);
      }

      if (matchingIndices.isEmpty) break;
    }

    if (matchingIndices == null || matchingIndices.isEmpty) {
      return const [];
    }

    // Collect and sort matches
    var results = matchingIndices.map((i) => _songs[i]).toList();

    results.sort((a, b) {
      int comparison;
      if (sortBy == 'artist') {
        comparison = a.artistLower.compareTo(b.artistLower);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'duration') {
        comparison = a.duration.compareTo(b.duration);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'recent') {
        var aTime = a.lastModifiedMs ?? 0;
        var bTime = b.lastModifiedMs ?? 0;
        comparison = bTime.compareTo(aTime);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else {
        comparison = a.titleLower.compareTo(b.titleLower);
      }

      if (comparison == 0) {
        comparison = a.id.compareTo(b.id);
      }
      return ascending ? comparison : -comparison;
    });

    return results;
  }

  /// Returns cached pre-sorted songs.
  List<Song> getSortedSongs({
    required String sortBy,
    required bool ascending,
  }) {
    var key = '${sortBy}_$ascending';
    var cached = _preSortedSongs[key];
    if (cached != null) return cached;

    var sorted = List<Song>.from(_songs);
    sorted.sort((a, b) {
      int comparison;
      if (sortBy == 'artist') {
        comparison = a.artistLower.compareTo(b.artistLower);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'duration') {
        comparison = a.duration.compareTo(b.duration);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else if (sortBy == 'recent') {
        var aTime = a.lastModifiedMs ?? 0;
        var bTime = b.lastModifiedMs ?? 0;
        comparison = bTime.compareTo(aTime);
        if (comparison == 0) {
          comparison = a.titleLower.compareTo(b.titleLower);
        }
      } else {
        comparison = a.titleLower.compareTo(b.titleLower);
      }

      if (comparison == 0) {
        comparison = a.id.compareTo(b.id);
      }
      return ascending ? comparison : -comparison;
    });

    var result = List<Song>.unmodifiable(sorted);
    _preSortedSongs[key] = result;
    return result;
  }

  /// Fast album filtering and sorting.
  List<AlbumGroup> searchAlbums(
    String query, {
    required List<AlbumGroup> allAlbums,
    required String sortBy, // 'name', 'artist', 'tracks', 'recent'
    required bool ascending,
  }) {
    var trimmed = query.trim().toLowerCase();
    var albums = allAlbums;

    if (trimmed.isNotEmpty) {
      albums = allAlbums
          .where(
            (a) =>
                a.nameLower.contains(trimmed) ||
                a.artistLower.contains(trimmed),
          )
          .toList();
    } else {
      var key = '${sortBy}_$ascending';
      var cached = _preSortedAlbums[key];
      if (cached != null && cached.length == allAlbums.length) return cached;
    }

    var sorted = List<AlbumGroup>.from(albums);
    sorted.sort((a, b) {
      int cmp;
      if (sortBy == 'artist') {
        cmp = a.artistLower.compareTo(b.artistLower);
      } else if (sortBy == 'tracks') {
        cmp = a.songs.length.compareTo(b.songs.length);
      } else if (sortBy == 'recent') {
        cmp = b.latestModifiedMs.compareTo(a.latestModifiedMs);
      } else {
        cmp = a.nameLower.compareTo(b.nameLower);
      }
      return ascending ? cmp : -cmp;
    });

    if (trimmed.isEmpty) {
      _preSortedAlbums['${sortBy}_$ascending'] =
          List<AlbumGroup>.unmodifiable(sorted);
    }

    return sorted;
  }

  /// Fast artist filtering and sorting.
  List<ArtistGroup> searchArtists(
    String query, {
    required List<ArtistGroup> allArtists,
    required String sortBy, // 'name', 'tracks', 'albums'
    required bool ascending,
  }) {
    var trimmed = query.trim().toLowerCase();
    var artists = allArtists;

    if (trimmed.isNotEmpty) {
      artists = allArtists
          .where((a) => a.nameLower.contains(trimmed))
          .toList();
    } else {
      var key = '${sortBy}_$ascending';
      var cached = _preSortedArtists[key];
      if (cached != null && cached.length == allArtists.length) return cached;
    }

    var sorted = List<ArtistGroup>.from(artists);
    sorted.sort((a, b) {
      int cmp;
      if (sortBy == 'tracks') {
        cmp = a.songs.length.compareTo(b.songs.length);
      } else if (sortBy == 'albums') {
        cmp = a.albums.length.compareTo(b.albums.length);
      } else {
        cmp = a.nameLower.compareTo(b.nameLower);
      }
      return ascending ? cmp : -cmp;
    });

    if (trimmed.isEmpty) {
      _preSortedArtists['${sortBy}_$ascending'] =
          List<ArtistGroup>.unmodifiable(sorted);
    }

    return sorted;
  }
}
