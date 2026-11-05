import 'dart:io';
import 'dart:ui' as ui;

/// Small on-disk cover copies for list tiles, so a cold start decodes tiny
/// files instead of full covers.
class ThumbnailStore {
  ThumbnailStore._();

  static const dim = 128;

  static String? _dir;
  static final _ready = <String>{};

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

  static String? find(String artworkPath) {
    var path = _pathFor(artworkPath);
    return path != null && _ready.contains(path) ? path : null;
  }

  /// Failures are swallowed: the full cover works without a thumbnail.
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
    // FNV-1a pair: stable across runs, unlike String.hashCode.
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
