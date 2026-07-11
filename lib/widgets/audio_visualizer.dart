import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
    this.barCount = 12,
    this.height = 32.0,
  });

  final bool isPlaying;
  final Color color;
  final int barCount;
  final double height;

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _amplitudeController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _amplitudeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450), // Smooth transition duration
    );

    _amplitudeController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _waveController.stop();
      }
    });

    if (widget.isPlaying) {
      _waveController.repeat();
      _amplitudeController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
        _amplitudeController.forward();
      } else {
        _amplitudeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _amplitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _amplitudeController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _VisualizerPainter(
            animationValue: _waveController.value,
            amplitudeFactor: _amplitudeController.value,
            color: widget.color,
            barCount: widget.barCount,
          ),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  _VisualizerPainter({
    required this.animationValue,
    required this.amplitudeFactor,
    required this.color,
    required this.barCount,
  });

  final double animationValue;
  final double amplitudeFactor;
  final Color color;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    var spacing = 4.0;
    var totalSpacing = spacing * (barCount - 1);
    var barWidth = (size.width - totalSpacing) / barCount;
    var minHeight = 4.0;

    for (var i = 0; i < barCount; i++) {
      double targetHeight;
      if (amplitudeFactor > 0.0) {
        var offset = i * (2 * pi / barCount);
        var rawSine = sin(animationValue * 2 * pi * 1.0 + offset);
        var rawSine2 = cos(animationValue * 2 * pi * 2.0 - offset * 1.4);
        var normalized = (rawSine + rawSine2 + 2.0) / 4.0;
        // Smoothly scale the active wave height using the amplitude factor
        targetHeight = minHeight + (normalized * (size.height - minHeight)) * amplitudeFactor;
      } else {
        targetHeight = minHeight;
      }

      var x = i * (barWidth + spacing);
      var y = size.height - targetHeight;

      var rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, targetHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.amplitudeFactor != amplitudeFactor ||
        oldDelegate.color != color ||
        oldDelegate.barCount != barCount;
  }
}
