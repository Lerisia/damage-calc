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
Future<List<Pokemon>>? _loading;

/// Maps requiredItem -> set of dexNumbers that use it.
/// Used to check if an item is unremovable for a specific Pokemon.
Map<String, Set<int>>? _requiredItemOwners;

/// Returns the requiredItem → dexNumber owners map (built on first call).
Map<String, Set<int>> getRequiredItemOwners() {
  if (_requiredItemOwners != null) return _requiredItemOwners!;
  if (_cache == null) return {};
  final map = <String, Set<int>>{};
  for (final p in _cache!) {
    if (p.requiredItem != null) {
      map.putIfAbsent(p.requiredItem!, () => {}).add(p.dexNumber);
    }
  }
  _requiredItemOwners = map;
  return map;
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
  return pokedex;
}

/// Call this early (e.g. in main or initState) to start loading in background.
void preloadPokedex() {
  loadPokedex();
}
