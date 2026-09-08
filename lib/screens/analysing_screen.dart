import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/press_scale.dart';
import '../widgets/scan_beam.dart';

/// The wait.
///
/// Two or three seconds is short enough that a spinner would technically do,
/// and long enough that a spinner would make it feel like ten. The difference
/// is entirely in what the screen says it is doing: named steps over the user's
/// own photo turn dead time into the product working, which is the one moment
/// where the app can look like it is paying attention to *them*.
///
/// Nothing here fabricates progress. The bar eases toward whatever step the
/// server last reported and **stops short of full until the result actually
/// arrives** — a bar that reaches 100% and then waits is worse than no bar,
/// because it teaches the user that the number is decoration.
class AnalysingScreen extends StatefulWidget {
  const AnalysingScreen({
    super.key,
    required this.photo,
    required this.progress,
    required this.pacedStage,
    required this.onCancel,
  });

  /// The photo being analysed, shown underneath so the wait is visibly about
  /// them rather than about the network.
  final File photo;

  /// Server-reported progress. Rebuilt as new polls arrive.
  final ScanProgress? progress;

  /// The step to show when the server has not reported one.
  ///
  /// Currently that is always, because the analysis runs inside POST /v1/scans
  /// and there is no scan id to poll until it has already finished. The flow
  /// paces these locally against the server-supplied estimate; when the worker
  /// lands, [progress] carries a real stage and this stops being consulted.
  final ScanStage pacedStage;

  final VoidCallback onCancel;

  @override
  State<AnalysingScreen> createState() => _AnalysingScreenState();
}

class _AnalysingScreenState extends State<AnalysingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _sweep;

  /// Where the bar is drawn, which trails the target rather than jumping to it.
  double _shown = 0;

  /// The ceiling the bar may drift to while a step is in flight.
  ///
  /// Stages arrive seconds apart, so a bar that only moved on updates would sit
  /// frozen and then lurch. Between updates it creeps toward the current
  /// stage's share of the job and stops — visibly alive, never claiming more
  /// than the server has confirmed.
  static const _idleCeiling = 0.97;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AynaMotion.reduced(context)) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  /// The target the bar eases toward.
  double get _target {
    final p = widget.progress;
    if (p == null) return widget.pacedStage.progress;
    if (p.state == ScanState.completed) return 1;
    return (p.stage?.progress ?? widget.pacedStage.progress).clamp(
      0.0,
      _idleCeiling,
    );
  }

  String get _label {
    final p = widget.progress;
    if (p?.state == ScanState.completed) return 'Done';
    return (p?.stage ?? widget.pacedStage).label;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      backgroundColor: AynaColors.captureGround,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(widget.photo, fit: BoxFit.cover),

          // Heavy dim. The photo is context, not the subject — and a bright
          // photo of your own face is distracting enough to pull attention off
          // the thing that is actually happening.
          Container(color: AynaColors.captureGround.withValues(alpha: 0.74)),

          AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) => TweenAnimationBuilder<double>(
              // Eased toward the target so the bar glides between steps rather
              // than snapping each time a poll lands.
              tween: Tween(begin: _shown, end: _target),
              duration: AynaMotion.of(
                context,
                const Duration(milliseconds: 900),
              ),
              curve: AynaMotion.enter,
              onEnd: () => _shown = _target,
              builder: (context, shown, _) =>
                  ScanBeam(sweep: _sweep.value, progress: shown),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: t.space3),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PressScale(
                      child: TextButton(
                        onPressed: widget.onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: AynaColors.captureGuide,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const Spacer(),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 132,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _target),
                          duration: AynaMotion.of(
                            context,
                            const Duration(milliseconds: 900),
                          ),
                          curve: AynaMotion.enter,
                          builder: (context, v, _) => ScanMeter(progress: v),
                        ),
                      ),
                      SizedBox(width: t.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Reading your skin',
                              style: AynaType.displaySmall.copyWith(
                                color: AynaColors.onClay,
                              ),
                            ),
                            SizedBox(height: t.space2),
                            AnimatedSwitcher(
                              duration: AynaMotion.of(context, AynaMotion.base),
                              // Slides up as it changes, so a new step reads as
                              // the next thing rather than a corrected label.
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0, 0.35),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  ),
                              child: Text(
                                _label,
                                key: ValueKey(_label),
                                style: AynaType.bodyLarge.copyWith(
                                  color: AynaColors.captureOk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: t.space6),
                  Text(
                    'This usually takes a few seconds. You can leave this '
                    'screen. The result will be waiting on your home screen.',
                    style: AynaType.bodySmall.copyWith(
                      color: AynaColors.onClayMuted,
                    ),
                  ),
                  SizedBox(height: t.space6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
