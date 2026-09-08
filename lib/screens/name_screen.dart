import 'package:flutter/material.dart';

import '../theme/ayna_colors.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/entrance.dart';
import '../widgets/press_scale.dart';

/// "What should we call you?"
///
/// Asked because the app was greeting people with a bare "Hello". Auth0's
/// Google connection supplies a name and its email connection does not, so
/// which login you picked silently decided whether the product knew who you
/// were — a difference no user could see and none would attribute to the right
/// cause.
///
/// It comes **before** the age gate on purpose. This is the first thing the
/// product asks for, and asking a warm question before a gating one is the
/// difference between an introduction and an interrogation. It also costs
/// nothing if refused: the gate is what actually decides anything.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key, required this.onContinue});

  /// Called with the entered name, or null when skipped.
  final void Function(String? name) onContinue;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Focused immediately: this screen asks exactly one thing, and making the
    // user tap a field to answer a question already on screen is a step that
    // exists only because nobody removed it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    widget.onContinue(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Scaffold(
      backgroundColor: AynaColors.cream,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              Entrance(
                child: Text(
                  'What should we\ncall you?',
                  style: AynaType.displayMedium,
                ),
              ),
              SizedBox(height: t.space3),
              Entrance(
                delay: const Duration(milliseconds: 90),
                child: Text(
                  // Says what it is for and what it is not. A name field with
                  // no explanation reads as data collection; one that says
                  // "just for the greeting" reads as manners.
                  'Just so the app can greet you properly. A first name is '
                  'plenty, and it is only ever shown to you.',
                  style: AynaType.bodyLarge,
                ),
              ),
              SizedBox(height: t.space6),

              Entrance(
                delay: const Duration(milliseconds: 150),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofillHints: const [AutofillHints.givenName],
                  textCapitalization: TextCapitalization.words,
                  // The keyboard's action key submits, so the button is a
                  // second route rather than the only one.
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) => setState(() {}),
                  style: AynaType.displaySmall,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              Entrance(
                delay: const Duration(milliseconds: 210),
                child: PressScale(
                  child: ElevatedButton(
                    onPressed: _controller.text.trim().isEmpty ? null : _submit,
                    child: const Text('Continue'),
                  ),
                ),
              ),
              SizedBox(height: t.space1),
              Entrance(
                delay: const Duration(milliseconds: 250),
                child: TextButton(
                  // Skippable, and visibly so. A name is a courtesy, not a
                  // requirement, and a mandatory field for something the
                  // product works fine without is just friction wearing a form.
                  onPressed: () => widget.onContinue(null),
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
