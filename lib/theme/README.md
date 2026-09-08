# Ayna theme — Warm Mirror

The design system from the screens canvas, as Flutter code. Analyzer clean,
13 tests passing.

## Files

| File | What lives here |
|---|---|
| `ayna_colors.dart` | Every hex literal in the app. Nothing else may hard-code a colour. |
| `ayna_typography.dart` | Mulish scale — display, title, body, label, and the score numeral |
| `ayna_tokens.dart` | `ThemeExtension`: spacing, radii, touch targets, both severity ramps, the `Severity` enum |
| `ayna_theme.dart` | Assembles `ThemeData` — component themes for buttons, inputs, chips, nav, sheets |
| `theme_preview.dart` | The system on one scrollable screen, rendered by the real theme |

## Using it

```dart
MaterialApp(theme: AynaTheme.light(), themeMode: ThemeMode.light)
```

Reach tokens through the context extension:

```dart
final t = context.ayna;
Padding(padding: EdgeInsets.all(t.space4));         // 16
Container(color: t.fillFor(Severity.moderate));      // UI ramp
Container(color: t.heatFor(Severity.moderate));      // photo overlay — cool
```

Run the preview to see everything at once:

```bash
flutter run
```

## Four things that will bite if you don't know them

**Letter spacing is not `em`.** CSS `-0.035em` is relative; Flutter's
`letterSpacing` is absolute logical pixels. Copying the stylesheet number
straight across gives you `-0.035px` — invisible, where the design wants about
`-1.19` at 34px. `AynaType.tracking(size, em)` does the conversion, and a test
pins the result.

**Mulish is a variable font.** Weights are set with an explicit
`FontVariation('wght', …)` alongside `fontWeight`. Without it some platforms
synthesise a fake bold, which looks visibly wrong at the 900 weights this
design leans on. The font is bundled (212 KB, ExtraLight→ExtraBlack) rather
than fetched at runtime — the app has to work on a poor connection, and a
first-run font download means the first screen renders in the wrong face.

**There are two severity ramps and they are not interchangeable.** `fillFor()`
is clay, for the UI. `heatFor()` is cool blues, for overlays on the user's
photo — warm overlays disappear into brown skin. A test asserts the blue
channel leads, because matching the heatmap to the brand colour is exactly the
"improvement" someone will eventually make.

**`colorScheme.error` is not red.** Nothing in this product is an error in the
alarming sense: a severe reading is information, and the referral card is olive
so it reads as care rather than warning (NFR-6). `error` is `clayDark` — the
strongest thing in the palette that isn't an alarm. A test pins that too.

## Not done

**No dark theme.** Warm Mirror is light-committed — its identity is cream and
clay — and inverting it mechanically produces mud. A real dark palette is a
design pass, not a code change. `themeMode` is pinned to `light` so a phone in
dark mode doesn't fall through to Flutter's default dark theme and look broken.
Remove the pin when a dark variant actually exists.

**Not visually verified.** The tests prove it builds, lays out without overflow
at 320/390/412 px, and holds its invariants — but nobody has looked at it on a
real screen yet. `flutter run` and check the type weights first: variable-font
rendering is the thing most likely to differ from the mockup.
