import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/entrance.dart';
import '../widgets/press_scale.dart';

/// Sign in.
///
/// One button, because there is one way in. Every choice a sign-in screen
/// offers is a decision taken before the user has any reason to care — Auth0's
/// hosted page handles the method, and this screen's job is to say what the
/// product is and get out of the way.
///
/// Hick's Law is the reason that stays true even when more providers exist
/// later: decision time grows with the number of options, and this is the
/// worst possible moment to spend it, because nobody has seen the product yet.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // The mark arrives first and alone. It is the only thing on this
              // screen that is purely the brand, and giving it its own beat is
              // what makes the rest read as introduced rather than dumped.
              const _MirrorMark(),

              SizedBox(height: t.space5),
              Entrance(
                delay: const Duration(milliseconds: 90),
                child: Text('Ayna', style: AynaType.displayLarge),
              ),
              SizedBox(height: t.space2),
              Entrance(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  'A kinder look at your skin',
                  style: AynaType.bodyLarge,
                ),
              ),

              const Spacer(),

              // The button does not move when this appears, because everything
              // below it is fixed height and the Spacers above absorb the
              // difference. That matters: a control that shifts under a finger
              // already travelling towards it is how a retry becomes a
              // mis-tap, and the retry is exactly what an error invites.
              //
              // An AnimatedSize here would be the obvious way to smooth the
              // insertion, and it is a trap — inside a Column whose Spacers
              // are already resolving flex, it re-dirties itself during its
              // own layout and throws.
              if (session.error != null) ...[
                Entrance(child: _ErrorNote(message: session.error!)),
                SizedBox(height: t.space4),
              ],

              Entrance(
                delay: const Duration(milliseconds: 210),
                child: PressScale(
                  child: ElevatedButton(
                    onPressed: session.signIn,
                    child: const Text('Sign in'),
                  ),
                ),
              ),

              SizedBox(height: t.space5),
              Entrance(
                delay: const Duration(milliseconds: 260),
                child: Text(
                  'Ayna gives you an impression, not a diagnosis. For anything '
                  'that worries you, see a dermatologist.',
                  style: AynaType.disclaimer,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Ayna mark: a ring with a soft centre, breathing slowly.
///
/// The name means mirror, and the mark is a face-sized circle with something
/// looking back out of it. Static, it was a decoration; breathing, it is the
/// one thing on the screen that suggests the product is alive and waiting
/// rather than a form to fill in.
class _MirrorMark extends StatefulWidget {
  const _MirrorMark();

  @override
  State<_MirrorMark> createState() => _MirrorMarkState();
}

class _MirrorMarkState extends State<_MirrorMark>
    with TickerProviderStateMixin {
  late final AnimationController _arrive;
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _arrive = AnimationController(vsync: this, duration: AynaMotion.settle);
    _breath = AnimationController(vsync: this, duration: AynaMotion.breath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AynaMotion.reduced(context)) {
      _arrive.value = 1;
      _breath
        ..stop()
        ..value = 0.5;
    } else {
      if (!_arrive.isAnimating && !_arrive.isCompleted) _arrive.forward();
      if (!_breath.isAnimating) _breath.repeat();
    }
  }

  @override
  void dispose() {
    _arrive.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: Listenable.merge([_arrive, _breath]),
      builder: (context, _) {
        // Overshoot is reserved for arrival, and this is the app's first
        // arrival: the mark lands rather than fades up.
        final in_ = AynaMotion.overshoot.transform(
          _arrive.value.clamp(0.0, 1.0),
        );
        // The centre expands and contracts a few percent — near the limit
        // of what is visible, which is the point. A pulse you can time is
        // a loading spinner.
        final pulse = 1 + 0.07 * math.sin(_breath.value * math.pi * 2);

        return Opacity(
          opacity: _arrive.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.86 + 0.14 * in_,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AynaColors.clay, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 32 * pulse,
                  height: 32 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AynaColors.clay.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// A failed sign-in, said plainly.
///
/// Kept in the warm palette rather than turned red. Most errors reaching this
/// screen are a cancelled login or a dropped connection — ordinary events, and
/// alarming the user about their own back button trains them to distrust real
/// warnings later.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(t.space4),
        decoration: BoxDecoration(
          color: AynaColors.clayTint,
          border: Border.all(color: AynaColors.border),
          borderRadius: BorderRadius.circular(t.radiusMd),
        ),
        child: Text(message, style: AynaType.bodyMedium),
      ),
    );
  }
}
