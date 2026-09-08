import 'package:ayna_app/models/user.dart';
import 'package:ayna_app/screens/home_screen.dart';
import 'package:ayna_app/screens/onboarding_screen.dart';
import 'package:ayna_app/screens/sign_in_screen.dart';
import 'package:ayna_app/state/session.dart';
import 'package:ayna_app/theme/ayna_motion.dart';
import 'package:ayna_app/theme/ayna_theme.dart';

import 'shell_screens_test.dart' show emptyHistory;
import 'package:ayna_app/widgets/onboarding_art.dart';
import 'package:ayna_app/widgets/press_scale.dart';
import 'package:ayna_app/widgets/entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motion tests, kept apart from `shell_screens_test.dart` for one mechanical
/// reason: that file disables animations so `pumpAndSettle` terminates. These
/// need animations on, so they pump fixed durations instead and must never
/// call `pumpAndSettle` — a repeating controller would hang it forever.
Widget wrapMotion(Widget child, {bool reduced = false}) => MaterialApp(
  theme: AynaTheme.light(),
  themeMode: ThemeMode.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child,
    ),
  ),
);

void main() {
  group('motion tokens', () {
    test('nothing blocking exceeds the Doherty Threshold', () {
      // Past 400ms the user is waiting on the interface rather than the
      // interface keeping up, and the animation stops being feedback and
      // starts being lag. Ambient loops are exempt because nothing is
      // blocked on them — which is exactly why they are asserted separately.
      for (final d in [
        AynaMotion.instant,
        AynaMotion.quick,
        AynaMotion.base,
        AynaMotion.settle,
      ]) {
        expect(
          d.inMilliseconds,
          lessThanOrEqualTo(400),
          reason: 'blocking motion must stay under the Doherty Threshold',
        );
      }
    });

    test('press feedback is fast enough to read as instantaneous', () {
      expect(AynaMotion.instant.inMilliseconds, lessThanOrEqualTo(100));
    });

    test('ambient loops are slow enough not to read as a spinner', () {
      // A loop near the blocking range reads as "loading", which would tell
      // the user to wait on a screen where nothing is happening.
      expect(AynaMotion.breath.inMilliseconds, greaterThan(1500));
      expect(AynaMotion.sweep.inMilliseconds, greaterThan(1500));
    });
  });

  group('reduced motion', () {
    testWidgets('collapses durations and displacement to zero', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        wrapMotion(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
          reduced: true,
        ),
      );

      expect(AynaMotion.reduced(ctx), isTrue);
      expect(AynaMotion.of(ctx, AynaMotion.base), Duration.zero);
      expect(AynaMotion.shift(ctx, 40), 0);
    });

    testWidgets('leaves them intact when motion is allowed', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        wrapMotion(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AynaMotion.reduced(ctx), isFalse);
      expect(AynaMotion.of(ctx, AynaMotion.base), AynaMotion.base);
      expect(AynaMotion.shift(ctx, 40), 40);
    });

    testWidgets('the illustration settles instead of looping forever', (
      tester,
    ) async {
      // The accessibility guarantee and the reason the rest of the suite can
      // use pumpAndSettle at all. If this ever regresses, every other widget
      // test hangs rather than failing, so it is asserted directly.
      await tester.pumpWidget(
        wrapMotion(
          const Scaffold(
            body: SizedBox(
              height: 200,
              child: OnboardingArt(kind: OnboardingArtKind.scan),
            ),
          ),
          reduced: true,
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('onboarding motion', () {
    testWidgets('the illustration animates when motion is allowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapMotion(
          const Scaffold(
            body: SizedBox(
              height: 200,
              child: OnboardingArt(kind: OnboardingArtKind.scan),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: 'the ambient sweep should be running',
      );

      // Deliberately not pumpAndSettle: the loop repeats, so settling would
      // never return.
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('every illustration paints at 320px without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final kind in OnboardingArtKind.values) {
        await tester.pumpWidget(
          wrapMotion(
            Scaffold(
              body: SizedBox(height: 120, child: OnboardingArt(kind: kind)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: '$kind threw');
      }
    });

    testWidgets('onboarding still pages through with motion enabled', (
      tester,
    ) async {
      // The same journey shell_screens_test covers, re-run with animations on,
      // because the parallax rebuilds every frame of the drag and that is a
      // different code path from the settled one.
      await tester.pumpWidget(wrapMotion(OnboardingScreen(onDone: () {})));
      await tester.pump();

      // The button is gone; the gesture is the only way through. Asserted
      // explicitly so a future "Next" cannot creep back unnoticed.
      expect(find.text('Next'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);

      // A fling needs its own frame before the clock advances, or time runs
      // forward on a frame that has not yet dispatched the gesture and the page
      // never starts moving. The settle window is generous because a fling
      // decelerates rather than running a fixed-length animation.
      for (var i = 0; i < 2; i++) {
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }

      // The label lives in an AnimatedSwitcher, so the outgoing "Skip" is still
      // mounted while it cross-fades out. One more frame past that duration is
      // what makes this an assertion about the finished screen rather than
      // about a transition frame.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  _signInHomeTests();
}

// ---------------------------------------------------------------------------
// Sign-in and home
// ---------------------------------------------------------------------------

/// A Session that never touches Auth0 or the network.
class _FakeSession extends Session {
  _FakeSession({AynaUser? user, String? error})
    : _fakeUser = user,
      _fakeError = error;

  final AynaUser? _fakeUser;
  final String? _fakeError;
  int signInCount = 0;

  @override
  AynaUser? get user => _fakeUser;

  @override
  String? get error => _fakeError;

  @override
  Future<void> signIn() async => signInCount++;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> start() async {}
}

AynaUser _user({int streakWeeks = 0}) => AynaUser(
  id: 'usr_01TEST',
  displayName: 'Sana Iqbal',
  birthYear: 1999,
  timezone: 'Asia/Karachi',
  hasConsent: true,
  streakWeeks: streakWeeks,
  entitlement: Entitlement(
    tier: 'free',
    scansRemaining: 1,
    periodResetsAt: DateTime.now().add(const Duration(days: 7)),
    hasHeatmap: false,
    hasSkinAge: false,
  ),
);

void _signInHomeTests() {
  group('press feedback', () {
    testWidgets('PressScale does not steal the tap from its button', (
      tester,
    ) async {
      // The failure this guards against is silent: a gesture detector wrapped
      // around a button wins the tap in the arena, the button stops firing,
      // and the only symptom is that pressing it does nothing. Listener does
      // not compete for the gesture, and this proves it.
      var taps = 0;
      await tester.pumpWidget(
        wrapMotion(
          Scaffold(
            body: Center(
              child: PressScale(
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('Tap me'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Tap me'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(taps, 1, reason: 'the wrapper must not consume the tap');
    });
  });

  group('entrance', () {
    testWidgets('shows content immediately under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapMotion(
          const Scaffold(body: Entrance(child: Text('arrived'))),
          reduced: true,
        ),
      );
      await tester.pump();

      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('arrived'), matching: find.byType(Opacity)),
      );
      expect(
        opacity.opacity,
        1.0,
        reason:
            'reduced motion should show a finished screen, not a fast '
            'version of the animation',
      );
    });

    testWidgets('starts hidden and finishes visible when motion is allowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapMotion(
          const Scaffold(
            body: Entrance(
              delay: Duration(milliseconds: 100),
              child: Text('arrived'),
            ),
          ),
        ),
      );
      await tester.pump();

      Opacity read() => tester.widget<Opacity>(
        find.ancestor(of: find.text('arrived'), matching: find.byType(Opacity)),
      );

      expect(read().opacity, 0.0);
      await tester.pumpAndSettle();
      expect(read().opacity, 1.0);
    });
  });

  group('sign in', () {
    testWidgets('the mark breathes, and settles under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapMotion(SignInScreen(session: _FakeSession())),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        wrapMotion(SignInScreen(session: _FakeSession()), reduced: true),
      );
      await tester.pumpAndSettle();
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason:
            'an ambient loop that never stops would hang every test '
            'that calls pumpAndSettle',
      );
    });

    testWidgets('signing in still works with motion enabled', (tester) async {
      final session = _FakeSession();
      await tester.pumpWidget(wrapMotion(SignInScreen(session: session)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(session.signInCount, 1);
    });

    testWidgets('an error does not push the button under a moving finger', (
      tester,
    ) async {
      // Everything below the button is fixed height and the Spacers above
      // absorb the difference, so inserting an error leaves it where it was.
      final clean = _FakeSession();
      await tester.pumpWidget(
        wrapMotion(SignInScreen(session: clean), reduced: true),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(ElevatedButton));

      final failed = _FakeSession(error: 'Something went wrong.');
      await tester.pumpWidget(
        wrapMotion(SignInScreen(session: failed), reduced: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(
        tester.getRect(find.byType(ElevatedButton)).bottom,
        before.bottom,
        reason: 'the button must not move when an error appears',
      );
    });
  });

  group('home', () {
    testWidgets('the streak row breathes, and settles under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapMotion(
          Scaffold(
            body: HomeScreen(
              session: _FakeSession(user: _user()),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        wrapMotion(
          Scaffold(
            body: HomeScreen(
              session: _FakeSession(user: _user()),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the scan button still fires through its press wrapper', (
      tester,
    ) async {
      var scans = 0;
      await tester.pumpWidget(
        wrapMotion(
          Scaffold(
            body: HomeScreen(
              session: _FakeSession(user: _user()),
              history: emptyHistory(),
              onScan: () => scans++,
              onOpenReport: (_) {},
            ),
          ),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take my first scan'));
      await tester.pump();

      expect(scans, 1);
    });

    testWidgets('lays out at 320px with motion running', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapMotion(
          Scaffold(
            body: HomeScreen(
              session: _FakeSession(user: _user(streakWeeks: 2)),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });
}
