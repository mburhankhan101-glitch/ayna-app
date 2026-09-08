import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_typography.dart';

/// The oval around your face becoming the arc around your score.
///
/// A shared-element transition, hand-drawn rather than handed to [Hero].
/// Hero swaps one widget for another and tweens the box between them, which is
/// right for a photo growing into a detail page and wrong here: the two shapes
/// differ in aspect ratio, stroke weight, colour, and in one being a closed
/// ellipse while the other is an open arc. Tweening the *box* would stretch a
/// ring; what has to be tweened is the geometry.
///
/// So there is one painter with a single value from 0 to 1. At 0 it draws the
/// capture oval over the photo; at 1 it draws the score arc on cream; in
/// between it draws neither screen — it draws the truth between them.
///
/// The claim the motion makes is causal, and no wording can make it: *this
/// circle was around your face, and it is now your score.* A cut says the app
/// finished loading. This says the app looked at you.
class ScanMorphView extends StatelessWidget {
  const ScanMorphView({
    super.key,
    required this.photo,
    required this.t,
    required this.score,
  });

  /// The photo being analysed.
  ///
  /// Nullable because the design harness has no camera roll, and because a
  /// file can vanish between capture and render on a device under storage
  /// pressure. Either way the morph must still run: the shape carries the
  /// meaning and the photo is context.
  final File? photo;

  /// 0 = the analysing screen's oval. 1 = the result screen's arc.
  final double t;

  final int score;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

    // The number appears only in the back half, once the shape has become
    // recognisably an arc. Counting up inside something still shaped like a
    // face outline would read as a glitch rather than a reveal.
    final numberIn = ((t - 0.45) / 0.4).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, box) {
        final target = _targetCenter(context, box.biggest);

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: AynaColors.cream),

            // The photo and its scrim fade together, so the dark capture world
            // recedes as one thing rather than the dim lifting off the image.
            Opacity(
              opacity: 1 - e,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photo != null)
                    Image.file(
                      photo!,
                      fit: BoxFit.cover,
                      // A missing file must not take the transition down with
                      // it. The ground colour underneath is what the scrim
                      // would have produced anyway.
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AynaColors.captureGround),
                    )
                  else
                    const ColoredBox(color: AynaColors.captureGround),
                  ColoredBox(
                    color: AynaColors.captureGround.withValues(alpha: 0.74),
                  ),
                ],
              ),
            ),

            CustomPaint(
              painter: _MorphPainter(t: e, score: score, targetCenter: target),
              size: Size.infinite,
            ),

            if (numberIn > 0)
              Positioned(
                left: 0,
                right: 0,
                top: target.dy - 46,
                child: Opacity(
                  opacity: numberIn,
                  child: Text(
                    (numberIn * score).round().toString(),
                    textAlign: TextAlign.center,
                    style: AynaType.displayLarge.copyWith(
                      fontSize: 76,
                      height: 1,
                      color: AynaColors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Where the arc must land: the centre of the result screen's hero.
  ///
  /// Derived from the same values that screen lays out with — safe-area top,
  /// its space8 leading gap, then half the 236pt hero. Hardcoding a guess here
  /// would make the shape jump on the frame the morph hands over, which is the
  /// one frame the whole effect is judged on.
  static Offset _targetCenter(BuildContext context, Size size) {
    final top = MediaQuery.paddingOf(context).top;
    return Offset(size.width / 2, top + 32 + 118);
  }
}

class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.t,
    required this.score,
    required this.targetCenter,
  });

  final double t;
  final int score;
  final Offset targetCenter;

  /// The result arc: open at the bottom, three quarters of a turn.
  static const _arcStart = math.pi * 0.75;
  static const _arcSweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final short = math.min(size.width, size.height);

    // Start: the capture oval, tall and centred on the face.
    final from = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: short * 0.84,
      height: short * 0.84 * 1.30,
    );

    // End: the hero circle, 236 across.
    const heroSide = 236.0;
    final to = Rect.fromCenter(
      center: targetCenter,
      width: heroSide - 24,
      height: heroSide - 24,
    );

    final rect = Rect.lerp(from, to, t)!;

    // The ring unwinds: a closed ellipse at 0, opening to the score's arc.
    // Sweeping the *end* backwards while the start rotates forwards is what
    // makes it read as unwinding rather than as a ring being cropped.
    final start = _lerp(-math.pi / 2, _arcStart, t);
    final sweep = _lerp(math.pi * 2, _arcSweep * (score / 100), t);
    final width = _lerp(1.5, 14, t);

    // The empty part of the track only exists on the result screen, so it
    // arrives late — before that there is nothing for it to be the remainder of.
    final trackIn = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    if (trackIn > 0) {
      canvas.drawArc(
        rect,
        _arcStart,
        _arcSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = AynaColors.clay.withValues(alpha: 0.10 * trackIn),
      );
    }

    // The bloom fades in with the clay, so the stroke gains weight rather than
    // suddenly acquiring a shadow.
    if (t > 0.2) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 1.6
          ..strokeCap = StrokeCap.round
          ..color = AynaColors.clay.withValues(alpha: 0.13 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Colour travels from the capture guide's amber to the report's clay-to-
    // olive gradient. A gradient cannot be lerped against a flat colour, so the
    // flat one is drawn under and the gradient faded over it.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = AynaColors.captureGuide.withValues(alpha: 0.85),
    );

    if (t > 0.05) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: _arcStart,
            endAngle: _arcStart + _arcSweep,
            colors: [
              AynaColors.clayDark.withValues(alpha: t),
              AynaColors.clay.withValues(alpha: t),
              AynaColors.olive.withValues(alpha: t),
            ],
            stops: const [0, 0.55, 1],
            transform: const GradientRotation(_arcStart),
          ).createShader(rect),
      );
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_MorphPainter old) =>
      old.t != t || old.score != score || old.targetCenter != targetCenter;
}
