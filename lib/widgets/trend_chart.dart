import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scan.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';

/// The score over time (FR-8).
///
/// Bars, not a line. A line implies the value existed continuously between two
/// readings, and it did not — there is one measurement per week and nothing in
/// between. Bars say "these are the weeks we measured", which is the truth, and
/// they degrade gracefully to a single bar where a one-point line would just be
/// a dot.
///
/// The y-axis is deliberately anchored at zero. Starting it at the lowest
/// reading would make a two-point rise from 30 to 33 fill the panel, which is
/// how a chart lies without a single wrong number in it — and on a metric this
/// noisy that would manufacture progress every week.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points, this.animation});

  final List<TrendPoint> points;

  /// Drives the grow-in. Bars rise from the baseline in sequence.
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final a = animation;
    if (a == null) return _bars(context, 1);
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) => _bars(context, a.value),
    );
  }

  Widget _bars(BuildContext context, double t) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < points.length; i++)
        Expanded(
          child: _Bar(
            point: points[i],
            isLatest: i == points.length - 1,
            // Each bar starts after the one before it, so the chart reads
            // left to right the way the time it represents does.
            progress: _staggered(t, i, points.length),
          ),
        ),
    ],
  );

  static double _staggered(double t, int i, int n) {
    if (n <= 1) return t;
    final slice = 1 / (n + 2);
    return ((t - i * slice) / (1 - i * slice)).clamp(0.0, 1.0);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.point,
    required this.isLatest,
    required this.progress,
  });

  final TrendPoint point;
  final bool isLatest;
  final double progress;

  static const _maxHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final h = _maxHeight * (point.overallScore / 100) * progress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The number sits above its own bar rather than on an axis. With at
          // most six weeks on screen there is room, and a value you can read
          // without tracing back to a scale is worth more than the axis it
          // replaces.
          Opacity(
            opacity: progress,
            child: Text(
              '${point.overallScore}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isLatest ? FontWeight.w600 : FontWeight.w400,
                color: isLatest ? AynaColors.clay : AynaColors.inkSubtle,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: math.max(h, 2),
            decoration: BoxDecoration(
              // Only the newest week is saturated. The rest are context, and
              // colouring them equally would make the chart a stripe pattern
              // instead of an answer to "where am I now".
              color: isLatest
                  ? AynaColors.clay
                  : AynaColors.clay.withValues(alpha: 0.28),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: progress,
            child: Text(
              _weekLabel(point.weekStart),
              style: const TextStyle(fontSize: 11, color: AynaColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  /// Day and month, no year. Six weeks never straddle enough time for a year to
  /// disambiguate anything, and it would cost the width the bars need.
  static String _weekLabel(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]}';
  }
}

/// The chart with its own entrance, for screens that do not already own a
/// timeline to hang it on.
class AnimatedTrendChart extends StatefulWidget {
  const AnimatedTrendChart({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  State<AnimatedTrendChart> createState() => _AnimatedTrendChartState();
}

class _AnimatedTrendChartState extends State<AnimatedTrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AynaMotion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && !_c.isCompleted) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrendChart(
    points: widget.points,
    animation: CurvedAnimation(parent: _c, curve: AynaMotion.enter),
  );
}
