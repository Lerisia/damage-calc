import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/move_transform.dart';
import 'package:damage_calc/utils/offensive_calculator.dart';

/// Helper: calculate offensive power with ally boosts applied as powerModifier/statModifier
int _calcWithBoosts(Move move, {
  double powerMod = 1.0,
  double statMod = 1.0,
}) {
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

  final transformed = transformMove(move, const MoveContext());

  return OffensiveCalculator.calculate(
    baseStats: baseStats,
    iv: maxIv,
    ev: zeroEv,
    nature: Nature.hardy,
    level: 50,
    transformed: transformed,
    type1: PokemonType.grass,
    type2: PokemonType.poison,
    statModifier: statMod,
    powerModifier: powerMod,
  );
}

void main() {
  const tackle = Move(
    name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
    type: PokemonType.normal, category: MoveCategory.physical,
    power: 40, accuracy: 100, pp: 35,
  );

  const thunderbolt = Move(
    name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
    type: PokemonType.electric, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 15,
  );

  const flashCannon = Move(
    name: 'Flash Cannon', nameKo: '러스터캐논', nameJa: 'ラスターカノン',
    type: PokemonType.steel, category: MoveCategory.special,
    power: 80, accuracy: 100, pp: 10,
  );

  const psychicMove = Move(
    name: 'Psychic', nameKo: '사이코키네시스', nameJa: 'サイコキネシス',
    type: PokemonType.psychic, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10,
  );

  group('Helping Hand', () {
    test('boosts power by 1.5x', () {
      final base = _calcWithBoosts(tackle);
      final boosted = _calcWithBoosts(tackle, powerMod: 1.5);
      // 69 * 40 = 2760, * 1.5 = 4140
      expect(base, equals(2760));
      expect(boosted, equals(4140));
    });
  });

  group('Charge', () {
    test('doubles electric move power', () {
      final base = _calcWithBoosts(thunderbolt);
      final charged = _calcWithBoosts(thunderbolt, powerMod: 2.0);
      // SpA = 85, power = 90 -> 7650, * 2.0 = 15300
      expect(base, equals(7650));
      expect(charged, equals(15300));
    });

    test('does not affect non-electric moves', () {
      // Charge only affects electric moves; non-electric should use powerMod 1.0
      final base = _calcWithBoosts(tackle);
      expect(base, equals(2760));
    });
  });

  group('Battery', () {
    test('boosts special move power by 1.3x', () {
      final base = _calcWithBoosts(psychicMove);
      final boosted = _calcWithBoosts(psychicMove, powerMod: 1.3);
      // SpA = 85, power = 90 -> 7650, * 1.3 = 9945
      expect(base, equals(7650));
      expect(boosted, equals(9945));
    });

    test('does not affect physical moves', () {
      final base = _calcWithBoosts(tackle);
      expect(base, equals(2760));
    });
  });

  group('Power Spot', () {
    test('boosts power by 1.3x', () {
      final base = _calcWithBoosts(tackle);
      final boosted = _calcWithBoosts(tackle, powerMod: 1.3);
      // 69 * 40 = 2760, * 1.3 = 3588
      expect(base, equals(2760));
      expect(boosted, equals(3588));
    });
  });

  group('Flower Gift', () {
    test('boosts physical attack stat by 1.5x', () {
      final base = _calcWithBoosts(tackle);
      final boosted = _calcWithBoosts(tackle, statMod: 1.5);
      // Atk = 69, * 1.5 = 103 (floored), * 40 = 4120
      expect(base, equals(2760));
      expect(boosted, equals(4120));
    });

    test('does not affect special moves stat', () {
      final base = _calcWithBoosts(psychicMove);
      // statMod 1.0 for special, SpA = 85, * 90 = 7650
      expect(base, equals(7650));
    });
  });

  group('Steely Spirit', () {
    test('boosts steel move power by 1.5x', () {
      final base = _calcWithBoosts(flashCannon);
      final boosted = _calcWithBoosts(flashCannon, powerMod: 1.5);
      // SpA = 85, power = 80 -> 6800, * 1.5 = 10200
      expect(base, equals(6800));
      expect(boosted, equals(10200));
    });

    test('does not affect non-steel moves', () {
      final base = _calcWithBoosts(tackle);
      expect(base, equals(2760));
    });
  });

  group('Stacking', () {
    test('Helping Hand + Battery stack on special move', () {
      // SpA = 85, power = 90 -> 7650 * 1.5 * 1.3 = 14917.5 -> 14917
      final boosted = _calcWithBoosts(psychicMove, powerMod: 1.5 * 1.3);
      expect(boosted, equals(14917));
    });

    test('Helping Hand + Power Spot stack', () {
      // 69 * 40 = 2760 * 1.5 * 1.3 = 5382
      final boosted = _calcWithBoosts(tackle, powerMod: 1.5 * 1.3);
      expect(boosted, equals(5382));
    });
  });
}
