import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sonora/providers/settings_provider.dart';

/// Blurred-looking cover behind a screen; empty unless the setting is on.
class BlurredCoverBackground extends StatelessWidget {
  const BlurredCoverBackground({
    super.key,
    required this.imagePath,
    required this.opacity,
  });

  final String imagePath;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsProvider.instance,
      builder: (context, _) {
        if (!SettingsProvider.instance.blurredBackgrounds) {
          return const SizedBox.shrink();
        }
        // A tiny decode scaled up smoothly stands in for an ImageFilter blur.
        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: ResizeImage(FileImage(File(imagePath)), width: 32),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                opacity: opacity,
              ),
            ),
          ),
        );
      },
    );
  }
}
