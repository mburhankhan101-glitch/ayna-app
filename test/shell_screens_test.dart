import 'package:ayna_app/models/user.dart';
import 'package:ayna_app/screens/age_gate_screen.dart';
import 'package:ayna_app/screens/consent_screen.dart';
import 'package:ayna_app/screens/home_screen.dart';
import 'package:ayna_app/screens/main_shell.dart';
import 'package:ayna_app/screens/onboarding_screen.dart';
import 'package:ayna_app/screens/settings_screen.dart';
import 'package:ayna_app/services/api_client.dart';
import 'package:ayna_app/services/auth_service.dart';
import 'package:ayna_app/state/history.dart';
import 'package:ayna_app/state/session.dart';
import 'package:ayna_app/theme/ayna_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Session that never touches Auth0 or the network.
///
/// Subclassed rather than mocked with a package: the surface is small, and a
/// real subclass keeps the type honest so a signature change breaks the test
/// rather than silently diverging from what the screens actually call.
class FakeSession extends Session {
  FakeSession({AynaUser? user, SessionStage stage = SessionStage.ready})
    : _fakeUser = user,
      _fakeStage = stage;

  final AynaUser? _fakeUser;
  final SessionStage _fakeStage;
  int refreshCount = 0;

  @override
  AynaUser? get user => _fakeUser;

  @override
  SessionStage get stage => _fakeStage;

  @override
  Future<void> refresh() async => refreshCount++;

  @override
  Future<void> start() async {}
}

AynaUser buildUser({
  int? photoRetentionDays = 30,
  int streakWeeks = 0,
  int scansRemaining = 1,
  String tier = 'free',
  String? displayName = 'Sana Iqbal',
}) => AynaUser(
  id: 'usr_01TEST',
  photoRetentionDays: photoRetentionDays,
  displayName: displayName,
  birthYear: 1999,
  timezone: 'Asia/Karachi',
  hasConsent: true,
  streakWeeks: streakWeeks,
  entitlement: Entitlement(
    tier: tier,
    scansRemaining: scansRemaining,
    periodResetsAt: DateTime.now().add(const Duration(days: 7)),
    hasHeatmap: tier != 'free',
    hasSkinAge: tier != 'free',
  ),
);

/// Wraps a screen for testing with animations disabled.
///
/// `disableAnimations` is not a test convenience here, it is the same
/// accessibility path a user gets from Android's "Remove animations": ambient
/// loops park on a representative frame instead of repeating. That matters
/// mechanically, because `pumpAndSettle` waits for the animation clock to go
/// quiet and a repeating controller never does — every test below would hang
/// rather than fail, which is a far worse way to find out.
///
/// Motion itself is exercised in `motion_test.dart`, which pumps
/// explicit durations instead.
Widget wrap(Widget child) => MaterialApp(
  theme: AynaTheme.light(),
  themeMode: ThemeMode.light,
  // Builder so the copyWith sees MaterialApp's own MediaQuery. Passing a
  // bare MediaQueryData would reset size to zero and break every layout.
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    ),
  ),
);

