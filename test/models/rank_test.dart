import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/rank.dart';

void main() {
  group('Rank', () {
    test('positive and negative rank multipliers', () {
      expect(Rank.multiplier(0), equals(1.0));
      expect(Rank.multiplier(1), closeTo(1.5, 0.001));
      expect(Rank.multiplier(2), closeTo(2.0, 0.001));
      expect(Rank.multiplier(6), closeTo(4.0, 0.001));
      expect(Rank.multiplier(-1), closeTo(0.6667, 0.001));
      expect(Rank.multiplier(-2), closeTo(0.5, 0.001));
      expect(Rank.multiplier(-6), closeTo(0.25, 0.001));
    });

    test('clamps values to -6..+6 range', () {
      const rank = Rank(attack: 10, defense: -10);
      expect(rank.attack, equals(6));
      expect(rank.defense, equals(-6));
    });

    test('each stat has its own multiplier', () {
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
