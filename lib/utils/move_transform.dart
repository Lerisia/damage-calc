import 'dart:math' as math;

import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/rank.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';

/// Which stat the move should use for offense
enum OffensiveStat {
  attack,
  spAttack,
  defense,
  higherAttack,
  opponentAttack,
}

/// Context for move transformation
class MoveContext {
  final Weather weather;
  final Terrain terrain;
  final Rank rank;
  final int hpPercent;
  final bool hasItem;

  final String? ability;
  final StatusCondition status;

  const MoveContext({
    this.weather = Weather.none,
    this.terrain = Terrain.none,
    this.rank = const Rank(),
    this.hpPercent = 100,
    this.hasItem = false,
    this.ability,
    this.status = StatusCondition.none,
  });
}

/// Result of move transformation: the modified move + which stat to use
class TransformedMove {
  final Move move;
  final OffensiveStat offensiveStat;

  const TransformedMove(this.move, this.offensiveStat);

  /// Resolve the actual stat value from calculated stats.
  /// [opponentAttack] is needed for Foul Play (uses opponent's Attack stat).
  int resolveStat(Stats actualStats, {int? opponentAttack}) {
    switch (offensiveStat) {
      case OffensiveStat.attack:
        return actualStats.attack;
      case OffensiveStat.spAttack:
        return actualStats.spAttack;
      case OffensiveStat.defense:
        return actualStats.defense;
      case OffensiveStat.higherAttack:
        return math.max(actualStats.attack, actualStats.spAttack);
      case OffensiveStat.opponentAttack:
        return opponentAttack ?? actualStats.attack;
    }
  }
}

/// Applies all move transformations based on battle context.
///
/// Order matters:
/// 1. Type-changing transforms (Weather Ball, Terrain Pulse)
/// 2. Ability type transforms (-ate skins: only affects Normal moves)
/// 3. Conditional power changes (Acrobatics, HP-based)
/// 4. Field-based power boosts (Rising Voltage, etc.)
/// 5. Rank-based power (Stored Power, etc.)
/// 6. Stat selection (Body Press, Photon Geyser, etc.)
TransformedMove transformMove(Move move, MoveContext context) {
  // 1. Type-changing transforms first
  move = _applyWeather(move, context.weather);
  move = _applyTerrain(move, context.terrain);

  // 2. Ability type transforms (only if still Normal after step 1)
  move = _applySkin(move, context.ability);

  // 3. Conditional power changes
  move = _applyItemCondition(move, context.hasItem);
  move = _applyHpPower(move, context.hpPercent);
  move = _applyStatusPower(move, context.status);

  // 4. Field-based power boosts
  move = _applyTerrainPowerBoost(move, context.terrain);

  // 5. Rank-based power
  move = _applyRankPower(move, context.rank);

  // 6. Stat selection
  final stat = _resolveOffensiveStat(move);
  return TransformedMove(move, stat);
}

/// Determine which stat the move uses
OffensiveStat _resolveOffensiveStat(Move move) {
  if (move.hasTag(MoveTags.useDefense)) return OffensiveStat.defense;
  if (move.hasTag(MoveTags.useHigherAtk)) return OffensiveStat.higherAttack;
  if (move.hasTag(MoveTags.useOpponentAtk)) return OffensiveStat.opponentAttack;
  return move.category == MoveCategory.physical
      ? OffensiveStat.attack
      : OffensiveStat.spAttack;
}

/// -ate abilities: convert Normal moves to another type with 1.2x power.
const Map<String, PokemonType> _skinAbilities = {
  'Aerilate': PokemonType.flying,
  'Pixilate': PokemonType.fairy,
  'Refrigerate': PokemonType.ice,
  'Galvanize': PokemonType.electric,
  'Normalize': PokemonType.normal,
};

Move _applySkin(Move move, String? ability) {
  if (ability == null) return move;

  // Normalize: ALL moves become Normal (not just Normal moves)
  if (ability == 'Normalize') {
    if (move.type == PokemonType.normal) return move;
    return move.copyWith(type: PokemonType.normal, power: (move.power * 1.2).floor());
  }

  // Other skins: only Normal moves get converted
  final skinType = _skinAbilities[ability];
  if (skinType == null || move.type != PokemonType.normal) return move;

  return move.copyWith(type: skinType, power: (move.power * 1.2).floor());
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
  if (move.hasTag(MoveTags.doubleNoItem) && !hasItem) {
    return move.copyWith(power: move.power * 2);
  }
  return move;
}

/// HP-based power: Eruption/Water Spout/Dragon Energy, Flail/Reversal.
Move _applyHpPower(Move move, int hpPercent) {
  if (move.hasTag(MoveTags.hpPowerHigh)) {
    return move.copyWith(power: math.max(1, (150 * hpPercent / 100).floor()));
  }
  if (move.hasTag(MoveTags.hpPowerLow)) {
    return move.copyWith(power: _flailPower(hpPercent));
  }
  return move;
}

/// Facade: doubles power when burned, poisoned, or paralyzed.
Move _applyStatusPower(Move move, StatusCondition status) {
  if (move.hasTag(MoveTags.facade) && status != StatusCondition.none) {
    final isAffected = status == StatusCondition.burn ||
        status == StatusCondition.poison ||
        status == StatusCondition.badlyPoisoned ||
        status == StatusCondition.paralysis;
    if (isAffected) {
      return move.copyWith(power: move.power * 2);
    }
  }
  return move;
}

/// Terrain-based power boosts: Rising Voltage, Expanding Force, Misty Explosion.
Move _applyTerrainPowerBoost(Move move, Terrain terrain) {
  if (move.hasTag(MoveTags.terrainDoubleElectric) && terrain == Terrain.electric) {
    return move.copyWith(power: move.power * 2);
  }
  if (move.hasTag(MoveTags.terrainBoostPsychic) && terrain == Terrain.psychic) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }
  if (move.hasTag(MoveTags.terrainBoostMisty) && terrain == Terrain.misty) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }
  return move;
}

/// Rank-based power: Stored Power, Power Trip.
Move _applyRankPower(Move move, Rank rank) {
  if (move.hasTag(MoveTags.rankPower)) {
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
