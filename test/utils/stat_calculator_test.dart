import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/utils/stat_calculator.dart';

void main() {
  group('StatCalculator', () {
    // Bulbasaur base stats: 45/49/49/65/65/45
    final baseStats = const Stats(
      hp: 45,
      attack: 49,
      defense: 49,
      spAttack: 65,
      spDefense: 65,
      speed: 45,
    );

    test('max IV, zero EV, neutral nature, level 50', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
      );
      // HP: ((2*45+31+0)*50/100)+50+10 = (121*50/100)+60 = 60+60 = 120
      expect(result.hp, equals(120));
      // Atk: (((2*49+31+0)*50/100)+5)*1.0 = (129*50/100+5) = 64+5 = 69
      expect(result.attack, equals(69));
    });

    test('nature boost and reduction', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.adamant, // +Atk -SpA
        level: 50,
      );
      // Atk with 1.1x: floor(69 * 1.1) = 75
      expect(result.attack, equals(75));
      // SpA with 0.9x: floor(85 * 0.9) = 76
      // SpA base=65: (((2*65+31)*50/100)+5) = (161*50/100+5) = 80+5 = 85
      // 85 * 0.9 = 76.5 -> 76
      expect(result.spAttack, equals(76));
    });

    test('EV investment affects stats', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 252, attack: 0, defense: 0,
          spAttack: 252, spDefense: 4, speed: 0,
        ),
        nature: Nature.modest, // +SpA -Atk
        level: 50,
      );
      // HP: ((2*45+31+252/4)*50/100)+50+10 = ((121+63)*50/100)+60
      //   = (184*50/100)+60 = 92+60 = 152
      expect(result.hp, equals(152));
      // SpA: (((2*65+31+63)*50/100)+5)*1.1 = ((224*50/100)+5)*1.1
      //   = (112+5)*1.1 = 117*1.1 = 128.7 -> 128
      expect(result.spAttack, equals(128));
    });

    test('level 100 calculation', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 100,
      );
      // HP: ((2*45+31)*100/100)+100+10 = 121+110 = 231
      expect(result.hp, equals(231));
      // Atk: ((2*49+31)*100/100)+5 = 129+5 = 134
      expect(result.attack, equals(134));
    });

    test('rank +2 doubles attack stat', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
        rank: const Rank(attack: 2),
      );
      // Atk without rank = 69, rank +2 = 2.0x -> floor(69 * 2.0) = 138
      expect(result.attack, equals(138));
      // HP unaffected by rank
      expect(result.hp, equals(120));
      // Other stats unaffected
      expect(result.defense, equals(69));
    });

    test('rank -1 reduces attack stat', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
        rank: const Rank(attack: -1),
      );
      // Atk = 69, rank -1 = 2/3 -> floor(69 * 2/3) = 46
      expect(result.attack, equals(46));
    });

    test('default rank does not change stats', () {
      final withRank = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
        rank: const Rank(),
      );
      final withoutRank = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
      );
      expect(withRank.attack, equals(withoutRank.attack));
      expect(withRank.speed, equals(withoutRank.speed));
    });

    test('rank +1 on spAttack', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
        rank: const Rank(spAttack: 1),
      );
      // SpA without rank = 85, rank +1 = 1.5x -> floor(85 * 1.5) = 127
      expect(result.spAttack, equals(127));
      // Attack unaffected
      expect(result.attack, equals(69));
    });

    test('rank -2 on speed', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
        rank: const Rank(speed: -2),
      );
      // Speed without rank = 65, rank -2 = 0.5x -> floor(65 * 0.5) = 32
      expect(result.speed, equals(32));
    });

    test('combined rank and nature boost', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.adamant, // +Atk -SpA
        level: 50,
        rank: const Rank(attack: 2),
      );
      // Atk = 69 base, nature 1.1x -> 75, rank +2 = 2.0x -> 150
      // But rank is applied in the stat formula: raw * nature * rank
      // raw = 64 + 5 = 69 (at base), then * 1.1 * 2.0 = floor(69 * 1.1 * 2.0) = floor(151.8) = 151
      // Wait, let me recalculate:
      // raw = ((2*49+31)*50/100) + 5 = (129*50/100) + 5 = 64 + 5 = 69
      // 69 * 1.1 (nature) * 2.0 (rank) = 69 * 2.2 = 151.8 -> 151
      expect(result.attack, equals(151));
    });

    test('rank +6 on defense', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
        rank: const Rank(defense: 6),
      );
      // Def = 69, rank +6 = 4.0x -> floor(69 * 4.0) = 276
      expect(result.defense, equals(276));
    });

    test('rank -6 on spDefense', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
        rank: const Rank(spDefense: -6),
      );
      // SpD base=65: ((2*65+31)*50/100)+5 = (161*50/100)+5 = 80+5 = 85
      // rank -6 = 0.25x -> floor(85 * 0.25) = 21
      expect(result.spDefense, equals(21));
    });

    test('zero IVs lower stats', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 50,
      );
      // HP: ((2*45+0)*50/100)+50+10 = (90*50/100)+60 = 45+60 = 105
      expect(result.hp, equals(105));
      // Atk: ((2*49+0)*50/100)+5 = (98*50/100)+5 = 49+5 = 54
      expect(result.attack, equals(54));
    });

    test('level 1 calculation', () {
      final result = StatCalculator.calculate(
        baseStats: baseStats,
        iv: const Stats(
          hp: 31, attack: 31, defense: 31,
          spAttack: 31, spDefense: 31, speed: 31,
        ),
        ev: const Stats(
          hp: 0, attack: 0, defense: 0,
          spAttack: 0, spDefense: 0, speed: 0,
        ),
        nature: Nature.hardy,
        level: 1,
      );
      // HP: ((2*45+31)*1/100)+1+10 = (121/100)+11 = 1+11 = 12
      expect(result.hp, equals(12));
      // Atk: ((2*49+31)*1/100)+5 = (129/100)+5 = 1+5 = 6
      expect(result.attack, equals(6));
    });
  });
}
