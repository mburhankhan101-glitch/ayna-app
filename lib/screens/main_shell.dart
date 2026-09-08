import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/ayna_tokens.dart';
import '../models/scan.dart';
import '../services/api_client.dart';
import '../state/history.dart';
import '../state/scan_flow.dart';
import '../theme/ayna_motion.dart';
import '../widgets/scan_morph.dart';
import 'analysing_screen.dart';
import 'capture_screen.dart';
import 'home_screen.dart';
import 'paywall_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import 'scan_outcome_screen.dart';
import 'trend_screen.dart';

/// The signed-in shell: three tabs and a bottom bar.
///
/// Trend is present rather than hidden until it works, because its empty state
/// is honest and useful — "your trend appears after your second scan" tells
/// the user what the feature is and what unlocks it. A tab labelled "coming
/// soon" would not; that is a stub, and this is a real empty state for a real
/// feature.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.session});

  final Session session;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  late final History _history = History(widget.session.api);

  @override
  void initState() {
    super.initState();
    _history.load();
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  /// Reopens a report the user already paid for.
  ///
  /// Fetched rather than cached: the list carries a summary, and holding six
  /// full reports in memory to save one request would trade a real constraint
  /// for an imagined one.
  Future<void> _openReport(String scanId) async {
    try {
      final json = await widget.session.api.scanReport(scanId);
      if (!mounted) return;
      final report = SkinReport.fromJson(json);
      // Fetched alongside, and tolerated as null. A scan without an overlay is
      // a tier difference, not a failure.
      final heatmap = await widget.session.api.scanHeatmap(scanId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            report: report,
            heatmap: heatmap,
            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.title)));
    }
  }

  /// The weekly limit, shown as a date rather than a refusal.
  ///
  /// [resetsAt] comes from the server on a 429; when the check happened before
  /// the request there is no 429 to read it from, and the screen says so
  /// instead of inventing one.
  Future<void> _showPaywall(DateTime? resetsAt) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => PaywallScreen(
        resetsAt: resetsAt ?? widget.session.user?.entitlement.periodResetsAt,
        // Their own weeks, and the count of the ones they cannot see. This is
        // the whole argument -- a feature list asks someone to imagine a
        // benefit; their own greyed-out history is already theirs.
        trend: _history.trend?.points,
        totalWeeks: _history.trend?.totalAvailable ?? 0,
        onClose: () => Navigator.of(context).pop(),
        // Null until store billing exists. The button says so rather than
        // opening something that cannot take money -- PD-3 chose store IAP,
        // and there is nothing to open yet.
        onUpgrade: null,
      ),
    ),
  );

  /// Opens the camera full-screen.
  ///
  /// Pushed as a route rather than swapped into the tab body: capture is a
  /// task the user enters and leaves, not a place they browse to. It needs the
  /// whole screen with no bottom bar, and the back gesture has to mean "cancel
  /// this scan" rather than "switch tab".
  ///
  /// `fullscreenDialog` is what makes the system back button and the swipe
  /// gesture both resolve to cancel, which is the one behaviour a camera screen
  /// must get right — a user who wants out of a viewfinder wants out now.
  Future<void> _onScan() async {
    // Checked BEFORE the camera opens. The allowance is now real on the
    // profile, so this is knowable without asking the server again -- and
    // finding out after taking a photo is the version that wastes the user's
    // effort as well as their time.
    if (widget.session.user?.entitlement.canScan == false) {
      await _showPaywall(null);
      return;
    }

    final photo = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CaptureScreen(
          onCaptured: (photo) => Navigator.of(context).pop(photo),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (photo == null || !mounted) return;

    final file = File(photo.path);
    final flow = ScanFlow(widget.session.api)..start(file);

    // The analysing screen is pushed rather than shown as an overlay so the
    // system back gesture during a scan means "stop watching", not "go back a
    // tab". The scan itself is already in flight and finishes regardless.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ScanRoute(
          flow: flow,
          photo: file,
          trend: _history.trend?.points,
          totalWeeks: _history.trend?.totalAvailable ?? 0,
        ),
      ),
    );

    flow.dispose();
    if (!mounted) return;

    // The new scan is not in the history yet, and home is about to show it.
    await _history.load();

    // A completed scan spends the weekly allowance, so the home screen's
    // counter is now stale. Refreshed on return rather than optimistically
    // decremented locally, because the server is the only thing that knows
    // whether the scan was charged.
    await widget.session.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return AnimatedBuilder(
      animation: _history,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: switch (_tab) {
            0 => HomeScreen(
              session: widget.session,
              history: _history,
              onScan: _onScan,
              onOpenReport: _openReport,
            ),
            1 => TrendScreen(history: _history),
            _ => ProfileScreen(session: widget.session),
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: 'Home',
              tooltip: '',
            ),
            NavigationDestination(
              icon: const Icon(Icons.show_chart_rounded),
              label: 'Trend',
              tooltip: '',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: 'You',
              tooltip: '',
            ),
          ],
          // Height comes from the theme; the SafeArea above already handles the
          // gesture bar, so no extra padding here.
          height: t.minTouch + 16,
        ),
      ),
    );
  }
}

