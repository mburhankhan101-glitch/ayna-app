import 'package:flutter/material.dart';

/// Raw colour tokens for the Warm Mirror direction.
///
/// These are the only place a hex literal is allowed to exist in the app.
/// Everything else, widgets and screens and one-off decorations, reads from
/// here or from [AynaTokens], so changing the brand is one edit rather than a
/// find-and-replace across every screen.
///
/// Revised away from terracotta-on-cream. That pairing (a salmon #CC785C-ish
/// accent on a yellow cream ground) is the default warm palette every AI tool
/// reaches for, and the app was wearing it exactly. The hue moved from orange
/// into genuine brown, and the ground lost its yellow in favour of a faint
/// blush, which suits a skin product and belongs to nobody else.
abstract final class AynaColors {
  // Brand — walnut, not terracotta. Roughly 30 degrees further round the wheel
  // and considerably darker, which is what makes it read as brown rather than
  // as a warmer orange.
  static const clay = Color(0xFF7B4A33);
  static const clayDark = Color(0xFF5C3524);
  static const clayTint = Color(0xFFF1EAE3);
  static const claySoft = Color(0xFFE6D8CA);
  static const olive = Color(0xFF55684A);
  static const oliveDeep = Color(0xFF3E4E35);
  static const oliveTint = Color(0xFFF0F4EC);

  // Ground — oat with a blush lean, not butter.
  static const cream = Color(0xFFF7F1EC);
  static const surface = Color(0xFFFFFCF9);
  static const surfaceSunk = Color(0xFFEDE4DA);

  // Ink
  static const ink = Color(0xFF3A322A);
  static const inkMuted = Color(0xFF6B6055);
  static const inkSubtle = Color(0xFF8A7D6E);
  static const inkFaint = Color(0xFFA79883);

  // Lines
  static const border = Color(0xFFDED2C6);
  static const divider = Color(0xFFEBE1D8);

  // On-brand foregrounds
  static const onClay = Color(0xFFFDF6EF);
  static const onClayMuted = Color(0xFFE8D3C2);

  /// Camera capture runs on its own near-black ground so the preview and the
  /// alignment guide carry the screen. It is deliberately not [ink].
  static const captureGround = Color(0xFF241D18);
  static const captureGuide = Color(0xFFE8C9A8);
  static const captureOk = Color(0xFF7FC08D);

  // ---------------------------------------------------------------------------
  // Severity — two ramps, and they are not interchangeable.
  // ---------------------------------------------------------------------------

  /// Severity in the UI: one hue, rising intensity.
  ///
  /// Not traffic lights. Red reads as *danger*, and the product explicitly does
  /// not diagnose (NFR-6); it is also the palette that fails red-green colour
  /// blindness. A single-hue ramp reads as "more of a thing" rather than
  /// "worse person", and survives greyscale.
  ///
  /// Re-cut to the walnut hue when the brand moved. The ramp has to be the
  /// brand's own hue for "more of a thing" to read; leaving it on the old
  /// terracotta would have made severity a second, competing colour.
  static const severityNone = Color(0xFFE7DED4);
  static const severityMild = Color(0xFFD2B79E);
  static const severityModerate = Color(0xFFAE7C5B);
  static const severitySevere = Color(0xFF7B4A33);

  /// Severity *over the photo* — cool hues only.
  ///
  /// Warm overlays disappear into brown skin. Since the stated market is South
  /// Asian users, the heatmap cannot reuse the clay ramp above however much
  /// more on-brand it would look. This constraint is the product's, not the
  /// palette's.
  static const heatNone = Color(0x00000000);
  static const heatMild = Color(0x8C7E8FA8);
  static const heatModerate = Color(0x8C5E8BB5);
  static const heatSevere = Color(0x9E3D74A8);

  /// Text colour for a severity label. Mild/Moderate need a darker ink than
  /// their fill to stay legible on cream.
  static const severityNoneText = Color(0xFF988E80);
  static const severityMildText = Color(0xFF9C7148);
  static const severityModerateText = Color(0xFF8A5537);
  static const severitySevereText = Color(0xFF7B4A33);
}
