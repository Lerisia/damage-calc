import 'package:flutter/material.dart';

/// Drops keyboard focus when the user taps anywhere that isn't an
/// input.
///
/// Flutter gives a text field no way out on its own: tapping empty
/// space does nothing, and in a dialog there's often no other field to
/// move focus to, so the keyboard just sits there covering the content
/// the user was trying to read. Every screen that grows a search box
/// hits this, so wrap the screen's body once instead of rediscovering
/// it each time.
///
/// [UnfocusDisposition.scope] hands focus back to the enclosing
/// FocusScope rather than the previously-focused child — otherwise
/// focus bounces into a neighbouring field and the keyboard reopens.
class DismissKeyboard extends StatelessWidget {
  final Widget child;
  const DismissKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque so taps on blank areas register, but this still sits
      // *behind* buttons and fields — they win the gesture arena, so
      // wrapping a whole screen doesn't swallow its own taps.
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus
          ?.unfocus(disposition: UnfocusDisposition.scope),
      child: child,
    );
  }
}
