import 'package:flutter/material.dart';

import '../models/scan.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/entrance.dart';
import '../widgets/press_scale.dart';
import '../widgets/trend_chart.dart';

/// The weekly scan is used up, and here is what Plus would change.
///
/// Shown *before* the camera opens, never after a photo has been taken and
/// refused — discovering a limit is annoying, discovering it after doing the
/// work is worse.
///
/// ## What persuades here, and what is deliberately absent
///
/// The persuasion is **endowment**: it shows the user their own data and the
/// part of it they cannot reach. A generic feature list asks someone to imagine
/// a benefit; their own greyed-out weeks make the loss concrete, because it is
/// already theirs and already recorded.
///
/// Everything else follows from being honest about a product with no billing
/// and one unproven feature:
///
///   * **No countdown timer, no "offer ends", no fake scarcity.** Nothing here
///     expires, and inventing a deadline to force a decision is the difference
///     between persuasion and manipulation.
///   * **No invented social proof.** There are no other users yet, so there is
///     nothing true to say about them.
///   * **Heatmaps are not sold.** FR-4's overlay would be the most compelling
///     line on this screen and it has never once been produced — `return_maps`
///     failed every call. Selling it would be selling something that does not
///     exist.
///   * **The close is a normal-sized button in the normal place.** A paywall
///     that is hard to leave gets left permanently.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({
    super.key,
    required this.resetsAt,
    required this.onClose,
    this.onUpgrade,
    this.trend,
    this.totalWeeks = 0,
  });

  /// When the next free scan unlocks. Null when the server did not say — the
  /// screen then says so rather than inventing a date.
  final DateTime? resetsAt;

  final VoidCallback onClose;

  /// Null while store billing does not exist. The button says so plainly
  /// instead of pretending to be a purchase.
  final VoidCallback? onUpgrade;

  /// The weeks the user can currently see. Shown alongside the ones they
  /// cannot, because that contrast is the argument.
  final List<TrendPoint>? trend;

  /// How many weeks exist in total, including the ones behind the plan.
  final int totalWeeks;

  int get _hidden {
    final shown = trend?.length ?? 0;
    return totalWeeks > shown ? totalWeeks - shown : 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final points = trend ?? const <TrendPoint>[];

    return Scaffold(
      backgroundColor: AynaColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  t.space6,
                  t.space8,
                  t.space6,
                  t.space6,
                ),
                children: [
                  // The wait comes first, and it is answered for free.
                  //
                  // Leading with the upgrade would make the date feel like
                  // something being withheld. Answering first costs nothing and
                  // means the offer that follows is a way to skip a known wait
                  // rather than the price of information.
                  Entrance(child: _Countdown(resetsAt: resetsAt)),
                  SizedBox(height: t.space8),

                  if (points.length >= 2) ...[
                    Entrance(
                      delay: const Duration(milliseconds: 120),
                      child: Text(
                        'YOUR SCANS SO FAR',
                        style: AynaType.label.copyWith(
                          color: AynaColors.inkSubtle,
                        ),
                      ),
                    ),
                    SizedBox(height: t.space4),
                    Entrance(
                      delay: const Duration(milliseconds: 170),
                      child: TrendChart(points: points),
                    ),
                    SizedBox(height: t.space4),
                    if (_hidden > 0)
                      Entrance(
                        delay: const Duration(milliseconds: 260),
                        child: Text(
                          // Their data, and the number of it they cannot see.
                          // Concrete, true, and about them rather than about
                          // the plan.
                          '$_hidden more week${_hidden == 1 ? '' : 's'} of your '
                          'own history is recorded but not shown on the free '
                          'plan.',
                          style: AynaType.bodyLarge,
                        ),
                      ),
                    SizedBox(height: t.space8),
                  ],

                  Entrance(
                    delay: const Duration(milliseconds: 300),
                    child: Text('With Plus', style: AynaType.titleMedium),
                  ),
                  SizedBox(height: t.space4),

                  for (var i = 0; i < _benefits.length; i++)
                    Entrance(
                      delay: Duration(milliseconds: 340 + i * 70),
                      fromX: 16,
                      child: _Benefit(
                        headline: _benefits[i].$1,
                        detail: _benefits[i].$2,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(t.space6, 0, t.space6, t.space5),
              child: Column(
                children: [
                  Entrance(
                    delay: const Duration(milliseconds: 560),
                    child: PressScale(
                      child: ElevatedButton(
                        onPressed: onUpgrade,
                        child: Text(
                          onUpgrade == null
                              ? 'Plus is not on sale yet'
                              : 'See Plus',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: t.space1),
                  Entrance(
                    delay: const Duration(milliseconds: 610),
                    child: TextButton(
                      onPressed: onClose,
                      child: const Text('Not now'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Each benefit names what it changes, not what it is.
  ///
  /// "Unlimited scans" is a spec. "Scan the morning after you change something"
  /// is the reason anyone would want one — it describes a moment the user has
  /// already had and been unable to act on.
  static const _benefits = [
    (
      'Scan whenever you want to',
      'Change a product on Monday and check on Tuesday, instead of waiting '
          'out the week to find out whether it helped.',
    ),
    (
      'Keep every week, not the last six',
      'Skin moves over months. Six weeks is barely long enough to tell a '
          'trend from a bad night.',
    ),
    (
      'Skin age on every scan',
      'The one number that changes slowly enough to be worth watching.',
    ),
  ];
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.resetsAt});

  final DateTime? resetsAt;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("That's this week's scan", style: AynaType.displayMedium),
        SizedBox(height: t.space3),
        Text(
          _wait(resetsAt),
          style: AynaType.bodyLarge.copyWith(color: AynaColors.inkMuted),
        ),
        SizedBox(height: t.space4),
        Container(
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
                  // Worth repeating here specifically. Someone looking at a
                  // limit is working out what used it up, and a rejected photo
                  // is the thing they are most likely to blame wrongly.
                  'Photos we could not read never counted against this.',
                  style: AynaType.bodyMedium.copyWith(
                    color: AynaColors.oliveDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Days and a weekday, not a timestamp. "Tuesday" is something a person can
  /// plan around; an ISO string is something they have to decode.
  static String _wait(DateTime? at) {
    if (at == null) {
      return 'Your next scan unlocks a week after your last one.';
    }

    final left = at.difference(DateTime.now());
    if (left.isNegative) return 'Your next scan is available now.';

    if (left.inHours < 24) {
      final h = left.inHours;
      return h <= 1
          ? 'Your next scan unlocks within the hour.'
          : 'Your next scan unlocks in $h hours.';
    }

    final d = left.inDays;
    return 'Your next scan unlocks in $d day${d == 1 ? '' : 's'}, '
        'on ${_weekday(at)}.';
  }

  static String _weekday(DateTime d) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][d.weekday - 1];
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.headline, required this.detail});

  final String headline;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Padding(
      padding: EdgeInsets.only(bottom: t.space5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AynaColors.clay,
              ),
            ),
          ),
          SizedBox(width: t.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: AynaType.titleSmall),
                SizedBox(height: t.space1),
                Text(
                  detail,
                  style: AynaType.bodyMedium.copyWith(
                    color: AynaColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
