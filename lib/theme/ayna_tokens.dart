import 'package:flutter/material.dart';

import 'ayna_colors.dart';

/// Mirrors the backend's `Severity` value object. Ordered, so it compares.
///
/// [unknown] is not decoration: a concern the analysis could not assess must
/// never render as "None". Telling someone they have no redness when nothing
/// ever looked is the worst failure this screen can produce, and it is the one
/// a missing-field bug produces by default.
enum Severity { unknown, none, mild, moderate, severe }

/// Design tokens that have no home in [ColorScheme] or [TextTheme].
///
/// A [ThemeExtension] rather than a bag of globals so these travel with the
/// theme — they resolve per-context, survive a future dark variant, and animate
/// correctly across theme changes.
@immutable
class AynaTokens extends ThemeExtension<AynaTokens> {
  const AynaTokens({
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.space8,
    required this.space11,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.minTouch,
    required this.severityFills,
    required this.severityInks,
    required this.heatmapFills,
  });

  // 4pt base scale.
  final double space1; // 4
  final double space2; // 8
  final double space3; // 12
  final double space4; // 16
  final double space5; // 20
  final double space6; // 24
  final double space8; // 32
  final double space11; // 44

  final double radiusSm; // 8
  final double radiusMd; // 10
  final double radiusLg; // 16
  final double radiusXl; // 26 — phone-card and sheet corners

  /// Minimum edge of anything tappable. Not advisory: the design review found
  /// two controls below this and both were wrong.
  final double minTouch; // 48

  final Map<Severity, Color> severityFills;
  final Map<Severity, Color> severityInks;

  /// Overlay colours for the heatmap on the user's own photo. Cool hues only —
  /// warm ones vanish into brown skin. See [AynaColors] for why that is a
  /// product constraint rather than a style choice.
  final Map<Severity, Color> heatmapFills;

  Color fillFor(Severity s) => severityFills[s] ?? AynaColors.severityNone;
  Color inkFor(Severity s) => severityInks[s] ?? AynaColors.inkFaint;
  Color heatFor(Severity s) => heatmapFills[s] ?? AynaColors.heatNone;

  static const light = AynaTokens(
    space1: 4,
    space2: 8,
    space3: 12,
    space4: 16,
    space5: 20,
    space6: 24,
    space8: 32,
    space11: 44,
    radiusSm: 8,
    radiusMd: 10,
    radiusLg: 16,
    radiusXl: 26,
    minTouch: 48,
    severityFills: {
      Severity.unknown: AynaColors.severityNone,
      Severity.none: AynaColors.severityNone,
      Severity.mild: AynaColors.severityMild,
      Severity.moderate: AynaColors.severityModerate,
      Severity.severe: AynaColors.severitySevere,
    },
    severityInks: {
      Severity.unknown: AynaColors.inkFaint,
      Severity.none: AynaColors.severityNoneText,
      Severity.mild: AynaColors.severityMildText,
      Severity.moderate: AynaColors.severityModerateText,
      Severity.severe: AynaColors.severitySevereText,
    },
    heatmapFills: {
      Severity.unknown: AynaColors.heatNone,
      Severity.none: AynaColors.heatNone,
      Severity.mild: AynaColors.heatMild,
      Severity.moderate: AynaColors.heatModerate,
      Severity.severe: AynaColors.heatSevere,
    },
  );

  @override
  AynaTokens copyWith({
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? space8,
    double? space11,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? minTouch,
    Map<Severity, Color>? severityFills,
    Map<Severity, Color>? severityInks,
    Map<Severity, Color>? heatmapFills,
  }) => AynaTokens(
    space1: space1 ?? this.space1,
    space2: space2 ?? this.space2,
    space3: space3 ?? this.space3,
    space4: space4 ?? this.space4,
    space5: space5 ?? this.space5,
    space6: space6 ?? this.space6,
    space8: space8 ?? this.space8,
    space11: space11 ?? this.space11,
    radiusSm: radiusSm ?? this.radiusSm,
    radiusMd: radiusMd ?? this.radiusMd,
    radiusLg: radiusLg ?? this.radiusLg,
    radiusXl: radiusXl ?? this.radiusXl,
    minTouch: minTouch ?? this.minTouch,
    severityFills: severityFills ?? this.severityFills,
    severityInks: severityInks ?? this.severityInks,
    heatmapFills: heatmapFills ?? this.heatmapFills,
  );

  @override
  AynaTokens lerp(covariant AynaTokens? other, double t) {
    if (other == null) return this;
    Map<Severity, Color> lerpMap(
      Map<Severity, Color> a,
      Map<Severity, Color> b,
    ) {
      return {
        for (final s in Severity.values)
          s: Color.lerp(a[s], b[s], t) ?? a[s] ?? const Color(0x00000000),
      };
    }

    return AynaTokens(
      space1: lerpDouble(space1, other.space1, t),
      space2: lerpDouble(space2, other.space2, t),
      space3: lerpDouble(space3, other.space3, t),
      space4: lerpDouble(space4, other.space4, t),
      space5: lerpDouble(space5, other.space5, t),
      space6: lerpDouble(space6, other.space6, t),
      space8: lerpDouble(space8, other.space8, t),
      space11: lerpDouble(space11, other.space11, t),
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t),
      minTouch: lerpDouble(minTouch, other.minTouch, t),
      severityFills: lerpMap(severityFills, other.severityFills),
      severityInks: lerpMap(severityInks, other.severityInks),
      heatmapFills: lerpMap(heatmapFills, other.heatmapFills),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// `context.ayna.space4` instead of digging through `Theme.of`.
extension AynaTokensX on BuildContext {
  AynaTokens get ayna =>
      Theme.of(this).extension<AynaTokens>() ?? AynaTokens.light;
}
