import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pokemon.dart';

const _allFiles = [
  'assets/pokemon/gen1.json',
  'assets/pokemon/gen2.json',
  'assets/pokemon/gen3.json',
  'assets/pokemon/gen4.json',
  'assets/pokemon/gen5.json',
  'assets/pokemon/gen6.json',
  'assets/pokemon/gen7.json',
  'assets/pokemon/gen8.json',
  'assets/pokemon/gen9.json',
  'assets/pokemon/mega.json',
  'assets/pokemon/alola.json',
  'assets/pokemon/galar.json',
  'assets/pokemon/hisui.json',
  'assets/pokemon/paldea.json',
  'assets/pokemon/forms.json',
];

List<Pokemon>? _cache;
Set<String>? _megaStoneIds;
Future<List<Pokemon>>? _loading;

/// `requiredItem` → the form that item produces, for every entry that
/// declares a [Pokemon.formChange] (mega / primal / fixed). Built once
/// in [_doLoad]. Mega Rayquaza has no stone and is absent.
Map<String, Pokemon>? _formByItem;

/// base species name → the forms it can reach via an item. A species
/// with two stones (Charizard, Absol, …) lists both.
Map<String, List<Pokemon>>? _formsByBase;

/// name → species, for callers that hold a name and need the entry.
/// Empty until [loadPokedex] finishes.
Map<String, Pokemon>? _byName;

/// The species entry called [name], or null when the dex hasn't loaded
/// or no such name exists.
Pokemon? pokedexByName(String name) => _byName?[name];

/// Whether [loadPokedex] has finished. The form-item lookups below all
/// answer "not a form item" before that, which callers must not
/// mistake for a real answer — see `isUnremovableItemFor`.
bool get isPokedexLoaded => _cache != null;

/// Set of item IDs that force Mega Evolution (any `requiredItem` on a
/// Mega form). Populated during [loadPokedex]. Returns empty set until
/// the pokedex has loaded.
Set<String> megaStoneItemIds() => _megaStoneIds ?? const {};

/// The form [stoneId] produces, regardless of who holds it — e.g.
/// `charizardite-x` → Mega Charizard X, `red-orb` → Primal Groudon,
/// `wellspring-mask` → Ogerpon (Wellspring Mask). Null for ordinary
/// items. Data-driven, so Champions-era stones that break the old
/// `endsWith('ite')` heuristic (`absolite-z`) resolve correctly.
Pokemon? formChangeForStone(String? stoneId) =>
    stoneId == null ? null : _formByItem?[stoneId];

/// The mega/primal form [species] would turn into while holding
/// [heldItem], or null when the toggle doesn't apply.
///
/// Returns null when the item isn't a form item, when it belongs to a
/// different species (Charizard holding Gyaradosite), or when the form
/// is `fixed` — holding an Ogerpon mask *is* the form, so there is
/// nothing to toggle.
Pokemon? togglableMegaFor(String species, String? heldItem) {
  final form = formChangeForStone(heldItem);
  if (form == null) return null;
  if (form.formChange != 'mega' && form.formChange != 'primal') return null;
  return form.allBaseSpecies.contains(species) ? form : null;
}

/// Every form-item [species] can legally hold — both stones for
/// Charizard, both Absol stones (regular + Z), and so on. Empty for
/// species with no form item.
List<String> megaStonesForSpecies(String species) => [
      for (final f in _formsByBase?[species] ?? const <Pokemon>[])
        if (f.requiredItem != null) f.requiredItem!,
    ];

/// Whether [itemId] is *this* species' own form item — its Mega Stone,
/// Primal orb, or held-forme item.
///
/// This is the ownership test the Knock Off rule needs: only the
/// rightful holder keeps the item. A Charizard holding Gyaradosite is
/// knocked off normally, and Zamazenta cannot claim the Rusted Sword.
bool isOwnFormItem(String species, String? itemId) {
  final form = formChangeForStone(itemId);
  return form != null && form.allBaseSpecies.contains(species);
}

/// Loads all Pokemon data from assets/pokemon/*.json (cached after first load).
/// Uses parallel loading for faster startup.
Future<List<Pokemon>> loadPokedex() {
  if (_cache != null) return Future.value(_cache!);
  return _loading ??= _doLoad();
}

Future<List<Pokemon>> _doLoad() async {
  // Load all files in parallel
  final futures = _allFiles.map((file) async {
    final jsonString = await rootBundle.loadString(file);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList.map((e) => Pokemon.fromJson(e as Map<String, dynamic>)).toList();
  });

  final results = await Future.wait(futures);
  final pokedex = results.expand((list) => list).toList();

  _cache = pokedex;
  _megaStoneIds = {
    for (final p in pokedex)
      if (p.requiredItem != null) p.requiredItem!,
  };
  // Form-item indexes. Only entries that declare a formChange take
  // part, so an ordinary held item never looks like a form item.
  final byItem = <String, Pokemon>{};
  final byBase = <String, List<Pokemon>>{};
  for (final p in pokedex) {
    if (p.formChange == null) continue;
    final item = p.requiredItem;
    if (item != null) byItem[item] = p;
    for (final base in p.allBaseSpecies) {
      (byBase[base] ??= <Pokemon>[]).add(p);
    }
  }
  _formByItem = byItem;
  _formsByBase = byBase;
  _byName = {for (final p in pokedex) p.name: p};
  return pokedex;
}

/// Call this early (e.g. in main or initState) to start loading in background.
void preloadPokedex() {
  loadPokedex();
}
