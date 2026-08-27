import 'package:flutter/material.dart';

class AmbientGlow extends StatefulWidget {
  const AmbientGlow({
    super.key,
    required this.isPlaying,
    this.color,
    this.intensity = 'vibrant',
  });

  final bool isPlaying;
  final Color? color;
  final String intensity; // 'off' | 'subtle' | 'vibrant' | 'immersive'

  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    if (widget.isPlaying && widget.intensity != 'off') {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AmbientGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying ||
        widget.intensity != oldWidget.intensity) {
      if (widget.isPlaying && widget.intensity != 'off') {
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
    if (widget.intensity == 'off') {
      return const SizedBox.shrink();
    }

    var theme = Theme.of(context);
    var glowColor = widget.color ?? theme.colorScheme.primary;

    double size;
    double alpha1;
    double alpha2;

    switch (widget.intensity) {
      case 'subtle':
        size = 260;
        alpha1 = 0.08;
        alpha2 = 0.03;
        break;
      case 'immersive':
        size = 400;
        alpha1 = 0.22;
        alpha2 = 0.10;
        break;
      case 'vibrant':
      default:
        size = 320;
        alpha1 = 0.14;
        alpha2 = 0.06;
        break;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glowColor.withValues(alpha: alpha1),
                  glowColor.withValues(alpha: alpha2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
