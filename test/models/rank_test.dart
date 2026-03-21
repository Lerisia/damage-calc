import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/rank.dart';

void main() {
  group('Rank', () {
    test('default values are all zero', () {
      const rank = Rank();
      expect(rank.attack, equals(0));
      expect(rank.defense, equals(0));
      expect(rank.spAttack, equals(0));
      expect(rank.spDefense, equals(0));
      expect(rank.speed, equals(0));
    });

    test('positive rank multiplier', () {
      const rank = Rank(attack: 1);
      // +1: (2 + 1) / 2 = 1.5
      expect(rank.attackMultiplier, closeTo(1.5, 0.001));

      const rank2 = Rank(attack: 6);
      // +6: (2 + 6) / 2 = 4.0
      expect(rank2.attackMultiplier, closeTo(4.0, 0.001));
    });

    test('negative rank multiplier', () {
      const rank = Rank(attack: -1);
      // -1: 2 / (2 + 1) = 0.6667
      expect(rank.attackMultiplier, closeTo(0.6667, 0.001));

      const rank2 = Rank(defense: -6);
      // -6: 2 / (2 + 6) = 0.25
      expect(rank2.defenseMultiplier, closeTo(0.25, 0.001));
    });

    test('zero rank multiplier is 1.0', () {
      const rank = Rank();
      expect(rank.attackMultiplier, equals(1.0));
      expect(rank.speedMultiplier, equals(1.0));
    });

    test('each stat has its own multiplier', () {
      const rank = Rank(attack: 2, spAttack: -1, speed: 3);
      expect(rank.attackMultiplier, closeTo(2.0, 0.001));
      expect(rank.spAttackMultiplier, closeTo(0.6667, 0.001));
      expect(rank.speedMultiplier, closeTo(2.5, 0.001));
      expect(rank.defenseMultiplier, equals(1.0));
    });

    test('clamps values to -6..+6 range', () {
      const rank = Rank(attack: 10, defense: -10);
      expect(rank.attack, equals(6));
      expect(rank.defense, equals(-6));
    });

    test('clamps exactly at boundary values', () {
      const rank = Rank(attack: 6, defense: -6);
      expect(rank.attack, equals(6));
      expect(rank.defense, equals(-6));
    });

    test('clamps at +7 to +6', () {
      const rank = Rank(attack: 7);
      expect(rank.attack, equals(6));
    });

    test('clamps at -7 to -6', () {
      const rank = Rank(defense: -7);
      expect(rank.defense, equals(-6));
    });

    test('+2 multiplier = 2.0', () {
      expect(Rank.multiplier(2), closeTo(2.0, 0.001));
    });

    test('+3 multiplier = 2.5', () {
      expect(Rank.multiplier(3), closeTo(2.5, 0.001));
    });

    test('+4 multiplier = 3.0', () {
      expect(Rank.multiplier(4), closeTo(3.0, 0.001));
    });

    test('+5 multiplier = 3.5', () {
      expect(Rank.multiplier(5), closeTo(3.5, 0.001));
    });

    test('-2 multiplier = 0.5', () {
      expect(Rank.multiplier(-2), closeTo(0.5, 0.001));
    });

    test('-3 multiplier = 0.4', () {
      expect(Rank.multiplier(-3), closeTo(0.4, 0.001));
    });

    test('-4 multiplier = 1/3', () {
      expect(Rank.multiplier(-4), closeTo(1.0 / 3.0, 0.001));
    });

    test('-5 multiplier = 2/7', () {
      expect(Rank.multiplier(-5), closeTo(2.0 / 7.0, 0.001));
    });

    test('spAttack multiplier works correctly', () {
      const rank = Rank(spAttack: 4);
      expect(rank.spAttackMultiplier, closeTo(3.0, 0.001));
    });

    test('spDefense multiplier works correctly', () {
      const rank = Rank(spDefense: -3);
      expect(rank.spDefenseMultiplier, closeTo(0.4, 0.001));
    });

    test('all stats can have different ranks', () {
      const rank = Rank(
        attack: 1, defense: -1, spAttack: 2,
        spDefense: -2, speed: 6,
      );
      expect(rank.attackMultiplier, closeTo(1.5, 0.001));
      expect(rank.defenseMultiplier, closeTo(2.0 / 3.0, 0.001));
      expect(rank.spAttackMultiplier, closeTo(2.0, 0.001));
      expect(rank.spDefenseMultiplier, closeTo(0.5, 0.001));
      expect(rank.speedMultiplier, closeTo(4.0, 0.001));
    });
  });
}
