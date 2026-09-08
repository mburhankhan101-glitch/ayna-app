import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/scan.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/press_scale.dart';
import '../widgets/redness_overlay.dart';

/// The report.
///
/// Rebuilt after the first version came back as eight stacked cards. Every
/// element sat in its own bordered box, which is the fastest way to destroy
/// hierarchy: when everything is framed, nothing is emphasised, and a result
/// reads as a form to be filled in.
///
/// The rules this version holds to:
///
///   * **One container, at most.** Hierarchy comes from size, weight and space.
///     A hairline separates; a box encloses. Separating is almost always what
///     was actually wanted.
///   * **The score owns the first screen.** It is the thing the user waited
///     for, and it should not share the fold with six list rows.
///   * **No paragraph under the number.** Nobody reads a sentence explaining a
///     score they can already see. Three words earn their place; thirty do not.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.report,
    required this.onDone,
    this.heroAlreadyOnScreen = false,
    this.heatmap,
  });

  final SkinReport report;
  final VoidCallback onDone;

  /// True when a morph has already drawn the arc and counted the number in.
  ///
  /// Without this the timeline restarts at zero and the hero re-animates from
  /// nothing on the frame the morph hands over -- the arc would collapse and
  /// redraw, which is the single most visible way a shared-element transition
  /// can fail. Starting the timeline past the hero interval means the arc is
  /// simply already there, and only the rest staggers in.
  final bool heroAlreadyOnScreen;

  /// The redness overlay, or null when this scan has none. Passed in rather
  /// than fetched here so the screen stays synchronous and testable.
  final Uint8List? heatmap;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in;

  /// The whole screen runs off one controller with intervals rather than a
  /// controller per element. It keeps the choreography readable in one place,
  /// and it guarantees the order can never drift as pieces are added.
  static const _total = Duration(milliseconds: 2400);

  /// Where the hero interval finishes. Everything after this is the stagger.
  static const _heroEnd = 0.42;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AynaMotion.reduced(context)) {
      _in.value = 1;
    } else if (!_in.isAnimating && !_in.isCompleted) {
      _in.forward(from: widget.heroAlreadyOnScreen ? _heroEnd : 0);
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  List<ScanIssue> get _ranked {
    const rank = {
      Severity.severe: 0,
      Severity.moderate: 1,
      Severity.mild: 2,
      Severity.none: 3,
      Severity.unknown: 4,
    };
    final sorted = [...widget.report.issues];
    sorted.sort(
      (a, b) => (rank[a.severity] ?? 9).compareTo(rank[b.severity] ?? 9),
    );
    return sorted;
  }

  /// Three or four words under the score, not a paragraph.
  String get _summary {
    final notable = widget.report.issues
        .where(
          (i) =>
              i.severity == Severity.moderate || i.severity == Severity.severe,
        )
        .length;
    if (notable == 0) {
      final mild = widget.report.issues
          .where((i) => i.severity == Severity.mild)
          .length;
      return mild == 0 ? 'All clear today' : 'Looking good';
    }
    return notable == 1 ? 'One thing to watch' : '$notable things to watch';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final ranked = _ranked;

    return Scaffold(
      backgroundColor: AynaColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(t.space6, 0, t.space6, t.space6),
                children: [
                  SizedBox(height: t.space8),

                  _Hero(
                    listen: _in,
                    score: widget.report.overallScore,
                    summary: _summary,
                  ),

                  SizedBox(height: t.space8),

                  if (widget.report.skinAge != null) ...[
                    _Reveal(
                      listen: _in,
                      begin: 0.42,
                      child: _SkinAgeLine(
                        skinAge: widget.report.skinAge!,
                        delta: widget.report.skinAgeDelta,
                      ),
                    ),
                    SizedBox(height: t.space6),
                  ],

                  _Reveal(
                    listen: _in,
                    begin: 0.48,
                    child: Text(
                      'WHAT WE LOOKED AT',
                      style: AynaType.label.copyWith(
                        color: AynaColors.inkSubtle,
                      ),
                    ),
                  ),
                  SizedBox(height: t.space2),

                  // One row per concern, arriving in order down the screen.
                  //
                  // The stagger is the hierarchy: reading order made temporal,
                  // so the worst concern is the first thing that exists. All
                  // six landing together is a table; six arriving in sequence
                  // is a result being read out.
                  for (var i = 0; i < ranked.length; i++)
                    _Reveal(
                      listen: _in,
                      begin: 0.52 + i * 0.07,
                      // Slides in from the left rather than up, so the eye
                      // tracks down the column instead of watching each row
                      // rise independently.
                      fromX: 18,
                      child: _IssueRow(issue: ranked[i]),
                    ),

                  if (widget.heatmap != null) ...[
                    SizedBox(height: t.space8),
                    _Reveal(
                      listen: _in,
                      begin: 0.88,
                      child: RednessOverlay(image: widget.heatmap),
                    ),
                  ],

                  SizedBox(height: t.space8),
                  _Reveal(
                    listen: _in,
                    begin: 0.95,
                    child: Text(
                      widget.report.disclaimer,
                      style: AynaType.disclaimer,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(t.space6, 0, t.space6, t.space5),
              child: _Reveal(
                listen: _in,
                begin: 0.9,
                child: PressScale(
                  child: ElevatedButton(
                    onPressed: widget.onDone,
                    child: const Text('Done'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a child in over a slice of the parent's timeline.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.listen,
    required this.begin,
    required this.child,
    this.fromX = 0,
  });

  /// Vertical lift is fixed. Rows slide horizontally and blocks lift, and
  /// making the lift configurable only invited each call site to pick its own
  /// number until nothing shared a rhythm.
  static const _fromY = 12.0;

  final Animation<double> listen;
  final double begin;
  final double fromX;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(
      parent: listen,
      curve: Interval(
        begin.clamp(0.0, 1.0),
        (begin + 0.22).clamp(0.0, 1.0),
        curve: AynaMotion.enter,
      ),
    );

    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(
            AynaMotion.shift(context, (1 - a.value) * fromX),
            AynaMotion.shift(context, (1 - a.value) * _fromY),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The score, and nothing competing with it.
///
/// No card, no border, no background panel. It is the largest thing on the
/// screen by a wide margin because it is the only thing the user came for, and
/// the arc around it is the one saturated mark above the fold.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.listen,
    required this.score,
    required this.summary,
  });

  final Animation<double> listen;
  final int score;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    // The arc draws first and the number counts alongside it, both finishing
    // together — one event, not two things that happen to overlap.
    final draw = CurvedAnimation(
      parent: listen,
      curve: const Interval(0, 0.42, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: draw,
      builder: (context, _) => SizedBox(
        height: 236,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(236, 236),
              painter: _ArcPainter(progress: draw.value * (score / 100)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (draw.value * score).round().toString(),
                  style: AynaType.displayLarge.copyWith(
                    fontSize: 76,
                    height: 1,
                    color: AynaColors.ink,
                    // Tabular figures so the number does not jitter sideways
                    // while it counts.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(height: t.space2),
                Opacity(
                  opacity: draw.value,
                  child: Text(
                    summary,
                    style: AynaType.titleMedium.copyWith(
                      color: AynaColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress});

  final double progress;

  /// Open at the bottom. A closed ring reads as a completion meter — "you are
  /// 30% done" — when the number is a reading, not progress.
  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 12;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = AynaColors.clay.withValues(alpha: 0.10),
    );

    if (progress <= 0.001) return;

    // A soft bloom under the arc. It is what stops a flat stroke from looking
    // like a progress bar bent into a circle.
    canvas.drawArc(
      rect,
      _start,
      _sweep * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..color = AynaColors.clay.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawArc(
      rect,
      _start,
      _sweep * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: _start,
          endAngle: _start + _sweep,
          colors: const [
            AynaColors.clayDark,
            AynaColors.clay,
            AynaColors.olive,
          ],
          stops: const [0, 0.55, 1],
          transform: GradientRotation(_start),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

/// Skin age as a line, not a card.
class _SkinAgeLine extends StatelessWidget {
  const _SkinAgeLine({required this.skinAge, required this.delta});

  final int skinAge;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final win = (delta ?? 0) > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$skinAge',
          style: AynaType.displayMedium.copyWith(
            color: win ? AynaColors.oliveDeep : AynaColors.ink,
            height: 1,
          ),
        ),
        SizedBox(width: t.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SKIN AGE',
                style: AynaType.label.copyWith(color: AynaColors.inkSubtle),
              ),
              SizedBox(height: t.space1),
              Text(
                // Never "older than you". The number already says it, and
                // saying it twice is unkindness with extra steps.
                delta == null
                    ? 'An impression, not a measurement'
                    : delta! > 0
                    ? '${delta!} year${delta! == 1 ? '' : 's'} younger than you'
                    : delta! == 0
                    ? 'Right in step with you'
                    : 'Reading a little above your age',
                style: AynaType.bodyMedium.copyWith(
                  color: win ? AynaColors.oliveDeep : AynaColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One concern: a label, a word, and a bar. No box.
///
/// Separated by a hairline rather than enclosed by a border. A box says "these
/// things are one unit"; a rule says "these things are adjacent", and adjacent
/// is what six independent readings actually are.
class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final ScanIssue issue;

  static const _order = [
    Severity.none,
    Severity.mild,
    Severity.moderate,
    Severity.severe,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final filled = _order.indexOf(issue.severity) + 1;

    return Container(
      padding: EdgeInsets.symmetric(vertical: t.space4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AynaColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              issue.type.label,
              style: AynaType.titleSmall.copyWith(color: AynaColors.ink),
            ),
          ),
          if (issue.isUnknown)
            // Never rendered as "clear". Telling someone they have no redness
            // when nothing ever looked is the worst thing this screen can do.
            Text(
              'Not assessed',
              style: AynaType.bodyMedium.copyWith(color: AynaColors.inkFaint),
            )
          else ...[
            Text(
              _label(issue.severity),
              style: AynaType.bodyMedium.copyWith(
                color: issue.severity == Severity.none
                    ? AynaColors.inkSubtle
                    : t.inkFor(issue.severity),
              ),
            ),
            SizedBox(width: t.space4),
            // The bar has exactly as many segments as the source can
            // distinguish. Four for Pro's 0-100 scores; two if the vendor ever
            // returns presence flags. Drawing four for a two-level signal
            // claims precision that was never measured.
            Row(
              children: [
                for (var i = 0; i < issue.severityLevels; i++)
                  Container(
                    width: 16,
                    height: 5,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i < filled
                          ? t.fillFor(issue.severity)
                          : AynaColors.clay.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _label(Severity s) => switch (s) {
    Severity.none => 'Clear',
    Severity.mild => 'Mild',
    Severity.moderate => 'Moderate',
    Severity.severe => 'Noticeable',
    Severity.unknown => 'Not assessed',
  };
}
