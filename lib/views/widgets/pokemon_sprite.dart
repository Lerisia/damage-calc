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
  /// 96×96 BW sprite. When the Mega-form icon isn't curated (ZA
  /// Megas), we fall back to the base species icon — same chain as
  /// the main sprite path. The pokéball shows only when neither the
  /// form-specific nor the base icon is available (truly uncurated
  /// species, or no pack installed on mobile).
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
        if (useBoxIcon) {
          // Mirror the main-sprite chain: form icon → base species
          // icon → placeholder. Lets uncurated Mega icons (ZA Megas
          // like Mega Feraligatr) render the base species' icon
          // instead of the pokéball.
          final main = SpriteService.instance.iconFor(pokemonName);
          final fallback =
              SpriteService.instance.fallbackIconFor(pokemonName);
          if (main == null && fallback == null) return _placeholder();
          if (main == null) {
            return _img(fallback!, onError: _placeholder());
          }
          final onError = fallback == null
              ? _placeholder()
              : _img(fallback, onError: _placeholder());
          return _img(main, onError: onError);
        }
        final main = SpriteService.instance
            .spriteFor(pokemonName, style: styleOverride);
        // BW-only base-species fallback (ZA Megas etc.). Both the
        // web (404 NetworkImage) and the mobile-pack (missing file →
        // spriteFor returns null) paths need to reach the fallback,
        // so we check it BEFORE the placeholder short-circuit.
        final fallback = SpriteService.instance
            .fallbackSpriteFor(pokemonName, style: styleOverride);
        if (main == null && fallback == null) return _placeholder();
        if (main == null) {
          // Mobile pack lookup returned null (file missing). Promote
          // the fallback to the primary image — there's no main to
          // chain from.
          return _img(fallback!, onError: _placeholder());
        }
        // Main exists. Chain main → fallback → placeholder so a
        // missing remote main (web 404) falls through to the base
        // species before giving up on the pokéball.
        final onError = fallback == null
            ? _placeholder()
            : _img(fallback, onError: _placeholder());
        return _img(main, onError: onError);
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
