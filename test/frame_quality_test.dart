import 'dart:typed_data';

import 'package:ayna_app/services/frame_quality.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a luma plane with optional row padding.
///
/// [bytesPerRow] larger than [width] is the normal case on real hardware, not
/// an edge case: camera planes are aligned to a boundary and the padding bytes
/// are whatever was in the buffer. Every test here uses padding by default so
/// a stride bug cannot pass.
Uint8List plane({
  required int width,
  required int height,
  required int bytesPerRow,
  required int Function(int x, int y) value,
  int padding = 255,
}) {
  final out = Uint8List(bytesPerRow * height)
    ..fillRange(0, bytesPerRow * height, padding);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      out[y * bytesPerRow + x] = value(x, y);
    }
  }
  return out;
}

void main() {
  group('meanLuma', () {
    test('averages a flat plane', () {
      final p = plane(
        width: 64,
        height: 64,
        bytesPerRow: 64,
        value: (_, _) => 120,
      );
      expect(
        FrameQuality.meanLuma(p, width: 64, height: 64, bytesPerRow: 64),
        closeTo(120, 0.001),
      );
    });

    test('ignores row padding', () {
      // The bug this guards: treating bytesPerRow as width walks diagonally
      // through the buffer and averages the padding along with the image. Here
      // the padding is deliberately 255 against an image of 100, so a stride
      // mistake pulls the mean far above the real value rather than failing
      // subtly.
      final p = plane(
        width: 64,
        height: 64,
        bytesPerRow: 96,
        value: (_, _) => 100,
        padding: 255,
      );
      expect(
        FrameQuality.meanLuma(p, width: 64, height: 64, bytesPerRow: 96),
        closeTo(100, 0.001),
      );
    });

    test('subsampling does not change the hint', () {
      // Subsampling is a performance choice, and the guarantee that matters is
      // not that it reproduces the exact mean -- it cannot. Skipping pixels
      // omits the last (step - 1) columns of every row, so any frame with a
      // strong left-to-right gradient reads slightly differently at step 8 than
      // at step 1. A synthetic ramp exaggerates that to about 7 points.
      //
      // What must hold is that the user-visible output is identical: a textured
      // frame near the middle of the range gives the same hint however finely
      // it is read. A step that could flip the ring from amber to green would
      // make the guidance depend on a performance tuning constant.
      final p = plane(
        width: 128,
        height: 128,
        bytesPerRow: 160,
        value: (x, y) => 110 + ((x * 7 + y * 13) % 31) - 15,
      );

      CaptureHint hintAt(int step) {
        final mean = FrameQuality.meanLuma(
          p,
          width: 128,
          height: 128,
          bytesPerRow: 160,
          step: step,
        );
        final h = FrameQuality.halves(
          p,
          width: 128,
          height: 128,
          bytesPerRow: 160,
          step: step,
        );
        return FrameQuality.hint(mean: mean, left: h.left, right: h.right);
      }

      expect(hintAt(8), hintAt(1));
      expect(hintAt(4), hintAt(1));
      expect(hintAt(1), CaptureHint.ready);
    });

    test('an empty or zero-sized plane is 0, not a crash', () {
      expect(
        FrameQuality.meanLuma(
          Uint8List(0),
          width: 0,
          height: 0,
          bytesPerRow: 0,
        ),
        0,
      );
    });
  });

  group('halves', () {
    test('detects side lighting', () {
      final p = plane(
        width: 100,
        height: 40,
        bytesPerRow: 128,
        value: (x, _) => x < 50 ? 200 : 60,
      );
      final h = FrameQuality.halves(
        p,
        width: 100,
        height: 40,
        bytesPerRow: 128,
      );
      expect(h.left, closeTo(200, 1));
      expect(h.right, closeTo(60, 1));
    });

    test('even light gives equal halves', () {
      final p = plane(
        width: 100,
        height: 40,
        bytesPerRow: 128,
        value: (_, _) => 130,
      );
      final h = FrameQuality.halves(
        p,
        width: 100,
        height: 40,
        bytesPerRow: 128,
      );
      expect((h.left - h.right).abs(), lessThan(1));
    });
  });

  group('hint', () {
    test('exposure is reported before evenness', () {
      // In a dark room both checks trip. "Find brighter light" fixes both;
      // sending someone to even out light they do not have is the wrong
      // instruction, so the order here is load-bearing rather than incidental.
      expect(
        FrameQuality.hint(mean: 20, left: 5, right: 90),
        CaptureHint.tooDark,
      );
    });

    test('flags each condition', () {
      expect(
        FrameQuality.hint(mean: 30, left: 30, right: 30),
        CaptureHint.tooDark,
      );
      expect(
        FrameQuality.hint(mean: 230, left: 230, right: 230),
        CaptureHint.tooBright,
      );
      expect(
        FrameQuality.hint(mean: 130, left: 40, right: 190),
        CaptureHint.uneven,
      );
      expect(
        FrameQuality.hint(mean: 130, left: 125, right: 135),
        CaptureHint.ready,
      );
    });

    test('ordinary indoor light passes', () {
      // A regression guard on the thresholds themselves. They are provisional,
      // but a normally-lit selfie must never be told to find better light --
      // a viewfinder that nags at usable conditions trains people to ignore it,
      // and then it cannot warn them when it matters.
      for (final mean in [70.0, 100.0, 140.0, 180.0]) {
        expect(
          FrameQuality.hint(mean: mean, left: mean - 10, right: mean + 10),
          CaptureHint.ready,
          reason: 'mean $mean should be acceptable',
        );
      }
    });

    test('every hint has copy, and only ready reads as good', () {
      for (final h in CaptureHint.values) {
        expect(h.message, isNotEmpty);
        expect(h.isGood, h == CaptureHint.ready);
      }
    });
  });
}
