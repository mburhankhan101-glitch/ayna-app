import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';

/// Which illustration a slide shows.
enum OnboardingArtKind { scan, privacy, impression }

/// The animated illustration on an onboarding slide.
///
/// Drawn rather than shipped as an asset, for the same reasons the icons it
/// replaces were: it recolours with the palette, stays sharp at any density,
/// and costs nothing in the bundle. A Lottie file would do this too, at the
/// price of a runtime dependency and an asset nobody on the team can edit.
///
/// Each one depicts what its slide claims, which is the point. A lock icon
/// says "security" as a word; a frame with rings closing around it shows
/// something being held. The first is decoration, the second is the argument.
class OnboardingArt extends StatefulWidget {
  const OnboardingArt({
    super.key,
    required this.kind,
    this.parallax = 0,
    this.accent = AynaColors.clay,
  });

  final OnboardingArtKind kind;

  /// The slide's own brown, passed in rather than read from the palette.
  ///
  /// The accent shifts continuously across the three slides, so the drawing
  /// has to take it from the same place the button does or the two would
  /// disagree mid-swipe.
  final Color accent;

  /// How far this slide is from centre, in pages. 0 is centred, ±1 is fully
  /// off-screen. Drives the parallax offset so the illustration lags the text.
  final double parallax;

  @override
  State<OnboardingArt> createState() => _OnboardingArtState();
}

