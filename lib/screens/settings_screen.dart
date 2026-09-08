import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/session.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';

/// Settings.
///
/// Photo retention sits at the top rather than buried under Account. NFR-4
/// calls it a trust feature, and a trust feature placed fourth is not one.
///
/// Retention is real now. It was a "SOON" placeholder while onboarding was
/// already promising photos are "deleted on a schedule you choose", which made
/// that sentence false on the second screen of a face-photo app. The setting,
/// the column and the sweep all exist; the promise is kept.
///
/// Reminders remain an honest placeholder, marked as such rather than wired to
/// nothing. A toggle that flips and does not persist is worse than one that
/// says it is coming — the first teaches the user their settings do not matter.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.session});

  final Session session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// One retention choice, as offered by the API's enum.
///
/// A null [days] is "keep them", which is a real option rather than the absence
/// of one. It is last in the list deliberately: the weakest privacy setting
/// should not be the first thing a thumb lands on.
class _RetentionOption {
  const _RetentionOption(this.days, this.label);
  final int? days;
  final String label;
}

const _retentionOptions = [
  _RetentionOption(7, 'After 7 days'),
  _RetentionOption(30, 'After 30 days'),
  _RetentionOption(365, 'After a year'),
  _RetentionOption(null, 'Keep them'),
];

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  /// The option being saved, so only the tapped row shows a spinner.
  int? _savingDays;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;
    final user = widget.session.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(t.space6, t.space4, t.space6, t.space8),
        children: [
          _section(t, 'YOUR PHOTOS'),
          _retention(t, user?.photoRetentionDays),

          SizedBox(height: t.space5),
          _section(t, 'REMINDERS'),
          _card(t, [
            _pending(
              t,
              'Weekly scan nudge',
              'A reminder when your next free scan is ready.',
            ),
          ]),

          SizedBox(height: t.space5),
          _section(t, 'ACCOUNT'),
          _card(t, [
            _row(t, 'Timezone', user?.timezone ?? '-'),
            const Divider(height: 1),
            _row(t, 'Birth year', '${user?.birthYear ?? '-'}'),
            const Divider(height: 1),
            _row(t, 'Plan', user?.entitlement.tier ?? '-'),
          ]),

          SizedBox(height: t.space5),
          OutlinedButton(
            onPressed: widget.session.signOut,
            child: const Text('Sign out'),
          ),

          SizedBox(height: t.space6),
          _section(t, 'DANGER ZONE'),
          SizedBox(height: t.space2),
          _deleteAccount(t),
        ],
      ),
    );
  }

  /// "Delete my photos after…" (NFR-4).
  ///
  /// Radio rows rather than a dropdown: there are four options, all of them
  /// short, and a dropdown would hide the current setting behind a tap on the
  /// one screen where a user came specifically to check it.
  Widget _retention(AynaTokens t, int? current) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _card(t, [
        for (var i = 0; i < _retentionOptions.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _retentionRow(t, _retentionOptions[i], current),
        ],
      ]),
      SizedBox(height: t.space2),
      Text(
        // Two things the user cannot infer from the options themselves, and
        // both would otherwise be discovered as surprises.
        //
        // The lag is stated because the sweep runs on a schedule, so choosing
        // 7 days does not empty last week instantly. Promising an immediate
        // purge the code does not perform is the exact failure this whole
        // feature exists to fix.
        'Your scores and trend are always kept. This only controls the '
        'photo. Deletions run once a day, so a shorter setting takes effect '
        'at the next sweep.',
        style: AynaType.bodySmall,
      ),
    ],
  );

  Widget _retentionRow(AynaTokens t, _RetentionOption o, int? current) {
    final selected = o.days == current;
    final busy = _saving && _savingDays == o.days;

    return InkWell(
      // Disabled while a save is in flight, so two quick taps cannot leave the
      // server holding the first choice and the screen showing the second.
      onTap: _saving ? null : () => _setRetention(o.days),
      child: Container(
        constraints: BoxConstraints(minHeight: t.minTouch),
        padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                o.label,
                style: selected
                    ? AynaType.titleSmall.copyWith(color: AynaColors.clay)
                    : AynaType.bodyLarge,
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (selected)
              const Icon(Icons.check_rounded, color: AynaColors.clay, size: 20),
          ],
        ),
      ),
    );
  }

  /// Saves the policy, then refreshes from the server.
  ///
  /// Deliberately not optimistic. The screen shows what the server holds, so a
  /// failed write leaves the old value visible rather than a checkmark next to
  /// a policy that was never stored — which on a privacy control is the one
  /// lie worth going out of the way to avoid.
  Future<void> _setRetention(int? days) async {
    setState(() {
      _saving = true;
      _savingDays = days;
    });
    try {
      await widget.session.api.setPhotoRetention(days);
      await widget.session.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${e.title}. ${e.detail}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(AynaTokens t, String label) => Padding(
    padding: EdgeInsets.only(bottom: t.space2),
    child: Text(label, style: AynaType.label),
  );

  Widget _card(AynaTokens t, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AynaColors.surface,
      border: Border.all(color: AynaColors.border),
      borderRadius: BorderRadius.circular(t.radiusMd),
    ),
    child: Column(children: children),
  );

  Widget _row(AynaTokens t, String label, String value) => Container(
    constraints: BoxConstraints(minHeight: t.minTouch),
    padding: EdgeInsets.symmetric(horizontal: t.space4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AynaType.titleSmall),
        Text(value, style: AynaType.bodyMedium),
      ],
    ),
  );

  /// A control that does not exist yet, said plainly.
  Widget _pending(AynaTokens t, String label, String detail) => Padding(
    padding: EdgeInsets.all(t.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AynaType.titleSmall)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: t.space2,
                vertical: t.space1 / 2,
              ),
              decoration: BoxDecoration(
                color: AynaColors.clayTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'SOON',
                style: AynaType.labelSmall.copyWith(
                  color: AynaColors.inkSubtle,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: t.space1),
        Text(detail, style: AynaType.bodySmall),
      ],
    ),
  );

  Widget _deleteAccount(AynaTokens t) => Container(
    padding: EdgeInsets.all(t.space4),
    decoration: BoxDecoration(
      color: AynaColors.surface,
      border: Border.all(color: AynaColors.border),
      borderRadius: BorderRadius.circular(t.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Delete my account and data', style: AynaType.titleSmall),
        SizedBox(height: t.space1),
        Text(
          'Your photos, scores and account are erased. This cannot be '
          'undone.',
          style: AynaType.bodySmall,
        ),
        SizedBox(height: t.space3),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _deleting ? null : _confirmDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AynaColors.clayDark,
              side: const BorderSide(color: AynaColors.clayDark, width: 1.5),
            ),
            child: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete account'),
          ),
        ),
      ],
    ),
  );

  /// Two steps to delete, deliberately.
  ///
  /// The dialog states what goes and that it cannot be undone, and the
  /// confirming button says "Delete" rather than "OK" — so a user who taps
  /// through on autopilot still reads the word for what they are doing.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your photos, scores and account will be erased. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AynaColors.clayDark),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.session.api.deleteAccount();
      if (!mounted) return;
      // Sign out locally too: leaving a live session pointing at an account
      // being purged would show a user their own data disappearing underneath
      // them, one 404 at a time.
      await widget.session.signOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${e.title}. ${e.detail}')));
    }
  }
}
