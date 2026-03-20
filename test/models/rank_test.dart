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
  });
}
