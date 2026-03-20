import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/move_transform.dart';
import 'package:damage_calc/utils/offensive_calculator.dart';

void main() {
  group('OffensiveCalculator', () {
    final baseStats = const Stats(
      hp: 45, attack: 49, defense: 49,
      spAttack: 65, spDefense: 65, speed: 45,
    );

    final maxIv = const Stats(
      hp: 31, attack: 31, defense: 31,
      spAttack: 31, spDefense: 31, speed: 31,
    );

    final zeroEv = const Stats(
      hp: 0, attack: 0, defense: 0,
      spAttack: 0, spDefense: 0, speed: 0,
    );

    const tackle = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35,
    );

    const psychic = Move(
      name: 'Psychic', nameKo: '사이코키네시스', nameJa: 'サイコキネシス',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10,
    );

    test('physical move uses attack stat', () {
      // Bulbasaur Lv50, 31IV/0EV, hardy: Atk = 69
      // Offensive power = 69 * 40 = 2760
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(2760));
    });

    test('special move uses spAttack stat', () {
      // Bulbasaur Lv50, 31IV/0EV, hardy: SpA = 85
      // Offensive power = 85 * 90 = 7650
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: psychic,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(7650));
    });

    test('nature and EV affect offensive power', () {
      final spAtkEv = const Stats(
        hp: 0, attack: 0, defense: 0,
        spAttack: 252, spDefense: 0, speed: 0,
      );
      // Bulbasaur Lv50, 31IV/252EV SpA, modest(+SpA):
      // SpA = floor(117 * 1.1) = 128
      // Offensive power = 128 * 90 = 11520
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: spAtkEv,
        nature: Nature.modest,
        level: 50,
        move: psychic,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(11520));
    });

    test('status move returns 0', () {
      const toxic = Move(
        name: 'Toxic', nameKo: '맹독', nameJa: 'どくどく',
        type: PokemonType.poison, category: MoveCategory.status,
        power: 0, accuracy: 90, pp: 10,
      );
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: toxic,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(0));
    });

    test('STAB applies 1.5x when move type matches type1', () {
      const sludgeBomb = Move(
        name: 'Sludge Bomb', nameKo: '오물폭탄', nameJa: 'ヘドロばくだん',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
      );
      // Bulbasaur is Grass/Poison, Sludge Bomb is Poison -> STAB
      // SpA = 85, power = 90
      // Offensive power = floor(85 * 90 * 1.5) = 11475
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: sludgeBomb,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(11475));
    });

    test('STAB applies when move type matches type2', () {
      const gigaDrain = Move(
        name: 'Giga Drain', nameKo: '기가드레인', nameJa: 'ギガドレイン',
        type: PokemonType.grass, category: MoveCategory.special,
        power: 75, accuracy: 100, pp: 10,
      );
      // Bulbasaur is Grass/Poison, Giga Drain is Grass -> STAB
      // SpA = 85, power = 75
      // Offensive power = floor(85 * 75 * 1.5) = 9562
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: gigaDrain,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(9562));
    });

    test('no STAB when move type does not match pokemon type', () {
      // Psychic is not Grass or Poison -> no STAB
      // Same as 'special move uses spAttack stat' = 7650
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: psychic,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(7650));
    });

    test('statModifier applies to attack stat before multiplication', () {
      // Atk = 69, statModifier 1.5 (Choice Band) -> floor(69 * 1.5) = 103
      // Tackle power = 40, no STAB
      // Offensive power = 103 * 40 = 4120
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        statModifier: 1.5,
      );
      expect(result, equals(4120));
    });

    test('powerModifier applies to final result', () {
      // Atk = 69, Tackle power = 40, no STAB
      // Base = 69 * 40 = 2760
      // With powerModifier 1.3 (Life Orb): floor(2760 * 1.3) = 3588
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        powerModifier: 1.3,
      );
      expect(result, equals(3588));
    });

    test('statModifier and powerModifier produce different results than combined', () {
      // Demonstrates that applying at different stages matters
      // Atk = 69
      // statModifier 1.5: floor(69 * 1.5) = 103, then 103 * 40 = 4120
      // vs powerModifier 1.5: 69 * 40 = 2760, floor(2760 * 1.5) = 4140
      final withStatMod = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        statModifier: 1.5,
      );
      final withPowerMod = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        powerModifier: 1.5,
      );
      // They differ because floor is applied at different stages
      expect(withStatMod, equals(4120));
      expect(withPowerMod, equals(4140));
      expect(withStatMod, isNot(equals(withPowerMod)));
    });

    test('both modifiers stack with STAB', () {
      const sludgeBomb = Move(
        name: 'Sludge Bomb', nameKo: '오물폭탄', nameJa: 'ヘドロばくだん',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
      );
      // SpA = 85, statModifier 1.5 -> floor(85 * 1.5) = 127
      // power = 90, STAB 1.5x, powerModifier 1.3
      // floor(127 * 90 * 1.5 * 1.3) = floor(22275.75) = floor(22275) = 22275
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: sludgeBomb,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        statModifier: 1.5,
        powerModifier: 1.3,
      );
      expect(result, equals(22275));
    });

    test('default modifiers are 1.0', () {
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(2760));
    });

    test('rank +2 doubles the attack stat', () {
      // Atk = 69, rank +2 multiplier = 2.0 -> floor(69 * 2.0) = 138
      // Tackle power = 40
      // Offensive power = 138 * 40 = 5520
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        rank: const Rank(attack: 2),
      );
      expect(result, equals(5520));
    });

    test('rank -1 reduces the attack stat', () {
      // Atk = 69, rank -1 multiplier = 2/3 -> floor(69 * 2/3) = 46
      // Tackle power = 40
      // Offensive power = 46 * 40 = 1840
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        rank: const Rank(attack: -1),
      );
      expect(result, equals(1840));
    });

    test('rank stacks with statModifier', () {
      // Atk = 69
      // rank +1 (1.5x) * statModifier 1.5 (Choice Band)
      // floor(69 * 1.5 * 1.5) = floor(155.25) = 155
      // Tackle power = 40
      // Offensive power = 155 * 40 = 6200
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        rank: const Rank(attack: 1),
        statModifier: 1.5,
      );
      expect(result, equals(6200));
    });

    test('special move uses spAttack rank', () {
      // SpA = 85, rank spAttack +2 (2.0x) -> floor(85 * 2.0) = 170
      // Psychic power = 90
      // Offensive power = 170 * 90 = 15300
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: psychic,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        rank: const Rank(spAttack: 2),
      );
      expect(result, equals(15300));
    });

    test('critical hit applies 1.5x multiplier', () {
      // Atk = 69, Tackle power = 40
      // Base = 69 * 40 = 2760
      // Critical 1.5x: floor(2760 * 1.5) = 4140
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        isCritical: true,
      );
      expect(result, equals(4140));
    });

    test('critical hit ignores negative attack rank', () {
      // Atk = 69, rank -2 would be 0.5x but critical ignores it
      // So Atk stays 69, Tackle power = 40
      // floor(69 * 40 * 1.5) = 4140
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        rank: const Rank(attack: -2),
        isCritical: true,
      );
      expect(result, equals(4140));
    });

    test('critical hit keeps positive attack rank', () {
      // Atk = 69, rank +2 (2.0x) -> floor(69 * 2.0) = 138
      // Tackle power = 40
      // floor(138 * 40 * 1.5) = 8280
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: tackle,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        rank: const Rank(attack: 2),
        isCritical: true,
      );
      expect(result, equals(8280));
    });

    test('sun boosts Fire move power', () {
      const flamethrower = Move(
        name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
        type: PokemonType.fire, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 15,
      );
      // SpA = 85, power = 90, sun 1.5x
      // floor(85 * 90 * 1.5) = 11475
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: flamethrower,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        weather: Weather.sun,
      );
      expect(result, equals(11475));
    });

    test('Weather Ball transforms to Fire/100 in sun and gets weather boost', () {
      const weatherBall = Move(
        name: 'Weather Ball', nameKo: '웨더볼', nameJa: 'ウェザーボール',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 50, accuracy: 100, pp: 10,
      );
      // Pre-process: Weather Ball in sun -> Fire/100
      final transformed = applyWeatherToMove(weatherBall, Weather.sun);
      // SpA = 85, power = 100, sun Fire 1.5x
      // floor(85 * 100 * 1.5) = 12750
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: transformed,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
        weather: Weather.sun,
      );
      expect(result, equals(12750));
    });

    test('Weather Ball with no weather stays Normal/50', () {
      const weatherBall = Move(
        name: 'Weather Ball', nameKo: '웨더볼', nameJa: 'ウェザーボール',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 50, accuracy: 100, pp: 10,
      );
      final transformed = applyWeatherToMove(weatherBall, Weather.none);
      // SpA = 85, power = 50, no weather
      // 85 * 50 = 4250
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats,
        iv: maxIv,
        ev: zeroEv,
        nature: Nature.hardy,
        level: 50,
        move: transformed,
        type1: PokemonType.grass,
        type2: PokemonType.poison,
      );
      expect(result, equals(4250));
    });
  });
}