void main() {
  // -------------------------------------------------------------------------
  // The age gate (PD-1)
  // -------------------------------------------------------------------------

  group('age gate', () {
    testWidgets('asks for a birth year, not "are you 18"', (tester) async {
      // A yes/no gate teaches the answer it wants: anyone refused simply taps
      // the other button. Asking for a fact is what makes it a gate.
      await tester.pumpWidget(
        wrap(
          AgeGateScreen(
            session: FakeSession(stage: SessionStage.needsProfile),
            onRefused: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What year were you born?'), findsOneWidget);
      expect(find.textContaining('Are you'), findsNothing);
      expect(find.text('Yes'), findsNothing);
      expect(find.text('No'), findsNothing);
    });

    testWidgets('says only the year is kept', (tester) async {
      // PD-1 collects a year rather than a full date of birth, and saying so
      // is the difference between a privacy decision and a hidden one.
      await tester.pumpWidget(
        wrap(
          AgeGateScreen(
            session: FakeSession(stage: SessionStage.needsProfile),
            onRefused: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('only keep the year'), findsOneWidget);
    });
  });

  group('under-age refusal', () {
    testWidgets('explains why and is not a dead end', (tester) async {
      // The person reading this is a teenager who was just told no by an app
      // about their face. A blank wall would be the wrong answer.
      await tester.pumpWidget(wrap(UnderAgeScreen(onBack: () {})));
      await tester.pumpAndSettle();

      expect(find.textContaining('growing into their face'), findsOneWidget);
      expect(find.textContaining('Nothing has been saved'), findsOneWidget);
      expect(find.text('Find a dermatologist instead'), findsOneWidget);
    });

    testWidgets('never uses rejecting language', (tester) async {
      await tester.pumpWidget(wrap(UnderAgeScreen(onBack: () {})));
      await tester.pumpAndSettle();

      for (final word in ['denied', 'rejected', 'not allowed', 'forbidden']) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: 'the refusal screen must not read as a punishment',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Consent (FR-1)
  // -------------------------------------------------------------------------

  group('consent', () {
    testWidgets('the button label states what agreeing does', (tester) async {
      // A generic "Continue" under a wall of text is how you get a signature
      // nobody read.
      await tester.pumpWidget(
        wrap(
          ConsentScreen(session: FakeSession(stage: SessionStage.needsConsent)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('I agree, open camera'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('has no pre-ticked box', (tester) async {
      await tester.pumpWidget(
        wrap(
          ConsentScreen(session: FakeSession(stage: SessionStage.needsConsent)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('states deletion is possible', (tester) async {
      await tester.pumpWidget(
        wrap(
          ConsentScreen(session: FakeSession(stage: SessionStage.needsConsent)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('delete everything'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Home — the empty state, which is the only state a new user sees
  // -------------------------------------------------------------------------

  group('home', () {
    testWidgets('leads with the first scan, not an absent score', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: HomeScreen(
              session: FakeSession(user: buildUser()),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR FIRST SCAN'), findsOneWidget);
      expect(find.text('Take my first scan'), findsOneWidget);
      // No fabricated score. A zero or a dash where a real number goes reads
      // as a broken screen rather than an empty one.
      expect(find.text('0'), findsNothing);
      expect(find.text('--'), findsNothing);
    });

    testWidgets('the streak reads weekly, never daily', (tester) async {
      // PD-5 settled on ISO weeks. Daily language here would also contradict
      // the one-scan-per-week free allowance in PD-3.
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: HomeScreen(
              session: FakeSession(user: buildUser()),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 scan a week keeps it'), findsOneWidget);
      expect(find.textContaining('day streak'), findsNothing);
      expect(find.textContaining('daily'), findsNothing);
    });

    testWidgets('disables the scan button when the allowance is spent', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: HomeScreen(
              session: FakeSession(user: buildUser(scansRemaining: 0)),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No scans left'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('carries the not-a-diagnosis line', (tester) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: HomeScreen(
              session: FakeSession(user: buildUser()),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('not a diagnosis'), findsOneWidget);
    });

    testWidgets('greets without a name when there is none', (tester) async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: HomeScreen(
              session: FakeSession(user: buildUser(displayName: null)),
              history: emptyHistory(),
              onScan: () {},
              onOpenReport: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
      // "Hello, null" and "Hello, " are both worse than no name at all.
      expect(find.textContaining('null'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Trend empty state
  // -------------------------------------------------------------------------

  testWidgets('trend explains what unlocks it rather than saying coming soon', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MainShell(session: FakeSession(user: buildUser()))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trend'));
    await tester.pumpAndSettle();

    expect(find.text('Two scans and this fills in'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Onboarding
  // -------------------------------------------------------------------------

  group('onboarding', () {
    /// Advances one slide the only way a user now can.
    ///
    /// There is no "Next" button any more, so these tests drive the gesture.
    /// That is not just a mechanical translation of `tap(find.text('Next'))`:
    /// if the swipe ever stops working the carousel has no way forward at all,
    /// so exercising the real input is now the thing that proves onboarding is
    /// completable.
    Future<void> swipe(WidgetTester tester) async {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }

    testWidgets('cannot be skipped past the disclaimer', (tester) async {
      // Skip exists on slides 1 and 2 and disappears on the last, because the
      // "not a diagnosis" slide is the one thing a user should not be able to
      // page past without seeing (NFR-6).
      await tester.pumpWidget(wrap(OnboardingScreen(onDone: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);

      await swipe(tester);
      await swipe(tester);

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('the last slide is the disclaimer', (tester) async {
      await tester.pumpWidget(wrap(OnboardingScreen(onDone: () {})));
      await tester.pumpAndSettle();

      await swipe(tester);
      await swipe(tester);

      expect(find.textContaining('Not a diagnosis'), findsOneWidget);
    });

    testWidgets('slide two is about the photo, before anything is asked for', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(OnboardingScreen(onDone: () {})));
      await tester.pumpAndSettle();

      await swipe(tester);

      expect(find.textContaining('Your photo stays'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Layout
  // -------------------------------------------------------------------------

  testWidgets('every shell screen lays out on a 320px phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final screens = <String, Widget>{
      'onboarding': OnboardingScreen(onDone: () {}),
      'age gate': AgeGateScreen(
        session: FakeSession(stage: SessionStage.needsProfile),
        onRefused: () {},
      ),
      'under age': UnderAgeScreen(onBack: () {}),
      'consent': ConsentScreen(
        session: FakeSession(stage: SessionStage.needsConsent),
      ),
      'shell': MainShell(session: FakeSession(user: buildUser())),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(wrap(entry.value));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} overflowed at 320px',
      );
    }
  });
  // ---------------------------------------------------------------------------
  // Photo retention (NFR-4)
  //
  // Onboarding promises photos are "deleted on a schedule you choose". These
  // are the tests that keep that sentence true.
  // ---------------------------------------------------------------------------

  group('photo retention', () {
    testWidgets('offers every option the API accepts, and no others', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(SettingsScreen(session: FakeSession(user: buildUser()))),
      );
      await tester.pumpAndSettle();

      // The four choices in the contract's enum: 7, 30, 365, null.
      expect(find.text('After 7 days'), findsOneWidget);
      expect(find.text('After 30 days'), findsOneWidget);
      expect(find.text('After a year'), findsOneWidget);
      expect(find.text('Keep them'), findsOneWidget);

      // The retention placeholder is gone. Its old body copy is the precise
      // marker: if it ever returns, the control has been unwired while
      // onboarding still promises photos are deleted on a schedule.
      expect(find.textContaining('Choose 7 days'), findsNothing);

      // Exactly one "SOON" remains, and it belongs to reminders. Asserting the
      // count rather than its absence keeps this test honest about what is
      // still unbuilt instead of quietly passing once retention shipped.
      expect(
        find.text('SOON'),
        findsOneWidget,
        reason: 'only the reminders control should still be a placeholder',
      );
    });

    testWidgets('shows the policy the server holds, not a default', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SettingsScreen(
            session: FakeSession(user: buildUser(photoRetentionDays: 7)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One tick, on the row the server says is current.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('"keep them" is a selectable state, not an empty one', (
      tester,
    ) async {
      // Null retention is a deliberate choice. Rendering it as "nothing
      // selected" would make the strongest-consent option look broken.
      await tester.pumpWidget(
        wrap(
          SettingsScreen(
            session: FakeSession(user: buildUser(photoRetentionDays: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('says scores survive and that deletion is not instant', (
      tester,
    ) async {
      // Both are things the option labels cannot convey, and both would
      // otherwise be found out as surprises — one alarming, one a broken
      // promise.
      await tester.pumpWidget(
        wrap(SettingsScreen(session: FakeSession(user: buildUser()))),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('scores and trend are always kept'),
        findsOneWidget,
      );
      expect(find.textContaining('once a day'), findsOneWidget);
    });
  });
}

/// A History with nothing in it, for screens that need one but are not the
/// subject of the test.
///
/// Backed by a client that will never be called: these tests pump a frame or
/// two and never invoke `load()`. A fake that reached the network would make
/// every home-screen test depend on timing it does not care about.
History emptyHistory() => History(ApiClient(NeverAuth()));

class NeverAuth extends AuthService {
  @override
  Future<String?> accessToken() async => null;
}
