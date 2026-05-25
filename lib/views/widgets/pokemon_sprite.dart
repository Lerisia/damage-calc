import 'package:flutter/material.dart';

import '../../utils/sprite_service.dart';
import 'sprite_style_dialog.dart';

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
    // Listen on SpriteService so every sprite slot rebuilds when the
    // user picks a new style from the menu, regardless of where in
    // the widget tree the slot lives.
    return ListenableBuilder(
      listenable: SpriteService.instance,
      builder: (context, _) {
        final main = SpriteService.instance
            .spriteFor(pokemonName, style: styleOverride);
        if (main == null) return _placeholder();
        final fallback = SpriteService.instance
            .fallbackSpriteFor(pokemonName, style: styleOverride);
        return _img(
          main,
          // Form sprites that Showdown hasn't gotten community art
          // for (most often new Legends Z-A Megas) try the base
          // species sprite next so the user at least sees their
          // Pokémon — the form name + Mega badge in surrounding UI
          // still make it clear it's the Mega form, just without
          // the Mega artwork. Only the truly unknown case (base
          // species sprite also missing, or input is already a base)
          // falls all the way to the pokéball placeholder.
          onError: fallback == null
              ? _placeholder()
              : _img(fallback, onError: _placeholder()),
        );
      },
    );
  }

  Widget _img(ImageProvider provider, {required Widget onError}) {
    return Image(
      image: provider,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => onError,
    );
  }

  Widget _placeholder() => Builder(
        // Builder so the tap handler can reach a real BuildContext
        // (the immediate parent Image's errorBuilder doesn't always
        // give us a usable one across hot-reloads).
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          // The pokéball is the user's entry point into the sprite
          // style + pack-management dialog. Without this, the
          // overflow menu was the only path — discoverability was
          // poor for users who'd never opened that menu.
          onTap: () => showSpriteStyleDialog(context),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.catching_pokemon,
              size: size * 0.8,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      );
}
