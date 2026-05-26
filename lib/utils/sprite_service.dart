import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sprite_override_manager.dart';
import 'sprite_pack_manager.dart';

/// The three sprite styles we support, mirroring Pokémon Showdown's
/// canonical paths under `play.pokemonshowdown.com/sprites/`:
///
///  * [bw] — generation-5 Black/White pixel sprites (`/sprites/gen5/`).
///    Smogon's community Sprite Project filled in coverage for every
///    later-gen Pokémon in BW style, so this covers gen 1–9.
///  * [ani] — modern animated GIFs (`/sprites/ani/`), all generations.
///  * [dex] — HOME-style 3D PNG models (`/sprites/dex/`), mostly all
///    generations (a few gen-8 box-legends are missing in HOME).
///
/// [hasMobilePack] gates whether the mobile import dialog shows
/// download / import controls for the style. Currently false for
/// [ani] because the damage-calc-sprite-pack workflow doesn't
/// publish ani.zip yet — the X/Y Sprite Project community hasn't
/// OK'd redistribution of their extended-coverage animated work.
enum SpriteStyle {
  bw('gen5', 'png', hasMobilePack: true),
  ani('ani', 'gif', hasMobilePack: false),
  dex('dex', 'png', hasMobilePack: true);

  /// Showdown CDN directory under `/sprites/`.
  final String dir;

  /// File extension (without the leading dot).
  final String ext;

  /// Whether damage-calc-sprite-pack publishes a downloadable ZIP
  /// for this style. Web ignores this — the web build streams from
  /// Showdown's CDN directly regardless.
  final bool hasMobilePack;

  const SpriteStyle(this.dir, this.ext, {required this.hasMobilePack});
}

/// Per-species sprite-key overrides — used when the [spriteKeyFor]
/// heuristic produces a key that doesn't exist on Showdown's CDN. Each
/// entry maps the calc's English display name to the actual Showdown
/// slug (verified by HEAD-testing the URL).
const Map<String, String> _spriteKeyOverrides = {
  // 'Crowned' forms drop the weapon suffix on Showdown.
  'Zacian (Crowned Sword)': 'zacian-crowned',
  'Zamazenta (Crowned Shield)': 'zamazenta-crowned',
  // Minior's default sprite is just 'minior' (meteor form is
  // separate). Our "(Core Form)" entry refers to the core variant
  // but Showdown serves a single default sprite for both.
  'Minior (Core Form)': 'minior',
};

/// Words that mean "this is a forme" and carry no info themselves —
/// stripped when building a slug from a parenthesised form name.
const Set<String> _noiseFormWords = {
  'Forme', 'Form', 'Mode', 'Mask', 'Cloak',
  'Size', 'Style', 'Face', 'Flower',
};

const Map<String, String> _regionalSlugs = {
  'Alolan': 'alola',
  'Hisuian': 'hisui',
  'Galarian': 'galar',
  'Paldean': 'paldea',
};

