import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/entrance.dart';
import '../widgets/press_scale.dart';

/// A scan that produced no report: rejected, failed, or refused.
///
/// One screen for all three because the user's situation is the same in each —
/// they waited and got nothing — and what differs is only what to do next.
///
/// The reassurance line is not padding. Every one of these outcomes leaves the
/// user's weekly allowance untouched, and they have no way to know that unless
/// the screen says so. Someone who suspects a blurry photo cost them their week
/// stops taking photos, which is the most expensive possible reaction to the
/// cheapest possible failure.
class ScanOutcomeScreen extends StatelessWidget {
  const ScanOutcomeScreen({
    super.key,
    required this.title,
    required this.body,
    required this.reassurance,
    required this.onClose,
  });

  final String title;
  final String body;
  final String reassurance;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              Entrance(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AynaColors.clayTint,
                  ),
                  child: const Icon(
                    // Deliberately not a warning triangle or a red cross. None
                    // of these outcomes is dangerous and none is the user's
                    // fault in a way that deserves alarm styling.
                    Icons.refresh_rounded,
                    color: AynaColors.clay,
                  ),
                ),
              ),
              SizedBox(height: t.space5),

              Entrance(
                delay: const Duration(milliseconds: 90),
                child: Text(title, style: AynaType.displaySmall),
              ),
              SizedBox(height: t.space3),
              Entrance(
                delay: const Duration(milliseconds: 150),
                child: Text(body, style: AynaType.bodyLarge),
              ),
              SizedBox(height: t.space4),

              Entrance(
                delay: const Duration(milliseconds: 210),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(t.space4),
                  decoration: BoxDecoration(
                    color: AynaColors.oliveTint,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: AynaColors.oliveDeep,
                      ),
                      SizedBox(width: t.space3),
                      Expanded(
                        child: Text(
                          reassurance,
                          style: AynaType.bodyMedium.copyWith(
                            color: AynaColors.oliveDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              Entrance(
                delay: const Duration(milliseconds: 260),
                child: PressScale(
                  child: ElevatedButton(
                    onPressed: onClose,
                    child: const Text('Try again'),
                  ),
                ),
              ),
              SizedBox(height: t.space4),
            ],
          ),
        ),
      ),
    );
  }
}
