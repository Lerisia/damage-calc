import '../models/rank.dart';
import '../models/stats.dart';
import '../models/nature.dart';

/// Calculates actual stats from base stats, IVs, EVs, nature, level, and rank.
///
/// Used across damage calculator, speed calculator, bulk calculator, etc.
class StatCalculator {
  static Stats calculate({
    required Stats baseStats,
    required Stats iv,
    required Stats ev,
    required Nature nature,
    required int level,
    Rank rank = const Rank(),
  }) {
    return Stats(
      hp: _calcHp(baseStats.hp, iv.hp, ev.hp, level),
      attack: _calcStat(baseStats.attack, iv.attack, ev.attack, level,
          nature.attackModifier, rank.attackMultiplier),
      defense: _calcStat(baseStats.defense, iv.defense, ev.defense, level,
          nature.defenseModifier, rank.defenseMultiplier),
      spAttack: _calcStat(baseStats.spAttack, iv.spAttack, ev.spAttack, level,
          nature.spAttackModifier, rank.spAttackMultiplier),
      spDefense: _calcStat(baseStats.spDefense, iv.spDefense, ev.spDefense,
          level, nature.spDefenseModifier, rank.spDefenseMultiplier),
      speed: _calcStat(baseStats.speed, iv.speed, ev.speed, level,
          nature.speedModifier, rank.speedMultiplier),
    );
  }

  /// HP = ((2 * base + iv + ev/4) * level / 100) + level + 10
  static int _calcHp(int base, int iv, int ev, int level) {
    return ((2 * base + iv + ev ~/ 4) * level ~/ 100) + level + 10;
  }

  /// Other stats = (((2 * base + iv + ev/4) * level / 100) + 5) * nature * rank
  static int _calcStat(
      int base, int iv, int ev, int level, double natureModifier, double rankMultiplier) {
    final int raw = ((2 * base + iv + ev ~/ 4) * level ~/ 100) + 5;
    return (raw * natureModifier * rankMultiplier).floor();
  }
}
