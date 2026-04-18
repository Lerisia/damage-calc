import 'dart:math' as math;

import '../models/stats.dart';
import '../models/status.dart';
import '../models/nature.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'damage_calculator.dart' show kStandardStab, kCriticalMultiplier,
    kStellarStabMatching, kStellarStabNonMatching, kTeraMinPower, kBurnDamageReduction;
import 'move_transform.dart';
import 'stat_calculator.dart';
import 'terrain_effects.dart';
import 'weather_effects.dart';

/// Terastal STAB: same original type + tera type
const double kTeraStabSameType = 2.0;

/// Terastal STAB: same original type + tera type + Adaptability
const double kTeraStabSameTypeWithOverride = 2.25;

/// Calculates offensive power from a [TransformedMove].
///
/// Move transformations (power, type, stat selection) should be done via
/// [transformMove] in move_transform.dart before calling this.
///
/// [statModifier] is applied to the attack stat (e.g. Choice Band).
/// [powerModifier] is applied to the final result (e.g. Life Orb).
/// Returns 0 for status moves.
class OffensiveCalculator {

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
    bool defenderGrounded = true,
    StatusCondition status = StatusCondition.none,
    bool hasGuts = false,
    double? stabOverride,
    double? criticalOverride,
    bool forceStab = false,
    int? opponentAttack,
    bool terastallized = false,
    PokemonType? teraType,
    bool spreadTargets = false,
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

    final int rawStat = transformed.resolveStat(actualStats, opponentAttack: opponentAttack);
    final int modifiedStat = (rawStat * statModifier).floor();

    // Protean/Libero: force STAB on all moves, but NOT during Terastal
    final bool isOriginalStab = (forceStab && !terastallized) || move.type == type1 || move.type == type2;
    final bool isTeraStab = terastallized && teraType != null && move.type == teraType;

    // Determine STAB multiplier
    double stabMult = 1.0;
    if (terastallized && teraType != null) {
      if (teraType == PokemonType.stellar) {
        // Stellar: original STAB -> 2.0, non-STAB -> 1.2
        stabMult = isOriginalStab ? kStellarStabMatching : kStellarStabNonMatching;
      } else if (isTeraStab && isOriginalStab) {
        stabMult = stabOverride != null ? kTeraStabSameTypeWithOverride : kTeraStabSameType;
      } else if (isTeraStab) {
        stabMult = stabOverride ?? kStandardStab;
      } else if (isOriginalStab) {
        // Adaptability does NOT apply to original-type STAB after Tera
        stabMult = kStandardStab;
      }
    } else {
      stabMult = isOriginalStab ? (stabOverride ?? kStandardStab) : 1.0;
    }

    // Terastal minimum power: moves below 60 power become 60
    // Exceptions: multi-hit moves and priority moves are not boosted
    final int effectivePower = (terastallized && isTeraStab
        && !move.isMultiHit && move.priority <= 0
        && move.power < kTeraMinPower && move.power > 0)
        ? kTeraMinPower : move.power;

    final double weatherMod = getWeatherOffensiveModifier(weather, move: move);
    final double terrainMod = getTerrainModifier(terrain,
        move: move, attackerGrounded: grounded, defenderGrounded: defenderGrounded);

    // Burn halves physical damage unless Guts negates it
    final double burnMod =
        (status == StatusCondition.burn &&
         move.category == MoveCategory.physical &&
         !hasGuts)
            ? kBurnDamageReduction
            : 1.0;

    // Parental Bond for 결정력: single-value approximation of 2-hit (1x + 0.25x).
    // Damage calculator handles the actual per-hit split separately.
    final double parentalBondMod = move.hasTag(MoveTags.parentalBond) ? 1.25 : 1.0;
    // Doubles spread reduction — mirrors damage_calculator's kSpreadMultiplier.
    final double spreadMod =
        (spreadTargets && move.hasTag(MoveTags.spread)) ? 0.75 : 1.0;

    final double raw = modifiedStat *
        effectivePower *
        stabMult *
        (isCritical ? (criticalOverride ?? kCriticalMultiplier) : 1.0) *
        weatherMod *
        terrainMod *
        burnMod *
        powerModifier *
        parentalBondMod *
        spreadMod;

    return raw.floor();
  }
}
