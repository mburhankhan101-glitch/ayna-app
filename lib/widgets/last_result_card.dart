import 'package:flutter/material.dart';

import '../models/scan.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/press_scale.dart';

/// What home shows once there is a scan to show.
///
/// The screen previously offered "YOUR FIRST SCAN" forever, to someone on their
/// fifth. That is not just a stale label: the result they paid for was
/// unreachable the moment they left it, so home was simultaneously forgetting
/// what they had done and asking them to do it again.
class LastResultCard extends StatelessWidget {
  const LastResultCard({
    super.key,
    required this.scan,
    required this.onOpen,
    required this.onScan,
    required this.canScan,
  });

  final ScanSummary scan;
  final VoidCallback onOpen;
  final VoidCallback onScan;
  final bool canScan;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Container(
      padding: EdgeInsets.all(t.space5),
      decoration: BoxDecoration(
        color: AynaColors.clay,
        borderRadius: BorderRadius.circular(t.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AynaColors.clay.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _when(scan.submittedAt).toUpperCase(),
            style: AynaType.label.copyWith(color: AynaColors.onClayMuted),
          ),
          SizedBox(height: t.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${scan.overallScore}',
                style: AynaType.displayLarge.copyWith(
                  fontSize: 56,
                  height: 1,
                  color: AynaColors.onClay,
                ),
              ),
              SizedBox(width: t.space2),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'out of 100',
                  style: AynaType.bodyMedium.copyWith(
                    color: AynaColors.onClayMuted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space5),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  child: OutlinedButton(
                    onPressed: onOpen,
                    style: OutlinedButton.styleFrom(
                      // Transparent, explicitly. The app theme fills every
                      // OutlinedButton with a near-white surface for light
                      // screens, which on this clay card put near-white text on
                      // near-white and made the label vanish once already.
                      backgroundColor: Colors.transparent,
                      foregroundColor: AynaColors.onClay,
                      side: const BorderSide(
                        color: AynaColors.onClayMuted,
                        width: 1.5,
                      ),
                      minimumSize: Size.fromHeight(t.minTouch),
                    ),
                    child: const Text('See report'),
                  ),
                ),
              ),
              SizedBox(width: t.space3),
              Expanded(
                child: PressScale(
                  child: FilledButton(
                    onPressed: canScan ? onScan : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AynaColors.onClay,
                      foregroundColor: AynaColors.clay,
                      disabledBackgroundColor: AynaColors.onClay.withValues(
                        alpha: 0.45,
                      ),
                      minimumSize: Size.fromHeight(t.minTouch),
                    ),
                    // Says why it is unavailable rather than sitting greyed out
                    // with no explanation. A disabled button that will not say
                    // what it wants is the most annoying control in software.
                    child: Text(canScan ? 'Scan again' : 'Next week'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Relative for the recent past, absolute once that stops being useful.
  /// "3 days ago" is easier to place than a date; "12 Aug" is easier than
  /// "20 days ago".
  static String _when(DateTime at) {
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 14) return '$days days ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${at.day} ${months[at.month - 1]}';
  }
}
