import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/ayna_motion.dart';
import 'age_gate_screen.dart';
import 'name_screen.dart';

/// The two questions asked before anyone reaches the app: your name, then your
/// birth year.
///
/// Split across two screens rather than one form, because they are different
/// kinds of question and mixing them makes both worse. The name is a courtesy
/// the user can decline; the year is a gate that can refuse them. A single
/// screen holding both would either make the courtesy feel mandatory or make
/// the gate feel casual.
///
/// One question per screen is also simply what works: fewer decisions visible
/// at once, and each screen can be answered without reading past it.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.session,
    required this.onRefused,
    this.suggestedName,
  });

  final Session session;
  final VoidCallback onRefused;

  /// Whatever the identity provider knew. Google supplies a name; the email
  /// connection does not, which is the entire reason the name step exists.
  final String? suggestedName;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String? _name;
  late bool _asked = _hasSuggestion;

  bool get _hasSuggestion =>
      widget.suggestedName != null && widget.suggestedName!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Never ask for something already known. Someone who signed in with Google
    // has handed over their name once; asking again reads as an app that was
    // not paying attention.
    if (_hasSuggestion) _name = widget.suggestedName;
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AynaMotion.of(context, AynaMotion.base),
    switchInCurve: AynaMotion.enter,
    switchOutCurve: AynaMotion.exit,
    child: _asked
        ? AgeGateScreen(
            key: const ValueKey('age'),
            session: widget.session,
            onRefused: widget.onRefused,
            suggestedName: _name,
          )
        : NameScreen(
            key: const ValueKey('name'),
            onContinue: (name) => setState(() {
              _name = name;
              _asked = true;
            }),
          ),
  );
}
