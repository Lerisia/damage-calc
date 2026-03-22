import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/battle_pokemon.dart';

class SampleStorage {
  static Future<String> get _path async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/pokemon_samples.json';
  }

  static Future<List<({String name, BattlePokemonState state})>> loadSamples() async {
    try {
      final file = File(await _path);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
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
    final file = File(await _path);
    await file.writeAsString(jsonEncode(list));
  }

  static Future<void> deleteSample(int index) async {
    final samples = await loadSamples();
    if (index < 0 || index >= samples.length) return;
    final list = samples.map((s) => {
      'name': s.name,
      'state': s.state.toJson(),
    }).toList();
    list.removeAt(index);
    final file = File(await _path);
    await file.writeAsString(jsonEncode(list));
  }
}
