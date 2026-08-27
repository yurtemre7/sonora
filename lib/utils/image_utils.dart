import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Processing utility for playlist cover images.
/// Center-crops image to 1:1 ratio and resizes to max [targetSize] (default 512px)
/// using hardware-accelerated native Android Bitmap processing with a pure dart:ui fallback.
class PlaylistImageUtils {
  PlaylistImageUtils._();

  static const _mediastoreChannel = MethodChannel(
    'de.yurtemre.sonora/mediastore',
  );

  static Future<void> processAndSavePlaylistCover(
    File sourceFile,
    String targetPath, {
    int targetSize = 512,
  }) async {
    if (Platform.isAndroid) {
      try {
        var success = await _mediastoreChannel.invokeMethod<bool>(
          'cropAndResizeImage',
          {
            'sourcePath': sourceFile.path,
            'targetPath': targetPath,
            'targetSize': targetSize,
            'quality': 85,
          },
        );
        if (success == true) return;
      } catch (_) {}
    }

    // Fallback using standard Flutter dart:ui engine (cross-platform, host tests)
    var inputBytes = await sourceFile.readAsBytes();
    var codec = await ui.instantiateImageCodec(inputBytes);
    var frame = await codec.getNextFrame();
    var image = frame.image;

    var cropSize = image.width < image.height ? image.width : image.height;
    var recorder = ui.PictureRecorder();
    var canvas = ui.Canvas(recorder);

    var srcRect = ui.Rect.fromCenter(
      center: ui.Offset(image.width / 2, image.height / 2),
      width: cropSize.toDouble(),
      height: cropSize.toDouble(),
    );
    var outSize = cropSize > targetSize ? targetSize : cropSize;
    var dstRect = ui.Rect.fromLTWH(0, 0, outSize.toDouble(), outSize.toDouble());

    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );

    var picture = recorder.endRecording();
    var rendered = await picture.toImage(outSize, outSize);
    var byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      var targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());
    }
  }
}
