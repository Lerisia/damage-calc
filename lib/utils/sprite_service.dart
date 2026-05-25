import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// The three sprite styles we support, mirroring Pokémon Showdown's
/// canonical paths under `play.pokemonshowdown.com/sprites/`:
///
///  * [bw] — generation-5 Black/White pixel sprites (`/sprites/gen5/`).
///    Smogon's community Sprite Project filled in coverage for every
///    later-gen Pokémon in BW style, so this covers gen 1–9.
///  * [ani] — modern animated GIFs (`/sprites/ani/`), all generations.
///  * [dex] — HOME-style 3D PNG models (`/sprites/dex/`), mostly all
///    generations (a few gen-8 box-legends are missing in HOME).
enum SpriteStyle {
  bw('gen5', 'png'),
  ani('ani', 'gif'),
  dex('dex', 'png');

  /// Showdown CDN directory under `/sprites/`.
  final String dir;

  /// File extension (without the leading dot).
  final String ext;

  const SpriteStyle(this.dir, this.ext);
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
class SpriteService {
  SpriteService._();
  static final SpriteService instance = SpriteService._();

  /// User's currently selected sprite style. Defaults to [SpriteStyle.bw]
  /// — the BW pixel set matches the calc's retro/competitive
  /// aesthetic and is the smallest payload on the wire.
  SpriteStyle style = SpriteStyle.bw;

  /// ImageProvider for a Pokémon's sprite in the current [style], or
  /// null when the platform has no sprite source wired up (mobile v1).
  ImageProvider? spriteFor(String pokemonName, {SpriteStyle? style}) {
    final s = style ?? this.style;
    if (!kIsWeb) {
      // Mobile: offline-first design. Sprite pack import is deferred
      // to a later feature pass — until then, mobile shows a pokéball
      // placeholder so the layout still announces "this is where the
      // sprite belongs".
      return null;
    }
    final key = spriteKeyFor(pokemonName);
    final url = 'https://play.pokemonshowdown.com/sprites/${s.dir}/'
        '$key.${s.ext}';
    return NetworkImage(url);
  }
}
