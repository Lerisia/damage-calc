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
