import 'dart:math' as math;

import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/gender.dart';
import '../models/move.dart';
import '../models/rank.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'grounded.dart';
import 'item_effects.dart';
import 'move_transform.dart';
import 'offensive_calculator.dart';
import 'defensive_calculator.dart';
import 'speed_calculator.dart';
import 'stat_calculator.dart';

/// Items nullified during Dynamax.
const dmaxNullItems = {'choice-band', 'choice-specs', 'choice-scarf'};

/// Abilities nullified during Dynamax.
const dmaxNullAbilities = {'Gorilla Tactics', 'Sheer Force'};

/// Display-ready information for a single move slot.
class MoveSlotInfo {
  /// Transformed move name (e.g. 다이번 for Dynamax Fire move).
  final String? displayName;

  /// Effective type after all transformations.
  final PokemonType? effectiveType;

  /// Effective category after overrides.
  final MoveCategory? effectiveCategory;

  /// Base power after transformation (before user override).
  final int basePower;

  /// Final power (user override or basePower).
  final int effectivePower;

  /// 결정력 result, null when no move is set.
  final int? offensivePower;

  const MoveSlotInfo({
    this.displayName,
    this.effectiveType,
    this.effectiveCategory,
    this.basePower = 0,
    this.effectivePower = 0,
    this.offensivePower,
  });
}

/// Facade that encapsulates all battle calculation logic.
///
/// Extracts business logic previously embedded in [PokemonPanel] so that
/// offensive power, defensive bulk, and effective speed can be computed
/// without any Flutter / UI dependency.
class BattleFacade {
  const BattleFacade._();

  // ------------------------------------------------------------------
  // Effective speed
  // ------------------------------------------------------------------

