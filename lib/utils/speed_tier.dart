import 'stat_calculator.dart';
import '../models/nature.dart';
import '../models/stats.dart';

/// Precomputed speed tier table for a given level.
/// Maps base speed → (최속, 준속) actual speed values.
class SpeedTierTable {
  final int level;
  final List<int> maxSpeed;    // 최속: 31IV, 252EV, +Speed nature
  final List<int> neutralSpeed; // 준속: 31IV, 252EV, neutral nature

  SpeedTierTable._(this.level, this.maxSpeed, this.neutralSpeed);

  /// Build table for base speeds 1~255.
  /// Index 0 = base speed 1, index 254 = base speed 255.
  factory SpeedTierTable.forLevel(int level) {
    final maxIv = const Stats(hp: 31, attack: 31, defense: 31,
        spAttack: 31, spDefense: 31, speed: 31);
    final maxEv = const Stats(hp: 0, attack: 0, defense: 0,
        spAttack: 0, spDefense: 0, speed: 252);

    final maxList = <int>[];
    final neutralList = <int>[];

    for (int base = 1; base <= 255; base++) {
      final baseStats = Stats(hp: 1, attack: 1, defense: 1,
          spAttack: 1, spDefense: 1, speed: base);

      final maxSpd = StatCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: maxEv,
        nature: Nature.jolly, // +Speed
        level: level,
      ).speed;

      final neutralSpd = StatCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: maxEv,
        nature: Nature.hardy, // neutral
        level: level,
      ).speed;

      maxList.add(maxSpd);
      neutralList.add(neutralSpd);
    }

    return SpeedTierTable._(level, maxList, neutralList);
  }

  /// Find what speed tier [effSpeed] corresponds to.
  /// Returns a human-readable string like "최속 100족 추월" or "준속 130족 상회".
  String describe(int effSpeed) {
    // Find highest base speed where 최속 < effSpeed
    int? maxTier;
    for (int base = 255; base >= 1; base--) {
      if (maxSpeed[base - 1] < effSpeed) {
        maxTier = base;
        break;
      }
    }

    // Find highest base speed where 최속 == effSpeed (동속)
    int? maxTie;
    for (int base = 255; base >= 1; base--) {
      if (maxSpeed[base - 1] == effSpeed) {
        maxTie = base;
        break;
      }
    }

    // Find highest base speed where 준속 < effSpeed
    int? neutralTier;
    for (int base = 255; base >= 1; base--) {
      if (neutralSpeed[base - 1] < effSpeed) {
        neutralTier = base;
        break;
      }
    }

    // Find highest base speed where 준속 == effSpeed (동속)
    int? neutralTie;
    for (int base = 255; base >= 1; base--) {
      if (neutralSpeed[base - 1] == effSpeed) {
        neutralTie = base;
        break;
      }
    }

    // Pick the most informative description
    final parts = <String>[];

    if (maxTie != null) {
      parts.add('최속$maxTie족');
    } else if (maxTier != null) {
      parts.add('최속${maxTier}족 추월');
    }

    if (neutralTie != null && neutralTie != maxTie) {
      parts.add('준속$neutralTie족');
    } else if (neutralTier != null && neutralTier != maxTier) {
      parts.add('준속${neutralTier}족 추월');
    }

    return parts.join(' / ');
  }
}

/// Cache of speed tier tables by level.
final Map<int, SpeedTierTable> _cache = {};

/// Get or create a speed tier table for the given level.
SpeedTierTable getSpeedTierTable(int level) {
  return _cache.putIfAbsent(level, () => SpeedTierTable.forLevel(level));
}
