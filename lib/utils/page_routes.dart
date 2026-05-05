import 'package:flutter/material.dart';

/// Short fade-in PageRoute used across screen pushes. Originally lived
/// inside damage_calculator_screen.dart; extracted so the dex
/// cross-links (Pokémon Dex ↔ Move Dex via pushReplacement) can match
/// the same transition without duplicating the code.
PageRouteBuilder<T> fadeRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

/// Wraps an [AppBar] so its visual chrome — background fill, shadow,
/// bottom border, the lot — caps at [maxWidth] on wide screens and
/// centers. Body content of the dex / coverage screens is capped at
/// the same width, so this aligns the toolbar with the columns below
/// instead of stretching across a 4K window.
///
/// Pass-through: the wrapped AppBar's `preferredSize` is preserved
/// (so `bottom: TabBar` height accounting still works).
PreferredSizeWidget cappedAppBar({
  required AppBar appBar,
  required double maxWidth,
}) {
  return PreferredSize(
    preferredSize: appBar.preferredSize,
    child: LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.clamp(0.0, maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: w, child: appBar),
        );
      },
    ),
  );
}
