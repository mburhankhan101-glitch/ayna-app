import 'package:flutter/material.dart';

import 'ayna_colors.dart';

/// Mulish, one family, hierarchy carried by weight and scale.
///
/// A single-family system rather than a display/body pairing: two sans-serifs
/// tend to read muddy, and Mulish holds up at 11px on a phone where a display
/// serif would not.
abstract final class AynaType {
  static const family = 'Mulish';

  /// CSS letter-spacing is relative (`-0.035em`); Flutter's is absolute logical
  /// pixels. Copying the CSS number straight across is a real and easy bug —
  /// `-0.035` in Flutter is imperceptible, where the design wants roughly −1.2
  /// at 34px. Always convert.
  static double tracking(double fontSize, double em) => fontSize * em;

  static TextStyle _base(
    double size,
    FontWeight weight, {
    double em = 0,
    double? height,
    Color color = AynaColors.ink,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    // Mulish ships as a variable font, so the `wght` axis is set explicitly
    // alongside fontWeight. Without it some platforms fall back to
    // synthesising a bold from the default instance, which is visibly
    // worse at the 900 weights this design leans on.
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    letterSpacing: tracking(size, em),
    height: height,
    color: color,
  );

  // --- The score numeral -----------------------------------------------------
  // The memorable element of the whole app, and the reason the type system can
  // survive losing its serif. Tight tracking is doing the work; do not relax it.

  static final scoreHero = _base(
    82,
    FontWeight.w900,
    em: -0.06,
    height: 0.82,
    color: AynaColors.clay,
  );
  static final scoreLarge = _base(
    56,
    FontWeight.w900,
    em: -0.055,
    height: 0.85,
    color: AynaColors.clay,
  );
  static final scoreCompact = _base(28, FontWeight.w900, em: -0.04);

  // --- Display / title / body / label ---------------------------------------

  static final displayLarge = _base(
    34,
    FontWeight.w900,
    em: -0.035,
    height: 1.05,
  );
  static final displayMedium = _base(
    28,
    FontWeight.w900,
    em: -0.035,
    height: 1.1,
  );
  static final displaySmall = _base(
    25,
    FontWeight.w900,
    em: -0.035,
    height: 1.15,
  );

  static final titleLarge = _base(20, FontWeight.w800, em: -0.02, height: 1.25);
  static final titleMedium = _base(17, FontWeight.w800, height: 1.35);
  static final titleSmall = _base(13.5, FontWeight.w700, height: 1.4);

  static final bodyLarge = _base(
    15,
    FontWeight.w400,
    height: 1.6,
    color: AynaColors.inkMuted,
  );
  static final bodyMedium = _base(
    13.5,
    FontWeight.w400,
    height: 1.55,
    color: AynaColors.inkMuted,
  );
  static final bodySmall = _base(
    12.5,
    FontWeight.w400,
    height: 1.5,
    color: AynaColors.inkSubtle,
  );

  /// All-caps eyebrow. The wide tracking is what makes it read as a label
  /// rather than as small body copy.
  static final label = _base(
    11,
    FontWeight.w800,
    em: 0.14,
    height: 1.3,
    color: AynaColors.inkSubtle,
  );
  static final labelSmall = _base(
    10.5,
    FontWeight.w800,
    em: 0.14,
    height: 1.3,
    color: AynaColors.inkFaint,
  );

  static final button = _base(15, FontWeight.w800, height: 1.2);

  /// The "not a diagnosis" line (NFR-6).
  ///
  /// It has its own named style because it is not decoration: it appears on
  /// every screen that shows a result, and it must stay calm — never an alert
  /// colour, never inside a dismissible banner. Giving it a style rather than
  /// ad-hoc formatting is what stops it drifting screen by screen.
  static final disclaimer = _base(
    10.5,
    FontWeight.w500,
    height: 1.5,
    color: AynaColors.inkFaint,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: displaySmall,
    headlineMedium: titleLarge,
    headlineSmall: titleMedium,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: button,
    labelMedium: label,
    labelSmall: labelSmall,
  );
}
