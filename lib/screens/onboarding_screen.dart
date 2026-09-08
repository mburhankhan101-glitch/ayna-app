import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/onboarding_art.dart';

/// Three slides, and each one earns its place.
///
/// Not a feature tour. The order is deliberate: what it does, what happens to
/// your photo, and what it will never claim. A product built on face photos
/// and health-adjacent output has to answer the second and third questions
/// before it asks for anything — leaving them to a privacy policy nobody opens
/// is how you get an install and no scan.
///
/// The motion here is not decoration. This screen is the first thing anyone
/// sees, and the Aesthetic-Usability Effect is blunt about the consequence:
/// people judge how well a thing works by how it looks, and they do it before
/// they have used any of it. For an app asking a stranger to photograph their
/// face, that first judgement is the whole conversion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide({required this.headline, required this.body, required this.art});

  final String headline;
  final String body;
  final OnboardingArtKind art;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      headline: 'One selfie.\nThirty seconds.',
      body:
          'See what your skin is actually doing. No appointment, '
          'no judgement, no sales pitch.',
      art: OnboardingArtKind.scan,
    ),
    _Slide(
      headline: 'Your photo stays\nyours',
      body:
          'Encrypted, never shown to another user, and deleted on a '
          'schedule you choose. You can erase everything at any time.',
      art: OnboardingArtKind.privacy,
    ),
    _Slide(
      headline: 'Not a diagnosis.\nEver.',
      body:
          'Ayna gives you an impression of your skin, the way a fitness '
          'tracker gives you an impression of your health. For anything that '
          'worries you, see a dermatologist.',
      art: OnboardingArtKind.impression,
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  /// One brown per slide, and the screen crossfades between them as you drag.
  ///
  /// Three shades of the same wood rather than three different colours: the
  /// slides are one argument in three parts, and hopping hue would make them
  /// look like three unrelated features. They deepen towards the end so the
  /// final call to action is the highest-contrast thing on the screen, which
  /// is where the only decision lives.
  static const _accents = [
    Color(0xFF8F5C3E),
    AynaColors.clay,
    AynaColors.clayDark,
  ];

  /// Interpolated from the fractional page, not the settled index, so the
  /// button warms and darkens *under the finger* rather than snapping once the
  /// drag lets go. That continuity is most of what makes a screen feel handled
  /// rather than stepped through.
  Color get _accent {
    final p = _page.clamp(0.0, (_accents.length - 1).toDouble());
    final i = p.floor().clamp(0, _accents.length - 2);
    return Color.lerp(_accents[i], _accents[i + 1], p - i)!;
  }

  /// The live, fractional page position — 1.4 mid-drag, not 1 then 2.
  ///
  /// Everything on the screen reads from this rather than from [_index], so
  /// the dots and the parallax track the finger continuously instead of
  /// snapping when the drag happens to end. Motion that follows the finger is
  /// what separates "animated" from "responsive".
  double get _page {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      return _controller.page ?? _index.toDouble();
    }
    return _index.toDouble();
  }

  // _next() lived here and drove the "Next" button. Both are gone: the slides
  // advance by swipe only. Worth noting what went with it — that method carried
  // a fix for PageController.nextPage asserting on a zero duration under
  // reduced motion. No programmatic page change remains, so the assert has
  // nothing left to fire on.

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  // Rebuilds per frame of the drag, which is what makes the
                  // parallax track the finger rather than the page change.
                  animation: _controller,
                  builder: (context, _) => _slideView(t, _slides[i], _page - i),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(t.space6, 0, t.space6, t.space6),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _dots(t),
                  ),
                  SizedBox(height: t.space3),

                  // One control, and it is not navigation.
                  //
                  // On the first two slides it is "Skip", the escape hatch.
                  // On the last it is "Get started", which is the same action
                  // — leave onboarding — under the name that fits where the
                  // user now is. It is deliberately still low-emphasis: making
                  // it a filled button would put a large tappable thing back in
                  // the corner where "Next" used to live, and that is the exact
                  // habit this change is trying to break.
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: _isLast
                            ? _accent
                            : AynaColors.inkSubtle,
                        textStyle: _isLast ? AynaType.button : null,
                      ),
                      child: AnimatedSwitcher(
                        duration: AynaMotion.of(context, AynaMotion.quick),
                        child: Text(
                          _isLast ? 'Get started' : 'Skip',
                          // Keyed so the switcher treats a changed label as a
                          // new child and cross-fades it, rather than seeing
                          // one Text widget whose string quietly changed.
                          key: ValueKey(_isLast),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The panel takes every pixel the text does not need.
  ///
  /// Three layout attempts landed here. A fixed 190px band was too short; a
  /// height-derived portrait panel was tall but left a margin of dead ground
  /// either side of it. This one is full content width and [Expanded], so the
  /// drawing is the largest thing on the screen and the copy sits directly
  /// above the dots rather than floating in the middle.
  ///
  /// Expanded is also what makes this safe without a scroll view: the text
  /// keeps its intrinsic height and the panel absorbs whatever is left, so a
  /// small screen or a large font setting shrinks the illustration instead of
  /// overflowing. The panel is the one thing on the slide that can afford to
  /// lose room.
  ///
  /// [delta] is how far this slide is from centre, in pages.
  Widget _slideView(AynaTokens t, _Slide slide, double delta) => Builder(
    // No LayoutBuilder any more: nothing here measures the box. Expanded does
    // the arithmetic that three versions of this method were doing by hand.
    builder: (context) {
      // Headline and body travel at different rates, and both lag the
      // illustration. Three speeds is what reads as depth; one speed is a
      // slide transition, which is what this screen had.
      final fade = (1 - delta.abs()).clamp(0.0, 1.0);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: t.space4),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  // A wash rather than a flat fill. A single flat swatch is
                  // the other half of why this screen read as generated: real
                  // surfaces have a light side. The wash is tinted with the
                  // slide's own accent, so the panel deepens along with the
                  // button instead of staying a constant beige card.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        _accent.withValues(alpha: 0.09),
                        AynaColors.claySoft,
                      ),
                      AynaColors.clayTint,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(t.radiusLg),
                ),
                // Law of Common Region: the filled panel is what makes the
                // drawing read as one object rather than marks floating
                // above the headline.
                child: OnboardingArt(
                  kind: slide.art,
                  parallax: delta,
                  accent: _accent,
                ),
              ),
            ),
            SizedBox(height: t.space5),
            _Lagged(
              delta: delta,
              distance: 22,
              opacity: fade,
              child: Text(slide.headline, style: AynaType.displayMedium),
            ),
            SizedBox(height: t.space3),
            _Lagged(
              delta: delta,
              distance: 40,
              opacity: fade,
              child: Text(slide.body, style: AynaType.bodyLarge),
            ),
            // The copy ends here and the dots begin immediately below. A
            // small deliberate gap rather than a token step: the text and the
            // progress indicator are the same block of information, and
            // spacing them apart made the dots look like they belonged to
            // the button instead.
            const SizedBox(height: 18),
          ],
        ),
      );
    },
  );

  /// Progress, and a small piece of motivation.
  ///
  /// Kept as dots rather than a bar because Jakob's Law applies hardest to
  /// onboarding: every carousel a user has ever seen used dots, and this is
  /// not the screen on which to teach a new convention. What changed is that
  /// the active dot now stretches continuously with the drag — the
  /// Goal-Gradient Effect says effort rises as the goal gets visibly closer,
  /// which only works if the progress is actually visible while moving.
  Widget _dots(AynaTokens t) {
    final page = _page;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slides.length; i++)
          Builder(
            builder: (context) {
              final near = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: EdgeInsets.symmetric(horizontal: t.space1 / 2),
                width: 5 + 15 * near,
                height: 5,
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFFD8C7B7), _accent, near),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Offsets and fades a child by its slide's distance from centre.
///
/// Separate widget so the two call sites cannot drift in how they interpret
/// [delta] — the headline and body differ only by [distance].
class _Lagged extends StatelessWidget {
  const _Lagged({
    required this.delta,
    required this.distance,
    required this.opacity,
    required this.child,
  });

  final double delta;
  final double distance;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Under reduced motion the displacement collapses and only the fade
    // remains, so the slide still changes visibly without anything sliding.
    final dx = AynaMotion.shift(context, delta * distance);

    return Transform.translate(
      offset: Offset(dx, 0),
      child: Opacity(opacity: opacity, child: child),
    );
  }
}
