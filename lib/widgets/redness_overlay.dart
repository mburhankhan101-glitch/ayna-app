import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';

/// "Where your redness is" — the photo with the overlay already on it.
///
/// Named for the one concern it covers rather than called a heatmap. The vendor
/// publishes five overlays; four were rejected on inspection, and calling this
/// "heatmaps" would promise a feature that mostly does not exist.
///
/// Comes from the server pre-composited, so there is no blending to get wrong
/// here and no clean face photograph held anywhere.
class RednessOverlay extends StatefulWidget {
  const RednessOverlay({super.key, required this.image});

  /// JPEG bytes, or null when this scan produced no overlay.
  final Uint8List? image;

  @override
  State<RednessOverlay> createState() => _RednessOverlayState();
}

class _RednessOverlayState extends State<RednessOverlay> {
  /// Whether the overlay is showing, as opposed to the bare photo.
  ///
  /// Toggleable, and it starts on. Being able to take the marks off is what
  /// makes them believable — a user who cannot compare has to take the app's
  /// word for what it has drawn on their face.
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final img = widget.image;
    if (img == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'WHERE YOUR REDNESS IS',
                style: AynaType.label.copyWith(color: AynaColors.inkSubtle),
              ),
            ),
            // A plain text toggle rather than a switch: it is a view control,
            // not a setting, and nothing about it persists.
            TextButton(
              onPressed: () => setState(() => _on = !_on),
              child: Text(_on ? 'Hide' : 'Show'),
            ),
          ],
        ),
        SizedBox(height: t.space2),

        ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusLg),
          child: AspectRatio(
            // The overlay is composited at the photo's own dimensions, and the
            // photo was trimmed to 4:3 before analysis. Matching that here keeps
            // the marks aligned with the face rather than stretched across it.
            aspectRatio: 3 / 4,
            child: AnimatedSwitcher(
              duration: AynaMotion.of(context, AynaMotion.base),
              // Cross-fade rather than a cut, so the marks appear to settle onto
              // the face instead of the whole image being swapped.
              child: _on
                  ? Image.memory(
                      img,
                      key: const ValueKey('on'),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : ColoredBox(
                      key: const ValueKey('off'),
                      color: AynaColors.surfaceSunk,
                      child: Center(
                        child: Text(
                          // The bare photo is not stored, so "off" cannot show
                          // it. Saying so is better than a blank panel that
                          // looks like a failed load.
                          'Your photo is not kept.\nOnly this marked-up copy.',
                          textAlign: TextAlign.center,
                          style: AynaType.bodyMedium.copyWith(
                            color: AynaColors.inkSubtle,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),

        SizedBox(height: t.space3),
        Text(
          // Says what the marks mean and what they do not. Without this the
          // overlay is a picture of someone's face with red on it, which
          // invites a more clinical reading than the data supports.
          'Darker areas are where the analysis found more redness. Lips are '
          'excluded, they are meant to be red.',
          style: AynaType.bodySmall,
        ),
      ],
    );
  }
}
