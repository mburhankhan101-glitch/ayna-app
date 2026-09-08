import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Durations were the one part of the design system that never got written
/// down, so every screen invented its own: 260ms here, 200ms there, chosen by
/// whoever typed the widget. That is why the app reads as static even where
/// things technically move — unrelated timings do not compose into a feel.
///
/// The ceiling is the Doherty Threshold (400ms). Past it the user starts
/// waiting on the interface rather than the interface keeping up with them,
/// and animation inverts from "making change legible" into "delay". Anything a
/// tap is blocked on lives at [quick] or below.
///
/// [breath] and [sweep] sit far outside that bound on purpose. They are
/// ambient: nothing is waiting on them to finish, so the threshold does not
/// apply. Holding them to 400ms would make them twitch.
abstract final class AynaMotion {
  /// Press and release. Below ~100ms reads as instantaneous, which is what a
  /// finger already touching glass expects.
  static const instant = Duration(milliseconds: 90);

  /// Small state changes: dots, toggles, colour shifts.
  static const quick = Duration(milliseconds: 170);

  /// The default. Page changes, card transitions.
  static const base = Duration(milliseconds: 260);

  /// Entrances that carry distance. The ceiling — nothing blocking goes above.
  static const settle = Duration(milliseconds: 380);

  /// Ambient loops. Slow enough to read as alive rather than as a spinner.
  static const breath = Duration(milliseconds: 3400);
  static const sweep = Duration(milliseconds: 2800);

  /// Decelerating. Correct for anything arriving — it lands rather than stops.
  static const enter = Curves.easeOutCubic;

  /// Accelerating. Correct for anything leaving; it should not linger.
  static const exit = Curves.easeInCubic;

  /// Material 3's emphasised curve, for the one movement that should feel
  /// deliberate rather than incidental.
  static const emphasised = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Slight overshoot. Reserved for confirmation — a thing appearing because
  /// the user succeeded, never for routine arrival.
  static const overshoot = Curves.easeOutBack;

  /// Whether the platform has asked for reduced motion.
  ///
  /// Android's "Remove animations" and iOS's "Reduce Motion" are accessibility
  /// settings, not preferences to second-guess: for a user with vestibular
  /// sensitivity, parallax and sweeping motion can cause actual nausea. Honour
  /// it by removing movement, not by speeding it up.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// A duration that collapses to zero under reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// A displacement that collapses to zero under reduced motion.
  ///
  /// Opacity still animates in that mode — cross-fades do not trigger motion
  /// sensitivity, and removing them too would make state changes jump with no
  /// indication anything happened.
  static double shift(BuildContext context, double px) =>
      reduced(context) ? 0 : px;
}
