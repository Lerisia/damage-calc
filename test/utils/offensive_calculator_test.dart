import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/utils/move_transform.dart';
import 'package:damage_calc/utils/offensive_calculator.dart';

/// Helper to create a TransformedMove from a Move with default context
TransformedMove _transform(Move move, [MoveContext? context]) {
  return transformMove(move, context ?? const MoveContext());
}

void main() {
  // Bulbasaur base stats
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

  const psychicMove = Move(
    name: 'Psychic', nameKo: '사이코키네시스', nameJa: 'サイコキネシス',
    type: PokemonType.psychic, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10,
  );

  const sludgeBomb = Move(
    name: 'Sludge Bomb', nameKo: '오물폭탄', nameJa: 'ヘドロばくだん',
    type: PokemonType.poison, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10,
  );

  const flamethrower = Move(
    name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
    type: PokemonType.fire, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 15,
  );

  group('Basic calculation', () {
    test('physical move uses attack stat', () {
      // Atk = 69, power = 40 -> 2760
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
      );
      expect(result, equals(2760));
    });

    test('special move uses spAttack stat', () {
      // SpA = 85, power = 90 -> 7650
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(psychicMove),
        type1: PokemonType.grass, type2: PokemonType.poison,
      );
      expect(result, equals(7650));
    });

    test('nature and EV affect result', () {
      final spAtkEv = const Stats(
        hp: 0, attack: 0, defense: 0,
        spAttack: 252, spDefense: 0, speed: 0,
      );
      // SpA = floor(117 * 1.1) = 128, power = 90 -> 11520
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: spAtkEv,
        nature: Nature.modest, level: 50,
        transformed: _transform(psychicMove),
        type1: PokemonType.grass, type2: PokemonType.poison,
      );
      expect(result, equals(11520));
    });
  });

  group('STAB', () {
    test('applies 1.5x when type matches', () {
      // Bulbasaur is Grass/Poison, Sludge Bomb is Poison -> STAB
      // SpA = 85, power = 90 -> floor(85 * 90 * 1.5) = 11475
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(sludgeBomb),
        type1: PokemonType.grass, type2: PokemonType.poison,
      );
      expect(result, equals(11475));
    });

    test('no STAB when type does not match', () {
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(psychicMove),
        type1: PokemonType.grass, type2: PokemonType.poison,
      );
      expect(result, equals(7650));
    });

    test('stabOverride changes STAB multiplier', () {
      // Adaptability: STAB = 2.0
      // SpA = 85, power = 90 -> floor(85 * 90 * 2.0) = 15300
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(sludgeBomb),
        type1: PokemonType.grass, type2: PokemonType.poison,
        stabOverride: 2.0,
      );
      expect(result, equals(15300));
    });
  });

  group('Stat modifier', () {
    test('statModifier applies to attack', () {
      // Atk = 69, statMod 1.5 -> floor(69 * 1.5) = 103
      // power = 40 -> 4120
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        statModifier: 1.5,
      );
      expect(result, equals(4120));
    });

    test('powerModifier applies to final result', () {
      // Atk = 69, power = 40 -> 2760 * 1.3 = 3588
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        powerModifier: 1.3,
      );
      expect(result, equals(3588));
    });
  });

  group('Critical hit', () {
    test('applies 1.5x multiplier', () {
      // 69 * 40 * 1.5 = 4140
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        isCritical: true,
      );
      expect(result, equals(4140));
    });

    test('ignores negative attack rank', () {
      // Atk rank -2 would be 0.5x, but critical ignores it
      // Atk = 69, power = 40, crit 1.5 -> 4140
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        rank: const Rank(attack: -2),
        isCritical: true,
      );
      expect(result, equals(4140));
    });

    test('keeps positive attack rank on crit', () {
      // Atk = 69, rank +2 (2.0x) -> 138, power = 40, crit 1.5
      // 138 * 40 * 1.5 = 8280
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        rank: const Rank(attack: 2),
        isCritical: true,
      );
      expect(result, equals(8280));
    });

    test('criticalOverride changes crit multiplier', () {
      // Sniper: crit = 2.25
      // 69 * 40 * 2.25 = 6210
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        isCritical: true,
        criticalOverride: 2.25,
      );
      expect(result, equals(6210));
    });
  });

  group('Weather', () {
    test('sun boosts fire moves', () {
      // SpA = 85, power = 90, sun 1.5x -> floor(85*90*1.5) = 11475
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(flamethrower),
        type1: PokemonType.grass, type2: PokemonType.poison,
        weather: Weather.sun,
      );
      expect(result, equals(11475));
    });
  });

  group('Terrain', () {
    test('electric terrain boosts electric moves when grounded', () {
      const thunderbolt = Move(
        name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
        type: PokemonType.electric, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 15,
      );
      // SpA = 85, power = 90, terrain 1.3x -> floor(85*90*1.3) = 9945
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(thunderbolt),
        type1: PokemonType.grass, type2: PokemonType.poison,
        terrain: Terrain.electric,
        grounded: true,
      );
      expect(result, equals(9945));
    });

    test('electric terrain does not boost when ungrounded', () {
      const thunderbolt = Move(
        name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
        type: PokemonType.electric, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 15,
      );
      // Ungrounded -> no terrain boost -> 85 * 90 = 7650
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(thunderbolt),
        type1: PokemonType.grass, type2: PokemonType.poison,
        terrain: Terrain.electric,
        grounded: false,
      );
      expect(result, equals(7650));
    });
  });

  group('Burn penalty', () {
    test('burn halves physical damage', () {
      // Atk = 69, power = 40 -> 2760 * 0.5 = 1380
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        status: StatusCondition.burn,
      );
      expect(result, equals(1380));
    });

    test('burn does not affect special moves', () {
      // SpA = 85, power = 90 -> 7650 (unchanged)
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(flamethrower),
        type1: PokemonType.grass, type2: PokemonType.poison,
        status: StatusCondition.burn,
      );
      expect(result, equals(7650));
    });

    test('Guts negates burn penalty', () {
      // Atk = 69, power = 40 -> 2760 (no halving)
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        status: StatusCondition.burn,
        hasGuts: true,
      );
      expect(result, equals(2760));
    });
  });

  group('Status moves', () {
    test('returns 0', () {
      const toxic = Move(
        name: 'Toxic', nameKo: '맹독', nameJa: 'どくどく',
        type: PokemonType.poison, category: MoveCategory.status,
        power: 0, accuracy: 90, pp: 10,
      );
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(toxic),
        type1: PokemonType.grass, type2: PokemonType.poison,
      );
      expect(result, equals(0));
    });
  });

  group('Rank integration', () {
    test('positive spAttack rank boosts special damage', () {
      // SpA base = 85, rank +2 = 2.0x -> 170
      // power = 90 -> 170 * 90 = 15300
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(psychicMove),
        type1: PokemonType.grass, type2: PokemonType.poison,
        rank: const Rank(spAttack: 2),
      );
      expect(result, equals(15300));
    });

    test('negative attack rank reduces physical damage', () {
      // Atk = 69, rank -1 = 2/3 -> 46
      // power = 40 -> 46 * 40 = 1840
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(tackle),
        type1: PokemonType.grass, type2: PokemonType.poison,
        rank: const Rank(attack: -1),
      );
      expect(result, equals(1840));
    });
  });

  group('Combined modifiers', () {
    test('STAB + weather + statModifier', () {
      // Bulbasaur using Sludge Bomb (Poison STAB) in rain
      // SpA = 85, power = 90, STAB 1.5x, rain doesn't affect poison
      // 85 * 90 * 1.5 * 1.5 (statMod) = floor(85 * 1.5) = 127; 127 * 90 * 1.5 = 17145
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(sludgeBomb),
        type1: PokemonType.grass, type2: PokemonType.poison,
        statModifier: 1.5,
        weather: Weather.rain,
      );
      expect(result, equals(17145));
    });

    test('STAB + powerModifier', () {
      // SpA = 85, power = 90, STAB 1.5x, powerMod 1.3x
      // floor(85 * 90 * 1.5 * 1.3) = floor(14917.5) = 14917
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(sludgeBomb),
        type1: PokemonType.grass, type2: PokemonType.poison,
        powerModifier: 1.3,
      );
      expect(result, equals(14917));
    });

    test('critical + STAB + weather', () {
      // Flamethrower in sun with STAB (if fire type)
      // Not STAB for Bulbasaur (Grass/Poison)
      // SpA = 85, power = 90, crit 1.5x, sun 1.5x = 85*90*1.5*1.5 = 17213
      // Wait: 85 * 90 * 1.5 * 1.5 = 17212.5 -> 17212
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(flamethrower),
        type1: PokemonType.grass, type2: PokemonType.poison,
        isCritical: true,
        weather: Weather.sun,
      );
      expect(result, equals(17212));
    });
  });

  group('Body Press stat selection', () {
    test('Body Press uses defense stat', () {
      const bodyPress = Move(
        name: 'Body Press', nameKo: '바디프레스', nameJa: 'ボディプレス',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 80, accuracy: 100, pp: 10, tags: [MoveTags.useDefense],
      );
      // Def = 69, power = 80 -> 69 * 80 = 5520
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(bodyPress),
        type1: PokemonType.grass, type2: PokemonType.poison,
      );
      expect(result, equals(5520));
    });
  });

  group('Misty terrain reduces dragon', () {
    test('Misty Terrain halves dragon move damage when grounded', () {
      const dragonPulse = Move(
        name: 'Dragon Pulse', nameKo: '용의파동', nameJa: 'りゅうのはどう',
        type: PokemonType.dragon, category: MoveCategory.special,
        power: 85, accuracy: 100, pp: 10,
      );
      // SpA = 85, power = 85, misty 0.5x -> floor(85*85*0.5) = 3612
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(dragonPulse),
        type1: PokemonType.grass, type2: PokemonType.poison,
        terrain: Terrain.misty,
        grounded: true,
      );
      expect(result, equals(3612));
    });
  });

  group('Rain weakens fire', () {
    test('rain halves fire move damage', () {
      // SpA = 85, power = 90, rain 0.5x -> floor(85*90*0.5) = 3825
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(flamethrower),
        type1: PokemonType.grass, type2: PokemonType.poison,
        weather: Weather.rain,
      );
      expect(result, equals(3825));
    });
  });

  group('Foul Play', () {
    const foulPlay = Move(
      name: 'Foul Play', nameKo: '속임수', nameJa: 'イカサマ',
      type: PokemonType.dark, category: MoveCategory.physical,
      power: 95, accuracy: 100, pp: 15,
      tags: [MoveTags.useOpponentAtk],
    );

    test('uses opponent attack stat instead of own', () {
      // Own Atk = 69 (Bulbasaur), but Foul Play uses opponent's attack
      // opponentAttack = 150, power = 95, Dark STAB 1.5
      // floor(150 * 95 * 1.5) = 21375
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(foulPlay),
        type1: PokemonType.dark,
        opponentAttack: 150,
      );
      expect(result, equals(21375));
    });

    test('falls back to own attack when opponentAttack is null', () {
      // Atk = 69, power = 95, Dark STAB 1.5 -> floor(69 * 95 * 1.5) = 9832
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(foulPlay),
        type1: PokemonType.dark,
      );
      expect(result, equals(9832));
    });

    test('STAB applies based on attacker type', () {
      // Dark-type attacker using Foul Play with STAB
      // opponentAttack = 100, power = 95, STAB 1.5
      // floor(100 * 95 * 1.5) = 14250
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(foulPlay),
        type1: PokemonType.dark,
        opponentAttack: 100,
      );
      expect(result, equals(14250));
    });

    test('no STAB when attacker is not dark type', () {
      // Non-dark attacker, opponentAttack = 100, power = 95
      // 100 * 95 = 9500 (no STAB)
      final result = OffensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        transformed: _transform(foulPlay),
        type1: PokemonType.grass, type2: PokemonType.poison,
        opponentAttack: 100,
      );
      expect(result, equals(9500));
    });
  });
}
