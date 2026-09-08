import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';

/// The oval a face goes in, and the scrim around it.
///
/// This is the whole framing instruction. There is no face detector behind it:
/// an outline of a head, centred, is a request people satisfy without being
/// told — and it costs nothing, works offline, and cannot be wrong about
/// someone's face the way a detector can.
///
/// The ring carries the lighting state, because that is where the user is
/// already looking. A hint pinned to the bottom of the screen competes with
/// their own reflection; a ring that turns green around their face does not.
class FaceGuide extends StatelessWidget {
  const FaceGuide({super.key, required this.good});

  /// Whether the current frame passes the lighting checks.
  final bool good;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // Eased rather than switched: exposure hovers at a threshold, and a ring
    // that flicks between two colours on a borderline frame is worse than no
    // signal at all.
    tween: Tween(begin: 0, end: good ? 1 : 0),
    duration: AynaMotion.of(context, AynaMotion.base),
    curve: AynaMotion.enter,
    builder: (context, t, _) => CustomPaint(
      painter: _FaceGuidePainter(good: t),
      size: Size.infinite,
    ),
  );
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter({required this.good});

  /// 0 = needs attention, 1 = ready. Continuous so the colour can be eased.
  final double good;

  /// Where the oval sits, as a fraction of the shorter edge.
  ///
  /// Sized from the short edge so the guide keeps its proportions on a tall
  /// phone and a squat one alike, and placed slightly above centre because a
  /// face framed dead-centre leaves the chin crowding the bottom of the oval —
  /// heads are not symmetrical about the eyes.
  static Rect ovalFor(Size size) {
    final short = math.min(size.width, size.height);
    // Widened from 0.72 after testing on a real phone: at arm's length a face
    // filling a 0.72 oval sits well back in the frame, and the vendor gets
    // fewer pixels of skin than the camera actually captured. The guide should
    // ask for the framing the analysis wants, not a comfortable-looking one.
    final w = short * 0.84;
    final h = w * 1.30;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width: w,
      height: h,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final oval = ovalFor(size);

    // Scrim everywhere except the oval, in one path with an even-odd fill.
    // Two rects and a clip would do it too, but this stays a single draw and
    // cannot leave a seam where the pieces meet.
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      scrim,
      Paint()..color = AynaColors.captureGround.withValues(alpha: 0.72),
    );

    final ring = Color.lerp(
      AynaColors.captureGuide,
      AynaColors.captureOk,
      good,
    )!;

    // A soft halo under the ring, growing as conditions improve. It reads as
    // the guide warming up rather than as a second element appearing.
    if (good > 0.01) {
      canvas.drawOval(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = ring.withValues(alpha: 0.18 * good)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ring.withValues(alpha: 0.9),
    );

    // Corner ticks. They give the oval a sense of being an instrument rather
    // than a sticker, and they mark the widest and tallest points so a user
    // who is slightly off-centre can see which way to move.
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = ring;

    const len = 16.0;
    canvas.drawLine(
      Offset(oval.center.dx - len / 2, oval.top),
      Offset(oval.center.dx + len / 2, oval.top),
      tick,
    );
    canvas.drawLine(
      Offset(oval.center.dx - len / 2, oval.bottom),
      Offset(oval.center.dx + len / 2, oval.bottom),
      tick,
    );
    canvas.drawLine(
      Offset(oval.left, oval.center.dy - len / 2),
      Offset(oval.left, oval.center.dy + len / 2),
      tick,
    );
    canvas.drawLine(
      Offset(oval.right, oval.center.dy - len / 2),
      Offset(oval.right, oval.center.dy + len / 2),
      tick,
    );
  }

  @override
  bool shouldRepaint(_FaceGuidePainter old) => old.good != good;
}
