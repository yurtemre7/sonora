import 'dart:io';
import 'dart:ui' as ui;

/// Small on-disk copies of cover art for list tiles.
///
/// Decoding the full cover (up to 1080px) for every tile on each cold start is
/// what makes list covers pop in. A [dim]px PNG decodes almost instantly.
/// Lookups are in-memory only; [ensure] creates a missing thumbnail.
class ThumbnailStore {
  ThumbnailStore._();

  /// Tile cache dimension these thumbnails serve (see AlbumArt.computeCacheDim).
  static const dim = 128;

  static String? _dir;
  static final _ready = <String>{};

  /// Points the store at [dir] and indexes the thumbnails already there.
  static Future<void> init(Directory dir) async {
    await dir.create(recursive: true);
    _dir = dir.path;
    _ready
      ..clear()
      ..addAll(
        await dir
            .list()
            .where((e) => e is File && e.path.endsWith('.png'))
            .map((e) => e.path)
            .toList(),
      );
  }

  /// Thumbnail path for [artworkPath] when it already exists, else null.
  static String? find(String artworkPath) {
    var path = _pathFor(artworkPath);
    return path != null && _ready.contains(path) ? path : null;
  }

  /// Creates the thumbnail for [artworkPath] unless it exists. Failures are
  /// swallowed: the full cover keeps working without a thumbnail.
  static Future<void> ensure(String artworkPath) async {
    var target = _pathFor(artworkPath);
    if (target == null || _ready.contains(target)) return;
    try {
      var bytes = await File(artworkPath).readAsBytes();
      var codec = await ui.instantiateImageCodec(bytes, targetWidth: dim);
      var frame = await codec.getNextFrame();
      var png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (png == null) return;
      var temp = File('$target.tmp');
      await temp.writeAsBytes(png.buffer.asUint8List(), flush: true);
      await temp.rename(target);
      _ready.add(target);
    } catch (_) {}
  }

  static String? _pathFor(String artworkPath) {
    if (_dir == null) return null;
    // Two 32-bit FNV-1a hashes with different seeds: stable across runs
    // (unlike String.hashCode) and collision-safe for a music library.
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193;
    for (var unit in artworkPath.codeUnits) {
      h1 = ((h1 ^ unit) * 0x01000193) & 0xffffffff;
      h2 = ((h2 ^ unit) * 0x01000193) & 0xffffffff;
    }
    var hash = '${h1.toRadixString(16)}${h2.toRadixString(16)}';
    return '$_dir/$hash.png';
  }
}
