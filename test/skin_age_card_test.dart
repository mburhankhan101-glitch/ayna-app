import 'package:ayna_app/theme/ayna_colors.dart';
import 'package:ayna_app/theme/ayna_theme.dart';
import 'package:ayna_app/widgets/skin_age_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
    MaterialApp(
      theme: AynaTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );

  Color groundOf(WidgetTester tester) {
    final box = tester.widget<Container>(find.byType(Container).first);
    return ((box.decoration as BoxDecoration).color)!;
  }

  group('a win is celebrated', () {
    testWidgets('younger skin age gets olive and warm copy', (tester) async {
      await pump(tester, const SkinAgeCard(skinAge: 24, chronologicalAge: 26));

      expect(find.text('24'), findsOneWidget);
      expect(find.text('2 years younger'), findsOneWidget);
      expect(groundOf(tester), AynaColors.oliveTint);
    });

    testWidgets('one year younger is singular', (tester) async {
      await pump(tester, const SkinAgeCard(skinAge: 25, chronologicalAge: 26));
      expect(find.text('a year younger'), findsOneWidget);
    });
  });

  group('a non-win is never punished', () {
    // This is the test that matters. Celebrating the good result is easy; the
    // product promise is that the bad one still feels kind. If someone later
    // adds a red tint or a "your skin is older" line, this fails.
    testWidgets('older skin age stays on the neutral ground', (tester) async {
      await pump(tester, const SkinAgeCard(skinAge: 29, chronologicalAge: 26));

      expect(
        groundOf(tester),
        AynaColors.clayTint,
        reason: 'an older reading must not get its own alarm colour',
      );
      expect(groundOf(tester), isNot(AynaTheme.light().colorScheme.error));
    });

    testWidgets('never says "older"', (tester) async {
      await pump(tester, const SkinAgeCard(skinAge: 29, chronologicalAge: 26));

      // The number already says it. Naming it as well is unkindness with
      // extra steps, and this app promised judgment-free (NFR-6).
      expect(find.textContaining('older'), findsNothing);
      expect(find.textContaining('worse'), findsNothing);
    });

    testWidgets('softens the reading with how slowly it moves', (tester) async {
      await pump(tester, const SkinAgeCard(skinAge: 29, chronologicalAge: 26));
      expect(
        find.textContaining('one week tells you very little'),
        findsOneWidget,
      );
    });

    testWidgets('level reads as in step, not as a null result', (tester) async {
      await pump(tester, const SkinAgeCard(skinAge: 26, chronologicalAge: 26));
      expect(find.text('right in step'), findsOneWidget);
    });
  });

  group('free tier', () {
    testWidgets('renders a locked state, never a fabricated age', (
      tester,
    ) async {
      await pump(
        tester,
        SkinAgeCard(skinAge: null, chronologicalAge: 26, onUnlock: () {}),
      );

      expect(find.text('See plans'), findsOneWidget);
      expect(
        find.text('26'),
        findsNothing,
        reason:
            'showing the chronological age here would read as the '
            'skin-age result and be a lie',
      );
    });

    testWidgets('no upsell button when there is nowhere to send them', (
      tester,
    ) async {
      await pump(
        tester,
        const SkinAgeCard(skinAge: null, chronologicalAge: 26),
      );
      expect(find.text('See plans'), findsNothing);
    });
  });

  testWidgets('lays out on the narrowest supported screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The longest headline against the largest plausible number.
    await pump(tester, const SkinAgeCard(skinAge: 18, chronologicalAge: 45));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('27 years younger'), findsOneWidget);
  });
}
