import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/poke_paste.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/data/sample_storage.dart' show StoredSample;
import 'package:damage_calc/models/battle_pokemon.dart';

/// Exhaustive guard: EVERY visible species must survive an encode →
/// decode round-trip, including the nickname path (name != species,
/// which is where the parenthesised-form vs nickname ambiguity bites).
void main() {
  test('every visible species round-trips through PokePaste', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moves = await loadMovedex();
    final items = await loadItemdex();
    final byName = {for (final p in pokedex) p.name: p};
    final displayToId = {
      for (final e in items.entries)
        if (e.value.nameEn != null) e.value.nameEn!.toLowerCase(): e.key,
    };
    final fails = <String>[];
    for (final p in pokedex) {
      if (p.hidden) continue;
      final st = BattlePokemonState()..applyPokemon(p);
      final code = PokePaste.encodeSample(
          StoredSample(id: '', name: 'Nick', state: st), itemsById: items);
      try {
        final d = PokePaste.decodeSample(code,
            pokemonByName: byName,
            itemDisplayToId: displayToId,
            moveByName: moves);
        if (d.state.pokemonName != p.name) {
          fails.add('${p.name} -> ${d.state.pokemonName}');
        }
      } catch (e) {
        fails.add('${p.name}: ${e.toString().split("\n").first}');
      }
    }
    expect(fails, isEmpty, reason: 'round-trip failed for: ${fails.take(20)}');
  });
}
