import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomScrollbar extends StatefulWidget {
  final Widget child;
  final String Function(double scrollPercentage)? sectionGetter;

  const CustomScrollbar({
    super.key,
    required this.child,
    this.sectionGetter,
  });

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
  String? _currentSection;

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

  void _updateSection(double percentage) {
    if (widget.sectionGetter == null) return;
    var newSection = widget.sectionGetter!(percentage.clamp(0.0, 1.0));
    if (newSection != _currentSection) {
      HapticFeedback.selectionClick();
      _currentSection = newSection;
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
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

    var showBubble = _isDragging &&
        widget.sectionGetter != null &&
        _currentSection != null &&
        _currentSection!.isNotEmpty;

    var bubbleTop = (thumbOffset + (thumbHeight / 2) - 24)
        .clamp(12.0, (_viewportDimension - 56.0).clamp(12.0, double.infinity));

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        children: [
          widget.child,
          if (_maxScrollExtent > 0 && thumbHeight < _viewportDimension) ...[
            // Floating section letter bubble
            Positioned(
              top: bubbleTop,
              right: 28,
              child: IgnorePointer(
                child: AnimatedScale(
                  scale: showBubble ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: showBubble ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _currentSection ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Fast scroll thumb
            Positioned(
              top: thumbOffset,
              right: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragDown: (details) {
                  var percentage = maxThumbOffset > 0
                      ? thumbOffset / maxThumbOffset
                      : 0.0;
                  _updateSection(percentage);
                  setState(() {
                    _isDragging = true;
                    _dragThumbOffset = thumbOffset;
                  });
                },
                onVerticalDragCancel: () {
                  setState(() {
                    _isDragging = false;
                    _dragThumbOffset = null;
                    _currentSection = null;
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

                  _updateSection(newPercentage);

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
                    _currentSection = null;
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
