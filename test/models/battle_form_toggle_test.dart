import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/stats.dart';

/// In-battle form changes share the Mega toggle: same slot, same
/// contract — the build the user typed survives, only the species and
/// what follows from it change.
void main() {
  late final Map<String, Pokemon> byName;
  late final Map<String, dynamic> moves;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dex = await loadPokedex();
    byName = {for (final p in dex) p.name: p};
    moves = await loadMovedex();
  });

  BattlePokemonState build(String species, {String? item}) {
    final s = BattlePokemonState()..applyPokemon(byName[species]!);
    s.level = 50;
    s.nature = NatureProfile.fromNature(Nature.adamant);
    s.ev = const Stats(hp: 4, attack: 252, defense: 0, spAttack: 0, spDefense: 0, speed: 252);
    s.moves[0] = moves['Shadow Sneak'];
    s.moves[1] = moves['Protect'];
    if (item != null) s.selectedItem = item;
    return s;
  }

  test('battleFormFor maps the three Champions pairs', () {
    expect(battleFormFor('Aegislash')?.name, 'Aegislash (Blade Forme)');
    expect(battleFormFor('Palafin')?.name, 'Palafin (Hero Form)');
    expect(battleFormFor('Morpeko')?.name, 'Morpeko (Hangry Mode)');
    expect(battleFormFor('Garchomp'), isNull);
  });

  test('Aegislash ↔ Blade Forme keeps the build and swaps the stats', () {
    final s = build('Aegislash', item: 'leftovers');
    expect(s.canToggleForm, isTrue);
    expect(s.canToggleMegaForm, isFalse, reason: 'no stone, so the slot is the form change');
    final baseAtk = s.baseStats.attack;
    expect(s.toggleForm(), isTrue);
    expect(s.pokemonName, 'Aegislash (Blade Forme)');
    expect(s.isBattleForm, isTrue);
    expect(s.baseStats.attack, greaterThan(baseAtk));
    expect(s.moves[0]?.name, 'Shadow Sneak');
    expect(s.ev.attack, 252);
    expect(s.nature.up, NatureStat.atk);
    expect(s.selectedItem, 'leftovers');
    expect(s.toggleForm(), isTrue);
    expect(s.pokemonName, 'Aegislash');
    expect(s.isBattleForm, isFalse);
  });

  test('Palafin and Morpeko toggle both ways', () {
    for (final (base, form) in [('Palafin', 'Palafin (Hero Form)'), ('Morpeko', 'Morpeko (Hangry Mode)')]) {
      final s = BattlePokemonState()..applyPokemon(byName[base]!);
      expect(s.toggleForm(), isTrue); expect(s.pokemonName, form);
      expect(s.toggleForm(), isTrue); expect(s.pokemonName, base);
    }
  });

  test('a Mega Stone still wins the slot', () {
    final s = BattlePokemonState()..applyPokemon(byName['Charizard']!);
    s.selectedItem = 'charizardite-x';
    expect(s.canToggleMegaForm, isTrue);
    expect(s.formToggleTarget?.name, 'Mega Charizard X');
  });

  test('species with no form have no toggle', () {
    final s = BattlePokemonState()..applyPokemon(byName['Garchomp']!);
    expect(s.canToggleForm, isFalse);
    expect(s.toggleForm(), isFalse);
  });
}
