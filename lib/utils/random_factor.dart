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

  /// Describes the KO chance based on roll count.
  /// Returns: "확정" (16/16), "고난수" (13-15/16), "난수" (5-12/16),
  /// "저난수" (1-4/16), or null if 0/16.
  static String? koLabel(int koRollCount) {
    if (koRollCount == rollCount) return '확정';
    if (koRollCount >= 13) return '고난수';
    if (koRollCount >= 5) return '난수';
    if (koRollCount >= 1) return '저난수';
    return null;
  }
}
