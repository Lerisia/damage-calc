import 'dart:math' as math;

import '../models/move.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import 'grounded.dart';
import 'move_transform.dart';
import 'stat_calculator.dart';
import 'type_effectiveness.dart';
import 'weather_effects.dart';
import 'terrain_effects.dart';

/// Result of a damage calculation
class DamageResult {
  final int minDamage;
  final int maxDamage;
  final double minPercent;
  final double maxPercent;
  final double effectiveness;
  final int hits; // how many hits to KO (0 = can't KO)

  const DamageResult({
    required this.minDamage,
    required this.maxDamage,
    required this.minPercent,
    required this.maxPercent,
    required this.effectiveness,
    required this.hits,
  });
}

/// Calculates actual damage range using the Gen V+ damage formula.
///
/// damage = floor(floor(floor((2*Lv/5+2) * Power * A/D) / 50 + 2) * modifiers)
/// The random factor ranges from 0.85 to 1.00 (16 rolls).
class DamageCalculator {
  static DamageResult calculate({
    // Attacker
    required Stats atkBaseStats,
    required Stats atkIv,
    required Stats atkEv,
    required Nature atkNature,
    required int atkLevel,
    required PokemonType atkType1,
    PokemonType? atkType2,
    Rank atkRank = const Rank(),
    String? atkAbility,
    String? atkItem,
    StatusCondition atkStatus = StatusCondition.none,
    int atkHpPercent = 100,
    // Attacker ally boosts
    double atkStatModifier = 1.0,
    double atkPowerModifier = 1.0,
    // Move
    required TransformedMove transformed,
    bool isCritical = false,
    int? opponentAttack,
    // Defender
    required Stats defBaseStats,
    required Stats defIv,
    required Stats defEv,
    required Nature defNature,
    required int defLevel,
    required PokemonType defType1,
    PokemonType? defType2,
    Rank defRank = const Rank(),
    String? defAbility,
    String? defItem,
    bool defFinalEvo = true,
    StatusCondition defStatus = StatusCondition.none,
    // Battle conditions
    Weather weather = Weather.none,
    Terrain terrain = Terrain.none,
    RoomConditions room = const RoomConditions(),
    bool atkGrounded = true,
    // STAB/crit overrides
    double? stabOverride,
    double? criticalOverride,
    bool hasGuts = false,
  }) {
    final move = transformed.move;

    if (move.category == MoveCategory.status || move.power == 0) {
      return const DamageResult(
        minDamage: 0, maxDamage: 0,
        minPercent: 0, maxPercent: 0,
        effectiveness: 1.0, hits: 0,
      );
    }

    // --- Attacker stat ---
    final atkStat = transformed.offensiveStat;
    final effectiveAtkRank = isCritical
        ? Rank(
            attack: atkStat == OffensiveStat.attack || atkStat == OffensiveStat.higherAttack
                ? math.max(0, atkRank.attack) : atkRank.attack,
            defense: atkStat == OffensiveStat.defense
                ? math.max(0, atkRank.defense) : atkRank.defense,
            spAttack: atkStat == OffensiveStat.spAttack || atkStat == OffensiveStat.higherAttack
                ? math.max(0, atkRank.spAttack) : atkRank.spAttack,
            spDefense: atkRank.spDefense,
            speed: atkRank.speed,
          )
        : atkRank;

    final atkActual = StatCalculator.calculate(
      baseStats: atkBaseStats, iv: atkIv, ev: atkEv,
      nature: atkNature, level: atkLevel, rank: effectiveAtkRank,
    );

    final int rawAtk = transformed.resolveStat(atkActual, opponentAttack: opponentAttack);
    final int A = (rawAtk * atkStatModifier).floor();

    // --- Defender stat ---
    // Wonder Room swaps base Def/SpDef
    final effectiveDefBase = room.wonderRoom
        ? Stats(
            hp: defBaseStats.hp, attack: defBaseStats.attack,
            defense: defBaseStats.spDefense, spAttack: defBaseStats.spAttack,
            spDefense: defBaseStats.defense, speed: defBaseStats.speed,
          )
        : defBaseStats;

    // Critical hit: clamp positive defense rank to 0
    final effectiveDefRank = isCritical
        ? Rank(
            attack: defRank.attack,
            defense: math.min(0, defRank.defense),
            spAttack: defRank.spAttack,
            spDefense: math.min(0, defRank.spDefense),
            speed: defRank.speed,
          )
        : defRank;

    final defActual = StatCalculator.calculate(
      baseStats: effectiveDefBase, iv: defIv, ev: defEv,
      nature: defNature, level: defLevel, rank: effectiveDefRank,
    );

    final int D = move.category == MoveCategory.physical
        ? defActual.defense
        : defActual.spDefense;

    // --- Type effectiveness ---
    final double effectiveness = getCombinedEffectiveness(
      move.type, defType1, defType2,
    );

    if (effectiveness == 0.0) {
      return const DamageResult(
        minDamage: 0, maxDamage: 0,
        minPercent: 0, maxPercent: 0,
        effectiveness: 0.0, hits: 0,
      );
    }

    // --- STAB ---
    final bool isOriginalStab = move.type == atkType1 || move.type == atkType2;
    final double stab = isOriginalStab ? (stabOverride ?? 1.5) : 1.0;

    // --- Weather/Terrain ---
    final double weatherMod = getWeatherOffensiveModifier(weather, move: move);
    final double terrainMod = getTerrainModifier(terrain, move: move, grounded: atkGrounded);

    // --- Burn ---
    final double burnMod = (atkStatus == StatusCondition.burn &&
        move.category == MoveCategory.physical && !hasGuts) ? 0.5 : 1.0;

    // --- Critical ---
    final double critMod = isCritical ? (criticalOverride ?? 1.5) : 1.0;

    // --- Base damage (before random) ---
    final int level = atkLevel;
    final int power = move.power;
    final int baseDmg = ((2 * level ~/ 5 + 2) * power * A ~/ D) ~/ 50 + 2;

    // --- Apply modifiers ---
    final double modifiers = stab *
        effectiveness *
        weatherMod *
        terrainMod *
        burnMod *
        critMod *
        atkPowerModifier;

    // --- Random rolls (0.85 to 1.00, 16 values) ---
    final int maxDamage = (baseDmg * modifiers).floor();
    final int minDamage = (baseDmg * modifiers * 0.85).floor();

    // --- HP and percent ---
    final int defHp = StatCalculator.calculate(
      baseStats: defBaseStats, iv: defIv, ev: defEv,
      nature: defNature, level: defLevel,
    ).hp;

    final double minPct = defHp > 0 ? minDamage / defHp * 100 : 0;
    final double maxPct = defHp > 0 ? maxDamage / defHp * 100 : 0;

    // --- Hits to KO (using max damage for optimistic, could use min for pessimistic) ---
    final int hits = maxDamage > 0 ? (defHp / maxDamage).ceil() : 0;

    return DamageResult(
      minDamage: minDamage,
      maxDamage: maxDamage,
      minPercent: minPct,
      maxPercent: maxPct,
      effectiveness: effectiveness,
      hits: hits,
    );
  }
}
