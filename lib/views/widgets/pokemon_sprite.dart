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

  /// Render the alternate-color (shiny / 이로치) variant. Only the
  /// main sprite path honours this — box icons fall back to the
  /// regular variant because we don't ship a shiny icon set yet.
  final bool shiny;

  const PokemonSprite({
    super.key,
    required this.pokemonName,
    this.styleOverride,
    this.size = 32,
    this.useBoxIcon = false,
    this.shiny = false,
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
          return _chainProviders([
            if (main != null) main,
            if (fallback != null) fallback,
          ]);
        }
        // Main-sprite chain. For shiny mode the chain is:
        //   shiny main → regular main → shiny fallback (base
        //   species) → regular fallback → placeholder.
        //
        // Why both shiny + regular at each level:
        //   - Mobile users on a pre-shiny pack download have the
        //     regular files but no shiny files — falling through
        //     to the regular sprite means they still see the
        //     species instead of a pokéball.
        //   - Web users with no shiny art for a specific form
        //     (rare niche entries that Showdown didn't ship as
        //     shiny) end up the same way.
        //
        // For regular mode we just chain regular main → fallback
        // → placeholder; the shiny rungs are skipped.
        ImageProvider? at(bool s) =>
            SpriteService.instance.spriteFor(pokemonName,
                style: styleOverride, shiny: s);
        ImageProvider? fb(bool s) =>
            SpriteService.instance.fallbackSpriteFor(pokemonName,
                style: styleOverride, shiny: s);
        final candidates = <ImageProvider>[
          if (shiny && at(true) != null) at(true)!,
          if (at(false) != null) at(false)!,
          if (shiny && fb(true) != null) fb(true)!,
          if (fb(false) != null) fb(false)!,
        ];
        return _chainProviders(candidates);
      },
    );
  }

  /// Build an Image chain that tries each provider in order and
  /// shows the pokéball placeholder if every one of them fails.
  /// Empty list → placeholder directly. Used by both the
  /// useBoxIcon path and the main-sprite path so the fallback
  /// shape stays consistent.
  Widget _chainProviders(List<ImageProvider> providers) {
    Widget current = _placeholder();
    for (final p in providers.reversed) {
      current = _img(p, onError: current);
    }
    return current;
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