/// Holds one scan from analysing through to its outcome.
///
/// A single route rather than three, because the user is in one continuous
/// activity: pushing a new screen on completion would put "back" between them
/// and the result they just waited for.
class _ScanRoute extends StatefulWidget {
  const _ScanRoute({
    required this.flow,
    required this.photo,
    this.trend,
    this.totalWeeks = 0,
  });

  final ScanFlow flow;
  final File photo;

  /// Passed through only so a 429 mid-scan can show the same evidence-backed
  /// paywall as the pre-flight check, rather than a thinner version of it.
  final List<TrendPoint>? trend;
  final int totalWeeks;

  @override
  State<_ScanRoute> createState() => _ScanRouteState();
}

class _ScanRouteState extends State<_ScanRoute>
    with SingleTickerProviderStateMixin {
  /// Drives the oval-to-arc morph between analysing and the report.
  ///
  /// Owned by the route rather than by either screen, because for its duration
  /// the shape on screen belongs to neither: it is the transition itself, not
  /// a version of one side or the other.
  late final AnimationController _morph;

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.flow.addListener(_onFlow);
  }

  @override
  void dispose() {
    widget.flow.removeListener(_onFlow);
    _morph.dispose();
    super.dispose();
  }

  void _onFlow() {
    // Only a completed scan morphs. A rejection or failure has no score for the
    // arc to become, so those cut straight to their own screen — animating
    // toward a number that does not exist would be motion for its own sake.
    if (widget.flow.state != ScanFlowState.done) return;
    if (_morph.value != 0 || _morph.isAnimating) return;

    if (AynaMotion.reduced(context)) {
      _morph.value = 1;
    } else {
      _morph.forward();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.flow, _morph]),
    builder: (context, _) {
      final flow = widget.flow;
      void close() => Navigator.of(context).maybePop();

      return switch (flow.state) {
        ScanFlowState.idle || ScanFlowState.working => AnalysingScreen(
          photo: widget.photo,
          progress: flow.progress,
          pacedStage: flow.stage,
          onCancel: close,
        ),
        // The morph owns the screen until it finishes, then hands over to a
        // report that knows its arc is already drawn.
        ScanFlowState.done when _morph.value < 1 => ScanMorphView(
          photo: widget.photo,
          t: _morph.value,
          score: flow.report!.overallScore,
        ),
        ScanFlowState.done => ResultScreen(
          report: flow.report!,
          heatmap: flow.heatmap,
          onDone: close,
          heroAlreadyOnScreen: true,
        ),
        // A rejection is the user's to fix and cost them nothing, so it offers
        // a retake and says why. Distinct from a failure, which is ours.
        ScanFlowState.rejected => ScanOutcomeScreen(
          title:
              flow.progress?.rejectionReason?.title ??
              'That photo did not work',
          body:
              flow.progress?.rejectionReason?.advice ??
              'Try again with your face inside the oval and good light.',
          // Derived from what the server reported, never assumed. The API
          // sends allowanceSpent on every status, and for a rejection it is
          // false -- but reading it rather than hardcoding it is what stops
          // this line from becoming a lie the day that changes.
          reassurance: flow.progress?.allowanceSpent == false
              ? 'This did not use up your weekly scan.'
              : 'Check your home screen for your remaining scans.',
          onClose: close,
        ),
        ScanFlowState.failed => ScanOutcomeScreen(
          title: 'The analysis did not finish',
          body: 'Something on our side stopped it before it produced a report.',
          reassurance: flow.progress?.allowanceSpent == false
              ? 'Your weekly scan is untouched.'
              : 'Check your home screen for your remaining scans.',
          onClose: close,
        ),
        // NO reassurance here, and that absence is the point.
        //
        // This state means the client could not find out what happened: a
        // dropped connection, a timeout, a bad response. The scan may well have
        // completed and been charged server-side. An earlier version hardcoded
        // "Nothing was charged" on this branch and told a user exactly that
        // while their scan had in fact succeeded and cost them credits.
        //
        // The rule this cost us: only claim something was not charged when the
        // SERVER said allowanceSpent is false. Anywhere else, say what is
        // actually known and point at where the truth lives.
        // A 429 is not an error screen. The user did nothing wrong and the
        // answer is a date, so it gets the paywall rather than an apology.
        ScanFlowState.error when flow.error?.isAllowanceExhausted ?? false =>
          PaywallScreen(
            resetsAt: flow.error?.resetsAt,
            trend: widget.trend,
            totalWeeks: widget.totalWeeks,
            onClose: close,
            onUpgrade: null,
          ),
        ScanFlowState.error => ScanOutcomeScreen(
          title: flow.error?.title ?? 'Something went wrong',
          body: flow.error?.detail ?? 'Please try again.',
          reassurance: flow.error?.status == 429
              ? 'Rejected photos never count against your week.'
              : 'If the scan did go through, it will be on your home screen.',
          onClose: close,
        ),
      };
    },
  );
}
