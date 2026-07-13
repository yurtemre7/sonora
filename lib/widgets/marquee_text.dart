import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 30.0,
    this.blankSpace = 40.0,
    this.startDelay = const Duration(seconds: 3),
    this.pauseAfterRound = const Duration(seconds: 3),
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final double velocity;
  final double blankSpace;
  final Duration startDelay;
  final Duration pauseAfterRound;
  final TextAlign textAlign;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  Timer? _timer;
  var _shouldScroll = false;
  var _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _stopScrolling();
      _scrollController.dispose();
      _scrollController = ScrollController();
    }
  }

  @override
  void dispose() {
    _stopScrolling();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopScrolling() {
    _timer?.cancel();
    _isScrolling = false;
  }

  void _startScrolling(double maxScroll) {
    if (_isScrolling) return;
    _isScrolling = true;
    _runScrollLoop(maxScroll);
  }

  void _runScrollLoop(double maxScroll) {
    _timer = Timer(widget.startDelay, () async {
      if (!mounted || !_scrollController.hasClients || !_isScrolling) return;

      var remainingDistance = maxScroll - _scrollController.offset;
      if (remainingDistance <= 0) return;

      var durationMs = (remainingDistance / widget.velocity * 1000).toInt();

      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.linear,
      );

      if (!mounted || !_scrollController.hasClients || !_isScrolling) return;

      await Future.delayed(widget.pauseAfterRound);

      if (!mounted || !_scrollController.hasClients || !_isScrolling) return;

      _scrollController.jumpTo(0.0);

      _runScrollLoop(maxScroll);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        var textWidth = textPainter.width;
        var maxVisibleWidth = constraints.maxWidth;

        _shouldScroll = textWidth > maxVisibleWidth;

        if (!_shouldScroll) {
          _stopScrolling();
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
          );
        }

        var maxScroll = textWidth + widget.blankSpace;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startScrolling(maxScroll);
          }
        });

        return SizedBox(
          width: maxVisibleWidth,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.text, style: widget.style),
                SizedBox(width: widget.blankSpace),
                Text(widget.text, style: widget.style),
              ],
            ),
          ),
        );
      },
    );
  }
}
