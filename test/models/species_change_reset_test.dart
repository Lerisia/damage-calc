import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/status.dart';

/// Picking a new species means a fresh Pokémon on the field: full HP,
/// no stat stages, no status, no charge. Side conditions (screens,
/// Tailwind) belong to the side, not the Pokémon, and stay. A form or
/// Mega toggle is the same Pokémon mid-battle and keeps everything.
void main() {
  late final Map<String, Pokemon> byName;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    byName = {for (final p in await loadPokedex()) p.name: p};
  });

  BattlePokemonState battered() {
    final s = BattlePokemonState()..applyPokemon(byName['Garchomp']!);
    s.hpPercent = 40;
    s.rank = const Rank(attack: 2, speed: -1);
    s.status = StatusCondition.burn;
    s.charge = true;
    s.reflect = true;
    s.tailwind = true;
    return s;
  }

  test('a new species enters fresh', () {
    final s = battered()..applyPokemon(byName['Hippowdon']!);
    expect(s.hpPercent, 100);
    expect(s.rank, const Rank());
    expect(s.status, StatusCondition.none);
    expect(s.charge, isFalse);
  });

  test('side conditions survive a species change', () {
    final s = battered()..applyPokemon(byName['Hippowdon']!);
    expect(s.reflect, isTrue);
    expect(s.tailwind, isTrue);
  });

  test('a form toggle keeps HP, stages and status', () {
    final s = BattlePokemonState()..applyPokemon(byName['Aegislash']!);
    s.hpPercent = 55;
    s.rank = const Rank(attack: 1);
    s.status = StatusCondition.paralysis;
    expect(s.toggleForm(), isTrue);
    expect(s.hpPercent, 55);
    expect(s.rank, const Rank(attack: 1));
    expect(s.status, StatusCondition.paralysis);
  });
}
