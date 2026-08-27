import 'dart:math' as math;

import 'package:flutter/material.dart';

class ThemeColorSelector extends StatelessWidget {
  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final bool enabled;
  final String? disabledTooltip;

  const ThemeColorSelector({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onColorSelected,
    this.enabled = true,
    this.disabledTooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget list = AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.38,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          itemCount: colors.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            var color = colors[index];
            var isSelected = color == selectedColor;

            return GestureDetector(
              onTap: enabled ? () => onColorSelected(color) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected && enabled
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            )
                          : Border.all(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.5)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                            ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: CustomPaint(
                        painter: ThemePieChartPainter(baseColor: color),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (!enabled && disabledTooltip != null) {
      return Tooltip(
        message: disabledTooltip!,
        triggerMode: TooltipTriggerMode.tap,
        child: AbsorbPointer(child: list),
      );
    }

    return list;
  }
}

class ThemePieChartPainter extends CustomPainter {
  final Color baseColor;

  ThemePieChartPainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Generate the color scheme exactly as AppTheme does for dark mode
    var scheme = ColorScheme.fromSeed(
      seedColor: baseColor,
      brightness: Brightness.dark,
    );

    var rect = Rect.fromLTWH(0, 0, size.width, size.height);
    var paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // We draw 3 equal slices of 120 degrees (2*pi/3 radians)
    var sweepAngle = (2 * math.pi) / 3;

    // Primary
    paint.color = scheme.primary;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, true, paint);

    // Secondary
    paint.color = scheme.secondary;
    canvas.drawArc(rect, -math.pi / 2 + sweepAngle, sweepAngle, true, paint);

    // Tertiary
    paint.color = scheme.tertiary;
    canvas.drawArc(
      rect,
      -math.pi / 2 + 2 * sweepAngle,
      sweepAngle,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(ThemePieChartPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor;
  }
}
