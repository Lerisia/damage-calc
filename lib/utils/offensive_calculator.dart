import 'dart:math' as math;

import '../models/stats.dart';
import '../models/nature.dart';
import '../models/move.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'move_transform.dart';
import 'stat_calculator.dart';
import 'terrain_effects.dart';
import 'weather_effects.dart';

/// Calculates offensive power from a [TransformedMove].
///
/// Move transformations (power, type, stat selection) should be done via
/// [transformMove] in move_transform.dart before calling this.
///
/// [statModifier] is applied to the attack stat (e.g. Choice Band).
/// [powerModifier] is applied to the final result (e.g. Life Orb).
/// Returns 0 for status moves.
class OffensiveCalculator {
  static const double _stabMultiplier = 1.5;
  static const double _criticalMultiplier = 1.5;

  static int calculate({
    required Stats baseStats,
    required Stats iv,
    required Stats ev,
    required Nature nature,
    required int level,
    required TransformedMove transformed,
    required PokemonType type1,
    PokemonType? type2,
    Rank rank = const Rank(),
    Weather weather = Weather.none,
    Terrain terrain = Terrain.none,
    double statModifier = 1.0,
    double powerModifier = 1.0,
    bool isCritical = false,
    bool grounded = true,
    double? stabOverride,
    double? criticalOverride,
  }) {
    final move = transformed.move;

    if (move.category == MoveCategory.status) {
      return 0;
    }

    final stat = transformed.offensiveStat;

    // Critical hit: clamp negative rank to 0 for the stat being used
    final effectiveRank = isCritical
        ? Rank(
            attack: stat == OffensiveStat.attack || stat == OffensiveStat.higherAttack
                ? math.max(0, rank.attack) : rank.attack,
            defense: stat == OffensiveStat.defense
                ? math.max(0, rank.defense) : rank.defense,
            spAttack: stat == OffensiveStat.spAttack || stat == OffensiveStat.higherAttack
                ? math.max(0, rank.spAttack) : rank.spAttack,
            spDefense: rank.spDefense,
            speed: rank.speed,
          )
        : rank;

    final actualStats = StatCalculator.calculate(
      baseStats: baseStats,
      iv: iv,
      ev: ev,
      nature: nature,
      level: level,
      rank: effectiveRank,
    );

    final int rawStat = transformed.resolveStat(actualStats);
    final int modifiedStat = (rawStat * statModifier).floor();

    final bool hasStab = move.type == type1 || move.type == type2;
    final double weatherMod = getWeatherModifier(weather, move: move);
    final double terrainMod = getTerrainModifier(terrain, move: move, grounded: grounded);
    final double raw = modifiedStat *
        move.power *
        (hasStab ? (stabOverride ?? _stabMultiplier) : 1.0) *
        (isCritical ? (criticalOverride ?? _criticalMultiplier) : 1.0) *
        weatherMod *
        terrainMod *
        powerModifier;

    return raw.floor();
  }
}