class _OnboardingArtState extends State<OnboardingArt>
    with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: widget.kind == OnboardingArtKind.scan
          ? AynaMotion.sweep
          : AynaMotion.breath,
    );
    _tap = AnimationController(
      vsync: this,
      duration: AynaMotion.settle,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Started here rather than in initState because it depends on the
    // reduced-motion setting, which needs an inherited widget to read.
    //
    // Under reduced motion the controller is parked at a representative frame
    // instead of looping: the sweep sits mid-face and the rings sit closed, so
    // the drawing still reads as itself rather than as an empty outline.
    if (AynaMotion.reduced(context)) {
      _ambient.stop();
      _ambient.value = 0.5;
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _tap.dispose();
    super.dispose();
  }

  void _onTap() {
    if (AynaMotion.reduced(context)) return;
    // Replaying on tap makes the illustration answer the finger. Onboarding is
    // the one place a user has nothing to do but wait for the next button, so
    // giving them something that responds costs nothing and buys attention.
    _ambient
      ..reset()
      ..repeat();
    _tap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AynaMotion.reduced(context);

    return GestureDetector(
      onTap: _onTap,
      // The illustration is decorative; the slide's text carries the meaning,
      // so a screen reader should walk straight past it rather than announce
      // an unlabelled graphic.
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: Listenable.merge([_ambient, _tap]),
          builder: (context, _) {
            // Depth: the art trails the page by 28px, so the slide reads as
            // layers moving at different speeds rather than one flat card.
            final offset = reduced ? 0.0 : widget.parallax * -28;
            // Falls away as the slide leaves, so the eye follows the incoming
            // one instead of tracking two at once.
            final away = widget.parallax.abs().clamp(0.0, 1.0);
            final pop = Curves.easeOutBack.transform(
              _tap.value.clamp(0.0, 1.0),
            );

            return Transform.translate(
              offset: Offset(offset, 0),
              child: Transform.scale(
                scale: (1 - away * 0.08) * (0.97 + 0.03 * pop),
                child: Opacity(
                  opacity: (1 - away * 0.7).clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _ArtPainter(
                      kind: widget.kind,
                      t: _ambient.value,
                      accent: widget.accent,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter({
    required this.kind,
    required this.t,
    required this.accent,
  });

  final OnboardingArtKind kind;
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn into the box's own shape, not a centred square inside it.
    //
    // The square was right while the panel was a wide band: it stopped the
    // composition stretching across a phone-width strip. Now the panel is
    // portrait, and a square would leave a third of it empty above and below
    // the drawing. Every proportion below is expressed against this rect, so
    // the illustrations grow tall with it.
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.74,
      height: size.height * 0.74,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    switch (kind) {
      case OnboardingArtKind.scan:
        _paintScan(canvas, rect);
      case OnboardingArtKind.privacy:
        _paintPrivacy(canvas, rect);
      case OnboardingArtKind.impression:
        _paintImpression(canvas, rect);
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------
  // Slide 1 — a face, and a sweep passing over it.
  // ---------------------------------------------------------------------

  void _paintScan(Canvas canvas, Rect r) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.75);

    // Near-round rather than a tall ellipse.
    //
    // The panel is wider than it is tall by less than it looks, so a ratio
    // that reads as "head-shaped" on paper came out as a long egg on screen.
    // These two multipliers are chosen against the *rendered* box, not against
    // face anatomy: they land within a few pixels of square on a phone.
    final face = Rect.fromCenter(
      center: r.center,
      width: r.width * 0.74,
      height: r.height * 0.60,
    );
    canvas.drawOval(face, stroke);

    // The sweep travels top to bottom, pauses off the bottom, and restarts.
    final travel = (t * 1.25).clamp(0.0, 1.0);
    final sweepY = face.top - 8 + (face.height + 16) * travel;
    // Band depth scales with the face so it stays a soft wash on a tall panel
    // instead of collapsing towards a hard line.
    final halfBand = face.height * 0.11;

    // Soft band rather than a hard line: a 1px line reads as a laser, which is
    // the wrong promise for something that says "no judgement".
    final band = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: 0),
              accent.withValues(alpha: 0.28),
              accent.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTRB(
              face.left,
              sweepY - halfBand,
              face.right,
              sweepY + halfBand,
            ),
          );

    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    canvas.drawRect(
      Rect.fromLTRB(
        face.left,
        sweepY - halfBand,
        face.right,
        sweepY + halfBand,
      ),
      band,
    );
    canvas.drawLine(
      Offset(face.left + 6, sweepY),
      Offset(face.right - 6, sweepY),
      Paint()
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.55),
    );
    canvas.restore();

    // Contour waves across the face, revealed by the sweep.
    //
    // Four dots claimed four discrete findings, which is both more specific
    // than the product is and easier to read as blemishes on someone's face.
    // Waves say the surface is being read rather than that four things are
    // wrong with it, and they carry the same "it is working" signal without
    // pointing at anything.
    //
    // Each line brightens as the sweep passes and stays lit behind it, so the
    // drawing accumulates instead of resetting: it looks like it is building a
    // picture, which is what the slide promises.
    canvas.save();
    canvas.clipPath(Path()..addOval(face));

    const lines = 7;
    for (var i = 0; i < lines; i++) {
      final y = face.top + face.height * ((i + 0.7) / (lines + 0.4));

      final passed = sweepY - y;
      final lit = passed < 0
          ? 0.0
          : (1 - (passed / (face.height * 0.85))).clamp(0.0, 1.0);
      // A faint resting state so the face is never an empty outline between
      // sweeps, particularly under reduced motion where the clock is parked.
      final alpha = 0.10 + 0.48 * lit;

      final path = Path();
      const steps = 40;
      for (var s = 0; s <= steps; s++) {
        final f = s / steps;
        final x = face.left + face.width * f;
        // Amplitude falls off towards the edges of the oval so the waves sit
        // inside the shape rather than being sliced flat by the clip.
        final envelope = math.sin(f * math.pi);
        // The phase offset per line is what makes them read as a contour map
        // rather than as a stack of identical ripples.
        final dy =
            math.sin(f * math.pi * 3 + t * math.pi * 2 + i * 0.8) *
            face.height *
            0.026 *
            envelope;
        s == 0 ? path.moveTo(x, y + dy) : path.lineTo(x, y + dy);
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 + 0.8 * lit
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: alpha),
      );
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------
  // Slide 2 — a photo, with rings closing around it.
  // ---------------------------------------------------------------------

  void _paintPrivacy(Canvas canvas, Rect r) {
    // Sized against the portrait box and lifted off centre: the lock hangs
    // below the frame, and on a tall panel a centred frame would push it into
    // the bottom edge.
    final frame = Rect.fromCenter(
      center: Offset(r.center.dx, r.center.dy - r.height * 0.08),
      width: r.width * 0.46,
      height: r.height * 0.52,
    );
    final rr = RRect.fromRectAndRadius(frame, const Radius.circular(10));

    // Rings contract inward and fade as they arrive. Outward rings would read
    // as broadcast — exactly the opposite of what the slide promises.
    for (var i = 0; i < 3; i++) {
      final phase = ((t + i / 3) % 1.0);
      final grow = 1.0 - phase;
      final spread = r.width * 0.16 * grow;
      final alpha = (phase < 0.12 ? phase / 0.12 : 1.0) * (1 - phase) * 0.5;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          frame.inflate(spread),
          Radius.circular(10 + spread * 0.5),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = accent.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }

    canvas.drawRRect(rr, Paint()..color = accent.withValues(alpha: 0.10));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.8),
    );

    // A face suggested inside the frame, so it is clearly *your photo* being
    // held rather than a generic document.
    canvas.drawCircle(
      Offset(frame.center.dx, frame.center.dy - frame.height * 0.10),
      frame.width * 0.15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = accent.withValues(alpha: 0.55),
    );
    final shoulders = Path()
      ..moveTo(frame.center.dx - frame.width * 0.26, frame.bottom - 14)
      ..quadraticBezierTo(
        frame.center.dx,
        frame.center.dy + frame.height * 0.12,
        frame.center.dx + frame.width * 0.26,
        frame.bottom - 14,
      );
    canvas.drawPath(
      shoulders,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.55),
    );

    // The shackle closes as the rings arrive: the lock is the resolution of
    // the motion, not an object sitting next to it.
    final close = Curves.easeOutCubic.transform(
      (math.sin(t * math.pi * 2) * 0.5 + 0.5).clamp(0.0, 1.0),
    );
    final lockW = r.width * 0.16;
    final lockBody = Rect.fromCenter(
      center: Offset(r.center.dx, frame.bottom + lockW * 0.55),
      width: lockW,
      height: lockW * 0.78,
    );

    final shackleLift = 5.0 * (1 - close);
    final shackle = Rect.fromCenter(
      center: Offset(lockBody.center.dx, lockBody.top - shackleLift),
      width: lockW * 0.52,
      height: lockW * 0.52,
    );
    canvas.drawArc(
      shackle,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lockBody, const Radius.circular(4)),
      Paint()..color = accent.withValues(alpha: 0.9),
    );
  }

  // ---------------------------------------------------------------------
  // Slide 3 — a pulse that is deliberately not clinical.
  // ---------------------------------------------------------------------

  void _paintImpression(Canvas canvas, Rect r) {
    // Pushed down and widened. On a portrait panel the heart takes the upper
    // third and the wave sits well below it, so the two read as stacked rather
    // than crowded onto one line.
    final mid = r.center.dy + r.height * 0.22;
    final w = r.width * 0.80;
    final left = r.center.dx - w / 2;

    // A rounded wave, not an ECG spike. The slide's whole claim is that this
    // is an impression rather than a medical reading; a hospital trace would
    // contradict the sentence sitting underneath it.
    final path = Path()..moveTo(left, mid);
    const steps = 48;
    for (var i = 1; i <= steps; i++) {
      final x = left + w * (i / steps);
      final phase = (i / steps) * math.pi * 2;
      final envelope = math.sin((i / steps) * math.pi); // fades at both ends
      final y =
          mid - math.sin(phase + t * math.pi * 2) * r.height * 0.08 * envelope;
      path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AynaColors.olive.withValues(alpha: 0.85),
    );

    // Breathing heart above the line. Scaled by the same clock, so the two
    // read as one organism rather than two loops that happen to share a box.
    final beat = 1 + 0.06 * math.sin(t * math.pi * 2);
    final hs = r.width * 0.17 * beat;
    final hc = Offset(r.center.dx, r.top + r.height * 0.30);

    final heart = Path();
    heart.moveTo(hc.dx, hc.dy + hs * 0.72);
    heart.cubicTo(
      hc.dx - hs * 1.4,
      hc.dy - hs * 0.30,
      hc.dx - hs * 0.55,
      hc.dy - hs * 1.12,
      hc.dx,
      hc.dy - hs * 0.36,
    );
    heart.cubicTo(
      hc.dx + hs * 0.55,
      hc.dy - hs * 1.12,
      hc.dx + hs * 1.4,
      hc.dy - hs * 0.30,
      hc.dx,
      hc.dy + hs * 0.72,
    );
    heart.close();

    canvas.drawPath(
      heart,
      Paint()..color = AynaColors.olive.withValues(alpha: 0.13),
    );
    canvas.drawPath(
      heart,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = AynaColors.olive.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.t != t || old.kind != kind;
}
