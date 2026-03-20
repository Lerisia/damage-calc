import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pokemon.dart';

const _genFiles = [
  'assets/pokemon/gen1.json',
  'assets/pokemon/gen2.json',
  'assets/pokemon/gen3.json',
  'assets/pokemon/gen4.json',
  'assets/pokemon/gen5.json',
  'assets/pokemon/gen6.json',
  'assets/pokemon/gen7.json',
  'assets/pokemon/gen8.json',
  'assets/pokemon/gen9.json',
];

/// Loads all Pokemon data from assets/pokemon/gen*.json
Future<Map<int, Pokemon>> loadPokedex() async {
  final Map<int, Pokemon> pokedex = {};

  for (final file in _genFiles) {
    final jsonString = await rootBundle.loadString(file);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    for (final entry in jsonList) {
      final pokemon = Pokemon.fromJson(entry as Map<String, dynamic>);
      pokedex[pokemon.dexNumber] = pokemon;
    }
  }

  return pokedex;
}
