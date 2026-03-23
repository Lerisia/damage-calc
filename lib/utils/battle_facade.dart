import 'dart:math' as math;

import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/gender.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
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
import 'terrain_effects.dart';
import 'weather_effects.dart';

/// Items nullified during Dynamax.
const dmaxNullItems = {'choice-band', 'choice-specs', 'choice-scarf'};

/// Abilities nullified during Dynamax.
const dmaxNullAbilities = {'Gorilla Tactics', 'Sheer Force'};

/// Resolves the effective held item considering Klutz and Dynamax nullification.
String? resolveEffectiveItem({
  String? item, String? ability, bool isDynamaxed = false,
}) {
  if (ability == 'Klutz') return null;
  if (isDynamaxed && dmaxNullItems.contains(item)) return null;
  return item;
}

/// Resolves the effective ability considering Dynamax nullification.
String? resolveEffectiveAbility({
  String? ability, bool isDynamaxed = false,
}) {
  if (isDynamaxed && dmaxNullAbilities.contains(ability)) return null;
  return ability;
}

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

  /// Whether the move deals fixed damage (bypasses normal formula).
  final bool isFixedDamage;

  /// 결정력 result, null when no move is set.
  final int? offensivePower;

  const MoveSlotInfo({
    this.displayName,
    this.effectiveType,
    this.effectiveCategory,
    this.basePower = 0,
    this.effectivePower = 0,
    this.isFixedDamage = false,
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
    required RoomConditions room,
  }) {
    final stats = StatCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
      rank: state.rank,
    );
    // Cloud Nine / Air Lock / Teraform Zero negates weather/terrain
    final effWeather = isWeatherNegating(state.selectedAbility)
        ? Weather.none : weather;
    final effTerrain = isTerrainNegating(state.selectedAbility)
        ? Terrain.none : terrain;
    return calcEffectiveSpeed(
      baseSpeed: stats.speed,
      ability: state.selectedAbility,
      item: state.selectedItem,
      status: state.status,
      weather: effWeather,
      terrain: effTerrain,
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
    double? opponentWeight,
  }) {
    final move = state.moves[moveIndex];
    if (move == null) {
      return const MoveSlotInfo();
    }

    // Compute base stats once for this slot
    final baseStats = _baseActualStats(state);
    final hits = move.isMultiHit
        ? (state.hitOverrides[moveIndex] ?? move.maxHits) : null;

    // Transform for display (name, type, power)
    final ctx = _buildMoveContext(
      state: state,
      weather: weather,
      terrain: terrain,
      actualStats: baseStats,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentSpeed: opponentSpeed,
      opponentWeight: opponentWeight,
      hitCount: hits,
    );
    final transformed = transformMove(move, ctx);

    final effectiveType = state.typeOverrides[moveIndex] ?? transformed.move.type;
    final effectiveCategory = state.categoryOverrides[moveIndex] ?? transformed.move.category;
    final basePower = transformed.move.power;
    var effectivePower = state.powerOverrides[moveIndex] ?? basePower;

    // Terastal minimum power: Tera STAB moves below 60 become 60
    // (except multi-hit and priority moves)
    if (state.terastal.active &&
        state.terastal.teraType != PokemonType.stellar &&
        state.terastal.teraType != null &&
        (effectiveType == state.terastal.teraType) &&
        !move.isMultiHit &&
        transformed.move.priority <= 0 &&
        effectivePower > 0 && effectivePower < 60) {
      effectivePower = 60;
    }
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
      opponentWeight: opponentWeight,
      hitCount: hits,
    );

    // Fixed damage is determined by the TRANSFORMED move, not the original
    final isFixed = transformed.move.hasTag(MoveTags.fixedLevel) ||
        transformed.move.hasTag(MoveTags.fixedHalfHp) ||
        transformed.move.hasTag(MoveTags.fixed20) ||
        transformed.move.hasTag(MoveTags.fixed40) ||
        transformed.move.hasTag(MoveTags.ohko);

    return MoveSlotInfo(
      displayName: displayName,
      effectiveType: effectiveType,
      effectiveCategory: effectiveCategory,
      basePower: basePower,
      effectivePower: effectivePower,
      isFixedDamage: isFixed,
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
    double? opponentWeight,
  }) {
    final move = state.moves[moveIndex];
    final hits = move != null && move.isMultiHit
        ? (state.hitOverrides[moveIndex] ?? move.maxHits) : null;
    return _calcOffensivePower(
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
      opponentWeight: opponentWeight,
      hitCount: hits,
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
    double? opponentWeight,
    int? hitCount,
  }) {
    if (move == null) return null;

    move = move.copyWith(
      type: typeOverride,
      power: powerOverride,
      category: categoryOverride,
    );

    // Neutralizing Gas: suppress own ability for 결정력
    final effectiveAbilityForCalc = state.selectedAbility == 'Neutralizing Gas'
        ? null : state.selectedAbility;

    // Cloud Nine / Air Lock / Teraform Zero negates weather/terrain
    if (isWeatherNegating(effectiveAbilityForCalc)) weather = Weather.none;
    if (isTerrainNegating(effectiveAbilityForCalc)) terrain = Terrain.none;

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
      opponentWeight: opponentWeight,
      hitCount: hitCount,
    );
    final transformed = transformMove(move, ctx);

    // Gravity: disabled moves return 0 (checked after transform,
    // so Dynamax moves pass through)
    if (room.gravity && transformed.move.hasTag(MoveTags.disabledByGravity)) {
      return 0;
    }

    // 2. Resolve item/ability effects (Dynamax nullification applied)
    final isDmaxed = state.dynamax != DynamaxState.none;

    final effectiveItem = resolveEffectiveItem(
        item: state.selectedItem, ability: effectiveAbilityForCalc, isDynamaxed: isDmaxed);
    final itemEffect = effectiveItem != null
        ? getItemEffect(effectiveItem,
            move: transformed.move, pokemonName: state.pokemonName)
        : const ItemEffect();

    final effectiveAbility = resolveEffectiveAbility(
        ability: effectiveAbilityForCalc, isDynamaxed: isDmaxed);
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

    // 4. Resolve effective type (Multitype, RKS System, Forecast, etc.)
    final abilityTypeOverride = getAbilityTypeOverride(
      ability: effectiveAbilityForCalc,
      pokemonName: state.pokemonName,
      weather: weather,
      terrain: terrain,
      heldItem: state.selectedItem,
    );
    final effectiveType1 = abilityTypeOverride?.type1 ?? state.type1;
    final effectiveType2 = abilityTypeOverride != null ? abilityTypeOverride.type2 : state.type2;

    // 5. Final calculation
    return OffensiveCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
      transformed: transformed,
      type1: effectiveType1,
      type2: effectiveType2,
      rank: state.rank,
      weather: weather,
      terrain: terrain,
      statModifier: statMod,
      powerModifier: powerMod,
      isCritical: isCritical,
      grounded: isGrounded(
        type1: effectiveType1,
        type2: effectiveType2,
        ability: effectiveAbilityForCalc,
        item: state.selectedItem,
        gravity: room.gravity,
      ),
      status: state.status,
      hasGuts: effectiveAbilityForCalc == 'Guts',
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
    // Cloud Nine / Air Lock / Teraform Zero negates weather/terrain
    final effWeather = isWeatherNegating(state.selectedAbility)
        ? Weather.none : weather;
    final effTerrain = isTerrainNegating(state.selectedAbility)
        ? Terrain.none : terrain;
    return DefensiveCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
      type1: state.type1,
      type2: state.type2,
      rank: state.rank,
      weather: effWeather,
      ability: state.selectedAbility,
      item: state.selectedAbility == 'Klutz' ? null : state.selectedItem,
      pokemonName: state.pokemonName,
      finalEvo: state.finalEvo,
      status: state.status,
      terrain: effTerrain,
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

  /// Returns the effective weight after ability/item modifiers.
  static double effectiveWeight(BattlePokemonState state) {
    var w = state.weight;
    switch (state.selectedAbility) {
      case 'Heavy Metal':
        w *= 2;
      case 'Light Metal':
        w *= 0.5;
    }
    // Float item also halves weight
    if (state.selectedItem == 'float-stone') w *= 0.5;
    return w;
  }

  static MoveContext _buildMoveContext({
    required BattlePokemonState state,
    required Weather weather,
    required Terrain terrain,
    required Stats actualStats,
    int? myEffectiveSpeed,
    int? opponentSpeed,
    double? opponentWeight,
    int? hitCount,
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
      myWeight: effectiveWeight(state),
      opponentWeight: opponentWeight,
      userType1: state.type1,
      heldItem: state.selectedItem,
      hitCount: hitCount,
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
