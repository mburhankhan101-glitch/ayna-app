import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';

/// A beam that leaves a contour mesh behind it as it crosses the face.
///
/// Replaces four dots that lit up in sequence. The dots were the wrong idea
/// twice over: four points cannot represent six concerns, and a handful of
/// blinking circles reads as decoration rather than as measurement.
///
/// Contours read as measurement because that is what they are for — a surface
/// being mapped. They also accumulate, so the screen fills rather than looping
/// back to empty, and a screen that fills looks like it is getting somewhere.
class ScanBeam extends StatelessWidget {
  const ScanBeam({super.key, required this.sweep, required this.progress});

  /// 0-1, repeating. Where the beam currently is.
  final double sweep;

  /// 0-1, monotonic. How much of the mesh has been laid down.
  final double progress;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BeamPainter(sweep: sweep, progress: progress),
    size: Size.infinite,
  );
}

class _BeamPainter extends CustomPainter {
  const _BeamPainter({required this.sweep, required this.progress});

  final double sweep;
  final double progress;

  /// Matches the capture guide, so the beam maps the region the user was asked
  /// to fill rather than an unrelated rectangle.
  static Rect ovalFor(Size size) {
    final short = math.min(size.width, size.height);
    final w = short * 0.84;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: w,
      height: w * 1.30,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final oval = ovalFor(size);

    canvas.save();
    canvas.clipPath(Path()..addOval(oval));

    _paintMesh(canvas, oval);
    _paintBeam(canvas, oval);

    canvas.restore();

    // The ring last and unclipped, so the mesh reads as contained by it.
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AynaColors.captureGuide.withValues(alpha: 0.30),
    );
  }

  /// Horizontal contours, revealed top-down in step with [progress].
  ///
  /// Each line bows slightly, more toward the middle of the face, which is
  /// enough to suggest a surface rather than a stack of straight rules. Cheap:
  /// a quadratic per line, no per-pixel work.
  void _paintMesh(Canvas canvas, Rect oval) {
    const lines = 16;
    final revealed = progress.clamp(0.0, 1.0) * lines;

    for (var i = 0; i < lines; i++) {
      final shown = (revealed - i).clamp(0.0, 1.0);
      if (shown <= 0.01) continue;

      final f = (i + 0.5) / lines;
      final y = oval.top + oval.height * f;

      // Bow is greatest across the middle of the face and flattens toward the
      // forehead and chin, the way a real contour would.
      final bow = math.sin(f * math.pi) * oval.height * 0.045;

      final path = Path()
        ..moveTo(oval.left, y)
        ..quadraticBezierTo(oval.center.dx, y + bow, oval.right, y);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          // Fades toward the edges of the oval by fading the whole line with
          // its own reveal, which keeps the count of draw calls flat.
          ..color = AynaColors.captureOk.withValues(alpha: 0.34 * shown),
      );
    }
  }

  void _paintBeam(Canvas canvas, Rect oval) {
    final y = oval.top - 24 + (oval.height + 48) * sweep;

    final band = Rect.fromLTRB(oval.left, y - 54, oval.right, y + 54);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AynaColors.captureOk.withValues(alpha: 0),
            AynaColors.captureOk.withValues(alpha: 0.26),
            AynaColors.captureOk.withValues(alpha: 0),
          ],
        ).createShader(band),
    );

    // The leading edge, bright and thin. A soft band alone has no position;
    // the line is what makes the beam somewhere rather than a glow.
    canvas.drawLine(
      Offset(oval.left, y),
      Offset(oval.right, y),
      Paint()
        ..strokeWidth = 1.6
        ..color = AynaColors.captureOk.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.sweep != sweep || old.progress != progress;
}

/// A slim vertical bar that fills upward.
///
/// Vertical, and never a circular spinner: a spinner says "something is
/// happening" and nothing else, which is the one thing the user can already
/// see. A bar that climbs says how much is left.
class ScanMeter extends StatelessWidget {
  const ScanMeter({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 6,
    child: CustomPaint(
      painter: _MeterPainter(progress: progress),
      size: Size.infinite,
    ),
  );
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.width / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = AynaColors.captureGuide.withValues(alpha: 0.22),
    );

    final h = size.height * progress.clamp(0.0, 1.0);
    if (h <= 0) return;

    // Bottom-up. Down-to-up reads as filling; up-to-down reads as draining.
    final fill = Rect.fromLTRB(0, size.height - h, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, r),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AynaColors.captureOk,
            AynaColors.captureOk.withValues(alpha: 0.7),
          ],
        ).createShader(fill),
    );
  }

  @override
  bool shouldRepaint(_MeterPainter old) => old.progress != progress;
}
