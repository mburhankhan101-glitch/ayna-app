import 'dart:io';

import 'package:flutter/material.dart';

import 'dev/sample_reports.dart';
import 'models/scan.dart';
import 'screens/result_screen.dart';
import 'screens/name_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/scan_outcome_screen.dart';
import 'theme/ayna_colors.dart';
import 'theme/ayna_theme.dart';
import 'theme/ayna_tokens.dart';
import 'theme/ayna_typography.dart';
import 'widgets/scan_morph.dart';
import 'widgets/trend_chart.dart';

/// A design harness for the screens that normally cost money to reach.
///
///     flutter run -t lib/main_preview.dart
///
/// The result screen is only reachable in the real app by completing a scan,
/// and every scan is a paid vendor call plus one of the user's weekly
/// allowance. Iterating on a layout through that path costs real credits per
/// look, which is an absurd price for moving a number four pixels — and it
/// makes designers avoid iterating, which is the worse cost.
///
/// No auth, no network, no camera. Every state is one tap away, and the
/// entrance animations replay on each visit so timing can actually be judged.
void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ayna preview',
    debugShowCheckedModeBanner: false,
    theme: AynaTheme.light(),
    themeMode: ThemeMode.light,
    home: const _Menu(),
  );
}

class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      backgroundColor: AynaColors.cream,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(t.space6),
          children: [
            SizedBox(height: t.space5),
            Text('Preview', style: AynaType.displayMedium),
            SizedBox(height: t.space2),
            Text(
              'Design harness. No network, no camera, no credits.',
              style: AynaType.bodyMedium,
            ),
            SizedBox(height: t.space6),

            _Item(
              label: 'Result: two mild concerns',
              detail: 'The real 30 / skin age 25 scan',
              onTap: () => _open(context, SampleReports.clear),
            ),
            _Item(
              label: 'Result: things to watch',
              detail: 'Severe acne, moderate redness and spots',
              onTap: () => _open(context, SampleReports.concerns),
            ),
            _Item(
              label: 'Result: free tier, one unassessed',
              detail: 'No skin age; redness reads "not assessed"',
              onTap: () => _open(context, SampleReports.partial),
            ),

            SizedBox(height: t.space5),
            Text(
              'TREND',
              style: AynaType.label.copyWith(color: AynaColors.inkSubtle),
            ),
            SizedBox(height: t.space2),

            _Item(
              label: 'Trend: six weeks',
              detail: 'Bars grow in sequence, newest highlighted',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TrendPreview(weeks: 6, total: 12),
                ),
              ),
            ),
            _Item(
              label: 'Trend: just two scans',
              detail: 'The minimum that counts as a trend',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrendPreview(weeks: 2)),
              ),
            ),

            SizedBox(height: t.space5),
            Text(
              'TRANSITION',
              style: AynaType.label.copyWith(color: AynaColors.inkSubtle),
            ),
            SizedBox(height: t.space2),

            _Item(
              label: 'Morph: oval into arc',
              detail: 'Scrub it frame by frame, or press Play',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MorphScrubber(score: 30),
                ),
              ),
            ),

            SizedBox(height: t.space5),
            Text(
              'ONBOARDING',
              style: AynaType.label.copyWith(color: AynaColors.inkSubtle),
            ),
            SizedBox(height: t.space2),

            // First in the section because it is first in the product. It was
            // missing from this harness entirely, which is why it went unseen.
            _Item(
              label: 'Onboarding: the three slides',
              detail: 'Swipe through; art and dots track the finger',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                    onDone: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            _Item(
              label: 'Name: what should we call you?',
              detail: 'Shown when the identity provider gave no name',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NameScreen(
                    onContinue: (_) => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

            SizedBox(height: t.space5),
            Text(
              'PAYWALL',
              style: AynaType.label.copyWith(color: AynaColors.inkSubtle),
            ),
            SizedBox(height: t.space2),

            _Item(
              label: 'Paywall: with their own history',
              detail: 'Six weeks shown, six more recorded and locked',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(
                    resetsAt: DateTime.now().add(const Duration(days: 5)),
                    trend: _sampleTrend,
                    totalWeeks: 12,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            _Item(
              label: 'Paywall: first week, no history yet',
              detail: 'Falls back to the wait and the benefits',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(
                    resetsAt: DateTime.now().add(const Duration(days: 5)),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            _Item(
              label: 'Paywall: hours away',
              detail: 'Under a day reads in hours',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(
                    resetsAt: DateTime.now().add(const Duration(hours: 7)),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            _Item(
              label: 'Paywall: server said nothing',
              detail: 'No date invented when none was sent',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(
                    resetsAt: null,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

            SizedBox(height: t.space5),
            Text(
              'OUTCOMES',
              style: AynaType.label.copyWith(color: AynaColors.inkSubtle),
            ),
            SizedBox(height: t.space2),

            for (final r in RejectionReason.values)
              _Item(
                label: r.title,
                detail: r.advice,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ScanOutcomeScreen(
                      title: r.title,
                      body: r.advice,
                      reassurance: 'This did not use up your weekly scan.',
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, SkinReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          report: report,
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.label, required this.detail, required this.onTap});

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: t.space4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AynaColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AynaType.titleSmall),
                  SizedBox(height: t.space1),
                  Text(detail, style: AynaType.bodySmall),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AynaColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrubber for the oval-to-arc morph.
///
/// A 900ms transition is exactly long enough to feel wrong and exactly short
/// enough that you cannot say where. Judging it at full speed means guessing;
/// dragging through it frame by frame means seeing which frame is ugly.
///
/// Needs a photo behind it to be worth anything — the morph is mostly about
/// how the dark capture world recedes — so it takes one from the camera roll
/// path if present and falls back to a flat panel.
class MorphScrubber extends StatefulWidget {
  const MorphScrubber({super.key, this.photo, required this.score});

  final File? photo;
  final int score;

  @override
  State<MorphScrubber> createState() => _MorphScrubberState();
}

class _MorphScrubberState extends State<MorphScrubber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => ScanMorphView(
              photo: widget.photo,
              t: _c.value,
              score: widget.score,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: AynaColors.surface,
              padding: EdgeInsets.fromLTRB(
                t.space5,
                t.space3,
                t.space5,
                t.space6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) =>
                        Slider(value: _c.value, onChanged: (v) => _c.value = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => _c.forward(from: 0),
                        child: const Text('Play'),
                      ),
                      TextButton(
                        onPressed: () => _c.value = 0,
                        child: const Text('Start'),
                      ),
                      TextButton(
                        onPressed: () => _c.value = 1,
                        child: const Text('End'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trend states, without needing weeks of real scans.
class TrendPreview extends StatelessWidget {
  const TrendPreview({super.key, required this.weeks, this.total = 0});

  final int weeks;
  final int total;

  @override
  Widget build(BuildContext context) {
    final base = DateTime(2026, 7, 20);
    const scores = [41, 38, 47, 44, 52, 58];

    return Scaffold(
      backgroundColor: AynaColors.cream,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.ayna.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your trend', style: AynaType.displaySmall),
              SizedBox(height: context.ayna.space8),
              AnimatedTrendChart(
                points: [
                  for (var i = 0; i < weeks; i++)
                    TrendPoint(
                      weekStart: base.add(Duration(days: 7 * i)),
                      overallScore: scores[i % scores.length],
                    ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six weeks of plausible movement, for the paywall and trend previews.
final _sampleTrend = [
  for (var i = 0; i < 6; i++)
    TrendPoint(
      weekStart: DateTime(2026, 7, 20).add(Duration(days: 7 * i)),
      overallScore: const [41, 38, 47, 44, 52, 58][i],
    ),
];
