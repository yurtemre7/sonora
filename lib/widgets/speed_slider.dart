import 'package:flutter/material.dart';

class SpeedSlider extends StatelessWidget {
  const SpeedSlider({super.key, required this.speed, required this.onChanged});

  final double speed;
  final ValueChanged<double> onChanged;

  static const _speeds = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    // Find closest index
    var currentIndex = 1; // Default to 1.0
    var minDiff = double.infinity;
    for (var i = 0; i < _speeds.length; i++) {
      var diff = (speed - _speeds[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        currentIndex = i;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: SizedBox(
          width: 280,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.speed_rounded, size: 20),
                onPressed: () => onChanged(1.0),
                tooltip: 'Reset to 1.0x',
                color: speed == 1.0
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SliderTheme(
                  data: theme.sliderTheme.copyWith(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    value: currentIndex.toDouble(),
                    max: (_speeds.length - 1).toDouble(),
                    divisions: _speeds.length - 1,
                    label: '${_speeds[currentIndex]}x',
                    onChanged: (val) {
                      onChanged(_speeds[val.round()]);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 40,
                child: Text(
                  '${speed.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '').replaceAll(RegExp(r'\.0$'), '')}x',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
