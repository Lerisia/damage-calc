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
    bool hasItem = false,
    int hpPercent = 100,
  }) {
    if (move.category == MoveCategory.status) {
      return 0;
    }

    // Acrobatics: double power when not holding an item
    if (move.hasTag('custom:double_no_item') && !hasItem) {
      move = move.copyWith(power: move.power * 2);
    }

    // HP-based power (Eruption, Water Spout, Dragon Energy)
    if (move.hasTag('custom:hp_power_high')) {
      move = move.copyWith(power: math.max(1, (150 * hpPercent / 100).floor()));
    }

    // HP-based power (Flail, Reversal) - lower HP = higher power
    if (move.hasTag('custom:hp_power_low')) {
      move = move.copyWith(power: _flailPower(hpPercent));
    }

    // Terrain-based power boosts
    if (move.hasTag('custom:terrain_double_electric') && terrain == Terrain.electric) {
      move = move.copyWith(power: move.power * 2);
    }
    if (move.hasTag('custom:terrain_boost_psychic') && terrain == Terrain.psychic) {
      move = move.copyWith(power: (move.power * 1.5).floor());
    }
    if (move.hasTag('custom:terrain_boost_misty') && terrain == Terrain.misty) {
      move = move.copyWith(power: (move.power * 1.5).floor());
    }

    // Rank-based power (Stored Power, Power Trip): 20 + 20 per positive rank stage
    if (move.hasTag('custom:rank_power')) {
      final totalBoosts = [rank.attack, rank.defense, rank.spAttack, rank.spDefense, rank.speed]
          .where((r) => r > 0)
          .fold(0, (sum, r) => sum + r);
      move = move.copyWith(power: 20 + 20 * totalBoosts);
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

    // Determine which stat to use
    final int rawStat;
    if (move.hasTag('custom:use_defense')) {
      // Body Press: use Defense stat
      rawStat = actualStats.defense;
    } else if (move.hasTag('custom:use_higher_atk')) {
      // Photon Geyser, Shell Side Arm: use higher of Attack/Sp.Atk
      rawStat = math.max(actualStats.attack, actualStats.spAttack);
    } else {
      rawStat = isPhysical ? actualStats.attack : actualStats.spAttack;
    }
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

  /// Flail/Reversal power table based on HP percentage
  static int _flailPower(int hpPercent) {
    if (hpPercent >= 69) return 20;
    if (hpPercent >= 35) return 40;
    if (hpPercent >= 21) return 80;
    if (hpPercent >= 10) return 100;
    if (hpPercent >= 4) return 150;
    return 200;
  }
}
