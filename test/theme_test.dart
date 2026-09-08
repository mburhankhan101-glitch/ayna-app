import 'package:ayna_app/theme/ayna_colors.dart';
import 'package:ayna_app/theme/ayna_theme.dart';
import 'package:ayna_app/theme/ayna_tokens.dart';
import 'package:ayna_app/theme/ayna_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AynaTheme.light();

  test('tokens travel with the theme', () {
    expect(
      theme.extension<AynaTokens>(),
      isNotNull,
      reason:
          'AynaTokens must be registered or context.ayna silently '
          'falls back to defaults and drift goes unnoticed',
    );
  });

  test('every tappable clears the 48px floor', () {
    final t = theme.extension<AynaTokens>()!;
    expect(t.minTouch, 48);

    for (final size in [
      theme.elevatedButtonTheme.style?.minimumSize?.resolve({}),
      theme.outlinedButtonTheme.style?.minimumSize?.resolve({}),
    ]) {
      expect(
        size?.height,
        greaterThanOrEqualTo(48),
        reason: 'the design review already caught two controls under this',
      );
    }
    expect(
      theme.inputDecorationTheme.constraints?.minHeight,
      greaterThanOrEqualTo(48),
    );
  });

  test('severity covers every level, including unknown', () {
    final t = theme.extension<AynaTokens>()!;
    for (final s in Severity.values) {
      expect(t.severityFills[s], isNotNull, reason: 'fill missing for $s');
      expect(t.severityInks[s], isNotNull, reason: 'ink missing for $s');
      expect(t.heatmapFills[s], isNotNull, reason: 'heat missing for $s');
    }
  });

  test('heatmap stays on the cool side of the wheel', () {
    final t = theme.extension<AynaTokens>()!;
    // Warm overlays vanish into brown skin. Blue channel must lead — this is
    // the constraint most likely to be "improved" away by someone matching the
    // heatmap to the brand colour.
    for (final s in [Severity.mild, Severity.moderate, Severity.severe]) {
      final c = t.heatFor(s);
      expect(
        c.b,
        greaterThan(c.r),
        reason: '$s heat overlay is warm — it will disappear on deeper skin',
      );
    }
  });

  test('nothing in the palette is an alarm red', () {
    // A severe reading is information, not a failure. If error ever becomes a
    // true red, the referral card stops reading as care and starts reading as
    // a warning — which is exactly what NFR-6 forbids.
    expect(theme.colorScheme.error, AynaColors.clayDark);
  });

  test('letter spacing is converted from em, not copied', () {
    // CSS -0.035em at 34px is about -1.19 logical px. Copying "-0.035" straight
    // from the stylesheet would be invisible on screen.
    expect(AynaType.displayLarge.letterSpacing, closeTo(-1.19, 0.01));
    expect(AynaType.scoreHero.letterSpacing, closeTo(-4.92, 0.01));
    expect(AynaType.label.letterSpacing, closeTo(1.54, 0.01));
  });

  test('display weights carry an explicit variable-font axis', () {
    // Mulish is a variable font; without the wght axis some platforms
    // synthesise the bold and the 900 weights look wrong.
    final v = AynaType.displayLarge.fontVariations;
    expect(v, isNotNull);
    expect(v!.first.axis, 'wght');
    expect(v.first.value, 900);
  });

  testWidgets('preview renders and resolves tokens from context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) =>
              Text('x', style: TextStyle(fontSize: context.ayna.space4)),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('x')).style?.fontSize, 16);
  });
}
