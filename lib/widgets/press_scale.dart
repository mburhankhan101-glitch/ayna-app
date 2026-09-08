import 'package:flutter/material.dart';

import '../theme/ayna_motion.dart';

/// Shrinks its child slightly while a finger is down.
///
/// Uses [Listener] rather than a gesture detector on purpose: a gesture
/// detector here would enter the gesture arena and could win the tap away from
/// the button it wraps, which is the classic way this effect silently breaks
/// the control it was meant to decorate. [Listener] observes pointers without
/// competing for them.
///
/// Wraps the button rather than replacing its `onPressed` so the button keeps
/// its own semantics, focus behaviour and ink response.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;

  /// How far to shrink. Deliberately small — this is confirmation that the
  /// touch registered, not an animation anyone should notice consciously.
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    // Without this, a press that turns into a scroll leaves the control
    // stuck at 97% until the next tap.
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      // Well inside the Doherty Threshold: press feedback that arrives
      // late reads as lag in the button, not as animation.
      duration: AynaMotion.of(context, AynaMotion.instant),
      curve: AynaMotion.enter,
      scale: _down ? widget.scale : 1.0,
      child: widget.child,
    ),
  );
}
