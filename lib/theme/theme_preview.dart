import 'package:flutter/material.dart';

import 'ayna_colors.dart';
import 'ayna_tokens.dart';
import '../widgets/skin_age_card.dart';
import 'ayna_typography.dart';

/// The design-system artboard, rendered by the real theme.
///
/// Its job is to fail loudly when a token drifts: every colour, weight and
/// severity level on one scrollable screen, so a regression is visible in
/// seconds rather than discovered on a report screen three sprints later.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayna · Warm Mirror')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(t.space6, t.space2, t.space6, t.space8),
        children: [
          _section('Score numeral', t),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('78', style: AynaType.scoreHero),
              SizedBox(width: t.space4),
              Expanded(
                child: Text('up 4 from last week', style: AynaType.titleSmall),
              ),
            ],
          ),

          _section('Skin age: all four states', t),
          const SkinAgeCard(skinAge: 24, chronologicalAge: 26),
          SizedBox(height: t.space3),
          const SkinAgeCard(skinAge: 26, chronologicalAge: 26),
          SizedBox(height: t.space3),
          const SkinAgeCard(skinAge: 29, chronologicalAge: 26),
          SizedBox(height: t.space3),
          SkinAgeCard(skinAge: null, chronologicalAge: 26, onUnlock: () {}),

          _section('Type scale', t),
          Text('Your skin, today', style: AynaType.displayMedium),
          SizedBox(height: t.space2),
          Text('Dryness is worth a look', style: AynaType.titleMedium),
          SizedBox(height: t.space2),
          Text(
            'Dryness is the one thing worth changing this week. '
            'Everything else is holding steady.',
            style: AynaType.bodyLarge,
          ),
          SizedBox(height: t.space2),
          Text('TUESDAY, 12 MAY', style: AynaType.label),

          _section('Severity: UI ramp', t),
          Row(
            children: [
              for (final s in [
                Severity.none,
                Severity.mild,
                Severity.moderate,
                Severity.severe,
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t.space2),
                    child: Column(
                      children: [
                        Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: t.fillFor(s),
                            borderRadius: BorderRadius.circular(t.radiusSm),
                          ),
                        ),
                        SizedBox(height: t.space1),
                        Text(s.name, style: AynaType.bodySmall),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          _section('Severity: heatmap, over skin', t),
          // Swatches flex rather than sitting at a fixed width: three 92px
          // boxes overflow a 320px screen, and a preview that overflows is
          // worse than no preview.
          Row(
            children: [
              for (final s in [
                Severity.mild,
                Severity.moderate,
                Severity.severe,
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t.space2),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B6146),
                        borderRadius: BorderRadius.circular(t.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: 0.58,
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: t.heatFor(s),
                            borderRadius: BorderRadius.circular(t.radiusSm),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: t.space2),
          Text(
            'Cool hues only. Clay vanishes into brown skin.',
            style: AynaType.bodySmall,
          ),

          _section('Concern rows', t),
          _concern(context, 'Dryness', Severity.moderate, 0.62),
          _concern(context, 'Acne', Severity.mild, 0.34),
          _concern(context, 'Redness', Severity.none, 0.09),
          _concern(context, 'Pores', Severity.unknown, 0),

          _section('Controls', t),
          ElevatedButton(onPressed: () {}, child: const Text('See my routine')),
          SizedBox(height: t.space3),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Find a dermatologist'),
          ),
          SizedBox(height: t.space3),
          const ElevatedButton(onPressed: null, child: Text('Verify')),
          SizedBox(height: t.space3),
          const TextField(
            decoration: InputDecoration(hintText: 'you@example.com'),
          ),
          SizedBox(height: t.space3),
          Wrap(
            spacing: t.space2,
            children: [
              for (final (i, label) in ['Week', 'Month', 'Year'].indexed)
                ChoiceChip(
                  label: Text(label),
                  selected: i == 0,
                  onSelected: (_) {},
                ),
            ],
          ),

          _section('Cards', t),
          Card(
            child: Padding(
              padding: EdgeInsets.all(t.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One thing this week',
                    style: AynaType.titleSmall.copyWith(
                      color: AynaColors.olive,
                    ),
                  ),
                  SizedBox(height: t.space1),
                  Text(
                    'Add a richer moisturiser at night. '
                    'Give it seven days before you judge it.',
                    style: AynaType.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: t.space6),
          Text(
            'Ayna gives you an impression, not a diagnosis. '
            'For anything that worries you, see a dermatologist.',
            style: AynaType.disclaimer,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _section(String label, AynaTokens t) => Padding(
    padding: EdgeInsets.only(top: t.space8, bottom: t.space4),
    child: Text(label.toUpperCase(), style: AynaType.label),
  );

  Widget _concern(BuildContext context, String name, Severity s, double fill) {
    final t = context.ayna;
    // An unassessed concern must never render as "None" — it says so instead.
    final unknown = s == Severity.unknown;

    return Padding(
      padding: EdgeInsets.only(bottom: t.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: AynaType.titleSmall),
              Text(
                unknown ? "couldn’t assess" : s.name,
                style: AynaType.labelSmall.copyWith(
                  letterSpacing: 0,
                  fontSize: 11.5,
                  color: t.inkFor(s),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space1),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: unknown ? 0 : fill,
              minHeight: 6,
              backgroundColor: AynaColors.severityNone,
              valueColor: AlwaysStoppedAnimation(t.fillFor(s)),
            ),
          ),
        ],
      ),
    );
  }
}
