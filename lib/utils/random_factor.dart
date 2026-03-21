/// Pokemon damage random factor (난수).
///
/// In Gen V+, after base damage is calculated and floored,
/// a random integer from 85 to 100 (inclusive, 16 values) is
/// multiplied and then divided by 100 (with floor).
///
/// This creates a ±7.5% variance in final damage.
class RandomFactor {
  /// Minimum random roll (85/100 = 0.85)
  static const int minRoll = 85;

  /// Maximum random roll (100/100 = 1.00)
  static const int maxRoll = 100;

  /// Total number of possible rolls
  static const int rollCount = maxRoll - minRoll + 1; // 16

  /// Apply a specific random roll (85~100) to a damage value.
  /// Returns floor(damage * roll / 100).
  static int apply(int damage, int roll) {
    assert(roll >= minRoll && roll <= maxRoll);
    return damage * roll ~/ 100;
  }

  /// Returns all 16 possible damage values for a given base damage.
  static List<int> allRolls(int damage) {
    return [for (int r = minRoll; r <= maxRoll; r++) apply(damage, r)];
  }

  /// Returns (min, max) damage after random factor.
  static ({int min, int max}) range(int damage) {
    return (min: apply(damage, minRoll), max: apply(damage, maxRoll));
  }

  /// Given a damage value and defender HP, returns how many rolls (out of 16)
  /// result in a KO (damage >= hp).
  static int koRolls(int damage, int hp) {
    int count = 0;
    for (int r = minRoll; r <= maxRoll; r++) {
      if (apply(damage, r) >= hp) count++;
    }
    return count;
  }

  /// Describes the KO chance based on roll count out of total combinations.
  /// Returns: "확정" if 100%, "난수" if partial, or null if 0%.
  static String? koLabel(int koCount, int totalCount) {
    if (koCount <= 0) return null;
    if (koCount >= totalCount) return '확정';
    return '난수';
  }

  /// Calculate N-hit KO information.
  ///
  /// Returns the minimum N where at least one random combination results in KO,
  /// and the number of successful combinations out of total for that N.
  ///
  /// For N=1: 16 combinations (one roll)
  /// For N=2: 256 combinations (16×16)
  /// For N=3: 4096 combinations (16^3)
  /// Caps at N=4 for performance (65536 combinations).
  static ({int hits, int koCount, int totalCount}) nHitKo(int baseDamage, int hp) {
    if (baseDamage <= 0 || hp <= 0) return (hits: 0, koCount: 0, totalCount: 1);

    // Check 1-hit KO
    final oneHitKo = koRolls(baseDamage, hp);
    if (oneHitKo > 0) {
      return (hits: 1, koCount: oneHitKo, totalCount: rollCount);
    }

    // Check 2-hit KO (16×16 = 256 combinations)
    int twoHitKo = 0;
    for (int r1 = minRoll; r1 <= maxRoll; r1++) {
      for (int r2 = minRoll; r2 <= maxRoll; r2++) {
        if (apply(baseDamage, r1) + apply(baseDamage, r2) >= hp) {
          twoHitKo++;
        }
      }
    }
    if (twoHitKo > 0) {
      return (hits: 2, koCount: twoHitKo, totalCount: rollCount * rollCount);
    }

    // Check 3-hit KO (16^3 = 4096 combinations)
    int threeHitKo = 0;
    for (int r1 = minRoll; r1 <= maxRoll; r1++) {
      final d1 = apply(baseDamage, r1);
      for (int r2 = minRoll; r2 <= maxRoll; r2++) {
        final d12 = d1 + apply(baseDamage, r2);
        for (int r3 = minRoll; r3 <= maxRoll; r3++) {
          if (d12 + apply(baseDamage, r3) >= hp) {
            threeHitKo++;
          }
        }
      }
    }
    if (threeHitKo > 0) {
      return (hits: 3, koCount: threeHitKo, totalCount: rollCount * rollCount * rollCount);
    }

    // For 4+ hits, use min/max damage to estimate
    final minDmg = apply(baseDamage, minRoll);
    final maxDmg = apply(baseDamage, maxRoll);
    if (maxDmg <= 0) return (hits: 0, koCount: 0, totalCount: 1);

    // Guaranteed N-hit with min damage
    final guaranteedHits = (hp / minDmg).ceil();
    // Best case N-hit with max damage
    final bestHits = (hp / maxDmg).ceil();

    if (guaranteedHits == bestHits) {
      // All rolls result in same hit count = 확정
      return (hits: guaranteedHits, koCount: 1, totalCount: 1);
    }

    // It's a 난수 situation at bestHits
    return (hits: bestHits, koCount: 1, totalCount: 2); // approximate
  }
}
