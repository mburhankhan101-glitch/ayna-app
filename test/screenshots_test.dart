@Tags(['screenshots'])
library;

import 'package:ayna_app/dev/sample_reports.dart';
import 'package:ayna_app/main_preview.dart';
import 'package:ayna_app/models/scan.dart';
import 'package:ayna_app/screens/home_screen.dart';
import 'package:ayna_app/screens/onboarding_screen.dart';
import 'package:ayna_app/screens/paywall_screen.dart';
import 'package:ayna_app/screens/result_screen.dart';
import 'package:ayna_app/screens/settings_screen.dart';
import 'package:ayna_app/theme/ayna_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screens_test.dart' as fixtures;

/// Generates the README screenshots.
///
///     flutter test test/screenshots_test.dart --update-goldens --run-skipped
///
/// Not a test. It asserts nothing and is tagged so a normal `flutter test` run
/// skips it -- without the tag, CI would compare these against goldens and fail
/// on any deliberate design change, which is the opposite of what they are for.
///
/// Rendered here rather than captured from a device because a device is a
/// manual step that produces a slightly different image every time: different
/// status bar, different clock, different scroll offset. These are byte-stable,
/// need no emulator, and cost no vendor credits -- the same reason
/// `lib/main_preview.dart` exists.
void main() {
  setUpAll(() async {
    // Without this, golden rendering falls back to a test font that draws
    // every glyph as a filled box. Screenshots of rectangles are worse than no
    // screenshots.
    final loader = FontLoader('Mulish')
      ..addFont(rootBundle.load('assets/fonts/Mulish.ttf'));
    await loader.load();
  });

  /// Renders one screen at phone size and writes it to docs/screenshots.
  ///
  /// Animations are disabled through the same MediaQuery flag Android's
  /// "Remove animations" sets, so every entrance lands on its final frame. It
  /// is also what stops `pumpAndSettle` hanging: the ambient loops on these
  /// screens never go quiet on their own.
  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget screen, {
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..devicePixelRatio = 3.0
      ..physicalSize = size * 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AynaTheme.light(),
        themeMode: ThemeMode.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/$name.png'),
    );
  }

  testWidgets('01 onboarding', (t) async {
    await shoot(t, '01-onboarding', OnboardingScreen(onDone: () {}));
  });

  testWidgets('02 home', (t) async {
    await shoot(
      t,
      '02-home',
      Scaffold(
        body: HomeScreen(
          session: fixtures.FakeSession(user: fixtures.buildUser()),
          history: fixtures.emptyHistory(),
          onScan: () {},
          onOpenReport: (_) {},
        ),
      ),
    );
  });

  testWidgets('03 result', (t) async {
    await shoot(
      t,
      '03-result',
      ResultScreen(report: SampleReports.concerns, onDone: () {}),
    );
  });

  testWidgets('04 trend', (t) async {
    await shoot(t, '04-trend', const TrendPreview(weeks: 6, total: 12));
  });

  testWidgets('05 paywall', (t) async {
    await shoot(
      t,
      '05-paywall',
      PaywallScreen(
        resetsAt: DateTime(2026, 9, 13),
        totalWeeks: 12,
        trend: [
          for (var i = 0; i < 6; i++)
            TrendPoint(
              weekStart: DateTime(2026, 7, 20).add(Duration(days: 7 * i)),
              overallScore: const [41, 38, 47, 44, 52, 58][i],
            ),
        ],
        onClose: () {},
      ),
    );
  });

  testWidgets('06 settings', (t) async {
    await shoot(
      t,
      '06-settings',
      SettingsScreen(session: fixtures.FakeSession(user: fixtures.buildUser())),
    );
  });
}
