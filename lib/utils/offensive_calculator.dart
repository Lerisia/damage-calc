import 'dart:math' as math;

import '../models/stats.dart';
import '../models/nature.dart';
import '../models/move.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'stat_calculator.dart';
import 'terrain_effects.dart';
import 'weather_effects.dart';

/// Calculates offensive power with stat modifier and power modifier.
///
/// Expects a pre-processed [move] (e.g. already transformed by weather/Z/Dynamax).
/// [rank] is applied via StatCalculator. On critical hit, negative attack rank is clamped to 0.
/// [statModifier] is applied to the attack stat (e.g. Choice Band). Floored before use.
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
    required Move move,
    required PokemonType type1,
    PokemonType? type2,
    Rank rank = const Rank(),
    Weather weather = Weather.none,
    Terrain terrain = Terrain.none,
    double statModifier = 1.0,
    double powerModifier = 1.0,
    bool isCritical = false,
  }) {
    if (move.category == MoveCategory.status) {
      return 0;
    }

    final bool isPhysical = move.category == MoveCategory.physical;

    // Critical hit: clamp negative attack rank to 0
    final effectiveRank = isCritical
        ? Rank(
            attack: isPhysical ? math.max(0, rank.attack) : rank.attack,
            defense: rank.defense,
            spAttack: isPhysical ? rank.spAttack : math.max(0, rank.spAttack),
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

    final rawStat = isPhysical ? actualStats.attack : actualStats.spAttack;
    final int modifiedStat = (rawStat * statModifier).floor();

    final bool hasStab = move.type == type1 || move.type == type2;
    final double weatherMod = getWeatherModifier(weather, move: move);
    final double terrainMod = getTerrainModifier(terrain, move: move);
    final double raw = modifiedStat *
        move.power *
        (hasStab ? _stabMultiplier : 1.0) *
        (isCritical ? _criticalMultiplier : 1.0) *
        weatherMod *
        terrainMod *
        powerModifier;

    return raw.floor();
  }
}
