import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/battle_pokemon.dart';

class SampleStorage {
  static const _key = 'pokemon_samples';

  static Future<List<({String name, BattlePokemonState state})>> loadSamples() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null) return [];
      final list = jsonDecode(json) as List;
      return list.map((entry) {
        final map = entry as Map<String, dynamic>;
        return (
          name: map['name'] as String,
          state: BattlePokemonState.fromJson(map['state'] as Map<String, dynamic>),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSample(String name, BattlePokemonState state) async {
    final samples = await loadSamples();
    final list = samples.map((s) => {
      'name': s.name,
      'state': s.state.toJson(),
    }).toList();
    list.add({
      'name': name,
      'state': state.toJson(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<void> deleteSample(int index) async {
    final samples = await loadSamples();
    if (index < 0 || index >= samples.length) return;
    final list = samples.map((s) => {
      'name': s.name,
      'state': s.state.toJson(),
    }).toList();
    list.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }
}
