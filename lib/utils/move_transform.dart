import 'dart:math' as math;

import '../models/move.dart';
import '../models/rank.dart';
import '../models/stats.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';

/// Which stat the move should use for offense
enum OffensiveStat {
  attack,
  spAttack,
  defense,
  higherAttack,
}

/// Context for move transformation
class MoveContext {
  final Weather weather;
  final Terrain terrain;
  final Rank rank;
  final int hpPercent;
  final bool hasItem;

  const MoveContext({
    this.weather = Weather.none,
    this.terrain = Terrain.none,
    this.rank = const Rank(),
    this.hpPercent = 100,
    this.hasItem = false,
  });
}

/// Result of move transformation: the modified move + which stat to use
class TransformedMove {
  final Move move;
  final OffensiveStat offensiveStat;

  const TransformedMove(this.move, this.offensiveStat);

  /// Resolve the actual stat value from calculated stats
  int resolveStat(Stats actualStats) {
    switch (offensiveStat) {
      case OffensiveStat.attack:
        return actualStats.attack;
      case OffensiveStat.spAttack:
        return actualStats.spAttack;
      case OffensiveStat.defense:
        return actualStats.defense;
      case OffensiveStat.higherAttack:
        return math.max(actualStats.attack, actualStats.spAttack);
    }
  }
}

/// Applies all move transformations based on battle context.
///
/// Returns a [TransformedMove] with adjusted type/power and which stat to use.
TransformedMove transformMove(Move move, MoveContext context) {
  move = _applyWeather(move, context.weather);
  move = _applyTerrain(move, context.terrain);
  move = _applyItemCondition(move, context.hasItem);
  move = _applyHpPower(move, context.hpPercent);
  move = _applyTerrainPowerBoost(move, context.terrain);
  move = _applyRankPower(move, context.rank);

  final stat = _resolveOffensiveStat(move);
  return TransformedMove(move, stat);
}

/// Determine which stat the move uses
OffensiveStat _resolveOffensiveStat(Move move) {
  if (move.hasTag('custom:use_defense')) return OffensiveStat.defense;
  if (move.hasTag('custom:use_higher_atk')) return OffensiveStat.higherAttack;
  return move.category == MoveCategory.physical
      ? OffensiveStat.attack
      : OffensiveStat.spAttack;
}

/// Weather Ball: changes type and power based on weather.
Move _applyWeather(Move move, Weather weather) {
  if (move.name != 'Weather Ball' || weather == Weather.none) {
    return move;
  }

  final PokemonType weatherType;
  switch (weather) {
    case Weather.sun:
      weatherType = PokemonType.fire;
    case Weather.rain:
      weatherType = PokemonType.water;
    case Weather.sandstorm:
      weatherType = PokemonType.rock;
    case Weather.snow:
      weatherType = PokemonType.ice;
    default:
      return move;
  }

  return move.copyWith(type: weatherType, power: 100);
}

/// Terrain Pulse: changes type and power based on terrain.
Move _applyTerrain(Move move, Terrain terrain) {
  if (move.name != 'Terrain Pulse' || terrain == Terrain.none) {
    return move;
  }

  final PokemonType terrainType;
  switch (terrain) {
    case Terrain.electric:
      terrainType = PokemonType.electric;
    case Terrain.grassy:
      terrainType = PokemonType.grass;
    case Terrain.psychic:
      terrainType = PokemonType.psychic;
    case Terrain.misty:
      terrainType = PokemonType.fairy;
    default:
      return move;
  }

  return move.copyWith(type: terrainType, power: 100);
}

/// Acrobatics: double power when not holding an item.
Move _applyItemCondition(Move move, bool hasItem) {
  if (move.hasTag('custom:double_no_item') && !hasItem) {
    return move.copyWith(power: move.power * 2);
  }
  return move;
}

/// HP-based power: Eruption/Water Spout/Dragon Energy, Flail/Reversal.
Move _applyHpPower(Move move, int hpPercent) {
  if (move.hasTag('custom:hp_power_high')) {
    return move.copyWith(power: math.max(1, (150 * hpPercent / 100).floor()));
  }
  if (move.hasTag('custom:hp_power_low')) {
    return move.copyWith(power: _flailPower(hpPercent));
  }
  return move;
}

/// Terrain-based power boosts: Rising Voltage, Expanding Force, Misty Explosion.
Move _applyTerrainPowerBoost(Move move, Terrain terrain) {
  if (move.hasTag('custom:terrain_double_electric') && terrain == Terrain.electric) {
    return move.copyWith(power: move.power * 2);
  }
  if (move.hasTag('custom:terrain_boost_psychic') && terrain == Terrain.psychic) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }
  if (move.hasTag('custom:terrain_boost_misty') && terrain == Terrain.misty) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }
  return move;
}

/// Rank-based power: Stored Power, Power Trip.
Move _applyRankPower(Move move, Rank rank) {
  if (move.hasTag('custom:rank_power')) {
    final totalBoosts = [rank.attack, rank.defense, rank.spAttack, rank.spDefense, rank.speed]
        .where((r) => r > 0)
        .fold(0, (sum, r) => sum + r);
    return move.copyWith(power: 20 + 20 * totalBoosts);
  }
  return move;
}

/// Flail/Reversal power table.
int _flailPower(int hpPercent) {
  if (hpPercent >= 69) return 20;
  if (hpPercent >= 35) return 40;
  if (hpPercent >= 21) return 80;
  if (hpPercent >= 10) return 100;
  if (hpPercent >= 4) return 150;
  return 200;
}

// Legacy wrappers for backward compatibility with tests
Move applyWeatherToMove(Move move, Weather weather) => _applyWeather(move, weather);
Move applyTerrainToMove(Move move, Terrain terrain) => _applyTerrain(move, terrain);
