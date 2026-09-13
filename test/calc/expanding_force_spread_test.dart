import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/calc/damage_calculator.dart';

/// On Psychic Terrain a grounded user's Expanding Force hits both
/// opponents, and like every multi-target move it then takes the
/// 0.75× spread reduction (Showdown: 252–297 → 187–222 for the same
/// Indeedee vs Garchomp). A user report claimed it is exempt; it isn't
/// — but the calculator was treating it that way because the move
/// carries no `custom:spread` tag, its spread being conditional.
void main() {
  const ef = Move(name: 'Expanding Force', nameKo: '와이드포스', nameJa: 'ワイドフォース',
      type: PokemonType.psychic, category: MoveCategory.special, power: 80, accuracy: 100, pp: 10,
      tags: ['custom:terrain_boost_psychic']);
  BattlePokemonState indeedee({required bool spread}) => BattlePokemonState(
      pokemonName: 'Indeedee', type1: PokemonType.psychic, type2: PokemonType.normal,
      baseStats: const Stats(hp: 60, attack: 65, defense: 55, spAttack: 105, spDefense: 95, speed: 95),
      selectedAbility: 'Psychic Surge',
      iv: const Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31),
      ev: const Stats(hp: 0, attack: 0, defense: 0, spAttack: 252, spDefense: 0, speed: 0),
      moves: [ef, null, null, null], spreadTargets: spread);
  final garchomp = BattlePokemonState(
      pokemonName: 'Garchomp', type1: PokemonType.dragon, type2: PokemonType.ground,
      baseStats: const Stats(hp: 108, attack: 130, defense: 95, spAttack: 80, spDefense: 85, speed: 102),
      selectedAbility: 'Rough Skin',
      iv: const Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31),
      ev: const Stats(hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0));

  DamageResult run({required bool spread, required Terrain terrain}) => DamageCalculator.calculate(
      attacker: indeedee(spread: spread), defender: garchomp, moveIndex: 0,
      weather: Weather.none, terrain: terrain, room: const RoomConditions(), doubles: true);

  test('hitting both opponents on Psychic Terrain takes the 0.75× spread cut', () {
    final single = run(spread: false, terrain: Terrain.psychic);
    final both = run(spread: true, terrain: Terrain.psychic);
    expect(both.maxDamage, lessThan(single.maxDamage));
    expect(both.maxDamage, closeTo(single.maxDamage * 0.75, 2));
  });

  test('without the terrain it is single-target, so no spread cut', () {
    final a = run(spread: false, terrain: Terrain.none);
    final b = run(spread: true, terrain: Terrain.none);
    expect(b.maxDamage, a.maxDamage);
  });
}
