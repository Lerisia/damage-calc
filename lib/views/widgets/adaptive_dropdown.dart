import 'package:flutter/material.dart';

/// Returns Alignment.bottomLeft if field is in top half of screen,
/// Alignment.topLeft if in bottom half (so dropdown opens upward).
Alignment dropdownAlignment(BuildContext fieldContext) {
  final box = fieldContext.findRenderObject() as RenderBox?;
  if (box == null) return Alignment.topLeft;
  final fieldTop = box.localToGlobal(Offset.zero).dy;
  final screenHeight = MediaQuery.of(fieldContext).size.height;
  return fieldTop < screenHeight / 2 ? Alignment.topLeft : Alignment.bottomLeft;
}

/// Wraps an Autocomplete options list with a full-screen transparent barrier.
/// Tapping anywhere outside the options list dismisses the dropdown.
Widget dismissibleOptionsWrapper({
  required Alignment alignment,
  required Widget child,
}) {
  return Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        ),
      ),
      Align(
        alignment: alignment,
        child: child,
      ),
    ],
  );
}
