import 'package:ayna_app/theme/ayna_theme.dart';
import 'package:ayna_app/theme/theme_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the whole design system at real phone sizes.
///
/// Widget tests fail on layout overflow, so this catches the failure mode a
/// token system actually produces: a weight or size bumped a few points, and a
/// row silently overflows on the smallest device anyone still uses.
void main() {
  Widget app() => MaterialApp(
    theme: AynaTheme.light(),
    themeMode: ThemeMode.light,
    home: const ThemePreviewScreen(),
  );

  for (final device in const [
    ('iPhone SE', Size(320, 568)), // the narrowest screen worth supporting
    ('iPhone 14', Size(390, 844)),
    ('Pixel 7 Pro', Size(412, 892)),
  ]) {
    testWidgets('renders without overflow on ${device.$1}', (tester) async {
      tester.view.physicalSize = device.$2;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Scroll the full sheet — overflow further down would otherwise never
      // be laid out and never be caught.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unassessed concern never reads as "none"', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // ListView only builds what is on screen, so the row has to be scrolled
    // into existence before it can be asserted on.
    await tester.scrollUntilVisible(
      find.text('Pores'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // The single most dangerous rendering bug in this product: a concern the
    // analysis could not assess showing as a clean "none" would tell someone
    // their skin is clear when nothing ever looked at it.
    expect(find.text('couldn’t assess'), findsOneWidget);

    // And it must not leak the enum name either — "unknown" is a programmer's
    // word, not something to show a user looking at their own face.
    expect(find.text('unknown'), findsNothing);
  });

  testWidgets('the not-a-diagnosis line is present and calm', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('not a diagnosis'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final disclaimer = find.textContaining('not a diagnosis');
    expect(
      disclaimer,
      findsOneWidget,
      reason:
          'NFR-6 requires it on every '
          'screen that shows a result',
    );

    // It must never be styled as an alert. If someone "improves" it into an
    // error colour, this fails.
    final style = tester.widget<Text>(disclaimer).style!;
    expect(style.color, isNot(AynaTheme.light().colorScheme.error));
  });
}
