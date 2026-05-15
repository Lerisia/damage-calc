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
import 'aura_effects.dart';
import 'doubles_effects.dart';
import 'grounded.dart';
import 'item_effects.dart';
import 'move_transform.dart';
import 'offensive_calculator.dart';
import 'defensive_calculator.dart';
import 'ruin_effects.dart';
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
  if (isKlutz(ability)) return null;
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

  /// Whether the transformed move is still multi-hit.
  final bool isMultiHit;

  /// Minimum hit count of the transformed move.
  final int minHits;

  /// Maximum hit count of the transformed move.
  final int maxHits;

  /// 결정력 result, null when no move is set.
  final int? offensivePower;

  /// Modifier notes (same key format as damage_calculator's modifier
  /// notes) that contributed to [offensivePower]. Used by the
  /// "결정력 breakdown" popup to show *why* the number is what it is.
  /// Empty when [offensivePower] is null or no modifiers were applied.
  final List<String> offensivePowerNotes;

  const MoveSlotInfo({
    this.displayName,
    this.effectiveType,
    this.effectiveCategory,
    this.basePower = 0,
    this.effectivePower = 0,
    this.isFixedDamage = false,
    this.isMultiHit = false,
    this.minHits = 1,
    this.maxHits = 1,
    this.offensivePower,
    this.offensivePowerNotes = const [],
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
      pokemonName: state.pokemonName,
      actualStats: stats,
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
    AuraToggles auras = AuraToggles.inactive,
    RuinToggles ruins = RuinToggles.inactive,
    int? opponentSpeed,
    int? opponentAttack,
    int? opponentDefense,
    int? opponentSpDefense,
    Gender opponentGender = Gender.unset,
    int? myEffectiveSpeed,
    double? opponentWeight,
    double? opponentHpPercent,
    String? opponentItem,
    String? opponentAbility,
    bool attackerGrounded = true,
    bool defenderGrounded = true,
  }) {
    final move = state.moves[moveIndex];
    if (move == null) {
      return const MoveSlotInfo();
    }

    // Compute base stats once for this slot
    final baseStats = _baseActualStats(state);
    final hits = move.isMultiHit
        ? (state.hitOverrides[moveIndex] ?? move.maxHits) : null;

    // Weather-override abilities (Mega Sol: applies Sun for offense)
    final atkWeather = effectiveOffensiveWeather(weather, ability: state.selectedAbility);

    // Transform for display (name, type, power)
    final ctx = _buildMoveContext(
      state: state,
      weather: atkWeather,
      terrain: terrain,
      actualStats: baseStats,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentSpeed: opponentSpeed,
      opponentWeight: opponentWeight,
      opponentHpPercent: opponentHpPercent,
      opponentItem: opponentItem,
      hitCount: hits,
      gravity: room.gravity,
      attackerGrounded: attackerGrounded,
      defenderGrounded: defenderGrounded,
      zMove: state.zMoves[moveIndex],
      isMega: state.isMega,
    );
    final transformed = transformMove(move, ctx);

    final effectiveType = transformed.move.type == PokemonType.typeless
        ? null
        : (state.typeOverrides[moveIndex] ?? transformed.move.type);

    // Shell Side Arm: pick physical/special by A×SpD vs C×Def when defender
    // defense stats are known. Uses rank-adjusted stats per game rule.
    // User category override still wins.
    MoveCategory resolvedCategory = transformed.move.category;
    if (transformed.move.hasTag(MoveTags.shellSideArm) &&
        opponentDefense != null && opponentSpDefense != null) {
      final atkRanked = StatCalculator.calculate(
        baseStats: state.baseStats, iv: state.iv, ev: state.ev,
        nature: state.nature, level: state.level, rank: state.rank);
      final usePhysical =
          atkRanked.attack * opponentSpDefense! > atkRanked.spAttack * opponentDefense!;
      resolvedCategory = usePhysical ? MoveCategory.physical : MoveCategory.special;
    }
    final effectiveCategory = state.categoryOverrides[moveIndex] ?? resolvedCategory;
    final basePower = transformed.move.power;
    // Move-conditional bpMods that aren't baked into the printed BP —
    // Knock Off ×1.5, Grav Apple / Misty Explosion / Expanding Force
    // ×1.5, Solar Beam / Solar Blade ×0.5. Fold them in with the same
    // 4096-fp rounding the damage calculator uses so the slot BP
    // matches the actual damage path (e.g. Solar Blade 125 → 63).
    // A manual power override always wins.
    final int condBpMod = conditionalBpModFp(
      transformed.move,
      weather: atkWeather,
      terrain: terrain,
      gravity: room.gravity,
      attackerGrounded: attackerGrounded,
      opponentItem: opponentItem,
    );
    var effectivePower = state.powerOverrides[moveIndex] ??
        applyBpModFp(basePower, condBpMod);

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
    final displayName = transformed.move.localizedName;

    // 결정력. The notes list is filled in by `_calcOffensivePower`
    // (and `OffensiveCalculator` underneath) so the breakdown popup
    // can surface every multiplier that contributed.
    final offensivePowerNotes = <String>[];
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
      attackerGrounded: attackerGrounded,
      defenderGrounded: defenderGrounded,
      opponentHpPercent: opponentHpPercent,
      opponentItem: opponentItem,
      opponentAbility: opponentAbility,
      auras: auras,
      ruins: ruins,
      zMove: state.zMoves[moveIndex],
      notesOut: offensivePowerNotes,
    );

    // Fixed damage is determined by the TRANSFORMED move, not the original
    final isFixed = transformed.move.hasTag(MoveTags.fixedLevel) ||
        transformed.move.hasTag(MoveTags.fixedHalfHp) ||
        transformed.move.hasTag(MoveTags.fixedThreeQuarterHp) ||
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
      isMultiHit: transformed.move.isMultiHit,
      minHits: transformed.move.minHits,
      maxHits: transformed.move.maxHits,
      offensivePower: offensivePower,
      offensivePowerNotes: offensivePowerNotes,
    );
  }

  // ------------------------------------------------------------------
  // Offensive power (결정력) — standalone
  // ------------------------------------------------------------------

  /// Calculates 결정력 for the move at [moveIndex] of [state].
  ///
  /// Returns `null` when the slot has no move assigned.
  ///
  /// [notesOut] is an optional collector: when non-null, the
  /// modifier-note keys behind the result are appended (same format
  /// as the damage tab's modifier list). The 결정력 breakdown popup
  /// reads this.
  static int? calcOffensivePower({
    required BattlePokemonState state,
    required int moveIndex,
    required Weather weather,
    required Terrain terrain,
    required RoomConditions room,
    AuraToggles auras = AuraToggles.inactive,
    RuinToggles ruins = RuinToggles.inactive,
    int? opponentSpeed,
    int? opponentAttack,
    Gender opponentGender = Gender.unset,
    int? myEffectiveSpeed,
    double? opponentWeight,
    double? opponentHpPercent,
    String? opponentItem,
    String? opponentAbility,
    List<String>? notesOut,
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
      auras: auras,
      ruins: ruins,
      opponentSpeed: opponentSpeed,
      opponentAttack: opponentAttack,
      opponentGender: opponentGender,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentWeight: opponentWeight,
      opponentHpPercent: opponentHpPercent,
      opponentItem: opponentItem,
      opponentAbility: opponentAbility,
      hitCount: hits,
      zMove: state.zMoves[moveIndex],
      notesOut: notesOut,
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
    // Optional collector — when non-null the function appends a
    // damage-calc-style note for each non-1.0 modifier it applies
    // (item / ability / conditional-bpMods / stat boosts). Used by
    // the "결정력 breakdown" popup.
    List<String>? notesOut,
    AuraToggles auras = AuraToggles.inactive,
    RuinToggles ruins = RuinToggles.inactive,
    int? opponentSpeed,
    int? opponentAttack,
    Gender opponentGender = Gender.unset,
    int? myEffectiveSpeed,
    double? opponentWeight,
    double? opponentHpPercent,
    String? opponentItem,
    String? opponentAbility,
    int? hitCount,
    bool attackerGrounded = true,
    bool defenderGrounded = true,
    bool zMove = false,
  }) {
    if (move == null) return null;

    move = move.copyWith(
      type: typeOverride,
      power: powerOverride,
      category: categoryOverride,
    );

    // Neutralizing Gas: suppress own ability for 결정력
    final effectiveAbilityForCalc = hasNeutralizingGas(state.selectedAbility, null)
        ? null : state.selectedAbility;

    // Cloud Nine / Air Lock / Teraform Zero negates weather/terrain
    if (isWeatherNegating(effectiveAbilityForCalc)) weather = Weather.none;
    if (isTerrainNegating(effectiveAbilityForCalc)) terrain = Terrain.none;

    // Weather-override abilities (Mega Sol: applies Sun for offense)
    final atkWeather = effectiveOffensiveWeather(weather, ability: effectiveAbilityForCalc);

    // Compute base stats once — reused by MoveContext and ability effects.
    final baseStats = _baseActualStats(state);

    // 1. Transform the move (type/power changes based on context)
    final ctx = _buildMoveContext(
      state: state,
      weather: atkWeather,
      terrain: terrain,
      actualStats: baseStats,
      myEffectiveSpeed: myEffectiveSpeed,
      opponentSpeed: opponentSpeed,
      opponentWeight: opponentWeight,
      opponentHpPercent: opponentHpPercent,
      opponentItem: opponentItem,
      hitCount: hitCount,
      gravity: room.gravity,
      attackerGrounded: attackerGrounded,
      defenderGrounded: defenderGrounded,
      zMove: zMove,
      isMega: state.isMega,
    );
    var transformed = transformMove(move, ctx);

    // Gravity: disabled moves return 0 (checked after transform,
    // so Dynamax moves pass through)
    if (room.gravity && transformed.move.hasTag(MoveTags.disabledByGravity)) {
      return 0;
    }

    // Move-conditional bpMods that aren't baked into the printed BP —
    // Knock Off ×1.5, Grav Apple / Misty Explosion / Expanding Force
    // ×1.5, Solar Beam / Solar Blade ×0.5. Fold into the move power so
    // 결정력 reflects them (same 4096-fp rounding as the damage calc).
    // A manual power override already replaced move.power above, so
    // skip when one is set.
    if (powerOverride == null) {
      final int condBpMod = conditionalBpModFp(
        transformed.move,
        weather: atkWeather,
        terrain: terrain,
        gravity: room.gravity,
        attackerGrounded: attackerGrounded,
        opponentItem: opponentItem,
      );
      if (condBpMod != 4096) {
        transformed = TransformedMove(
          transformed.move
              .copyWith(power: applyBpModFp(transformed.move.power, condBpMod)),
          transformed.offensiveStat,
        );
      }
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
            weather: atkWeather,
            terrain: terrain,
            status: state.status,
            heldItem: effectiveItem,
            opponentSpeed: opponentSpeed,
            myGender: state.gender,
            opponentGender: opponentGender,
            actualStats: baseStats)
        : const AbilityEffect();

    // 3. Pick the right ability stat-modifier by *move category* (not
    // by the offensive-stat slot) — Body Press is physical so it
    // gets the Attack-side ability multipliers (Huge Power × 2 etc.)
    // even though the underlying stat used is Defense. Matches
    // Showdown's atMods chain. Photon Geyser keeps the
    // max-of-attack/spAttack behaviour so a Huge Power user still
    // benefits when Atk > SpA.
    final double abilityStatMod;
    if (transformed.move.hasTag(MoveTags.useHigherAtk)) {
      abilityStatMod = math.max(
        abilityEffect.statModifiers.attack,
        abilityEffect.statModifiers.spAttack,
      );
    } else if (transformed.move.category == MoveCategory.physical) {
      abilityStatMod = abilityEffect.statModifiers.attack;
    } else {
      abilityStatMod = abilityEffect.statModifiers.spAttack;
    }

    // Two ItemEffect buckets that damage_calculator splits across the
    // 4096-fp chains (atMods + finalMods) but 결정력 collapses into
    // one float product:
    //   * atkStatModifier — Choice Band / Specs ×1.5, Light Ball /
    //     Thick Club / Deep Sea Tooth ×2 (atMods bucket).
    //   * damageModifier — Life Orb ×1.3 (finalMods bucket).
    // Without these two, 결정력 silently drops those items even
    // though they shipped in damage_calculator. Regressed at commits
    // 9ecc8a3 (Choice Band) and 044847b (Life Orb) when the item
    // model was re-split to match Showdown's chain layout but the
    // 결정력 collector wasn't updated to read the new buckets.
    // (Expert Belt is *not* in damageModifier — it's effectiveness-
    // conditional and lives in damage_calculator directly, so it
    // stays out of 결정력 by design.)
    double powerMod = itemEffect.powerModifier *
        itemEffect.atkStatModifier *
        itemEffect.damageModifier *
        abilityEffect.powerModifier *
        abilityStatMod;

    // Per-bucket modifier notes for the 결정력 breakdown popup.
    // damage_calculator uses keys like `ability:Tough Claws:×1.3` and
    // `item:choice-band:×1.5`; we mirror those exactly so the same
    // formatter renders both tabs' notes.
    if (notesOut != null) {
      final atkAbilName = state.selectedAbility;
      if (atkAbilName != null) {
        if (abilityEffect.powerModifier != 1.0) {
          notesOut.add('ability:$atkAbilName:${formatNoteMul(abilityEffect.powerModifier)}');
        }
        if (abilityStatMod != 1.0) {
          notesOut.add('ability:$atkAbilName:${formatNoteMul(abilityStatMod)}');
        }
      }
      final atkItem = state.selectedItem;
      if (atkItem != null && atkItem.isNotEmpty) {
        if (itemEffect.powerModifier != 1.0) {
          notesOut.add('item:$atkItem:${formatNoteMul(itemEffect.powerModifier)}');
        }
        if (itemEffect.atkStatModifier != 1.0) {
          notesOut.add('item:$atkItem:${formatNoteMul(itemEffect.atkStatModifier)}');
        }
        if (itemEffect.damageModifier != 1.0) {
          notesOut.add('item:$atkItem:${formatNoteMul(itemEffect.damageModifier)}');
        }
      }
    }

    // Charge: Electric moves deal 2x damage
    if (state.charge && transformed.move.type == PokemonType.electric) {
      powerMod *= 2.0;
      if (notesOut != null) notesOut.add('move:charge:×2.0');
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
    // Ability-driven type rewrites (Multitype, RKS System, …) collapse
    // to a 1-or-2-type form, so any user-set 3rd type is dropped.
    final PokemonType? effectiveType3 = abilityTypeOverride != null ? null : state.type3;

    // Doubles-only modifiers (spread, helping hand, ally abilities, ...)
    final doublesMods = computeDoublesModifiers(
      attacker: state,
      move: transformed.move,
      isDoubles: true,
      weather: atkWeather,
    );
    // Surface each doubles-ally contribution by name in the 결정력
    // breakdown (도우미 / 배터리 / 파워스폿 / 플라워기프트 /
    // 플러스마이너스 / 광역). doublesMods already emits individual
    // `move:helpingHand:×1.5` style notes — pass them through.
    if (notesOut != null) {
      notesOut.addAll(doublesMods.notes);
    }

    // Field-state ability effects (auras + ruins). The toggles live on
    // RoomConditions; attacker/defender abilities also count as sources.
    final auraState = computeAuraState(
      attackerAbility: effectiveAbilityForCalc,
      defenderAbility: opponentAbility,
      allyFairyAura: auras.fairyAura,
      allyDarkAura: auras.darkAura,
      allyAuraBreak: auras.auraBreak,
    );
    final ruinState = computeRuinState(
      attackerAbility: effectiveAbilityForCalc,
      defenderAbility: opponentAbility,
      allyTabletsOfRuin: ruins.tabletsOfRuin,
      allySwordOfRuin: ruins.swordOfRuin,
      allyVesselOfRuin: ruins.vesselOfRuin,
      allyBeadsOfRuin: ruins.beadsOfRuin,
    );
    final bool targetPhysDef = transformed.move.category == MoveCategory.physical ||
        transformed.move.hasTag(MoveTags.targetPhysDef);

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
      type3: effectiveType3,
      rank: state.rank,
      weather: atkWeather,
      terrain: terrain,
      powerModifier: powerMod,
      isCritical: isCritical,
      grounded: isGrounded(
        type1: effectiveType1,
        type2: effectiveType2,
        type3: effectiveType3,
        ability: effectiveAbilityForCalc,
        item: state.selectedItem,
        gravity: room.gravity,
      ),
      status: state.status,
      hasGuts: negatesBurn(effectiveAbilityForCalc),
      stabOverride: abilityEffect.stabOverride,
      criticalOverride: abilityEffect.criticalOverride,
      forceStab: abilityEffect.forceStab,
      opponentAttack: opponentAttack,
      terastallized: state.terastal.active,
      teraType: state.terastal.teraType,
      doublesPowerMod: doublesMods.powerMod,
      doublesAttackMod: doublesMods.attackMod,
      auraState: auraState,
      ruinState: ruinState,
      attackerAbility: effectiveAbilityForCalc,
      defenderAbility: opponentAbility,
      targetPhysDef: targetPhysDef,
      notesOut: notesOut,
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
    RuinToggles ruins = RuinToggles.inactive,
    String? opponentAbility,
  }) {
    // Cloud Nine / Air Lock / Teraform Zero negates weather/terrain
    final effWeather = isWeatherNegating(state.selectedAbility)
        ? Weather.none : weather;
    final effTerrain = isTerrainNegating(state.selectedAbility)
        ? Terrain.none : terrain;
    // Ruin field state — [state] is the defender here, so pass its
    // ability as the defenderAbility so self-exempt applies correctly.
    final ruinState = computeRuinState(
      attackerAbility: opponentAbility,
      defenderAbility: state.selectedAbility,
      allyTabletsOfRuin: ruins.tabletsOfRuin,
      allySwordOfRuin: ruins.swordOfRuin,
      allyVesselOfRuin: ruins.vesselOfRuin,
      allyBeadsOfRuin: ruins.beadsOfRuin,
    );
    return DefensiveCalculator.calculate(
      baseStats: state.baseStats,
      iv: state.iv,
      ev: state.ev,
      nature: state.nature,
      level: state.level,
      type1: state.type1,
      type2: state.type2,
      type3: state.type3,
      rank: state.rank,
      weather: effWeather,
      ability: state.selectedAbility,
      item: isKlutz(state.selectedAbility) ? null : state.selectedItem,
      pokemonName: state.pokemonName,
      finalEvo: state.finalEvo,
      status: state.status,
      terrain: effTerrain,
      room: room,
      isDynamaxed: state.dynamax != DynamaxState.none,
      ruinState: ruinState,
      allyFlowerGift: state.allyFlowerGift,
      allyFriendGuard: state.allyFriendGuard,
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
    w *= getWeightAbilityModifier(state.selectedAbility);
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
    double? opponentHpPercent,
    String? opponentItem,
    int? hitCount,
    bool gravity = false,
    bool attackerGrounded = true,
    bool defenderGrounded = true,
    bool zMove = false,
    bool isMega = false,
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
      opponentHpPercent: opponentHpPercent,
      opponentItem: opponentItem,
      userType1: state.type1,
      heldItem: state.selectedItem,
      hitCount: hitCount,
      gravity: gravity,
      attackerGrounded: attackerGrounded,
      defenderGrounded: defenderGrounded,
      zMove: zMove,
      isMega: isMega,
    );
  }

}
