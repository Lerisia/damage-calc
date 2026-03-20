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

/// Loads all Pokemon data from assets/pokemon/*.json
Future<List<Pokemon>> loadPokedex() async {
  final List<Pokemon> pokedex = [];

  for (final file in _allFiles) {
    final jsonString = await rootBundle.loadString(file);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    for (final entry in jsonList) {
      pokedex.add(Pokemon.fromJson(entry as Map<String, dynamic>));
    }
  }

  return pokedex;
}
