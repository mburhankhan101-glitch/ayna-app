import 'package:flutter/material.dart';

import '../state/history.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/entrance.dart';
import '../widgets/trend_chart.dart';

/// The score over time (FR-8).
///
/// Three states, and the empty ones are not placeholders. A trend genuinely
/// needs two readings to exist, and saying so — while showing the shape the
/// chart will take — tells the user what the feature is and exactly what
/// unlocks it. "Coming soon" would tell them neither.
class TrendScreen extends StatelessWidget {
  const TrendScreen({super.key, required this.history});

  final History history;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final trend = history.trend;

    return RefreshIndicator(
      onRefresh: history.load,
      color: AynaColors.clay,
      child: ListView(
        padding: EdgeInsets.fromLTRB(t.space6, t.space5, t.space6, t.space8),
        children: [
          Entrance(child: Text('Your trend', style: AynaType.displaySmall)),
          SizedBox(height: t.space6),

          if (trend == null || !trend.hasTrend)
            _Waiting(scansSoFar: trend?.points.length ?? 0)
          else ...[
            Entrance(
              delay: const Duration(milliseconds: 100),
              child: AnimatedTrendChart(points: trend.points),
            ),
            SizedBox(height: t.space6),
            Entrance(
              delay: const Duration(milliseconds: 400),
              child: _Reading(history: history),
            ),
            if (trend.truncated) ...[
              SizedBox(height: t.space5),
              Entrance(
                delay: const Duration(milliseconds: 470),
                child: _Truncated(
                  hidden: trend.totalAvailable - trend.points.length,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Not enough readings yet.
///
/// Shows the shape the chart will take rather than an icon, so the empty state
/// previews the feature instead of replacing it.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.scansSoFar});

  final int scansSoFar;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Column(
      children: [
        SizedBox(height: t.space8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Container(
                width: 26,
                height: 40.0 + (i * 8),
                margin: EdgeInsets.symmetric(horizontal: t.space1),
                decoration: BoxDecoration(
                  // The weeks already recorded are solid; the rest are the
                  // shape waiting to be filled. Progress the user can see.
                  color: i < scansSoFar
                      ? AynaColors.clay
                      : AynaColors.severityNone,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: t.space5),
        Text(
          scansSoFar == 0
              ? 'Two scans and this fills in'
              : 'One more scan and this fills in',
          style: AynaType.titleMedium,
        ),
        SizedBox(height: t.space2),
        Text(
          'A trend needs something to compare. Scan once a week and this '
          'becomes the most useful screen in the app.',
          style: AynaType.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// One sentence about the direction, in the second person.
class _Reading extends StatelessWidget {
  const _Reading({required this.history});

  final History history;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final points = history.trend!.points;
    final change =
        points.last.overallScore - points[points.length - 2].overallScore;

    // A three-point band around zero reads as "steady" rather than as movement.
    // The vendor's own stability gate allows 8 points of drift between
    // identical photos, so calling a 2-point change an improvement would be
    // reporting noise as progress — the exact failure FR-8 cannot survive.
    final text = switch (change) {
      > 3 => 'Up $change points since last time.',
      < -3 => 'Down ${-change} points since last time.',
      _ => 'Holding steady.',
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space5),
      decoration: BoxDecoration(
        color: AynaColors.clayTint,
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AynaType.titleMedium),
          SizedBox(height: t.space2),
          Text(
            'Small week-to-week movement is normal. Look at the shape over a '
            'month rather than any single step.',
            style: AynaType.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// What is behind the paywall, said plainly.
class _Truncated extends StatelessWidget {
  const _Truncated({required this.hidden});

  final int hidden;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        border: Border.all(color: AynaColors.border),
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Text(
        // Naming the number is the point. A paywall works because you can see
        // what you are missing; hiding that anything exists just makes the app
        // look like it has nothing.
        '$hidden earlier week${hidden == 1 ? '' : 's'} are kept but not shown '
        'on the free plan.',
        style: AynaType.bodyMedium,
      ),
    );
  }
}
