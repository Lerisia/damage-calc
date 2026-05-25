import 'package:flutter/material.dart';

import '../../utils/sprite_override_manager.dart';
import '../../utils/sprite_pack_manager.dart';
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
    // Listen on both SpriteService (style switches) AND
    // SpritePackManager (pack install / remove) so every sprite
    // slot rebuilds the moment any of those state sources change.
    // Without the SpritePackManager listen, freshly imported packs
    // wouldn't show up until the user manually triggered a rebuild
    // elsewhere — e.g., by relaunching the app.
    return ListenableBuilder(
      listenable: Listenable.merge([
        SpriteService.instance,
        SpritePackManager.instance,
        SpriteOverrideManager.instance,
      ]),
      builder: (context, _) {
        // Box-icon path: try the gen1-7 icon (own name first, then
        // base species for Mega/regional forms). When neither hits
        // — gen8+ species, no pack installed, web — fall to the
        // pokéball placeholder directly instead of scaling the
        // larger style sprite down. Reason: a mixed display where
        // some rows show crisp icons and others show scaled-down
        // BW battle sprites hides the fact that the box-icon set
        // is gen1-7-capped; users who don't see a pokéball don't
        // realise there's a pack to download.
        if (useBoxIcon) {
          final icon = SpriteService.instance.iconFor(pokemonName);
          if (icon != null) {
            return _img(icon, onError: _placeholder());
          }
          final base = baseSpeciesName(pokemonName);
          if (base != null) {
            final baseIcon = SpriteService.instance.iconFor(base);
            if (baseIcon != null) {
              return _img(baseIcon, onError: _placeholder());
            }
          }
          return _placeholder();
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
