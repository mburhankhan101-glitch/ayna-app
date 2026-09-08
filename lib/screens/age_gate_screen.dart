import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';

/// The age gate (PD-1), before consent and before the camera ever opens.
///
/// It asks what year you were born, not whether you are eighteen. A yes/no
/// gate teaches the answer it wants — anyone refused simply taps the other
/// button — so it collects a fact instead of asking for a promise.
///
/// Only the YEAR is collected. That satisfies both the gate and the skin-age
/// comparison (FR-5), and a full date of birth would be meaningfully more
/// identifying for no added benefit.
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({
    super.key,
    required this.session,
    required this.onRefused,
    this.suggestedName,
  });

  final Session session;
  final VoidCallback onRefused;
  final String? suggestedName;

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  static const _minimumAge = 18;

  late final int _thisYear = DateTime.now().year;
  late final List<int> _years = List.generate(
    90,
    (i) => _thisYear - 10 - i,
  ); // 10..99 years old

  late final FixedExtentScrollController _wheel = FixedExtentScrollController(
    initialItem: 16,
  ); // ~26 years old

  int _selected = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = _years[16];
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  /// Same year-only arithmetic the server uses, so the two cannot disagree.
  bool get _oldEnough => _thisYear - _selected >= _minimumAge;

  Future<void> _submit() async {
    // Checked here purely for speed of feedback. The server is the authority:
    // a client-side gate is a courtesy, and anything that only exists in the
    // app is not a rule.
    if (!_oldEnough) {
      widget.onRefused();
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await widget.session.createProfile(
      birthYear: _selected,
      // The device's zone, which is what PD-5 computes streak weeks in. Taken
      // from the phone rather than asked, because nobody wants a timezone
      // question during sign-up.
      timezone: DateTime.now().timeZoneName == 'UTC'
          ? 'UTC'
          : _resolveTimezone(),
      displayName: widget.suggestedName,
    );

    if (!mounted) return;

    if (failure == Session.underAge) {
      widget.onRefused();
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  /// Flutter has no first-class IANA zone name, and the server requires one
  /// because a fixed offset cannot express when a week begins across a DST
  /// change. Falling back to the app's primary market is honest and correct
  /// far more often than UTC would be; Settings can change it later.
  String _resolveTimezone() => 'Asia/Karachi';

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
              SizedBox(height: t.space5),
              Text('What year were you born?', style: AynaType.displayMedium),
              SizedBox(height: t.space3),
              Text(
                'Ayna is built for adults. We only keep the year, never your '
                'full date of birth.',
                style: AynaType.bodyLarge,
              ),
              SizedBox(height: t.space6),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AynaColors.surface,
                    border: Border.all(color: AynaColors.border),
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: ListWheelScrollView.useDelegate(
                    controller: _wheel,
                    itemExtent: 56,
                    perspective: 0.002,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) =>
                        setState(() => _selected = _years[i]),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _years.length,
                      builder: (context, i) {
                        final selected = _years[i] == _selected;
                        return Center(
                          child: Text(
                            '${_years[i]}',
                            style: selected
                                ? AynaType.displaySmall
                                : AynaType.titleMedium.copyWith(
                                    color: const Color(0xFFC4B7A5),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              if (_error != null) ...[
                SizedBox(height: t.space4),
                Text(_error!, style: AynaType.bodyMedium),
              ],

              SizedBox(height: t.space5),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
              SizedBox(height: t.space3),
              Text(
                'Used to check you are 18 or over, and to compare your skin '
                'age with your actual age.',
                style: AynaType.disclaimer,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the gate refuses.
///
/// It explains why and still offers something useful. A dead end here would be
/// a poor look for a health-adjacent product, and the person on the other side
/// of it is a teenager who was told no by an app about their face — the tone
/// matters more here than almost anywhere else in the product.
class UnderAgeScreen extends StatelessWidget {
  const UnderAgeScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    // Scrollable rather than Spacer-balanced: the copy here is deliberately
    // longer than a one-line refusal, and on a 320x568 screen that overflows.
    // Text this screen exists to deliver must not be the text that gets
    // clipped.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.all(t.space6),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - t.space6 * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: t.space8),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AynaColors.claySoft,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AynaColors.clay,
                      size: 30,
                    ),
                  ),
                  SizedBox(height: t.space5),
                  Text(
                    "Come back when you're 18",
                    style: AynaType.displayMedium,
                  ),
                  SizedBox(height: t.space4),
                  Text(
                    'Ayna scores how skin looks, and that is not something we '
                    'want to put in front of anyone still growing into their '
                    'face.',
                    style: AynaType.bodyLarge,
                  ),
                  SizedBox(height: t.space3),
                  Text(
                    'Nothing has been saved, and no account was created.',
                    style: AynaType.bodyLarge,
                  ),
                  SizedBox(height: t.space8),
                  OutlinedButton(
                    onPressed: onBack,
                    child: const Text('Find a dermatologist instead'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
