import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ColorExtractor {
  /// Extracts the average/dominant color of an image file by downsampling it
  /// natively to 32x32 pixels, then scanning the pixels.
  static Future<Color?> extractDominantColor(String filePath) async {
    try {
      var file = File(filePath);
      if (!file.existsSync()) return null;

      var bytes = await file.readAsBytes();
      // Downsample natively during decoding to ensure low memory and CPU footprint
      var codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      var frameInfo = await codec.getNextFrame();
      var image = frameInfo.image;

      var byteData = await image.toByteData();
      if (byteData == null) return null;

      var buffer = byteData.buffer.asUint8List();
      var rSum = 0;
      var gSum = 0;
      var bSum = 0;
      var count = 0;

      for (var i = 0; i < buffer.length; i += 4) {
        var r = buffer[i];
        var g = buffer[i + 1];
        var b = buffer[i + 2];
        var a = buffer[i + 3];

        // Skip transparent/extremely dark pixels to get vibrant colors
        if (a > 128) {
          rSum += r;
          gSum += g;
          bSum += b;
          count++;
        }
      }

      if (count == 0) return null;

      return Color.fromARGB(
        255,
        (rSum / count).round(),
        (gSum / count).round(),
        (bSum / count).round(),
      );
    } catch (e) {
      debugPrint('Error extracting color: $e');
      return null;
    }
  }
}
