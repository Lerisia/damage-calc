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

  /// When true, prefer the gen6-7 box icon over the current style's
  /// sprite. Used by compact placements (dex list rows, simple-mode
  /// species row) where a 40×30 icon looks crisper than a scaled-down
  /// 96×96 BW sprite. Falls through to the regular sprite chain when
  /// the icons cache isn't populated (web, or pre-import on mobile).
  final bool useBoxIcon;

  const PokemonSprite({
    super.key,
    required this.pokemonName,
    this.styleOverride,
    this.size = 32,
    this.useBoxIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    // Listen on SpriteService so every sprite slot rebuilds when the
    // user picks a new style from the menu, regardless of where in
    // the widget tree the slot lives.
    return ListenableBuilder(
      listenable: SpriteService.instance,
      builder: (context, _) {
        // Box-icon path: try the gen1-7 icon for this name first.
        // Falls through to the regular sprite chain on miss (no icon
        // for gen8+ species / web / no pack installed yet).
        if (useBoxIcon) {
          final icon = SpriteService.instance.iconFor(pokemonName);
          if (icon != null) {
            return _img(icon, onError: _spriteChain());
          }
          // Also try the base species' icon — covers Mega/regional
          // forms whose own slug isn't in the pack but whose base
          // species is.
          final base = baseSpeciesName(pokemonName);
          if (base != null) {
            final baseIcon = SpriteService.instance.iconFor(base);
            if (baseIcon != null) {
              return _img(baseIcon, onError: _spriteChain());
            }
          }
        }
        return _spriteChain();
      },
    );
  }

  /// Regular sprite-with-fallback chain: style sprite → base species
  /// sprite → pokéball placeholder. Pulled out so the box-icon path
  /// can use it as its own onError fallback.
  Widget _spriteChain() {
    final main = SpriteService.instance
        .spriteFor(pokemonName, style: styleOverride);
    if (main == null) return _placeholder();
    final fallback = SpriteService.instance
        .fallbackSpriteFor(pokemonName, style: styleOverride);
    return _img(
      main,
      onError: fallback == null
          ? _placeholder()
          : _img(fallback, onError: _placeholder()),
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
