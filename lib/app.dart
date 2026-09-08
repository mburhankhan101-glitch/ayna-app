import 'package:flutter/material.dart';

import 'screens/age_gate_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';
import 'state/session.dart';
import 'theme/ayna_motion.dart';
import 'theme/ayna_theme.dart';

/// The app, and its router.
///
/// Routing is a switch over [SessionStage] rather than a named-route table.
/// The stages are ordered gates — signed in, then a profile, then consent —
/// and a `switch` makes that literal: adding a stage without handling it is a
/// compile error, whereas a route table would simply never navigate there.
///
/// It also means the flow cannot be skipped by deep link, because there are no
/// routes to link to. Consent (FR-1) is not something to leave reachable-around.
class AynaApp extends StatefulWidget {
  const AynaApp({super.key});

  @override
  State<AynaApp> createState() => _AynaAppState();
}

class _AynaAppState extends State<AynaApp> {
  final _session = Session();

  /// Set when the server refuses on age grounds (PD-1).
  ///
  /// Held here rather than in Session because it is a screen the user is
  /// shown, not a state the account is in — no account was created, so there
  /// is nothing for the session to be.
  bool _refusedForAge = false;

  @override
  void initState() {
    super.initState();
    _session.start();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ayna',
      debugShowCheckedModeBanner: false,
      theme: AynaTheme.light(),

      // Pinned deliberately. Warm Mirror is a light-committed direction, and
      // there is no dark palette yet — without this pin a phone in dark mode
      // falls back to Flutter's default dark theme and the app looks broken.
      themeMode: ThemeMode.light,

      home: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          if (_refusedForAge) {
            return UnderAgeScreen(
              onBack: () => setState(() => _refusedForAge = false),
            );
          }

          // Cross-fade between stages rather than swapping instantly.
          //
          // Tapping "Sign in" moves the session to `starting`, which replaces
          // the whole screen with the splash — as a hard cut that reads as the
          // app restarting rather than as the tap being accepted. The switcher
          // tells them apart by runtimeType, so each stage is its own child
          // without needing keys threaded through.
          return AnimatedSwitcher(
            duration: AynaMotion.of(context, AynaMotion.base),
            switchInCurve: AynaMotion.enter,
            switchOutCurve: AynaMotion.exit,
            child: switch (_session.stage) {
              SessionStage.starting => const SplashScreen(),
              SessionStage.onboarding => OnboardingScreen(
                onDone: _session.completeOnboarding,
              ),
              SessionStage.signedOut => SignInScreen(session: _session),
              SessionStage.needsProfile => ProfileSetupScreen(
                session: _session,
                onRefused: () => setState(() => _refusedForAge = true),
                // Whatever the identity provider knew. Google supplies a
                // name; the email connection does not, so this is null for
                // half the users and the name step exists to cover it.
                suggestedName: _session.suggestedName,
              ),
              SessionStage.needsConsent => ConsentScreen(session: _session),
              SessionStage.ready => MainShell(session: _session),
            },
          );
        },
      ),
    );
  }
}