String _stripNonAlnum(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Strip diacritics by hand for the only Pokémon names that carry
/// them. Dart core doesn't expose Unicode NFD without a package and
/// the set of affected names is tiny (just Flabébé and its line).
String _stripDiacritics(String s) =>
    s.replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e');

/// The base species name for a form/Mega/regional variant, used as
/// a fallback when the form's own sprite isn't on Showdown's CDN —
/// e.g., new Legends Z-A Megas Showdown hasn't gotten community
/// sprites for yet. Returns null when no fallback is meaningful
/// (already a base species).
///
/// Examples:
///  * `Mega Baxcalibur` → `Baxcalibur`
///  * `Mega Charizard X` → `Charizard`
///  * `Primal Groudon` → `Groudon`
///  * `Alolan Raichu` → `Raichu`
///  * `Ice Rider Calyrex` → `Calyrex`
///  * `Heat Rotom` → `Rotom`
///  * `Black Kyurem` → `Kyurem`
///  * `Deoxys (Attack Forme)` → `Deoxys`
///  * `Galarian Darmanitan (Zen Mode)` → `Darmanitan`
///  * `Pikachu` → null (already base)
String? baseSpeciesName(String pokemonName) {
  final n = pokemonName.trim();

  // Mega X / Mega X Y|Z / Primal X / Ultra X — strip the prefix word.
  final megaXY = RegExp(r'^Mega (\w+) [XYZ]$').firstMatch(n);
  if (megaXY != null) return megaXY.group(1);
  final mega = RegExp(r'^Mega (\w+)$').firstMatch(n);
  if (mega != null) return mega.group(1);
  final primal = RegExp(r'^Primal (\w+)$').firstMatch(n);
  if (primal != null) return primal.group(1);
  if (n == 'Ultra Necrozma') return 'Necrozma';
  if (n == 'Hoopa Unbound') return 'Hoopa';

  // Compound forms whose first word(s) qualify the species at the end.
  if (n == 'Black Kyurem' || n == 'White Kyurem') return 'Kyurem';
  if (n == 'Dawn Wings Necrozma' || n == 'Dusk Mane Necrozma') {
    return 'Necrozma';
  }
  if (n == 'Ice Rider Calyrex' || n == 'Shadow Rider Calyrex') {
    return 'Calyrex';
  }

  // Rotom appliances put the form word first.
  final rotom = RegExp(r'^(Heat|Wash|Frost|Fan|Mow) Rotom$').firstMatch(n);
  if (rotom != null) return 'Rotom';

  // Regional variants: "Alolan Raichu" → "Raichu",
  // "Galarian Darmanitan (Zen Mode)" → "Darmanitan".
  for (final prefix in _regionalSlugs.keys) {
    if (n.startsWith('$prefix ')) {
      final rest = n.substring(prefix.length + 1);
      final nested = RegExp(r'^(\w+) \(').firstMatch(rest);
      return nested != null ? nested.group(1) : rest;
    }
  }

  // Parenthesised forme: "Tornadus (Therian Forme)" → "Tornadus".
  // Allow dots/hyphens/apostrophes in the species part (Mr. Mime,
  // Farfetch'd, Ho-Oh). Double-quoted raw string lets the apostrophe
  // sit inside the character class unescaped.
  final paren = RegExp(r"^([\w\.\-' ]+?) \([^)]+\)$").firstMatch(n);
  if (paren != null) return paren.group(1)!.trim();

  // Already a base species — no fallback.
  return null;
}

/// Convert an English Pokémon display name to the slug used by
/// Pokémon Showdown's sprite CDN.
///
/// Showdown's convention:
///  * Base species: lowercase, all non-alphanumeric stripped
///    (`Mr. Mime` → `mrmime`, `Ho-Oh` → `hooh`, `Farfetch'd` → `farfetchd`).
///  * Forms: `<species>-<form>` with a single hyphen and the form
///    suffix itself stripped of separators
///    (`Mega Charizard X` → `charizard-megax`,
///     `Alolan Raichu` → `raichu-alola`,
///     `Deoxys (Attack Forme)` → `deoxys-attack`).
///  * Special slugs collected in [_spriteKeyOverrides] for the few
///    names whose Showdown spelling doesn't fall out of the rules.
///
/// Empirically verified to resolve to a real sprite for 1210/1239
/// distinct names in our pokedex (the remaining ~24 are
/// Champions-original Mega forms that Showdown obviously doesn't
/// have — they fall through to the widget's pokéball placeholder).
String spriteKeyFor(String pokemonName) {
  if (_spriteKeyOverrides.containsKey(pokemonName)) {
    return _spriteKeyOverrides[pokemonName]!;
  }

  final n = _stripDiacritics(pokemonName)
      .replaceAll('♀', 'f')
      .replaceAll('♂', 'm');

  // Mega X (X|Y) — e.g., "Mega Charizard X" → "charizard-megax".
  final megaXY = RegExp(r'^Mega (\w+) ([XY])$').firstMatch(n);
  if (megaXY != null) {
    return '${_stripNonAlnum(megaXY.group(1)!)}-mega'
        '${megaXY.group(2)!.toLowerCase()}';
  }
  // Mega X — e.g., "Mega Garchomp" → "garchomp-mega".
  final mega = RegExp(r'^Mega (\w+)$').firstMatch(n);
  if (mega != null) return '${_stripNonAlnum(mega.group(1)!)}-mega';
  // Primal X — Groudon, Kyogre.
  final primal = RegExp(r'^Primal (\w+)$').firstMatch(n);
  if (primal != null) return '${_stripNonAlnum(primal.group(1)!)}-primal';

  // One-off prefix forms whose names don't share a common pattern.
  switch (n) {
    case 'Ultra Necrozma':
      return 'necrozma-ultra';
    case 'Hoopa Unbound':
      return 'hoopa-unbound';
    case 'Dawn Wings Necrozma':
      return 'necrozma-dawnwings';
    case 'Dusk Mane Necrozma':
      return 'necrozma-duskmane';
    case 'Ice Rider Calyrex':
      return 'calyrex-ice';
    case 'Shadow Rider Calyrex':
      return 'calyrex-shadow';
    case 'Black Kyurem':
      return 'kyurem-black';
    case 'White Kyurem':
      return 'kyurem-white';
  }

  // Rotom appliance forms — "Heat Rotom" → "rotom-heat".
  final rotom = RegExp(r'^(Heat|Wash|Frost|Fan|Mow) Rotom$').firstMatch(n);
  if (rotom != null) return 'rotom-${rotom.group(1)!.toLowerCase()}';

  // Regional variants. "Galarian Darmanitan (Zen Mode)" needs to nest
  // — Showdown collapses it to "darmanitan-galarzen".
  for (final entry in _regionalSlugs.entries) {
    if (n.startsWith('${entry.key} ')) {
      final rest = n.substring(entry.key.length + 1);
      final nested = RegExp(r'^(\w+) \(([^)]+)\)$').firstMatch(rest);
      if (nested != null) {
        final species = _stripNonAlnum(nested.group(1)!);
        final formeWord =
            _stripNonAlnum(nested.group(2)!.split(' ').first);
        return '$species-${entry.value}$formeWord';
      }
      return '${_stripNonAlnum(rest)}-${entry.value}';
    }
  }

  // Parenthesised forme — "Tornadus (Therian Forme)" → "tornadus-therian",
  // "Toxtricity (Low Key Form)" → "toxtricity-lowkey",
  // "Indeedee (Female)" → "indeedee-f", "(Male)" → just the base.
  final paren = RegExp(r'^(.+?) \(([^)]+)\)$').firstMatch(n);
  if (paren != null) {
    final species = _stripNonAlnum(paren.group(1)!);
    final inner = paren.group(2)!;
    if (inner == 'Female') return '$species-f';
    if (inner == 'Male') return species;
    final meaningful = inner
        .split(' ')
        .where((w) => !_noiseFormWords.contains(w))
        .toList();
    final slug = _stripNonAlnum(
        meaningful.isEmpty ? inner : meaningful.join(''));
    return '$species-$slug';
  }

  return _stripNonAlnum(n);
}

/// Resolves Pokémon sprite images for the UI.
///
/// **Web** loads each sprite lazily from Pokémon Showdown's CDN
/// (`play.pokemonshowdown.com/sprites/...`) — the browser caches it
/// the second time it's needed, and the calc never hosts the IP
/// itself. The user's selected [SpriteStyle] determines which
/// Showdown directory is read.
///
/// **Mobile** intentionally returns null for v1 of this feature —
/// the app's offline-first design rules out streaming sprites at
/// runtime, and we haven't yet decided where the import-pack should
/// be hosted. Mobile callers therefore always fall through to the
/// pokéball placeholder. The sprite slot is still rendered so the UI
/// shape stays consistent across platforms.
class SpriteService extends ChangeNotifier {
  SpriteService._();
  static final SpriteService instance = SpriteService._();

  static const _prefsKey = 'sprite_style';

  /// User's currently selected sprite style. Defaults to [SpriteStyle.dex]
  /// — HOME 3D is the only style with full gen 1–9 coverage right
  /// now (BW pack scope is held to gen1-5 until Smogon's X/Y Sprite
  /// Project OKs redistribution), so it's the better out-of-box
  /// experience for users who haven't picked anything yet.
  SpriteStyle _style = SpriteStyle.dex;
  SpriteStyle get style => _style;

  /// Update the active style and persist the choice. Notifies listeners
  /// so [PokemonSprite] widgets across the app rebuild on the new style.
  Future<void> setStyle(SpriteStyle next) async {
    if (_style == next) return;
    _style = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next.name);
  }

  /// Hydrate the persisted style preference at app startup. Called
  /// from [main]'s preload alongside the other controllers'
  /// `load()`s. Safe to call before any UI binds, and idempotent.
  ///
  /// On mobile we additionally guard against landing on a style whose
  /// pack the app currently can't ship (hasMobilePack == false) —
  /// otherwise a user who picked that style on the web build and
  /// later opens the mobile app would be silently stuck on
  /// pokéballs with no UI affordance to switch (the picker row is
  /// hidden on mobile for such styles).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null) return;
    for (final s in SpriteStyle.values) {
      if (s.name == saved) {
        _style = s;
        break;
      }
    }
    if (!kIsWeb && !_style.hasMobilePack) {
      _style = SpriteStyle.dex;
    }
  }

  /// ImageProvider for a Pokémon's sprite in the current [style], or
  /// null when neither a user override, the web fetch, nor a local
  /// pack covers it. Per-Pokémon overrides win across all three
  /// styles — the user's custom image always overrides the bundled
  /// art regardless of which style they've picked.
  ImageProvider? spriteFor(String pokemonName, {SpriteStyle? style}) {
    final s = style ?? this.style;
    final key = spriteKeyFor(pokemonName);
    // Overrides win on every platform — the user picking a custom
    // image trumps whichever style / pack source we'd otherwise hit.
    final override = SpriteOverrideManager.instance
        .overrideFor(pokemonName, OverrideChannel.large);
    if (override != null) return override;
    if (kIsWeb) {
      // jsDelivr-fronted GitHub raw — Showdown's CDN doesn't send
      // access-control-allow-origin, which CanvasKit's image decode
      // pipeline requires. Our pack repo's extracted tree at
      // sprites/<style>/ is published with that header automatically.
      // Same scope cap as the mobile pack (bw = gen1-5, dex = full)
      // — anything outside falls through the fallback chain → base
      // species → pokéball.
      final url = 'https://cdn.jsdelivr.net/gh/Lerisia/damage-calc-sprite-pack@main/'
          'sprites/${s.name}/$key.${s.ext}';
      return NetworkImage(url);
    }
    if (!SpritePackManager.instance.isInstalled(s)) return null;
    final dir = SpritePackManager.instance.cacheDirFor(s);
    if (dir == null) return null;
    final file = File('$dir/$key.${s.ext}');
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  /// Fallback sprite for the base species when the form's sprite
  /// isn't available — e.g., Legends Z-A Megas Showdown's community
  /// hasn't drawn yet (`Mega Baxcalibur` → `Baxcalibur`), or
  /// Champions-original Z-suffix Megas that will never exist on
  /// Showdown (`Mega Absol Z` → `Absol`). Returns null when there's
  /// no meaningful fallback (the input is already a base species, or
  /// we're on mobile).
  ImageProvider? fallbackSpriteFor(String pokemonName, {SpriteStyle? style}) {
    final base = baseSpeciesName(pokemonName);
    if (base == null) return null;
    return spriteFor(base, style: style);
  }

  /// Box icon (40×30) for compact placements (dex list / simple
  /// calc row). Reads from the icons cache populated by any
  /// imported style pack (each ZIP bundles an icons/ subdir).
  /// Returns null on web (no sheet-clipping path implemented; the
  /// regular style sprite scales down instead) and when no pack is
  /// installed.
  ImageProvider? iconFor(String pokemonName) {
    final key = spriteKeyFor(pokemonName);
    final override = SpriteOverrideManager.instance
        .overrideFor(pokemonName, OverrideChannel.small);
    if (override != null) return override;
    if (kIsWeb) {
      return NetworkImage(
          'https://cdn.jsdelivr.net/gh/Lerisia/damage-calc-sprite-pack@main/'
          'sprites/icons/$key.png');
    }
    if (!SpritePackManager.instance.iconsInstalled) return null;
    final dir = SpritePackManager.instance.iconsCacheDir;
    if (dir == null) return null;
    final file = File('$dir/$key.png');
    if (!file.existsSync()) return null;
    return FileImage(file);
  }
}
