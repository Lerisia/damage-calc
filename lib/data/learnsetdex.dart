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

  // Collect form-specific moves
  final result = <String>{};
  final formMoves = learnsets[id];
  if (formMoves != null) result.addAll(formMoves);

  // Merge with base form moves (form may only have exclusive moves)
  final baseId = _baseFormId(name);
  if (baseId != null && baseId != id) {
    final baseMoves = learnsets[baseId];
    if (baseMoves != null) result.addAll(baseMoves);
  }

  // If no form-specific entry, try base ID directly
  if (result.isEmpty) {
    final baseMoves = learnsets[_normalize(name)];
    if (baseMoves != null) return baseMoves.toSet();
  }

  return result;
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
  // Parenthesized forms with distinct Showdown learnsets
  const parenthesizedForms = {
    'Urshifu (Rapid Strike Style)': 'urshifurapidstrike',
    'Lycanroc (Midnight Form)': 'lycanrocmidnight',
    'Lycanroc (Dusk Form)': 'lycanrocdusk',
    'Indeedee (Female)': 'indeedeef',
    'Meowstic (Female)': 'meowsticf',
    'Basculegion (Female)': 'basculegionf',
    'Oinkologne (Female)': 'oinkolognef',
    'Toxtricity (Low Key Form)': 'toxtricitylowkey',
    'Wormadam (Sandy Cloak)': 'wormadamsandy',
    'Wormadam (Trash Cloak)': 'wormadamtrash',
    'Shaymin (Sky Forme)': 'shayminsky',
    'Giratina (Origin Forme)': 'giratinaorigin',
    'Tornadus (Therian Forme)': 'tornadustherian',
    'Thundurus (Therian Forme)': 'thundurustherian',
    'Landorus (Therian Forme)': 'landorustherian',
    'Enamorus (Therian Forme)': 'enamorustherian',
  };
  if (parenthesizedForms.containsKey(name)) return parenthesizedForms[name];

  // "Deoxys (Attack Forme)" → "deoxys" (base form fallback)
  if (name.contains(' (')) {
    return _normalize(name.split(' (')[0]);
  }
  // Prefixed forms: map to Showdown form-specific ID first, base form as fallback
  const prefixedForm = {
    'Heat Rotom': 'rotomheat', 'Wash Rotom': 'rotomwash',
    'Frost Rotom': 'rotomfrost', 'Fan Rotom': 'rotomfan', 'Mow Rotom': 'rotommow',
    'Black Kyurem': 'kyuremblack', 'White Kyurem': 'kyuremwhite',
    'Primal Kyogre': 'kyogreprimal', 'Primal Groudon': 'groudonprimal',
    'Ultra Necrozma': 'necrozmaultra',
    'Dusk Mane Necrozma': 'necrozmaduskmane', 'Dawn Wings Necrozma': 'necrozmadawnwings',
    'Ice Rider Calyrex': 'calyrexice', 'Shadow Rider Calyrex': 'calyrexshadow',
    'Hoopa Unbound': 'hoopaunbound',
  };
  if (prefixedForm.containsKey(name)) return prefixedForm[name];
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
