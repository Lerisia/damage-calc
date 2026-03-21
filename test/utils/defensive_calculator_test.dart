import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/defensive_calculator.dart';

void main() {
  // Bulbasaur base stats
  const baseStats = Stats(
    hp: 45, attack: 49, defense: 49,
    spAttack: 65, spDefense: 65, speed: 45,
  );

  const maxIv = Stats(
    hp: 31, attack: 31, defense: 31,
    spAttack: 31, spDefense: 31, speed: 31,
  );

  const zeroEv = Stats(
    hp: 0, attack: 0, defense: 0,
    spAttack: 0, spDefense: 0, speed: 0,
  );

  group('Basic defensive calculation', () {
    test('physical bulk = HP * Def', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
      );
      // HP = 120, Def = 69 -> 120 * 69 = 8280
      expect(result.physical, equals(8280));
    });

    test('special bulk = HP * SpDef', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
      );
      // HP = 120, SpD = 85 -> 120 * 85 = 10200
      expect(result.special, equals(10200));
    });
  });

  group('Weather defensive modifiers', () {
    test('sandstorm boosts Rock-type special bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.rock,
        weather: Weather.sandstorm,
      );
      // HP = 120, SpD = 85, sandstorm 1.5x -> floor(120 * 85 * 1.5) = 15300
      expect(result.special, equals(15300));
      // Physical unaffected
      expect(result.physical, equals(8280));
    });

    test('snow boosts Ice-type physical bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.ice,
        weather: Weather.snow,
      );
      // HP = 120, Def = 69, snow 1.5x -> floor(120 * 69 * 1.5) = 12420
      expect(result.physical, equals(12420));
      // Special unaffected
      expect(result.special, equals(10200));
    });
  });

  group('Ability defensive effects', () {
    test('Fur Coat doubles physical bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        ability: 'Fur Coat',
      );
      // HP = 120, Def = 69, Fur Coat 2.0x -> floor(120 * 69 * 2.0) = 16560
      expect(result.physical, equals(16560));
      expect(result.special, equals(10200));
    });

    test('Ice Scales doubles special bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.bug,
        ability: 'Ice Scales',
      );
      expect(result.special, equals(20400)); // 120 * 85 * 2.0
      expect(result.physical, equals(8280));
    });

    test('Marvel Scale boosts physical bulk when statused', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.water,
        ability: 'Marvel Scale',
        status: StatusCondition.burn,
      );
      // floor(120 * 69 * 1.5) = 12420
      expect(result.physical, equals(12420));
    });

    test('Marvel Scale no effect when healthy', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.water,
        ability: 'Marvel Scale',
        status: StatusCondition.none,
      );
      expect(result.physical, equals(8280));
    });
  });

  group('Item defensive effects', () {
    test('Eviolite boosts both bulks for non-final evo', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        item: 'eviolite',
        finalEvo: false,
      );
      // Physical: floor(120 * 69 * 1.5) = 12420
      expect(result.physical, equals(12420));
      // Special: floor(120 * 85 * 1.5) = 15300
      expect(result.special, equals(15300));
    });

    test('Eviolite no effect for final evo', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        item: 'eviolite',
        finalEvo: true,
      );
      expect(result.physical, equals(8280));
      expect(result.special, equals(10200));
    });

    test('Assault Vest boosts special bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.fighting,
        item: 'assault-vest',
      );
      expect(result.physical, equals(8280));
      // Special: floor(120 * 85 * 1.5) = 15300
      expect(result.special, equals(15300));
    });
  });

  group('Screens', () {
    test('Reflect doubles physical bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        reflect: true,
      );
      expect(result.physical, equals(16560)); // 8280 * 2
      expect(result.special, equals(10200));
    });

    test('Light Screen doubles special bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        lightScreen: true,
      );
      expect(result.physical, equals(8280));
      expect(result.special, equals(20400)); // 10200 * 2
    });

    test('Aurora Veil doubles both bulks', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        auroraVeil: true,
      );
      expect(result.physical, equals(16560));
      expect(result.special, equals(20400));
    });
  });

  group('Friend Guard', () {
    test('Friend Guard boosts both bulks by 4/3', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        friendGuard: true,
      );
      // Physical: floor(120 * 69 * 4/3) = floor(11040) = 11040
      expect(result.physical, equals(11040));
      // Special: floor(120 * 85 * 4/3) = floor(13600) = 13600
      expect(result.special, equals(13600));
    });
  });

  group('Flower Gift defensive', () {
    test('Flower Gift boosts special bulk in sun', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        weather: Weather.sun,
        flowerGift: true,
      );
      expect(result.physical, equals(8280));
      // Special: floor(120 * 85 * 1.5) = 15300
      expect(result.special, equals(15300));
    });

    test('Flower Gift no effect without sun', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        weather: Weather.rain,
        flowerGift: true,
      );
      expect(result.special, equals(10200));
    });

    test('Flower Gift works in harsh sun', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        weather: Weather.harshSun,
        flowerGift: true,
      );
      expect(result.special, equals(15300));
    });
  });

  group('Rank integration', () {
    test('positive defense rank increases physical bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        rank: const Rank(defense: 2),
      );
      // Def = 69, rank +2 = 2.0x -> 138
      // Physical: 120 * 138 = 16560
      expect(result.physical, equals(16560));
    });

    test('negative spDefense rank decreases special bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        rank: const Rank(spDefense: -2),
      );
      // SpD = 85, rank -2 = 0.5x -> 42
      // Special: 120 * 42 = 5040
      expect(result.special, equals(5040));
    });
  });

  group('Combined modifiers', () {
    test('Eviolite + Reflect stack', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        item: 'eviolite',
        finalEvo: false,
        reflect: true,
      );
      // Physical: floor(120 * 69 * 1.5 * 2.0) = floor(24840) = 24840
      expect(result.physical, equals(24840));
    });

    test('Sandstorm + Assault Vest stack for Rock type', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.rock,
        weather: Weather.sandstorm,
        item: 'assault-vest',
      );
      // Special: floor(120 * 85 * 1.5 * 1.5) = floor(22950) = 22950
      expect(result.special, equals(22950));
    });
  });
}
