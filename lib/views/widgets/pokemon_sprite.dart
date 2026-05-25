import 'package:flutter/material.dart';

import '../../utils/sprite_service.dart';

/// Renders a Pokémon's sprite at the current [SpriteService.style],
/// always reserving the slot so the UI shape stays consistent across
/// platforms — even when the sprite isn't available (mobile, offline,
/// Champions-original Megas with no Showdown sprite), the slot still
/// shows the pokéball placeholder so the user knows that's where the
/// image goes.
class PokemonSprite extends StatelessWidget {
  /// English species name — the sprite key is derived from this via
  /// [spriteKeyFor].
  final String pokemonName;

  /// Override the global [SpriteService.style] for this widget only.
  /// Use when a specific UI surface wants a different style from the
  /// user's overall pick (e.g., the dex detail page might force `dex`).
  final SpriteStyle? styleOverride;

  /// Edge length of the (square) sprite slot in logical pixels.
  final double size;

  const PokemonSprite({
    super.key,
    required this.pokemonName,
    this.styleOverride,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final provider =
        SpriteService.instance.spriteFor(pokemonName, style: styleOverride);
    if (provider == null) return _placeholder();
    return Image(
      image: provider,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      // Errored loads (404 from Showdown — usually Champions-original
      // Megas or DLC mons not yet in the CDN) fall back to the same
      // placeholder so the UI never goes blank.
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.catching_pokemon,
          size: size * 0.8,
          color: Colors.grey.shade300,
        ),
      );
}
