import 'package:flutter/material.dart';

import '../models/user.dart';
import '../state/session.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final user = session.user;

    return ListView(
      padding: EdgeInsets.fromLTRB(t.space6, t.space5, t.space6, t.space8),
      children: [
        _header(context, t, user),
        SizedBox(height: t.space6),
        _stats(t, user),
        SizedBox(height: t.space4),
        _upgradeCard(t, user),
        SizedBox(height: t.space6),
        Text('RECENT', style: AynaType.label),
        SizedBox(height: t.space3),
        _recentEmpty(t),
        SizedBox(height: t.space6),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SettingsScreen(session: session)),
          ),
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('Settings'),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, AynaTokens t, AynaUser? user) {
    final name = user?.displayName ?? 'You';
    final tier = user?.entitlement.tier ?? 'free';

    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AynaColors.claySoft,
          child: Text(
            name.characters.first.toUpperCase(),
            style: AynaType.displaySmall.copyWith(color: AynaColors.clay),
          ),
        ),
        SizedBox(height: t.space3),
        Text(name, style: AynaType.titleLarge),
        SizedBox(height: t.space2),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: t.space3,
            vertical: t.space1 + 1,
          ),
          decoration: BoxDecoration(
            color: AynaColors.clayTint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${tier.toUpperCase()} PLAN',
            style: AynaType.labelSmall.copyWith(color: AynaColors.inkSubtle),
          ),
        ),
      ],
    );
  }

  Widget _stats(AynaTokens t, AynaUser? user) => Row(
    children: [
      // All zero, and shown anyway. A new profile that hides its counters
      // until they are non-zero looks broken; one that shows zeroes tells
      // you what will fill in.
      _stat(t, '0', 'scans'),
      SizedBox(width: t.space2),
      _stat(t, '-', 'best'),
      SizedBox(width: t.space2),
      _stat(t, '${user?.streakWeeks ?? 0}', 'weeks'),
    ],
  );

  Widget _stat(AynaTokens t, String value, String label) => Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(vertical: t.space3),
      decoration: BoxDecoration(
        color: AynaColors.surface,
        border: Border.all(color: AynaColors.border),
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Column(
        children: [
          Text(value, style: AynaType.scoreCompact),
          SizedBox(height: t.space1),
          Text(label, style: AynaType.bodySmall),
        ],
      ),
    ),
  );

  /// Sells the heatmap, because that is the thing Plus actually gives you
  /// that you can see (PD-3). Hidden once they are on a paid tier — an upsell
  /// shown to someone who already paid reads as not knowing who they are.
  Widget _upgradeCard(AynaTokens t, AynaUser? user) {
    if (user != null && !user.entitlement.isFree) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        color: AynaColors.olive,
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'See more of your skin',
            style: AynaType.titleMedium.copyWith(color: AynaColors.oliveTint),
          ),
          SizedBox(height: t.space2),
          Text(
            'Plus shows the heatmap on your own photo, your full history, and '
            'your skin age.',
            style: AynaType.bodyMedium.copyWith(color: const Color(0xFFD9E3D2)),
          ),
          SizedBox(height: t.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // Deliberately inert: PD-3 settled the tiers but store billing
              // is not wired, and a button that opens nothing is better than
              // one that opens a checkout we cannot honour.
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: AynaColors.oliveTint,
                foregroundColor: AynaColors.oliveDeep,
                disabledBackgroundColor: AynaColors.oliveTint,
                disabledForegroundColor: AynaColors.oliveDeep,
                minimumSize: Size.fromHeight(t.minTouch),
                textStyle: AynaType.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
              ),
              child: const Text('Coming soon'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentEmpty(AynaTokens t) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(t.space5),
    decoration: BoxDecoration(
      color: AynaColors.surfaceSunk,
      borderRadius: BorderRadius.circular(t.radiusLg),
    ),
    child: Column(
      children: [
        Text('Nothing here yet', style: AynaType.titleSmall),
        SizedBox(height: t.space1),
        Text(
          'Your scans will appear here, newest first.',
          style: AynaType.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
