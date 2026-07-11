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

class _AudioVisualizerState extends State<AudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _VisualizerPainter(
            animationValue: _controller.value,
            isPlaying: widget.isPlaying,
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
    required this.isPlaying,
    required this.color,
    required this.barCount,
  });

  final double animationValue;
  final bool isPlaying;
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
      if (isPlaying) {
        // High-performance smooth wave equations.
        // No allocations or complex paths.
        var offset = i * (2 * pi / barCount);
        var rawSine = sin(animationValue * 2 * pi * 1.0 + offset);
        var rawSine2 = cos(animationValue * 2 * pi * 2.0 - offset * 1.4);
        var normalized = (rawSine + rawSine2 + 2.0) / 4.0;
        targetHeight = minHeight + normalized * (size.height - minHeight);
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
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color ||
        oldDelegate.barCount != barCount;
  }
}