  /// Calculates effective speed for [state] under the given field conditions.
  static int calcSpeed({
    required BattlePokemonState state,
    required Weather weather,
    required Terrain terrain,
  }) {
    final stats = StatCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
      rank: state.rank,
    );
    return calcEffectiveSpeed(
      baseSpeed: stats.speed,
      ability: state.selectedAbility,
      item: state.selectedItem,
      status: state.status,
      weather: weather,
      terrain: terrain,
      isDynamaxed: state.dynamax != DynamaxState.none,
      tailwind: state.tailwind,
    );
  }

  // ------------------------------------------------------------------
  // Move slot info (display + 결정력)
  // ------------------------------------------------------------------

  /// Returns all display-ready info for the move at [moveIndex],
  /// including the 결정력 result.
  static MoveSlotInfo getMoveSlotInfo({
    required BattlePokemonState state,
    required int moveIndex,
    required Weather weather,
    required Terrain terrain,
    required RoomConditions room,
    int? opponentSpeed,
    int? opponentAttack,
    Gender opponentGender = Gender.unset,
    int? myEffectiveSpeed,
  }) {
    final move = state.moves[moveIndex];
    if (move == null) {
      return const MoveSlotInfo();
    }

    // Compute base stats once for this slot
    final baseStats = _baseActualStats(state);

    // Transform for display (name, type, power)
    final ctx = _buildMoveContext(
      state: state,
      weather: weather,
      terrain: terrain,
      actualStats: baseStats,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentSpeed: opponentSpeed,
    );
    final transformed = transformMove(move, ctx);

    final effectiveType = state.typeOverrides[moveIndex] ?? transformed.move.type;
    final effectiveCategory = state.categoryOverrides[moveIndex] ?? transformed.move.category;
    final basePower = transformed.move.power;
    final effectivePower = state.powerOverrides[moveIndex] ?? basePower;
    final displayName = transformed.move.nameKo;

    // 결정력
    final offensivePower = _calcOffensivePower(
      state: state,
      move: move,
      isCritical: state.criticals[moveIndex],
      typeOverride: state.typeOverrides[moveIndex],
      categoryOverride: state.categoryOverrides[moveIndex],
      powerOverride: state.powerOverrides[moveIndex],
      weather: weather,
      terrain: terrain,
      room: room,
      opponentSpeed: opponentSpeed,
      opponentAttack: opponentAttack,
      opponentGender: opponentGender,
      myEffectiveSpeed: myEffectiveSpeed,
    );

    return MoveSlotInfo(
      displayName: displayName,
      effectiveType: effectiveType,
      effectiveCategory: effectiveCategory,
      basePower: basePower,
      effectivePower: effectivePower,
      offensivePower: offensivePower,
    );
  }

  // ------------------------------------------------------------------
  // Offensive power (결정력) — standalone
  // ------------------------------------------------------------------

  /// Calculates 결정력 for the move at [moveIndex] of [state].
  ///
  /// Returns `null` when the slot has no move assigned.
  static int? calcOffensivePower({
    required BattlePokemonState state,
    required int moveIndex,
    required Weather weather,
    required Terrain terrain,
    required RoomConditions room,
    int? opponentSpeed,
    int? opponentAttack,
    Gender opponentGender = Gender.unset,
    int? myEffectiveSpeed,
  }) {
    return _calcOffensivePower(
      state: state,
      move: state.moves[moveIndex],
      isCritical: state.criticals[moveIndex],
      typeOverride: state.typeOverrides[moveIndex],
      categoryOverride: state.categoryOverrides[moveIndex],
      powerOverride: state.powerOverrides[moveIndex],
      weather: weather,
      terrain: terrain,
      room: room,
      opponentSpeed: opponentSpeed,
      opponentAttack: opponentAttack,
      opponentGender: opponentGender,
      myEffectiveSpeed: myEffectiveSpeed,
    );
  }

  static int? _calcOffensivePower({
    required BattlePokemonState state,
    required Move? move,
    required bool isCritical,
    PokemonType? typeOverride,
    MoveCategory? categoryOverride,
    int? powerOverride,
    required Weather weather,
    required Terrain terrain,
    required RoomConditions room,
    int? opponentSpeed,
    int? opponentAttack,
    Gender opponentGender = Gender.unset,
    int? myEffectiveSpeed,
  }) {
    if (move == null) return null;

    move = move.copyWith(
      type: typeOverride,
      power: powerOverride,
      category: categoryOverride,
    );

    // Compute base stats once — reused by MoveContext and ability effects.
    final baseStats = _baseActualStats(state);

    // 1. Transform the move (type/power changes based on context)
    final ctx = _buildMoveContext(
      state: state,
      weather: weather,
      terrain: terrain,
      actualStats: baseStats,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentSpeed: opponentSpeed,
    );
    final transformed = transformMove(move, ctx);

    // 2. Resolve item/ability effects (Dynamax nullification applied)
    final isDmaxed = state.dynamax != DynamaxState.none;

    final effectiveItem =
        (isDmaxed && dmaxNullItems.contains(state.selectedItem))
            ? null
            : state.selectedAbility == 'Klutz'
                ? null
                : state.selectedItem;
    final itemEffect = effectiveItem != null
        ? getItemEffect(effectiveItem,
            move: transformed.move, pokemonName: state.pokemonName)
        : const ItemEffect();

    final effectiveAbility =
        (isDmaxed && dmaxNullAbilities.contains(state.selectedAbility))
            ? null
            : state.selectedAbility;
    final abilityEffect = effectiveAbility != null
        ? getAbilityEffect(effectiveAbility,
            move: transformed.move,
            originalBasePower: isDmaxed ? null : move.power,
            hpPercent: state.hpPercent,
            weather: weather,
            terrain: terrain,
            status: state.status,
            heldItem: effectiveItem,
            opponentSpeed: opponentSpeed,
            myGender: state.gender,
            opponentGender: opponentGender,
            actualStats: baseStats)
        : const AbilityEffect();

    // 3. Determine stat modifier based on the offensive stat used
    final double abilityStatMod = _resolveAbilityStatMod(
      transformed.offensiveStat,
      abilityEffect.statModifiers,
    );

    final double statMod = itemEffect.statModifier * abilityStatMod;
    double powerMod = itemEffect.powerModifier * abilityEffect.powerModifier;

    // Charge: Electric moves deal 2x damage
    if (state.charge && transformed.move.type == PokemonType.electric) {
      powerMod *= 2.0;
    }

    // 4. Final calculation
    return OffensiveCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
      transformed: transformed,
      type1: state.type1,
      type2: state.type2,
      rank: state.rank,
      weather: weather,
      terrain: terrain,
      statModifier: statMod,
      powerModifier: powerMod,
      isCritical: isCritical,
      grounded: isGrounded(
        type1: state.type1,
        type2: state.type2,
        ability: state.selectedAbility,
        item: state.selectedItem,
        gravity: room.gravity,
      ),
      status: state.status,
      hasGuts: state.selectedAbility == 'Guts',
      stabOverride: abilityEffect.stabOverride,
      criticalOverride: abilityEffect.criticalOverride,
      forceStab: abilityEffect.forceStab,
      opponentAttack: opponentAttack,
      terastallized: state.terastal.active,
      teraType: state.terastal.teraType,
    );
  }

  // ------------------------------------------------------------------
  // Defensive bulk (내구)
  // ------------------------------------------------------------------

  /// Calculates physical and special bulk for [state].
  static ({int physical, int special}) calcBulk({
    required BattlePokemonState state,
    required Weather weather,
    Terrain terrain = Terrain.none,
    required RoomConditions room,
  }) {
    return DefensiveCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
      type1: state.type1,
      type2: state.type2,
      rank: state.rank,
      weather: weather,
      ability: state.selectedAbility,
      item: state.selectedAbility == 'Klutz' ? null : state.selectedItem,
      pokemonName: state.pokemonName,
      finalEvo: state.finalEvo,
      status: state.status,
      terrain: terrain,
      room: room,
      isDynamaxed: state.dynamax != DynamaxState.none,
    );
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Computes rank-less base stats for [state]. Use this single result
  /// across MoveContext, ability effects, etc. to avoid redundant calls.
  static Stats _baseActualStats(BattlePokemonState state) {
    return StatCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
    );
  }

  static MoveContext _buildMoveContext({
    required BattlePokemonState state,
    required Weather weather,
    required Terrain terrain,
    required Stats actualStats,
    int? myEffectiveSpeed,
    int? opponentSpeed,
  }) {
    // Tera Blast needs rank-applied stats for category comparison
    final rankedStats = state.rank != const Rank()
        ? StatCalculator.calculate(
            baseStats: state.baseStats,
            iv: state.iv,
            ev: state.ev,
            nature: state.nature,
            level: state.level,
            rank: state.rank,
          )
        : actualStats;

    return MoveContext(
      weather: weather,
      terrain: terrain,
      rank: state.rank,
      hpPercent: state.hpPercent,
      hasItem: state.selectedItem != null,
      ability: state.selectedAbility,
      status: state.status,
      dynamax: state.dynamax,
      pokemonName: state.pokemonName,
      terastallized: state.terastal.active,
      teraType: state.terastal.teraType,
      mySpeed: myEffectiveSpeed,
      opponentSpeed: opponentSpeed,
      actualAttack: rankedStats.attack,
      actualSpAttack: rankedStats.spAttack,
    );
  }

  static double _resolveAbilityStatMod(
    OffensiveStat stat,
    AbilityStatModifiers modifiers,
  ) {
    switch (stat) {
      case OffensiveStat.attack:
        return modifiers.attack;
      case OffensiveStat.spAttack:
        return modifiers.spAttack;
      case OffensiveStat.defense:
        return modifiers.defense;
      case OffensiveStat.higherAttack:
        return math.max(modifiers.attack, modifiers.spAttack);
      case OffensiveStat.opponentAttack:
        return 1.0;
    }
  }

}
