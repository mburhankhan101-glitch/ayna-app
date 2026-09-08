import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';

/// Skin age against chronological age (FR-5).
///
/// ## Why this is its own component
///
/// For a lot of users this is *the* result — a skin age below their real age
/// is the thing they screenshot. Rendering it as a grey subtitle under the
/// score wastes the best moment the report has.
///
/// ## The asymmetry, which is the actual design problem
///
/// Celebrating the win is easy. The hard part is that the same component has
/// to handle "your skin reads 31 and you're 26" without it landing as a slap.
/// So the treatment is deliberately lopsided:
///
///   * **younger** — olive, warm copy, the number given real weight
///   * **level**   — neutral, quietly positive
///   * **older**   — neutral, *factual*, and no editorialising at all
///
/// The older case gets the same calm container as level, never a warning
/// colour and never a downward arrow. An app that says "judgment-free" and
/// then marks your face red for aging has not been judgment-free (NFR-6).
///
/// ## Free tier
///
/// Skin age comes from the specialist API, so free-tier reports do not have
/// one. Pass `skinAge: null` and the card renders a locked state rather than
/// an empty gap or a fabricated number.
class SkinAgeCard extends StatelessWidget {
  const SkinAgeCard({
    super.key,
    required this.skinAge,
    required this.chronologicalAge,
    this.onUnlock,
  });

  /// Null when the tier did not include a skin-age reading.
  final int? skinAge;
  final int chronologicalAge;
  final VoidCallback? onUnlock;

  int get _delta => chronologicalAge - (skinAge ?? chronologicalAge);
  bool get _isWin => skinAge != null && _delta > 0;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    if (skinAge == null) return _locked(context, t);

    final accent = _isWin ? AynaColors.oliveDeep : AynaColors.ink;
    final ground = _isWin ? AynaColors.oliveTint : AynaColors.clayTint;
    final border = _isWin ? const Color(0xFFD3E0CB) : AynaColors.border;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SKIN AGE',
            style: AynaType.label.copyWith(
              color: _isWin ? AynaColors.olive : AynaColors.inkSubtle,
            ),
          ),
          SizedBox(height: t.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$skinAge',
                style: AynaType.scoreLarge.copyWith(color: accent),
              ),
              SizedBox(width: t.space3),
              Expanded(
                child: Text(
                  _headline(),
                  style: AynaType.titleMedium.copyWith(color: accent),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space2),
          Text(_subline(), style: AynaType.bodyMedium),
        ],
      ),
    );
  }

  /// The win gets the emphatic line; everything else gets a plain statement of
  /// fact. Note there is no "older than you" anywhere — the number already
  /// says it, and naming it twice is just unkindness with extra steps.
  String _headline() {
    if (_delta > 0) {
      return _delta == 1 ? 'a year younger' : '$_delta years younger';
    }
    if (_delta == 0) return 'right in step';
    return 'reading a little above';
  }

  String _subline() {
    if (_delta > 0) {
      return 'Your skin is reading younger than $chronologicalAge. '
          'Whatever you are doing, keep doing it.';
    }
    if (_delta == 0) return 'Your skin is reading right at $chronologicalAge.';
    return 'Your skin is reading at ${skinAge!}, against your $chronologicalAge. '
        'This moves slowly, and one week tells you very little.';
  }

  Widget _locked(BuildContext context, AynaTokens t) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        color: AynaColors.clayTint,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: AynaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AynaColors.inkSubtle,
              ),
              SizedBox(width: t.space2),
              Text('SKIN AGE', style: AynaType.label),
            ],
          ),
          SizedBox(height: t.space2),
          Text(
            'See how your skin compares to your age',
            style: AynaType.titleMedium,
          ),
          if (onUnlock != null) ...[
            SizedBox(height: t.space3),
            OutlinedButton(onPressed: onUnlock, child: const Text('See plans')),
          ],
        ],
      ),
    );
  }
}
