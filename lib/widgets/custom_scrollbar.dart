import 'dart:async';
import 'package:flutter/material.dart';

class CustomScrollbar extends StatefulWidget {
  final Widget child;

  const CustomScrollbar({super.key, required this.child});

  @override
  State<CustomScrollbar> createState() => _CustomScrollbarState();
}

class _CustomScrollbarState extends State<CustomScrollbar> {
  var _scrollOffset = 0.0;
  var _maxScrollExtent = 0.0;
  var _viewportDimension = 1.0;
  var _isScrolling = false;
  var _isDragging = false;
  double? _dragThumbOffset;
  Timer? _fadeTimer;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      if (mounted) {
        setState(() {
          _scrollOffset = notification.metrics.pixels;
          _maxScrollExtent = notification.metrics.maxScrollExtent;
          _viewportDimension = notification.metrics.viewportDimension;

          _isScrolling = true;
          _fadeTimer?.cancel();
          _fadeTimer = Timer(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() {
                _isScrolling = false;
              });
            }
          });
        });
      }
    }
    return false;
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double contentHeight = _maxScrollExtent + _viewportDimension;
    double thumbHeight =
        (_viewportDimension / contentHeight * _viewportDimension) * 0.75;
    if (thumbHeight.isNaN || thumbHeight.isInfinite) thumbHeight = 0;

    // Ensure clamp limits are valid
    double minThumbHeight = _viewportDimension < 40.0
        ? _viewportDimension
        : 40.0;
    thumbHeight = thumbHeight.clamp(minThumbHeight, _viewportDimension);

    double maxThumbOffset = _viewportDimension - thumbHeight;
    if (maxThumbOffset < 0) maxThumbOffset = 0;

    double scrollPercentage = _maxScrollExtent > 0
        ? _scrollOffset / _maxScrollExtent
        : 0;
    double thumbOffset = _isDragging && _dragThumbOffset != null
        ? _dragThumbOffset!
        : (scrollPercentage * maxThumbOffset);
    if (thumbOffset.isNaN || thumbOffset.isInfinite) thumbOffset = 0;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        children: [
          widget.child,
          if (_maxScrollExtent > 0 && thumbHeight < _viewportDimension)
            Positioned(
              top: thumbOffset,
              right: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragDown: (details) {
                  setState(() {
                    _isDragging = true;
                    _dragThumbOffset = thumbOffset;
                  });
                },
                onVerticalDragCancel: () {
                  setState(() {
                    _isDragging = false;
                    _dragThumbOffset = null;
                  });
                },
                onVerticalDragUpdate: (details) {
                  _fadeTimer?.cancel();

                  double currentOffset = _dragThumbOffset ?? thumbOffset;
                  double newThumbOffset = (currentOffset + details.delta.dy)
                      .clamp(0.0, maxThumbOffset);
                  double newPercentage = maxThumbOffset > 0
                      ? newThumbOffset / maxThumbOffset
                      : 0;
                  double newScrollOffset = newPercentage * _maxScrollExtent;

                  setState(() {
                    _isScrolling = true;
                    _dragThumbOffset = newThumbOffset;
                  });

                  var primaryController = PrimaryScrollController.maybeOf(
                    context,
                  );
                  if (primaryController != null &&
                      primaryController.hasClients) {
                    for (var position in primaryController.positions) {
                      position.jumpTo(newScrollOffset);
                    }
                  }
                },
                onVerticalDragEnd: (details) {
                  setState(() {
                    _isDragging = false;
                    _dragThumbOffset = null;
                  });
                  _fadeTimer = Timer(const Duration(milliseconds: 1500), () {
                    if (mounted) setState(() => _isScrolling = false);
                  });
                },
                child: MouseRegion(
                  onEnter: (_) {
                    _fadeTimer?.cancel();
                    setState(() => _isScrolling = true);
                  },
                  onExit: (_) {
                    _fadeTimer = Timer(const Duration(milliseconds: 1500), () {
                      if (mounted) setState(() => _isScrolling = false);
                    });
                  },
                  child: AnimatedOpacity(
                    opacity: (_isScrolling || _isDragging) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: _isDragging ? 12 : 8,
                      height: thumbHeight,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
