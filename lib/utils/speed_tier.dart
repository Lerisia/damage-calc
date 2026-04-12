import 'app_strings.dart';
import 'stat_calculator.dart';
import '../models/nature.dart';
import '../models/stats.dart';

/// Precomputed speed tier table for a given level.
/// Maps base speed → (최속, 준속) actual speed values.
class SpeedTierTable {
  final int level;
  final List<int> maxSpeed;    // 최속: 31IV, 252EV, +Speed nature
  final List<int> neutralSpeed; // 준속: 31IV, 252EV, neutral nature
  final List<int> unboostedSpeed; // 무보정: 31IV, 0EV, neutral nature

  SpeedTierTable._(this.level, this.maxSpeed, this.neutralSpeed, this.unboostedSpeed);

  /// Build table for base speeds 1~255.
  /// Index 0 = base speed 1, index 254 = base speed 255.
  factory SpeedTierTable.forLevel(int level) {
    final maxIv = const Stats(hp: 31, attack: 31, defense: 31,
        spAttack: 31, spDefense: 31, speed: 31);
    final maxEv = const Stats(hp: 0, attack: 0, defense: 0,
        spAttack: 0, spDefense: 0, speed: 252);
    final zeroEv = const Stats(hp: 0, attack: 0, defense: 0,
        spAttack: 0, spDefense: 0, speed: 0);

    final maxList = <int>[];
    final neutralList = <int>[];
    final unboostedList = <int>[];

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

      final unboostedSpd = StatCalculator.calculate(
        baseStats: baseStats, iv: maxIv, ev: zeroEv,
        nature: Nature.hardy, // neutral, no investment
        level: level,
      ).speed;

      maxList.add(maxSpd);
      neutralList.add(neutralSpd);
      unboostedList.add(unboostedSpd);
    }

    return SpeedTierTable._(level, maxList, neutralList, unboostedList);
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

    // Find highest base speed where 무보정 < effSpeed
    int? unboostedTier;
    for (int base = 255; base >= 1; base--) {
      if (unboostedSpeed[base - 1] < effSpeed) {
        unboostedTier = base;
        break;
      }
    }

    // Find highest base speed where 무보정 == effSpeed (동속)
    int? unboostedTie;
    for (int base = 255; base >= 1; base--) {
      if (unboostedSpeed[base - 1] == effSpeed) {
        unboostedTie = base;
        break;
      }
    }

    // Pick the most informative description
    final parts = <String>[];

    if (maxTie != null) {
      parts.add(_formatTier('speed.maxSpeed', maxTie, 'speed.sameTier'));
    } else if (maxTier != null) {
      parts.add(_formatTier('speed.maxSpeed', maxTier, 'speed.outspeeds'));
    }

    if (neutralTie != null && neutralTie != maxTie) {
      parts.add(_formatTier('speed.neutralSpeed', neutralTie, 'speed.sameTier'));
    } else if (neutralTier != null && neutralTier != maxTier) {
      parts.add(_formatTier('speed.neutralSpeed', neutralTier, 'speed.outspeeds'));
    }

    if (unboostedTie != null && unboostedTie != maxTie && unboostedTie != neutralTie) {
      parts.add(_formatTier('speed.unboostedSpeed', unboostedTie, 'speed.sameTier'));
    } else if (unboostedTier != null && unboostedTier != maxTier && unboostedTier != neutralTier) {
      parts.add(_formatTier('speed.unboostedSpeed', unboostedTier, 'speed.outspeeds'));
    }

    return parts.join(' / ');
  }
  /// Format a speed tier phrase respecting language word order.
  /// ko/ja: "최속130족 추월" / "最速130族抜き"
  /// en:    "Outspeeds +Spe base 130" / "Ties +Spe base 130"
  static String _formatTier(String speedKey, int base, String relKey) {
    final lang = AppStrings.current;
    final speedLabel = AppStrings.t(speedKey);
    final relLabel = AppStrings.t(relKey);

    if (lang == AppLanguage.en) {
      final natureLabel = switch (speedKey) {
        'speed.maxSpeed' => '+Spe',
        'speed.neutralSpeed' => 'Neutral',
        _ => 'Uninvested',
      };
      // Capitalize relation: "Outspeeds" / "Ties"
      final rel = relLabel[0].toUpperCase() + relLabel.substring(1);
      return '$rel $natureLabel base $base';
    }

    // ko: "최속130족 추월", ja: "最速130族抜き"
    final suffix = lang == AppLanguage.ja ? '族' : '족';
    return '$speedLabel$base$suffix $relLabel';
  }
}

/// Cache of speed tier tables by level.
final Map<int, SpeedTierTable> _cache = {};

/// Get or create a speed tier table for the given level.
SpeedTierTable getSpeedTierTable(int level) {
  return _cache.putIfAbsent(level, () => SpeedTierTable.forLevel(level));
}
