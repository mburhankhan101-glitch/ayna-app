import 'dart:typed_data';

/// What the capture screen should tell the user right now.
///
/// Ordered by how much it should interrupt: [ready] says nothing, the others
/// each name one fixable thing. Never more than one at a time — a viewfinder
/// listing three problems is a viewfinder nobody reads.
enum CaptureHint { ready, tooDark, tooBright, uneven }

extension CaptureHintCopy on CaptureHint {
  /// Second person, present tense, and always an instruction rather than a
  /// diagnosis. "Underexposed" is a fact about the image; "find brighter light"
  /// is something a person can act on while holding a phone at arm's length.
  String get message => switch (this) {
    CaptureHint.ready => 'Looks good, hold still',
    CaptureHint.tooDark => 'Find brighter light',
    CaptureHint.tooBright => 'Too bright, move out of direct light',
    CaptureHint.uneven => 'Light is uneven, face a window not a lamp',
  };

  bool get isGood => this == CaptureHint.ready;
}

/// Frame quality, computed from the luma plane alone.
///
/// Deliberately not a face detector. ML Kit would give real face positioning
/// and cost a large dependency, a bigger APK, and a Play Services requirement —
/// for a check the oval guide already handles socially: people put their face
/// in the outline because it is an outline of a face.
///
/// What an outline cannot fix is lighting, and lighting is the one capture
/// variable that actually changes the vendor's numbers. A dark frame yields a
/// worse reading of the same skin, which would show up as "your skin got worse"
/// on the trend — the exact failure FR-8 cannot survive. So this measures the
/// thing that matters and leaves framing to the guide.
abstract final class FrameQuality {
  /// Thresholds on the 0–255 luma scale.
  ///
  /// Provisional, and honestly so: they were chosen from how a mid-range phone
  /// exposes an indoor selfie and want checking on real devices in real rooms.
  /// They are wide on purpose — a viewfinder that nags at usable light trains
  /// people to ignore it, and a false "too dark" is worse than a slightly dim
  /// photo the vendor handles fine.
  static const darkBelow = 55.0;
  static const brightAbove = 205.0;

  /// How much brighter one half of the face may be than the other before the
  /// light counts as uneven. Side-lighting from a window or a lamp is the most
  /// common real-world capture problem after darkness, and unlike overall
  /// exposure the camera will not correct for it.
  static const unevenAbove = 58.0;

  /// Mean luma over the [y] plane, sampled rather than summed.
  ///
  /// [step] skips pixels: at step 4 this reads one pixel in sixteen, which is
  /// far more than enough for an average and keeps the work off the frame
  /// budget. This runs on every analysed frame, so it must stay cheap — a
  /// preview that stutters reads as a broken app long before anyone reads a
  /// hint.
  ///
  /// [bytesPerRow] is not always [width]: camera planes are commonly padded to
  /// an alignment boundary, and treating the stride as the width walks
  /// diagonally across the image and averages garbage.
  static double meanLuma(
    Uint8List y, {
    required int width,
    required int height,
    required int bytesPerRow,
    int step = 4,
  }) {
    if (width <= 0 || height <= 0 || y.isEmpty) return 0;

    var total = 0;
    var count = 0;
    for (var row = 0; row < height; row += step) {
      final offset = row * bytesPerRow;
      for (var col = 0; col < width; col += step) {
        final i = offset + col;
        if (i >= y.length) break;
        total += y[i];
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  /// Mean luma of the left and right halves, for the side-lighting check.
  static ({double left, double right}) halves(
    Uint8List y, {
    required int width,
    required int height,
    required int bytesPerRow,
    int step = 4,
  }) {
    if (width <= 0 || height <= 0 || y.isEmpty) {
      return (left: 0, right: 0);
    }

    var lSum = 0, lCount = 0, rSum = 0, rCount = 0;
    final mid = width ~/ 2;

    for (var row = 0; row < height; row += step) {
      final offset = row * bytesPerRow;
      for (var col = 0; col < width; col += step) {
        final i = offset + col;
        if (i >= y.length) break;
        if (col < mid) {
          lSum += y[i];
          lCount++;
        } else {
          rSum += y[i];
          rCount++;
        }
      }
    }

    return (
      left: lCount == 0 ? 0 : lSum / lCount,
      right: rCount == 0 ? 0 : rSum / rCount,
    );
  }

  /// The single hint to show for this frame.
  ///
  /// Exposure is checked before evenness on purpose: in a genuinely dark room
  /// both trip, and "find brighter light" is the instruction that fixes both.
  /// Telling someone their light is uneven when the real problem is that there
  /// is barely any sends them to solve the wrong thing.
  static CaptureHint hint({
    required double mean,
    required double left,
    required double right,
  }) {
    if (mean < darkBelow) return CaptureHint.tooDark;
    if (mean > brightAbove) return CaptureHint.tooBright;
    if ((left - right).abs() > unevenAbove) return CaptureHint.uneven;
    return CaptureHint.ready;
  }
}
