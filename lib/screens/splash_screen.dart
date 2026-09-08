import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';

/// The one moment clay owns the whole screen.
///
/// Shown while the stored session is restored, so it doubles as the loading
/// state — which is why there is no spinner. A returning user sees a brand
/// moment for a fraction of a second instead of a progress indicator that
/// implies something is slow.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      backgroundColor: AynaColors.clay,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A mirror: an outer ring with a soft highlight inside. Drawn
            // rather than shipped as an asset so it scales cleanly and can be
            // recoloured with the palette.
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AynaColors.onClay, width: 3),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AynaColors.onClay.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
            SizedBox(height: t.space5),
            Text(
              'Ayna',
              style: AynaType.displayLarge.copyWith(color: AynaColors.onClay),
            ),
            SizedBox(height: t.space2),
            Text(
              'A kinder look at your skin',
              style: AynaType.bodyMedium.copyWith(
                color: AynaColors.onClayMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
