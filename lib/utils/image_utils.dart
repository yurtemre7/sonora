import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;

/// Processing utility for playlist cover images.
/// Center-crops image to 1:1 ratio and resizes to max [targetSize] (default 512px)
/// before encoding to compressed JPEG to prevent UI jank.
class PlaylistImageUtils {
  PlaylistImageUtils._();

  static Future<void> processAndSavePlaylistCover(
    File sourceFile,
    String targetPath, {
    int targetSize = 512,
  }) async {
    var inputBytes = await sourceFile.readAsBytes();

    var processedBytes = await Isolate.run<List<int>>(() {
      var decoded = img.decodeImage(inputBytes);
      if (decoded == null) return inputBytes;

      // Calculate center crop square bounds
      var cropSize =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      var offsetX = (decoded.width - cropSize) ~/ 2;
      var offsetY = (decoded.height - cropSize) ~/ 2;

      var cropped = img.copyCrop(
        decoded,
        x: offsetX,
        y: offsetY,
        width: cropSize,
        height: cropSize,
      );

      var resized = cropSize > targetSize
          ? img.copyResize(
              cropped,
              width: targetSize,
              height: targetSize,
              interpolation: img.Interpolation.average,
            )
          : cropped;

      return img.encodeJpg(resized, quality: 85);
    });

    var targetFile = File(targetPath);
    await targetFile.writeAsBytes(processedBytes);
  }
}
