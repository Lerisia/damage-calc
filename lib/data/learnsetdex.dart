import 'dart:convert';
import 'package:flutter/services.dart';

/// Cached learnset data: { showdownPokemonId: [showdownMoveId, ...] }
Map<String, List<String>>? _learnsetCache;

/// Cached regional form map: { "dexNumber_region": showdownPokemonId }
Map<String, String>? _regionalCache;

/// Loads learnset data (cached after first call).
Future<Map<String, List<String>>> loadLearnsets() async {
  if (_learnsetCache != null) return _learnsetCache!;
  final raw = await rootBundle.loadString('assets/learnsets.json');
  final parsed = json.decode(raw) as Map<String, dynamic>;

  final learnsets = <String, List<String>>{};
  Map<String, String>? regional;

  for (final entry in parsed.entries) {
    if (entry.key == '_regional') {
      regional = (entry.value as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
    } else {
      learnsets[entry.key] = (entry.value as List).cast<String>();
    }
  }

  _learnsetCache = learnsets;
  _regionalCache = regional ?? {};
  return _learnsetCache!;
}

/// Returns the set of learnable Showdown move IDs for a Pokemon.
///
/// [name]: BattlePokemonState.pokemonName
/// [nameKo]: BattlePokemonState.pokemonNameKo (needed for regional forms)
/// [dexNumber]: for resolving regional forms (e.g. Alolan Raichu = dex 26)
Future<Set<String>> getLearnableMoves(String name, {
  String? nameKo,
  int? dexNumber,
}) async {
  final learnsets = await loadLearnsets();
  final id = toShowdownPokemonId(name, nameKo: nameKo, dexNumber: dexNumber);

  // Direct match
  final moves = learnsets[id];
  if (moves != null) return moves.toSet();

  // Base form fallback (Mega, alternate forms)
  final baseId = _baseFormId(name);
  if (baseId != null && baseId != id) {
    final baseMoves = learnsets[baseId];
    if (baseMoves != null) return baseMoves.toSet();
  }

  return {};
}

/// Resolve the Showdown ID for any Pokemon name format.
String toShowdownPokemonId(String name, {String? nameKo, int? dexNumber}) {
  // Special name mappings
  const specials = {
    'Nidoran♀': 'nidoranf',
    'Nidoran♂': 'nidoranm',
    'Flabébé': 'flabebe',
    'Mr. Mime': 'mrmime',
    'Mr. Rime': 'mrrime',
    'Mime Jr.': 'mimejr',
    "Farfetch'd": 'farfetchd',
    "Sirfetch'd": 'sirfetchd',
    'Type: Null': 'typenull',
  };
  if (specials.containsKey(name)) return specials[name]!;

  // Regional forms: use _regional map with dexNumber
  if (_isRegionalFormName(name) && dexNumber != null && _regionalCache != null) {
    final region = _detectRegion(name, nameKo);
    if (region != null) {
      final key = '${dexNumber}_$region';
      final sid = _regionalCache![key];
      if (sid != null) return sid;
    }
  }

  // Mega → base form
  if (name.startsWith('Mega ')) {
    return _baseFormId(name) ?? _normalize(name);
  }

  // Alternate form suffix → base (aegislash-blade → aegislash)
  if (name.contains('-')) {
    return _baseFormId(name) ?? _normalize(name);
  }

  return _normalize(name);
}

/// Detect region from name or nameKo.
String? _detectRegion(String name, String? nameKo) {
  if (name.contains('Alolan') || (nameKo != null && nameKo.contains('알로라'))) return 'alola';
  if (name.contains('Galarian') || (nameKo != null && nameKo.contains('가라르'))) return 'galar';
  if (name.contains('Hisuian') || (nameKo != null && nameKo.contains('히스이'))) return 'hisui';
  if (name.contains('Paldean') || (nameKo != null && nameKo.contains('팔데아'))) return 'paldea';
  return null;
}

bool _isRegionalFormName(String name) {
  return name.startsWith('Alolan ') || name.startsWith('Galarian ') ||
         name.startsWith('Hisuian ') || name.startsWith('Paldean ');
}

/// Extract base form ID from Mega/alternate form names.
String? _baseFormId(String name) {
  if (name.startsWith('Mega ')) {
    var base = name.substring(5);
    for (final suffix in [' X', ' Y', ' Z']) {
      if (base.endsWith(suffix)) {
        base = base.substring(0, base.length - suffix.length);
        break;
      }
    }
    return _normalize(base);
  }
  // "Deoxys (Attack Forme)" → "deoxys"
  if (name.contains(' (')) {
    return _normalize(name.split(' (')[0]);
  }
  // Prefixed forms: "Heat Rotom" → "rotom", "Black Kyurem" → "kyurem", etc.
  const prefixed = {
    'Heat Rotom': 'rotom', 'Wash Rotom': 'rotom', 'Frost Rotom': 'rotom',
    'Fan Rotom': 'rotom', 'Mow Rotom': 'rotom',
    'Black Kyurem': 'kyurem', 'White Kyurem': 'kyurem',
    'Primal Kyogre': 'kyogre', 'Primal Groudon': 'groudon',
    'Ultra Necrozma': 'necrozma',
    'Dusk Mane Necrozma': 'necrozma', 'Dawn Wings Necrozma': 'necrozma',
    'Ice Rider Calyrex': 'calyrex', 'Shadow Rider Calyrex': 'calyrex',
    'Hoopa Unbound': 'hoopa',
  };
  if (prefixed.containsKey(name)) return prefixed[name];
  if (name.contains('-')) {
    return _normalize(name.split('-')[0]);
  }
  return null;
}

/// Converts a display move name to Showdown move ID.
/// "Acid Spray" → "acidspray", "King's Shield" → "kingsshield"
String toShowdownMoveId(String name) {
  return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _normalize(String name) {
  return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
