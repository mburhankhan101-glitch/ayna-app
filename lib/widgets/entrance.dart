import 'package:flutter/material.dart';

import '../theme/ayna_motion.dart';

/// Fades and lifts a child into place once, on first build.
///
/// Screens arrive as a stack of finished elements, which gives the eye nothing
/// to follow and is most of why a static layout reads as flat. Staggering the
/// arrival gives it an order, and the order is the reading order — the
/// Serial Position Effect says the first and last things in a sequence are the
/// ones that stick, so what arrives first and last is a content decision, not
/// a timing one.
///
/// The delay is expressed as an [Interval] on a single controller rather than
/// a `Future.delayed` that calls `forward()`. That is deliberate: a timer
/// firing into a disposed widget is a crash, and the guard against it is easy
/// to forget. There is no timer here to get wrong.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 14,
    this.fromX = 0,
  });

  final Widget child;

  /// How long after the screen appears this element should begin arriving.
  final Duration delay;

  /// How far below its resting place it starts, in logical pixels.
  final double distance;

  /// Horizontal offset to arrive from, for rows in a list. Lists read better
  /// sliding in from the side: the eye tracks down the column instead of
  /// watching each row rise independently.
  final double fromX;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    final total = widget.delay + AynaMotion.settle;
    _controller = AnimationController(vsync: this, duration: total);

    final begin = total.inMicroseconds == 0
        ? 0.0
        : (widget.delay.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);

    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1, curve: AynaMotion.enter),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reading the reduced-motion setting needs an inherited widget, which is
    // not available in initState.
    if (AynaMotion.reduced(context)) {
      // Straight to finished. Not a fast version of the animation — a user who
      // asked for no motion should see the screen already assembled.
      _controller.value = 1;
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    // Passed as `child` so the subtree is built once and only the wrappers
    // rebuild per frame.
    child: widget.child,
    builder: (context, child) {
      final v = _progress.value.clamp(0.0, 1.0);
      return Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(
            0,
            AynaMotion.shift(context, (1 - v) * widget.distance),
          ),
          child: child,
        ),
      );
    },
  );
}
