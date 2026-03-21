import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/random_factor.dart';

void main() {
  group('RandomFactor', () {
    test('apply calculates floor(damage * roll / 100)', () {
      // 100 * 85 / 100 = 85
      expect(RandomFactor.apply(100, 85), equals(85));
      // 100 * 100 / 100 = 100
      expect(RandomFactor.apply(100, 100), equals(100));
      // 137 * 85 / 100 = 116.45 -> 116
      expect(RandomFactor.apply(137, 85), equals(116));
      // 137 * 93 / 100 = 127.41 -> 127
      expect(RandomFactor.apply(137, 93), equals(127));
    });

    test('allRolls returns 16 values', () {
      final rolls = RandomFactor.allRolls(100);
      expect(rolls.length, equals(16));
      expect(rolls.first, equals(85));
      expect(rolls.last, equals(100));
    });

    test('range returns min and max', () {
      final r = RandomFactor.range(200);
      expect(r.min, equals(170)); // 200 * 85 / 100
      expect(r.max, equals(200)); // 200 * 100 / 100
    });

    test('koRolls counts rolls that KO', () {
      // damage 100 vs hp 90: rolls 90~100 KO (11/16)
      expect(RandomFactor.koRolls(100, 90), equals(11));
      // damage 100 vs hp 100: only roll 100 KOs (1/16)
      expect(RandomFactor.koRolls(100, 100), equals(1));
      // damage 100 vs hp 101: no rolls KO
      expect(RandomFactor.koRolls(100, 101), equals(0));
      // damage 100 vs hp 95: rolls 95~100 KO (6/16)
      expect(RandomFactor.koRolls(100, 95), equals(6));
    });

    test('koLabel describes KO chance', () {
      expect(RandomFactor.koLabel(16), equals('확정'));
      expect(RandomFactor.koLabel(14), equals('고난수'));
      expect(RandomFactor.koLabel(8), equals('난수'));
      expect(RandomFactor.koLabel(2), equals('저난수'));
      expect(RandomFactor.koLabel(0), isNull);
    });
  });
}
