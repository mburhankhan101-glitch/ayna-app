import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../state/history.dart';
import '../state/session.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/entrance.dart';
import '../widgets/last_result_card.dart';
import '../widgets/press_scale.dart';

/// Home.
///
/// Every user starts here with **no scans**, so the empty state is the only
/// state that exists today — and it is the one that decides whether they take
/// the first scan at all. The designs showed a populated screen with a score
/// of 78; that screen has never been seen by anyone new, and building it first
/// would have meant shipping a home screen that is wrong on day one.
///
/// The arrival order is the argument: greeting, then the one action worth
/// taking, then the habit it belongs to. Nothing else competes, because by the
/// Von Restorff Effect the single distinct element is the one that gets
/// remembered — and a screen where three cards all shout has no distinct one.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.history,
    required this.onScan,
    required this.onOpenReport,
  });

  final Session session;
  final History history;
  final VoidCallback onScan;

  /// Opens a report the user already paid for.
  final void Function(String scanId) onOpenReport;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final user = session.user;
    final last = history.latestWithResult;

    return RefreshIndicator(
      onRefresh: () async {
        // Both, because the two are shown together and refreshing one would
        // leave the screen internally inconsistent.
        await session.refresh();
        await history.load();
      },
      color: AynaColors.clay,
      child: ListView(
        padding: EdgeInsets.fromLTRB(t.space6, t.space5, t.space6, t.space8),
        children: [
          Entrance(child: _greeting(t, user)),
          SizedBox(height: t.space5),
          Entrance(
            delay: const Duration(milliseconds: 80),
            // Their last result if there is one, otherwise the invitation.
            // Showing "your first scan" to someone on their fifth is not a
            // stale label -- it means the app forgot what they paid for.
            child: last == null
                ? _firstScanCard(t, user)
                : LastResultCard(
                    scan: last,
                    canScan: user?.entitlement.canScan ?? false,
                    onOpen: () => onOpenReport(last.scanId),
                    onScan: onScan,
                  ),
          ),
          SizedBox(height: t.space4),
          Entrance(
            delay: const Duration(milliseconds: 150),
            child: _streakCard(t, user),
          ),
          SizedBox(height: t.space8),
          Entrance(
            delay: const Duration(milliseconds: 210),
            child: Text(
              'Ayna gives you an impression, not a diagnosis. For anything '
              'that worries you, see a dermatologist.',
              style: AynaType.disclaimer,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _greeting(AynaTokens t, AynaUser? user) {
    final name = user?.firstName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_partOfDay(), style: AynaType.bodyMedium),
              SizedBox(height: t.space1),
              Text(
                name == null ? 'Hello' : 'Hello, $name',
                style: AynaType.displaySmall,
              ),
            ],
          ),
        ),
        if (name != null)
          _AvatarPop(
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AynaColors.claySoft,
              child: Text(
                name.characters.first.toUpperCase(),
                style: AynaType.titleMedium.copyWith(color: AynaColors.clay),
              ),
            ),
          ),
      ],
    );
  }

  String _partOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// The empty state, and the most important card in the app right now.
  ///
  /// It leads with what happens rather than a score the user does not have
  /// yet, and it names the time cost up front — "thirty seconds" is the
  /// objection being answered.
  Widget _firstScanCard(AynaTokens t, AynaUser? user) {
    final canScan = user?.entitlement.canScan ?? false;

    return Container(
      padding: EdgeInsets.all(t.space5),
      decoration: BoxDecoration(
        color: AynaColors.clay,
        borderRadius: BorderRadius.circular(t.radiusLg),
        // A shadow only on this card. It is the one thing that should sit
        // above the page, and depth used everywhere is depth nowhere.
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
            'YOUR FIRST SCAN',
            style: AynaType.label.copyWith(color: AynaColors.onClayMuted),
          ),
          SizedBox(height: t.space3),
          Text(
            'Take a selfie and\nsee where you stand',
            style: AynaType.displaySmall.copyWith(color: AynaColors.onClay),
          ),
          SizedBox(height: t.space2),
          Text(
            'Good light, no makeup, hair off your forehead. '
            'About thirty seconds.',
            style: AynaType.bodyMedium.copyWith(color: AynaColors.onClayMuted),
          ),
          SizedBox(height: t.space5),
          PressScale(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canScan ? onScan : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AynaColors.onClay,
                  foregroundColor: AynaColors.clay,
                  disabledBackgroundColor: AynaColors.onClay.withValues(
                    alpha: 0.45,
                  ),
                  minimumSize: Size.fromHeight(t.minTouch),
                  textStyle: AynaType.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                ),
                child: Text(canScan ? 'Take my first scan' : 'No scans left'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Five weekly boxes, all empty.
  ///
  /// Weekly, not daily (PD-5) — and shown before there is a streak because an
  /// empty row of boxes explains the mechanic better than any sentence, and
  /// sets the expectation that this is a weekly habit rather than a daily one.
  Widget _streakCard(AynaTokens t, AynaUser? user) {
    final weeks = user?.streakWeeks ?? 0;

    return Container(
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        color: AynaColors.surface,
        border: Border.all(color: AynaColors.border),
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Both sides flex. Neither string is fixed-width — the left grows
          // once there is a streak to name, and the right grows with the
          // user's text-size setting — and two unflexed Texts in a Row
          // overflow at 320px the moment either does. The existing layout test
          // never caught it because it only ever rendered a zero-week user,
          // where "No streak yet" happens to be the short case.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  weeks == 0
                      ? 'No streak yet'
                      : '$weeks week${weeks == 1 ? '' : 's'} in a row',
                  style: AynaType.titleSmall,
                ),
              ),
              SizedBox(width: t.space3),
              Flexible(
                child: Text(
                  '1 scan a week keeps it',
                  style: AynaType.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: t.space3),
          _StreakRow(weeks: weeks),
        ],
      ),
    );
  }
}

