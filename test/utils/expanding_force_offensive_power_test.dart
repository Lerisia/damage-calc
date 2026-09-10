import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/battle_facade.dart';

/// The 결정력 number must take the same spread cut the damage does.
/// After the damage path learned that Expanding Force spreads on
/// Psychic Terrain, the 결정력 path still keyed off the spread tag and
/// showed the full value — users saw the KO count change but not the
/// power.
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
  int power({required bool spread, required Terrain terrain}) => BattleFacade.calcOffensivePower(
      state: indeedee(spread: spread), moveIndex: 0, weather: Weather.none, terrain: terrain,
      room: const RoomConditions())!;

  test('결정력 drops by 0.75 when Expanding Force spreads on Psychic Terrain', () {
    final single = power(spread: false, terrain: Terrain.psychic);
    final both = power(spread: true, terrain: Terrain.psychic);
    expect(both, closeTo(single * 0.75, 2));
  });

  test('no terrain, no spread, no drop', () {
    expect(power(spread: true, terrain: Terrain.none), power(spread: false, terrain: Terrain.none));
  });
}
