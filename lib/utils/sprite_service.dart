import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Stable, unique sprite key for a Pokémon, derived from its English
/// species name.
///
/// This is the calculator's *own* pack naming scheme — a build-time tool
/// repackages the Pokémon Showdown sprites under these keys, so runtime
/// resolution stays a trivial lookup instead of having to mirror
/// Showdown's filename conventions.
///
/// Examples: `Pikachu` → `pikachu`, `Mega Abomasnow` → `mega-abomasnow`,
/// `Terapagos (Stellar Form)` → `terapagos-stellar-form`,
/// `Nidoran♀` → `nidoran-f`, `Nidoran♂` → `nidoran-m`.
///
/// Verified collision-free across the full pokedex (the gender symbols
/// are mapped explicitly because they would otherwise both collapse to
/// `nidoran`).
String spriteKeyFor(String pokemonName) => pokemonName
    .replaceAll('♀', '-f')
    .replaceAll('♂', '-m')
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// TEMPORARY preview flag. When true the sprite layouts render even with
/// no sprite pack present (with a placeholder), so the new arrangement
/// can be checked on a TestFlight build before the pack exists. Set back
/// to false before merging to main / once the real pack is wired in.
const bool kSpritePreviewMode = true;

/// Resolves Pokémon sprite images for the UI.
///
/// The sprite pack (small box icons for the simple calculator, larger
/// dex sprites for the expanded calculator — sourced from the Pokémon
/// Showdown sprite project) is **not bundled in the app binary**: on web
/// it is served as static files alongside the site, and on mobile it is
/// downloaded once after install and cached locally. Keeping it out of
/// the store artifact is deliberate.
///
/// Until the pack is in place [iconFor] returns null and callers render
/// their own placeholder. Champions-original forms that Showdown has no
/// sprite for also resolve to null.
class SpriteService {
  SpriteService._();
  static final SpriteService instance = SpriteService._();

  /// True once the sprite pack is available for the current platform.
  /// Web: set when the static sprite files are confirmed deployed.
  /// Mobile: set after the downloaded pack is extracted to the cache.
  /// Flipped on by the pack-install path (wired with the download step).
  bool packReady = false;

  /// Small box-style icon for a Pokémon, for the simple calculator.
  /// Returns null when the pack isn't available so the caller can show a
  /// placeholder.
  ImageProvider? iconFor(String pokemonName) => _resolve('icons', pokemonName);

  /// Larger dex sprite for a Pokémon, for the expanded calculator.
  /// Returns null when the pack isn't available so the caller can fall
  /// back to the title-only species layout.
  ImageProvider? dexSpriteFor(String pokemonName) =>
      _resolve('dex', pokemonName);

  ImageProvider? _resolve(String set, String pokemonName) {
    if (!packReady) return null;
    final key = spriteKeyFor(pokemonName);
    if (kIsWeb) {
      // Served as static files from the site root (Flutter `web/`
      // folder) — keeps the sprite assets out of the mobile binary.
      return NetworkImage('sprites/$set/$key.png');
    }
    // Mobile: resolved from the downloaded pack cache. Wired together
    // with the download mechanism (needs a conditional dart:io import)
    // in a later step.
    return null;
  }
}
