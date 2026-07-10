import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavySliderTrackShape extends SliderTrackShape {
  WavySliderTrackShape({
    required this.phase,
    required this.isPlaying,
    required this.isDragging,
  });

  final double phase; // Value from 0.0 to 2*pi
  final bool isPlaying;
  final bool isDragging;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    var trackHeight = sliderTheme.trackHeight ?? 4.0;
    var trackLeft = offset.dx;
    var trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    var trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    var trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    var activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue
      ..strokeWidth = sliderTheme.trackHeight!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    var inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey
      ..strokeWidth = sliderTheme.trackHeight!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw Inactive Track (straight line to the right of thumbCenter)
    var inactiveStart = thumbCenter.dx + 6.0; // small gap for thumb
    if (inactiveStart < trackRect.right) {
      context.canvas.drawLine(
        Offset(inactiveStart, thumbCenter.dy),
        Offset(trackRect.right, thumbCenter.dy),
        inactivePaint,
      );
    }

    // Draw Active Track (wavy line or straight line to the left of thumbCenter)
    var activeEnd = thumbCenter.dx - 6.0;
    if (trackRect.left < activeEnd) {
      // If we are dragging or not playing, draw a straight line
      if (isDragging || !isPlaying) {
        context.canvas.drawLine(
          Offset(trackRect.left, thumbCenter.dy),
          Offset(activeEnd, thumbCenter.dy),
          activePaint,
        );
      } else {
        // Draw Sine Wave (Squiggly Snake!)
        var path = Path();
        path.moveTo(trackRect.left, thumbCenter.dy);

        // Sine wave configuration
        const waveLength = 28.0; // Horizontal width of one wave cycle
        const amplitude = 3.5;  // Height of wave peak

        var x = trackRect.left;
        while (x < activeEnd) {
          // Smoothly transition amplitude from flat at start to full wave near the thumb
          var progressFraction = (x - trackRect.left) / (activeEnd - trackRect.left);
          var currentAmplitude = amplitude * progressFraction.clamp(0.0, 1.0);
          
          var y = thumbCenter.dy + currentAmplitude * math.sin((x * 2 * math.pi / waveLength) - phase);
          path.lineTo(x, y);
          x += 2.0; // Step size
        }
        // Ensure connection to activeEnd
        path.lineTo(activeEnd, thumbCenter.dy);
        
        context.canvas.drawPath(path, activePaint);
      }
    }
  }
}

class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.positionStream,
    required this.totalDuration,
    required this.onSeek,
    required this.isPlaying,
  });

  final Stream<Duration> positionStream;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;
  final bool isPlaying;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> with SingleTickerProviderStateMixin {
  var _dragging = false;
  var _dragValue = 0.0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isPlaying) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    var minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    var seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var totalMs = widget.totalDuration.inMilliseconds.toDouble();

    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      builder: (context, snapshot) {
        var position = snapshot.data ?? Duration.zero;
        var posMs = _dragging
            ? _dragValue
            : position.inMilliseconds.toDouble().clamp(0.0, totalMs);

        var elapsed = _dragging
            ? Duration(milliseconds: _dragValue.round())
            : position;
        var remaining = widget.totalDuration - elapsed;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                // Shift phase from 0.0 to 2*pi based on animation value
                var phase = _animationController.value * 2 * math.pi;

                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    thumbColor: theme.colorScheme.primary,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    trackShape: WavySliderTrackShape(
                      phase: phase,
                      isPlaying: widget.isPlaying,
                      isDragging: _dragging,
                    ),
                  ),
                  child: Slider(
                    value: posMs.clamp(0.0, totalMs > 0 ? totalMs : 1.0),
                    max: totalMs > 0 ? totalMs : 1.0,
                    onChangeStart: (value) {
                      setState(() {
                        _dragging = true;
                        _dragValue = value;
                      });
                    },
                    onChanged: (value) {
                      setState(() {
                        _dragValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      widget.onSeek(Duration(milliseconds: value.round()));
                      setState(() {
                        _dragging = false;
                      });
                    },
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(elapsed),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '-${_formatDuration(remaining)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
