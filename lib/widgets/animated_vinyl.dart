import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sonora/widgets/album_art.dart';

class AnimatedVinyl extends StatefulWidget {
  const AnimatedVinyl({
    super.key,
    required this.artworkBytes,
    required this.isPlaying,
    required this.size,
  });

  final Uint8List? artworkBytes;
  final bool isPlaying;
  final double size;

  @override
  State<AnimatedVinyl> createState() => _AnimatedVinylState();
}

class _AnimatedVinylState extends State<AnimatedVinyl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedVinyl oldWidget) {
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
    var theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: Center(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
            // Concentric vinyl grooves
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Groove lines representation
              _buildGrooves(widget.size),

              // Center label (Album Art)
              Container(
                width: widget.size * 0.45,
                height: widget.size * 0.45,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                child: ClipOval(
                  child: AlbumArt(
                    artworkBytes: widget.artworkBytes,
                    size: widget.size * 0.45,
                    borderRadius: widget.size * 0.45 / 2,
                  ),
                ),
              ),

              // Spindle hole
              Container(
                width: widget.size * 0.05,
                height: widget.size * 0.05,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrooves(double size) {
    return Stack(
      alignment: Alignment.center,
      children: List.generate(6, (index) {
        var radius = size * (0.5 + (index * 0.07));
        return Container(
          width: radius,
          height: radius,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.03 + (index * 0.005)),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}