/// The five weekly boxes, with the next one waiting.
///
/// The box the user is about to earn breathes; the rest are still. That is the
/// Goal-Gradient Effect made visible — effort rises as the goal gets closer,
/// but only if the user can see which one is next. A row of identical empty
/// boxes shows a mechanic; one live box shows a target.
class _StreakRow extends StatefulWidget {
  const _StreakRow({required this.weeks});

  final int weeks;

  @override
  State<_StreakRow> createState() => _StreakRowState();
}

class _StreakRowState extends State<_StreakRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: AynaMotion.breath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AynaMotion.reduced(context)) {
      _breath
        ..stop()
        ..value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final glow = 0.5 + 0.5 * math.sin(_breath.value * math.pi * 2);

        return Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Container(
                  height: 30,
                  margin: EdgeInsets.only(right: i == 4 ? 0 : t.space1),
                  decoration: BoxDecoration(
                    color: i < widget.weeks
                        ? AynaColors.clay
                        : AynaColors.severityNone,
                    borderRadius: BorderRadius.circular(6),
                    border: i == widget.weeks
                        ? Border.all(
                            color: Color.lerp(
                              const Color(0xFFD6C4AE),
                              AynaColors.clay,
                              glow * 0.7,
                            )!,
                            width: 1.5,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The avatar, landing rather than appearing.
///
/// Separate from [Entrance] because it overshoots and scales from the centre
/// instead of lifting: it is a small round object arriving, and lifting a
/// circle reads as a bug rather than as motion.
class _AvatarPop extends StatefulWidget {
  const _AvatarPop({required this.child});

  final Widget child;

  @override
  State<_AvatarPop> createState() => _AvatarPopState();
}

class _AvatarPopState extends State<_AvatarPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AynaMotion.settle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AynaMotion.reduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: CurvedAnimation(parent: _controller, curve: AynaMotion.overshoot),
    child: widget.child,
  );
}
