import '../models/stats.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import 'stat_calculator.dart';

/// Calculates defensive bulk (내구) as HP * Defense or HP * SpDefense.
class DefensiveCalculator {
  static ({int physical, int special}) calculate({
    required Stats baseStats,
    required Stats iv,
    required Stats ev,
    required Nature nature,
    required int level,
    Rank rank = const Rank(),
  }) {
    final actualStats = StatCalculator.calculate(
      baseStats: baseStats,
      iv: iv,
      ev: ev,
      nature: nature,
      level: level,
      rank: rank,
    );

    return (
      physical: actualStats.hp * actualStats.defense,
      special: actualStats.hp * actualStats.spDefense,
    );
  }
}
