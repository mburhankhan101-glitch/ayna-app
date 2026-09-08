import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';

/// Explicit consent to photo processing (FR-1).
///
/// Three plain sentences, no pre-ticked box, and **the button label is the
/// consent**: "I agree, open camera" states what agreeing does. A generic
/// "Continue" under a wall of text is how you get a signature nobody read.
///
/// The record the server writes is version-scoped and append-only, so
/// revoking later adds a row rather than erasing this one. That is what makes
/// "was this user consented when that scan ran?" answerable.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.session});

  final Session session;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _busy = false;
  String? _error;

  static const _points = [
    'Your photo is encrypted, analysed, and never shown to another user.',
    'It is sent to our analysis partner to be scored, then deleted on the '
        'schedule you choose.',
    'You can delete everything, any time, from Settings.',
  ];

  Future<void> _agree() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await widget.session.grantConsent();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    // Terms scroll; the action stays pinned. On a small screen a single
    // scrolling column would push the agree button below the fold, and an
    // agreement whose button you have to hunt for is a worse agreement.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  t.space6,
                  t.space6,
                  t.space6,
                  t.space4,
                ),
                children: [
                  Text('Your photo, your call', style: AynaType.displayMedium),
                  SizedBox(height: t.space3),
                  Text(
                    'Before we open the camera, here is exactly what happens.',
                    style: AynaType.bodyLarge,
                  ),
                  SizedBox(height: t.space5),
                  for (final point in _points) ...[
                    _point(t, point),
                    SizedBox(height: t.space3),
                  ],
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space6,
                t.space2,
                t.space6,
                t.space4,
              ),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: AynaType.bodyMedium),
                    SizedBox(height: t.space3),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _agree,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          // The label IS the consent: it says what agreeing does.
                          : const Text('I agree, open camera'),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Read the full policy'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _point(AynaTokens t, String text) => Container(
    padding: EdgeInsets.all(t.space3),
    decoration: BoxDecoration(
      color: AynaColors.surface,
      border: Border.all(color: AynaColors.border),
      borderRadius: BorderRadius.circular(t.radiusMd),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.check_rounded, size: 18, color: AynaColors.olive),
        ),
        SizedBox(width: t.space3),
        Expanded(child: Text(text, style: AynaType.bodyMedium)),
      ],
    ),
  );
}
