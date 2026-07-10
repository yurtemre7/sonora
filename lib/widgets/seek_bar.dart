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

        var elapsed = _dragging
            ? Duration(milliseconds: _dragValue.round())
            : (totalMs > 0 && position > widget.totalDuration
                ? widget.totalDuration
                : (position < Duration.zero ? Duration.zero : position));
        var remaining = widget.totalDuration - elapsed;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                thumbColor: theme.colorScheme.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
