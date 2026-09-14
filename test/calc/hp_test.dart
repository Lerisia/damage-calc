import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/calc/hp.dart';

/// HP is an integer; the stored share only remembers the user's
/// intent. Every conversion goes through calc/hp.dart so a share no
/// real HP can produce never shows up anywhere.
void main() {
  test('a typed share lands on the nearest achievable HP', () {
    expect(currentHpOf(175, 33), 58); // 57.75
    expect(currentHpOf(175, 50), 88); // 87.5 → half away from zero
    expect(currentHpOf(187, 40), 75); // 74.8
    expect(currentHpOf(187, 100), 187);
    expect(currentHpOf(187, 0), 0);
  });

  test('clamps to 0…max and tolerates a zero max', () {
    expect(currentHpOf(187, 150), 187);
    expect(currentHpOf(187, -5), 0);
    expect(currentHpOf(0, 50), 0);
    expect(hpPercentOf(0, 0), 100);
  });

  test('real HP → share → HP round-trips exactly', () {
    for (final max in [1, 2, 3, 175, 187, 256, 341, 714]) {
      for (var hp = 0; hp <= max; hp++) {
        expect(currentHpOf(max, hpPercentOf(max, hp)), hp, reason: '$hp/$max');
      }
    }
  });

  test('snapping shows the share of the integer, not the typed one', () {
    expect(snapHpPercent(175, 33), closeTo(33.142857, 1e-6));
    expect(snapHpPercent(175, 100), 100);
  });

  test('"1/3 or less" is exact on integers, like the game', () {
    // 58 × 3 = 174 ≤ 175 → in pinch; 59 × 3 = 177 → not.
    expect(hpAtOrBelowThird(hpPercentOf(175, 58)), isTrue);
    expect(hpAtOrBelowThird(hpPercentOf(175, 59)), isFalse);
    // Exactly a third (max divisible by 3) counts, float noise or not.
    expect(hpAtOrBelowThird(hpPercentOf(180, 60)), isTrue);
    expect(hpAtOrBelowThird(hpPercentOf(180, 61)), isFalse);
    expect(hpAtOrBelowThird(33), isTrue);
    expect(hpAtOrBelowThird(34), isFalse);
  });
}
