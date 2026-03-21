import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/room.dart';
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
      // HP = 120, Def = 69 -> floor(120 * 69 / 0.411) = 20145
      expect(result.physical, equals(20145));
    });

    test('special bulk = HP * SpDef', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
      );
      // HP = 120, SpD = 85 -> floor(120 * 85 / 0.411) = 24817
      expect(result.special, equals(24817));
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
      // SpD = floor(85 * 1.5) = 127, HP * SpD = 120 * 127 = 15240
      expect(result.special, equals(37080));
      // Physical unaffected
      expect(result.physical, equals(20145));
    });

    test('snow boosts Ice-type physical bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.ice,
        weather: Weather.snow,
      );
      // Def = floor(69 * 1.5) = 103, HP * Def = 120 * 103 = 12360
      expect(result.physical, equals(30072));
      // Special unaffected
      expect(result.special, equals(24817));
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
      expect(result.physical, equals(40291));
      expect(result.special, equals(24817));
    });

    test('Ice Scales doubles special bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.bug,
        ability: 'Ice Scales',
      );
      expect(result.special, equals(49635)); // 120 * 85 * 2.0
      expect(result.physical, equals(20145));
    });

    test('Marvel Scale boosts physical bulk when statused', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.water,
        ability: 'Marvel Scale',
        status: StatusCondition.burn,
      );
      // Def = floor(69 * 1.5) = 103, Physical: 120 * 103 = 12360
      expect(result.physical, equals(30072));
    });

    test('Marvel Scale no effect when healthy', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.water,
        ability: 'Marvel Scale',
        status: StatusCondition.none,
      );
      expect(result.physical, equals(20145));
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
      // Def = floor(69 * 1.5) = 103, Physical: 120 * 103 = 12360
      expect(result.physical, equals(30072));
      // SpD = floor(85 * 1.5) = 127, Special: 120 * 127 = 15240
      expect(result.special, equals(37080));
    });

    test('Eviolite no effect for final evo', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        item: 'eviolite',
        finalEvo: true,
      );
      expect(result.physical, equals(20145));
      expect(result.special, equals(24817));
    });

    test('Assault Vest boosts special bulk', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.fighting,
        item: 'assault-vest',
      );
      expect(result.physical, equals(20145));
      // Special: floor(120 * 85 * 1.5) = 15300
      expect(result.special, equals(37080));
    });
  });

  group('Flower Gift defensive', () {
    test('Flower Gift boosts special bulk in sun', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        weather: Weather.sun,
        ability: 'Flower Gift',
      );
      expect(result.physical, equals(20145));
      // Special: floor(120 * 85 * 1.5) = 15300
      expect(result.special, equals(37080));
    });

    test('Flower Gift no effect without sun', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        weather: Weather.rain,
        ability: 'Flower Gift',
      );
      expect(result.special, equals(24817));
    });

    test('Flower Gift works in harsh sun', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.normal,
        weather: Weather.harshSun,
        ability: 'Flower Gift',
      );
      expect(result.special, equals(37080));
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
      expect(result.physical, equals(40291));
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
      expect(result.special, equals(12262));
    });
  });

  group('Combined modifiers', () {
    test('Sandstorm + Assault Vest stack for Rock type', () {
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.rock,
        weather: Weather.sandstorm,
        item: 'assault-vest',
      );
      // SpD = floor(85 * 1.5 * 1.5) = floor(191.25) = 191, Special: 120 * 191 = 22920
      expect(result.special, equals(55766));
    });
  });

  group('Wonder Room', () {
    test('swaps Defense and Sp.Def', () {
      // Normal: HP=120, Def=69, SpDef=85
      // Wonder Room: Def uses SpDef(85), SpDef uses Def(69)
      final normal = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
      );
      final wonder = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        room: RoomConditions(wonderRoom: true),
      );
      expect(wonder.physical, equals(normal.special));
      expect(wonder.special, equals(normal.physical));
    });

    test('Wonder Room with defensive modifiers applies correctly', () {
      // Assault Vest (SpDef x1.5) under Wonder Room:
      // Physical uses SpDef(85) base, Special uses Def(69) base * 1.5
      final result = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        item: 'assault-vest',
        room: RoomConditions(wonderRoom: true),
      );
      // Physical: HP(120) * SpDef(85) / 0.411 = 24817
      expect(result.physical, equals(24817));
      // Special: HP(120) * floor(Def(69) * 1.5) / 0.411 = floor(120 * 103 / 0.411) = 30072
      expect(result.special, equals(30072));
    });

    test('Wonder Room with rank: swaps final stats (rank applied before swap)', () {
      // Bulbasaur: Def base=49, SpDef base=65
      // Rank +2 on defense: Def = floor(69 * 2.0) = 138, SpDef = 85
      // Wonder Room swaps final values: physical uses 85, special uses 138
      // HP = 120
      final wonder = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        rank: const Rank(defense: 2),
        room: RoomConditions(wonderRoom: true),
      );
      // physical bulk = floor(120 * 85 / 0.411) = 24817
      expect(wonder.physical, equals(24817));
      // special bulk = floor(120 * 138 / 0.411) = 40291
      expect(wonder.special, equals(40291));
    });

    test('non-Wonder rooms do not swap', () {
      final trick = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
        room: RoomConditions(trickRoom: true),
      );
      final normal = DefensiveCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, level: 50,
        type1: PokemonType.grass,
      );
      expect(trick.physical, equals(normal.physical));
      expect(trick.special, equals(normal.special));
    });
  });
}
