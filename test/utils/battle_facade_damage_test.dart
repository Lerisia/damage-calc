import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/battle_facade.dart';
import 'package:damage_calc/utils/damage_calculator.dart';
import 'package:damage_calc/utils/stat_calculator.dart';

/// Screens must get damage through BattleFacade.calcDamage, which owns
/// the recipe the calculator needs around the two states — the
/// defender's rank-adjusted Attack (Foul Play), both effective speeds
/// (Gyro Ball, Electro Ball), gender (Rivalry), format. Until
/// 2026-09-13 three screens each copied that recipe by hand.
void main() {
  const foulPlay = Move(name: 'Foul Play', nameKo: '탁쳐서떨구기', nameJa: 'イカサマ',
      type: PokemonType.dark, category: MoveCategory.physical, power: 95, accuracy: 100, pp: 15,
      tags: [MoveTags.useOpponentAtk]);
  const gyroBall = Move(name: 'Gyro Ball', nameKo: '자이로볼', nameJa: 'ジャイロボール',
      type: PokemonType.steel, category: MoveCategory.physical, power: 1, accuracy: 100, pp: 5,
      tags: [MoveTags.gyroSpeed]);
  final atk = BattlePokemonState(
      pokemonName: 'Umbreon', type1: PokemonType.dark,
      baseStats: const Stats(hp: 95, attack: 65, defense: 110, spAttack: 60, spDefense: 130, speed: 65),
      selectedAbility: 'Synchronize',
      iv: const Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31),
      ev: const Stats(hp: 252, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0),
      moves: [foulPlay, gyroBall, null, null]);
  final def = BattlePokemonState(
      pokemonName: 'Garchomp', type1: PokemonType.dragon, type2: PokemonType.ground,
      baseStats: const Stats(hp: 108, attack: 130, defense: 95, spAttack: 80, spDefense: 85, speed: 102),
      selectedAbility: 'Rough Skin', selectedItem: 'choice-scarf',
      rank: const Rank(attack: 2),
      iv: const Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31),
      ev: const Stats(hp: 0, attack: 252, defense: 0, spAttack: 0, spDefense: 0, speed: 252));

  DamageResult manual(int i, {bool doubles = false}) {
    final defStats = StatCalculator.calculate(
        baseStats: def.baseStats, iv: def.iv, ev: def.ev,
        nature: def.nature, level: def.level, rank: def.rank);
    return DamageCalculator.calculate(
      attacker: atk, defender: def, moveIndex: i,
      weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      opponentAttack: defStats.attack,
      opponentSpeed: BattleFacade.calcSpeed(state: def, weather: Weather.none, terrain: Terrain.none, room: const RoomConditions()),
      myEffectiveSpeed: BattleFacade.calcSpeed(state: atk, weather: Weather.none, terrain: Terrain.none, room: const RoomConditions()),
      opponentGender: def.gender,
      doubles: doubles,
    );
  }

  DamageResult facade(int i, {bool doubles = false}) => BattleFacade.calcDamage(
      attacker: atk, defender: def, moveIndex: i,
      weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      doubles: doubles);

  test('Foul Play uses the defender\'s rank-adjusted Attack', () {
    expect(facade(0).maxDamage, manual(0).maxDamage);
    expect(facade(0).maxDamage, greaterThan(0));
  });

  test('Gyro Ball sees both effective speeds (Scarf on the defender)', () {
    expect(facade(1).maxDamage, manual(1).maxDamage);
    expect(facade(1).maxDamage, greaterThan(0));
  });

  test('format flag passes through', () {
    expect(facade(0, doubles: true).maxDamage, manual(0, doubles: true).maxDamage);
  });

  test('maxHp matches the stat formula (no nature, no rank)', () {
    final hp = StatCalculator.calculate(
        baseStats: def.baseStats, iv: def.iv, ev: def.ev, nature: def.nature, level: def.level).hp;
    expect(BattleFacade.maxHp(def), hp);
    expect(BattleFacade.maxHp(def), 183); // 108 base, 31 IV, 0 EV, Lv50
  });
}
