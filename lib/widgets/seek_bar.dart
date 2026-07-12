import 'package:flutter/material.dart';

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

class _SeekBarState extends State<SeekBar> {
  var _dragging = false;
  var _dragValue = 0.0;

  String _formatDuration(Duration d) {
    var absMs = d.inMilliseconds.abs();
    var minutes = (absMs ~/ 60000).remainder(60).toString().padLeft(2, '0');
    var seconds = ((absMs ~/ 1000) % 60).toString().padLeft(2, '0');
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

        var progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

        var elapsed = _dragging
            ? Duration(milliseconds: _dragValue.round())
            : (totalMs > 0 && position > widget.totalDuration
                  ? widget.totalDuration
                  : (position < Duration.zero ? Duration.zero : position));
        var remaining = widget.totalDuration - elapsed;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 32,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var trackWidth = constraints.maxWidth;
                    var thumbRadius = 6.0;
                    var fillWidth = trackWidth * progress;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        var tapFraction =
                            (details.localPosition.dx / trackWidth).clamp(
                              0.0,
                              1.0,
                            );
                        var seekMs = (tapFraction * totalMs).round().toDouble();
                        widget.onSeek(Duration(milliseconds: seekMs.round()));
                      },
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _dragging = true;
                          _dragValue =
                              (details.localPosition.dx / trackWidth).clamp(
                                0.0,
                                1.0,
                              ) *
                              totalMs;
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _dragValue =
                              ((_dragValue / totalMs) +
                                      (details.delta.dx / trackWidth))
                                  .clamp(0.0, 1.0) *
                              totalMs;
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        widget.onSeek(
                          Duration(milliseconds: _dragValue.round()),
                        );
                        setState(() {
                          _dragging = false;
                        });
                      },
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Track background (pill shape)
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          // Filled portion (pill shape)
                          Container(
                            width: fillWidth > 6 ? fillWidth : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.tertiary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          // Thumb dot at the end of the fill
                          if (fillWidth > thumbRadius)
                            Positioned(
                              left: fillWidth - thumbRadius,
                              child: Container(
                                width: thumbRadius * 2,
                                height: thumbRadius * 2,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
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
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '-${_formatDuration(remaining)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
