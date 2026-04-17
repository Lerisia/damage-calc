import 'dart:math' as math;

import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/gender.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'battle_facade.dart' show resolveEffectiveItem, resolveEffectiveAbility, BattleFacade;
import 'grounded.dart';
import 'item_effects.dart';
import 'move_transform.dart';
import 'random_factor.dart';
import 'stat_calculator.dart';
import 'terrain_effects.dart';
import 'type_effectiveness.dart';
import 'weather_effects.dart';

// ====== Damage formula constants ======

/// STAB multipliers
const double kStandardStab = 1.5;
const double kStellarStabMatching = 2.0;
const double kStellarStabNonMatching = 1.2;
const double kTeraStabBonus = 0.5;

/// Combat modifiers
const double kBurnDamageReduction = 0.5;
const double kCriticalMultiplier = 1.5;
const double kScreenReduction = 0.5;
const double kExpertBeltBoost = 1.2;
const double kTeraShellReduction = 0.5;
const double kChargePowerBoost = 2.0;

/// Move-specific power multipliers
const double kKnockOffBoost = 1.5;
const double kDoubleMovePower = 2.0;
const double kSolarBeamWeatherPenalty = 0.5;
const double kGravAppleBoost = 1.5;
const double kCollisionCourseBoost = 5461 / 4096; // ~1.3333

/// Terastal minimum power threshold
const int kTeraMinPower = 60;

/// Pokemon "pokeRound": round to nearest, rounding DOWN at 0.5.
/// e.g. 10.4→10, 10.5→10, 10.6→11
int _pokeRound(num x) => (x.toDouble() - 0.5).ceil();

/// Result of a single move's damage calculation.
class DamageResult {
  /// Raw base damage (at max roll, for display)
  final int baseDamage;

  /// Minimum damage
  final int minDamage;

  /// Maximum damage
  final int maxDamage;

  /// Defender's actual HP
  final int defenderHp;

  /// Type effectiveness multiplier
  final double effectiveness;

  /// Whether the move is physical
  final bool isPhysical;

  /// Whether the move targets the defender's physical Defense stat.
  final bool targetPhysDef;

  /// The move used (after transformation)
  final Move move;

  /// Notes explaining special modifiers applied (for UI display)
  final List<String> modifierNotes;

  /// All 16 possible damage values (one per random roll) for single-hit.
  final List<int> allRolls;

  /// Per-hit roll lists for multi-hit moves. Each element is 16 possible
  /// damage values for that hit. null for single-hit moves.
  final List<List<int>>? perHitAllRolls;

  const DamageResult({
    required this.baseDamage,
    required this.minDamage,
    required this.maxDamage,
    required this.defenderHp,
    required this.effectiveness,
    required this.isPhysical,
    this.targetPhysDef = false,
    required this.move,
    this.modifierNotes = const [],
    this.allRolls = const [],
    this.perHitAllRolls,
  });

  double get minPercent {
    if (defenderHp <= 0) return 0;
    final v = minDamage / defenderHp * 100;
    return v.isFinite ? v : 0;
  }
  double get maxPercent {
    if (defenderHp <= 0) return 0;
    final v = maxDamage / defenderHp * 100;
    return v.isFinite ? v : 0;
  }

  /// N-hit KO analysis including random roll combinations.
  ({int hits, int koCount, int totalCount}) get koInfo {
    if (perHitAllRolls != null) {
      return _multiHitKoInfo;
    }
    return RandomFactor.nHitKoFromRolls(allRolls, defenderHp);
  }

  /// Multi-hit KO probability (0.0~1.0), only meaningful for multi-hit moves.
  double? get multiHitKoProb {
    if (perHitAllRolls == null) return null;
    return RandomFactor.multiHitKoProbFromRolls(perHitAllRolls!, defenderHp).koProb;
  }

  /// Multi-hit KO: uses convolution-based probability distribution.
  /// "1타" = one use of the multi-hit move (all hits combined).
  ({int hits, int koCount, int totalCount}) get _multiHitKoInfo {
    final prob = multiHitKoProb!;
    if (prob >= 1.0) {
      return (hits: 1, koCount: 1, totalCount: 1); // 확정
    } else if (prob > 0) {
      const denom = 10000;
      final koCount = (prob * denom).round().clamp(1, denom - 1);
      return (hits: 1, koCount: koCount, totalCount: denom);
    }
    // Multi-hit didn't KO in one use; calculate N-use KO using
    // total damage per use (min/max) instead of individual hit rolls.
    if (maxDamage <= 0 || minDamage <= 0) return (hits: 0, koCount: 0, totalCount: 1);
    final guaranteedUses = (defenderHp / minDamage).ceil();
    final bestUses = (defenderHp / maxDamage).ceil();
    if (guaranteedUses == bestUses) {
      return (hits: guaranteedUses, koCount: 1, totalCount: 1);
    }
    return (hits: bestUses, koCount: 1, totalCount: 2); // approximate
  }

  /// Human-readable KO label: "확정 1타", "난수 2타 (52.3%)", etc.
  String get koLabel {
    final info = koInfo;
    if (info.hits <= 0) return '';

    // Multi-hit move with per-hit distribution
    if (perHitAllRolls != null && info.hits == 1) {
      final prob = multiHitKoProb!;
      if (prob >= 1.0) return '확정 1타';
      if (prob <= 0) return '';
      final pct = prob * 100;
      if (pct >= 99.9) {
        return '난수 1타 (>99.9%)';
      } else if (pct < 0.1) {
        return '난수 1타 (<0.1%)';
      }
      return '난수 1타 (${pct.toStringAsFixed(1)}%)';
    }

    // Standard single-hit KO label
    final label = RandomFactor.koLabel(info.koCount, info.totalCount) ?? '';
    if (label == '난수') {
      final pct = info.koCount / info.totalCount * 100;
      if (pct >= 99.9) {
        return '난수 ${info.hits}타 (>99.9%)';
      } else if (pct < 0.1) {
        return '난수 ${info.hits}타 (<0.1%)';
      }
      return '난수 ${info.hits}타 (${pct.toStringAsFixed(1)}%)';
    }
    return '$label ${info.hits}타'.trim();
  }

  bool get isEmpty => baseDamage == 0 && effectiveness != 0;

  static const empty = DamageResult(
    baseDamage: 0, minDamage: 0, maxDamage: 0,
    defenderHp: 1, effectiveness: 1.0, isPhysical: true,
    move: Move(name: '', nameKo: '', nameJa: '',
      type: PokemonType.normal, category: MoveCategory.status,
      power: 0, accuracy: 0, pp: 0),
  );
}

/// Calculates damage using the official Gen V+ formula:
///
/// `damage = floor(floor((2*Lv/5+2) * Power * A/D) / 50 + 2) * modifiers * random`
///
/// Takes [BattlePokemonState] for both sides and battle conditions.

/// Items that can't be removed by Knock Off (no power boost).
bool _isUnremovableItem(String itemName) {
  // Z-Crystals
  if (itemName.endsWith('--held')) return true;
  // Mega stones
  if (itemName.endsWith('ite') || itemName.endsWith('ite-x') || itemName.endsWith('ite-y')) {
    return true;
  }
  // Silvally Memory items
  if (itemName.endsWith('-memory')) return true;
  // Arceus Plates
  if (itemName.endsWith('-plate')) return true;
  // Primal orbs, Griseous, Rusted items, Origin forme items
  // Ogerpon masks
  if (itemName.endsWith('-mask')) return true;
  const fixedItems = {
    'blue-orb', 'red-orb', 'rusted-sword', 'rusted-shield',
    'griseous-core', 'griseous-orb', 'adamant-crystal', 'lustrous-globe',
  };
  if (fixedItems.contains(itemName)) return true;
  return false;
}

class DamageCalculator {
  /// Calculate damage for a specific move slot.
  static DamageResult calculate({
    required BattlePokemonState attacker,
    required BattlePokemonState defender,
    required int moveIndex,
    required Weather weather,
    required Terrain terrain,
    required RoomConditions room,
    int? opponentAttack,
    int? opponentSpeed,
    int? myEffectiveSpeed,
    Gender opponentGender = Gender.unset,
  }) {
    final move = attacker.moves[moveIndex];
    if (move == null) return DamageResult.empty;

    // Apply move overrides
    var effectiveMove = move.copyWith(
      type: attacker.typeOverrides[moveIndex],
      category: attacker.categoryOverrides[moveIndex],
      power: attacker.powerOverrides[moveIndex],
    );

    if (effectiveMove.category == MoveCategory.status) {
      return DamageResult.empty;
    }

    // --- Neutralizing Gas: suppress all abilities ---
    final bool gasActive = hasNeutralizingGas(
        attacker.selectedAbility, defender.selectedAbility);
    final String? atkAbilityRaw = gasActive ? null : attacker.selectedAbility;
    final String? defAbilityRaw = gasActive ? null : defender.selectedAbility;

    // Cloud Nine / Air Lock / Teraform Zero: negate weather/terrain
    final List<String> weatherNotes = [];
    final originalWeather = weather;
    weather = effectiveWeather(weather,
        abilityA: atkAbilityRaw, abilityB: defAbilityRaw);
    if (weather != originalWeather) {
      final negator = isWeatherNegating(atkAbilityRaw) ? atkAbilityRaw! : defAbilityRaw!;
      weatherNotes.add('weather_negate:$negator');
    }
    final originalTerrain = terrain;
    terrain = effectiveTerrain(terrain,
        abilityA: atkAbilityRaw, abilityB: defAbilityRaw);
    if (terrain != originalTerrain) {
      final negator = isTerrainNegating(atkAbilityRaw) ? atkAbilityRaw! : defAbilityRaw!;
      weatherNotes.add('terrain_negate:$negator');
    }

    // Weather-override abilities (Mega Sol: applies Sun for offense)
    final atkWeather = effectiveOffensiveWeather(weather, ability: atkAbilityRaw);
    if (atkWeather != weather) {
      weatherNotes.add('ability:$atkAbilityRaw:쾌청 적용');
    }

    // Note: power == 0 check moved AFTER transform, since weight-based
    // and speed-based moves start at 0 and get power from transform.

    // Transform move (weather ball, terrain pulse, skins, tera blast, etc.)
    final isDmaxed = attacker.dynamax != DynamaxState.none;
    final atkBaseStats = StatCalculator.calculate(
      baseStats: attacker.baseStats, iv: attacker.iv, ev: attacker.ev,
      nature: attacker.nature, level: attacker.level, rank: attacker.rank,
    );
    final atkGroundedEarly = isGrounded(
      type1: attacker.type1, type2: attacker.type2,
      ability: atkAbilityRaw, item: attacker.selectedItem,
      gravity: room.gravity,
    );
    final defGroundedEarly = isGrounded(
      type1: defender.type1, type2: defender.type2,
      ability: defAbilityRaw, item: defender.selectedItem,
      gravity: room.gravity,
    );
    final moveCtx = MoveContext(
      weather: atkWeather,
      terrain: terrain,
      rank: attacker.rank,
      hpPercent: attacker.hpPercent,
      hasItem: attacker.selectedItem != null,
      ability: atkAbilityRaw,
      status: attacker.status,
      dynamax: attacker.dynamax,
      pokemonName: attacker.pokemonName,
      terastallized: attacker.terastal.active,
      teraType: attacker.terastal.teraType,
      actualAttack: atkBaseStats.attack,
      actualSpAttack: atkBaseStats.spAttack,
      myWeight: BattleFacade.effectiveWeight(attacker),
      opponentWeight: BattleFacade.effectiveWeight(defender),
      opponentHpPercent: defender.hpPercent,
      userType1: attacker.type1,
      heldItem: attacker.selectedItem,
      hitCount: null, // multi-hit handled after damage calc for per-hit random
      mySpeed: myEffectiveSpeed,
      opponentSpeed: opponentSpeed,
      gravity: room.gravity,
      attackerGrounded: atkGroundedEarly,
      defenderGrounded: defGroundedEarly,
      zMove: attacker.zMoves[moveIndex],
      isMega: attacker.isMega,
    );
    var transformed = transformMove(effectiveMove, moveCtx);
    effectiveMove = transformed.move;

    // --- Shell Side Arm: choose physical vs special based on damage output ---
    // Compare A×SpD vs C×Def using rank-adjusted actual stats. The higher ratio
    // (A/D vs C/SpD, cross-multiplied to avoid floats) wins. Ability-based stat
    // mods like Huge Power are NOT considered for the decision per game rules.
    if (effectiveMove.hasTag(MoveTags.shellSideArm)) {
      final atkForSSA = StatCalculator.calculate(
        baseStats: attacker.baseStats, iv: attacker.iv, ev: attacker.ev,
        nature: attacker.nature, level: attacker.level, rank: attacker.rank,
      );
      final defForSSA = StatCalculator.calculate(
        baseStats: defender.baseStats, iv: defender.iv, ev: defender.ev,
        nature: defender.nature, level: defender.level, rank: defender.rank,
      );
      final usePhysical = atkForSSA.attack * defForSSA.spDefense >
          atkForSSA.spAttack * defForSSA.defense;
      effectiveMove = effectiveMove.copyWith(
        category: usePhysical ? MoveCategory.physical : MoveCategory.special,
      );
      transformed = TransformedMove(
        effectiveMove,
        usePhysical ? OffensiveStat.attack : OffensiveStat.spAttack,
      );
    }

    // --- Gravity: certain moves are disabled (checked AFTER transform,
    //     so Dynamax moves are not affected) ---
    if (room.gravity && effectiveMove.hasTag(MoveTags.disabledByGravity)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: 1, effectiveness: 0.0,
        isPhysical: effectiveMove.category == MoveCategory.physical,
        move: effectiveMove,
        modifierNotes: ['gravity:disabled'],
      );
    }

    // --- Dream Eater: fails if target is not asleep ---
    if (effectiveMove.hasTag(MoveTags.requiresDefSleep) &&
        defender.status != StatusCondition.sleep) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: 1, effectiveness: 0.0,
        isPhysical: false,
        move: effectiveMove,
        modifierNotes: ['꿈먹기: 상대가 잠듦 상태가 아니면 실패'],
      );
    }

    // --- Mold Breaker check (needed early for OHKO/fixed damage) ---
    final bool earlyMoldBreaks = shouldIgnoreAbility(atkAbilityRaw, defAbilityRaw) ||
        (effectiveMove.hasTag(MoveTags.ignoreAbility) &&
         defAbilityRaw != null && ignorableAbilities.contains(defAbilityRaw));
    final String? earlyDefAbility = earlyMoldBreaks ? null : defAbilityRaw;

    // --- OHKO moves ---
    if (effectiveMove.hasTag(MoveTags.ohko)) {
      return _calcOhkoDamage(
        attacker: attacker, defender: defender, move: effectiveMove,
        defenderAbility: earlyDefAbility, room: room,
      );
    }

    // --- Fixed damage moves (checked after transform so Dynamax → Max Guard passes) ---
    if (effectiveMove.hasTag(MoveTags.fixedLevel) || effectiveMove.hasTag(MoveTags.fixedHalfHp) ||
        effectiveMove.hasTag(MoveTags.fixedThreeQuarterHp) ||
        effectiveMove.hasTag(MoveTags.fixed20) || effectiveMove.hasTag(MoveTags.fixed40)) {
      return _calcFixedDamage(
        attacker: attacker, defender: defender, move: effectiveMove,
        weather: weather, room: room,
        defenderAbility: earlyDefAbility,
      );
    }

    // After transform: if power is still 0, no damage
    if (effectiveMove.power == 0) {
      return DamageResult.empty;
    }

    // Ability-based type overrides (e.g. Forecast for Castform)
    final atkTypeOverride = getAbilityTypeOverride(
      ability: atkAbilityRaw,
      pokemonName: attacker.pokemonName,
      weather: weather,
      terrain: terrain,
      heldItem: attacker.selectedItem,
    );
    final atkType1 = atkTypeOverride?.type1 ?? attacker.type1;
    final PokemonType? atkType2 = atkTypeOverride != null ? atkTypeOverride.type2 : attacker.type2;

    final defTypeOverride = getAbilityTypeOverride(
      ability: defAbilityRaw,
      pokemonName: defender.pokemonName,
      weather: weather,
      terrain: terrain,
      heldItem: defender.selectedItem,
    );
    // Defender type: Terastal takes priority over ability override
    // (handled later in type effectiveness section)

    final isPhysical = effectiveMove.category == MoveCategory.physical;

    // --- Attacker stat ---
    // Note: isCritical may be overridden later by Shell Armor / Battle Armor
    var isCritical = attacker.criticals[moveIndex];
    final atkStat = transformed.offensiveStat;

    // Unaware (defender) + Critical hit rank adjustments
    var effectiveAtkRank = getEffectiveOffensiveRank(
      rank: attacker.rank,
      offensiveStat: atkStat,
      isCritical: isCritical,
      attackerAbility: atkAbilityRaw,
      defenderAbility: defAbilityRaw,
    );

    final atkActual = StatCalculator.calculate(
      baseStats: attacker.baseStats, iv: attacker.iv, ev: attacker.ev,
      nature: attacker.nature, level: attacker.level, rank: effectiveAtkRank,
    );

    // Resolve which stat to use (Foul Play uses opponent's attack)
    int rawA = transformed.resolveStat(atkActual, opponentAttack: opponentAttack);

    // Item/ability resolution (Klutz, Dynamax nullification)
    final effectiveItem = resolveEffectiveItem(
        item: attacker.selectedItem, ability: atkAbilityRaw, isDynamaxed: isDmaxed);
    final itemEffect = effectiveItem != null
        ? getItemEffect(effectiveItem, move: effectiveMove, pokemonName: attacker.pokemonName)
        : const ItemEffect();

    final effectiveAbility = resolveEffectiveAbility(
        ability: atkAbilityRaw, isDynamaxed: isDmaxed);
    final abilityEffect = effectiveAbility != null
        ? getAbilityEffect(effectiveAbility, move: effectiveMove,
            originalBasePower: isDmaxed ? null : move.power,
            hpPercent: attacker.hpPercent, weather: weather,
            terrain: terrain, status: attacker.status,
            heldItem: effectiveItem,
            opponentSpeed: opponentSpeed,
            myGender: attacker.gender,
            opponentGender: opponentGender,
            actualStats: StatCalculator.calculate(
              baseStats: attacker.baseStats, iv: attacker.iv, ev: attacker.ev,
              nature: attacker.nature, level: attacker.level,
            ))
        : const AbilityEffect();

    final double abilityStatMod;
    switch (atkStat) {
      case OffensiveStat.attack:
        abilityStatMod = abilityEffect.statModifiers.attack;
      case OffensiveStat.spAttack:
        abilityStatMod = abilityEffect.statModifiers.spAttack;
      case OffensiveStat.defense:
        abilityStatMod = abilityEffect.statModifiers.defense;
      case OffensiveStat.higherAttack:
        abilityStatMod = math.max(
          abilityEffect.statModifiers.attack,
          abilityEffect.statModifiers.spAttack,
        );
      case OffensiveStat.opponentAttack:
        // Foul Play: user's own Attack modifiers (Huge Power, Pure Power, etc.)
        // still apply to the opponent's Attack stat
        abilityStatMod = abilityEffect.statModifiers.attack;
    }

    // Foul Play uses opponent's raw stat, but user's own item/ability modifiers still apply
    final double statMod = itemEffect.statModifier * abilityStatMod;
    double powerMod = itemEffect.powerModifier * abilityEffect.powerModifier;

    // Charge: Electric moves deal 2x damage
    if (attacker.charge && effectiveMove.type == PokemonType.electric) {
      powerMod *= kChargePowerBoost;
    }

    int A = (rawA * statMod).floor();

    // --- Ruin abilities (not affected by Mold Breaker) ---
    final ruin = getRuinModifiers(
      attackerAbility: effectiveAbility,
      defenderAbility: defAbilityRaw,
      isPhysical: isPhysical,
    );
    A = (A * ruin.atkMod).floor();

    // --- Defender stat ---
    // Unaware (attacker) + Critical hit + ignore-def-rank moves
    final effectiveDefRank = getEffectiveDefensiveRank(
      rank: defender.rank,
      isCritical: isCritical,
      attackerAbility: effectiveAbility,
      defenderAbility: defAbilityRaw,
      ignoreDefRank: effectiveMove.hasTag(MoveTags.ignoreDefRank),
    );

    final defCalculated = StatCalculator.calculate(
      baseStats: defender.baseStats, iv: defender.iv, ev: defender.ev,
      nature: defender.nature, level: defender.level, rank: effectiveDefRank,
    );

    // Wonder Room: swap final Def/SpDef after all stat calculations
    final defActual = room.wonderRoom
        ? Stats(
            hp: defCalculated.hp, attack: defCalculated.attack,
            defense: defCalculated.spDefense, spAttack: defCalculated.spAttack,
            spDefense: defCalculated.defense, speed: defCalculated.speed,
          )
        : defCalculated;

    // Dynamax doubles HP
    final int defMaxHp = defender.dynamax != DynamaxState.none
        ? defActual.hp * 2 : defActual.hp;

    // Psyshock/Psystrike/Secret Sword: special move targeting physical Defense
    final bool targetPhysDef = isPhysical || effectiveMove.hasTag(MoveTags.targetPhysDef);
    int D = targetPhysDef ? defActual.defense : defActual.spDefense;

    // Mold Breaker or ability-ignoring moves: ignore defender's ignorable abilities
    // (reuse early check computed before OHKO/fixed damage branches)
    final bool moldBreaks = earlyMoldBreaks;
    final String? effectiveDefAbility = earlyDefAbility;

    // Shell Armor / Battle Armor: negate critical hit
    String? critNegateNote;
    if (isCritical && isCritImmune(effectiveDefAbility)) {
      isCritical = false;
      critNegateNote = 'ability:$effectiveDefAbility:급소에 맞지 않음';
    }

    // Defender ability/item defensive modifiers
    if (effectiveDefAbility != null) {
      final defAbility = getDefensiveAbilityEffect(
        effectiveDefAbility, status: defender.status, weather: weather, terrain: terrain,
        heldItem: defender.selectedItem, actualStats: defActual);
      D = (D * (targetPhysDef ? defAbility.defModifier : defAbility.spdModifier)).floor();
    }
    if (defender.selectedItem != null) {
      final defItem = getDefensiveItemEffect(
        defender.selectedItem!, finalEvo: defender.finalEvo, pokemonName: defender.pokemonName);
      D = (D * (targetPhysDef ? defItem.defModifier : defItem.spdModifier)).floor();
    }
    // Weather defensive (sandstorm rock SpDef, snow ice Def)
    // Use ability-overridden types if applicable
    final defEffType1 = defTypeOverride?.type1 ?? defender.type1;
    final defEffType2 = defTypeOverride != null ? defTypeOverride.type2 : defender.type2;
    final weatherDef = getWeatherDefensiveModifier(
      weather, type1: defEffType1, type2: defEffType2);
    D = (D * (targetPhysDef ? weatherDef.defMod : weatherDef.spdMod)).floor();

    // Apply Ruin defensive modifier
    D = (D * ruin.defMod).floor();

    // --- Immunity checks ---
    final defAbilityName = effectiveDefAbility;
    final moveType = effectiveMove.type;
    final notes = <String>[];
    if (gasActive) notes.add('ability:Neutralizing Gas:특성 무효화');
    notes.addAll(weatherNotes);
    if (critNegateNote != null) notes.add(critNegateNote);
    if (moldBreaks) notes.add('moldbreaker:${attacker.selectedAbility}');
    // Unaware: show when it actually affects the calculation
    if (defAbilityRaw == 'Unaware' && !moldBreaks) {
      notes.add('unaware:defender');
    }
    if (effectiveAbility == 'Unaware') {
      notes.add('unaware:attacker');
    }
    notes.addAll(ruin.notes);

    // Weight-based moves fail against Dynamaxed targets
    if (defender.dynamax != DynamaxState.none &&
        effectiveMove.hasTag(MoveTags.weightBased)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defMaxHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['다이맥스 상대에게 무게 기반 기술 무효'],
      );
    }

    // Type immunity abilities (Volt Absorb, Water Absorb, Flash Fire, etc.)
    if (defAbilityName != null && isAbilityTypeImmune(defAbilityName, moveType)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defMaxHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['ability:$defAbilityName:immune'],
      );
    }
    // Move-based immunity (Bulletproof, Soundproof, Overcoat)
    if (defAbilityName != null && isAbilityMoveImmune(defAbilityName, effectiveMove)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defMaxHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['ability:$defAbilityName:immune'],
      );
    }

    // Priority move immunity (Queenly Majesty, Dazzling, Armor Tail)
    // Mold Breaker ignores this
    if (!moldBreaks && effectiveMove.priority > 0 && isPriorityImmune(defAbilityName)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defMaxHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['ability:$defAbilityName:선공기 무효'],
      );
    }

    // Psychic Terrain blocks priority moves against grounded targets
    if (effectiveMove.priority > 0 && terrain == Terrain.psychic) {
      final defGroundedForTerrain = isGrounded(
        type1: defEffType1, type2: defEffType2,
        ability: defAbilityName, item: defender.selectedItem,
        gravity: room.gravity,
      );
      if (defGroundedForTerrain) {
        return DamageResult(
          baseDamage: 0, minDamage: 0, maxDamage: 0,
          defenderHp: defMaxHp, effectiveness: 0.0,
          isPhysical: isPhysical, move: effectiveMove,
          modifierNotes: ['사이코필드: 선공기 무효'],
        );
      }
    }

    // --- Defender type (Terastal > Ability override > original) ---
    final PokemonType defType1;
    final PokemonType? defType2;
    if (defender.terastal.active && defender.terastal.teraType != null &&
        defender.terastal.teraType != PokemonType.stellar) {
      defType1 = defender.terastal.teraType!;
      defType2 = null;
    } else if (defTypeOverride != null) {
      defType1 = defTypeOverride.type1;
      defType2 = defTypeOverride.type2;
    } else {
      defType1 = defender.type1;
      defType2 = defender.type2;
    }

    // --- Type effectiveness (immunities removed from chart, checked below) ---
    var effectiveness = getCombinedEffectiveness(
      moveType, defType1, defType2,
      freezeDry: effectiveMove.hasTag(MoveTags.freezeDry),
      flyingPress: effectiveMove.hasTag(MoveTags.flyingPress));

    // --- Ground immunity: ungrounded targets (Flying, Levitate, Air Balloon) ---
    // Thousand Arrows bypasses this. Mold Breaker ignores Levitate.
    if (moveType == PokemonType.ground) {
      final defIsGrounded = isGrounded(
        type1: defType1, type2: defType2,
        ability: moldBreaks ? null : defAbilityName,
        item: defender.selectedItem,
        gravity: room.gravity,
      );
      if (!defIsGrounded && !effectiveMove.hasTag(MoveTags.thousandArrows)) {
        return DamageResult(
          baseDamage: 0, minDamage: 0, maxDamage: 0,
          defenderHp: defMaxHp, effectiveness: 0.0,
          isPhysical: isPhysical, move: effectiveMove,
          modifierNotes: [...notes, 'ground:ungrounded'],
        );
      }
    }

    // --- Type immunity check ---
    // Each immunity can be overridden by specific mechanics.
    // Note: Ground→Flying is handled above via isGrounded.
    if (hasTypeImmunity(moveType, defType1, defType2) &&
        moveType != PokemonType.ground) {
      bool immune = true;

      // Normal/Fighting → Ghost: overridden by Scrappy / Mind's Eye
      if ((moveType == PokemonType.normal || moveType == PokemonType.fighting) &&
          (defType1 == PokemonType.ghost || defType2 == PokemonType.ghost) &&
          canHitGhost(effectiveAbility)) {
        immune = false;
        notes.add('ability:$effectiveAbility:고스트에게 적중');
      }

      // Poison → Steel: overridden by Corrosion
      if (moveType == PokemonType.poison &&
          (defType1 == PokemonType.steel || defType2 == PokemonType.steel) &&
          canPoisonSteel(effectiveAbility)) {
        immune = false;
        notes.add('ability:Corrosion:강철에게 적중');
      }

      if (immune) {
        return DamageResult(
          baseDamage: 0, minDamage: 0, maxDamage: 0,
          defenderHp: defMaxHp, effectiveness: 0.0,
          isPhysical: isPhysical, move: effectiveMove,
          modifierNotes: [...notes, 'type:immune'],
        );
      }
    }

    // Strong Winds (Delta Stream): removes Flying-type weaknesses
    // Ice/Electric/Rock vs Flying becomes 1x instead of 2x
    if (weather == Weather.strongWinds &&
        (defType1 == PokemonType.flying || defType2 == PokemonType.flying) &&
        effectiveness > 1.0 &&
        (moveType == PokemonType.ice || moveType == PokemonType.electric || moveType == PokemonType.rock)) {
      // Recalculate without the Flying weakness
      final nonFlyingEff = defType1 == PokemonType.flying
          ? (defType2 != null ? getCombinedEffectiveness(moveType, defType2, null) : 1.0)
          : getCombinedEffectiveness(moveType, defType1, null);
      effectiveness = nonFlyingEff;
      notes.add('weather:strong_winds');
    }

    // Note: Scrappy, Ground→Flying, Corrosion immunity overrides
    // are handled above in the type immunity check section.

    // Stellar-type Tera Starstorm: super effective vs Terastallized targets
    if (moveType == PokemonType.stellar && defender.terastal.active) {
      effectiveness = 2.0;
      notes.add('스텔라: 테라스탈 상대 효과 좋음');
    }

    // Tera Shell: full HP reduces super effective to 0.5x
    // Save original effectiveness for multi-hit (subsequent hits bypass Tera Shell)
    final double preTeraShellEffectiveness = effectiveness;
    final teraShellResult = applyTeraShell(
      defenderAbility: defAbilityName,
      defenderHpPercent: defender.hpPercent,
      effectiveness: effectiveness,
    );
    if (teraShellResult != effectiveness) {
      effectiveness = teraShellResult;
      notes.add('ability:Tera Shell:×$kTeraShellReduction');
    }

    // Wonder Guard: only super effective moves deal damage
    if (isWonderGuardImmune(defAbilityName, effectiveness)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defMaxHp, effectiveness: effectiveness,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['ability:Wonder Guard:immune'],
      );
    }

    // --- STAB (with Terastal rules) ---
    final bool isOriginalStab = effectiveMove.type == atkType1 ||
        effectiveMove.type == atkType2;
    final bool isTeraStab = attacker.terastal.active &&
        attacker.terastal.teraType != null &&
        effectiveMove.type == attacker.terastal.teraType;

    double stab = 1.0;
    if (attacker.terastal.active && attacker.terastal.teraType != null) {
      final teraType = attacker.terastal.teraType!;
      if (teraType == PokemonType.stellar) {
        stab = isOriginalStab ? kStellarStabMatching : kStellarStabNonMatching;
      } else if (isTeraStab && isOriginalStab) {
        stab = abilityEffect.stabOverride != null ? 2.25 : kStellarStabMatching;
      } else if (isTeraStab) {
        stab = abilityEffect.stabOverride ?? kStandardStab;
      } else if (isOriginalStab) {
        stab = kStandardStab; // Adaptability does NOT apply to original-type STAB after Tera
      }
    } else {
      final bool hasStab = (abilityEffect.forceStab) || isOriginalStab;
      stab = hasStab ? (abilityEffect.stabOverride ?? kStandardStab) : 1.0;
    }

    // --- Weather/Terrain offensive ---
    final double weatherMod = getWeatherOffensiveModifier(atkWeather, move: effectiveMove);
    if (weatherMod == 0.0) {
      final reason = weather == Weather.harshSun
          ? 'weather:harsh_sun_water' : 'weather:heavy_rain_fire';
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defMaxHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: [...notes, reason],
      );
    }
    final atkGrounded = isGrounded(
      type1: atkType1, type2: atkType2,
      ability: atkAbilityRaw, item: attacker.selectedItem,
      gravity: room.gravity,
    );
    // Defender grounding for terrain: use effectiveDefAbility (Mold Breaker applied)
    final defGroundedForTerrain = isGrounded(
      type1: defEffType1, type2: defEffType2,
      ability: effectiveDefAbility, item: defender.selectedItem,
      gravity: room.gravity,
    );
    final double terrainMod = getTerrainModifier(terrain,
      move: effectiveMove, attackerGrounded: atkGrounded, defenderGrounded: defGroundedForTerrain);

    // --- Burn ---
    final double burnMod = (attacker.status == StatusCondition.burn &&
        isPhysical && !negatesBurn(atkAbilityRaw)) ? kBurnDamageReduction : 1.0;

    // --- Critical ---
    final double critMod = isCritical
        ? (abilityEffect.criticalOverride ?? kCriticalMultiplier) : 1.0;

    // --- Defender ability type-based damage modifier ---
    // (not included in bulk calc, so noted here)
    double defAbilityDmgMod = 1.0;
    if (defAbilityName != null) {
      defAbilityDmgMod = getDefensiveAbilityDamageMultiplier(
        defAbilityName, move: effectiveMove);
      if (defAbilityDmgMod != 1.0) {
        notes.add('ability:$defAbilityName:×$defAbilityDmgMod');
      }
    }

    // --- Effectiveness-dependent modifiers ---
    final bool isSuperEffective = effectiveness > 1.0;

    // Attacker ability damage modifier (Tinted Lens, Neuroforce)
    final atkAbilityDmg = getOffensiveAbilityDamageModifier(
      attackerAbility: effectiveAbility, effectiveness: effectiveness);
    if (atkAbilityDmg.note != null) notes.add(atkAbilityDmg.note!);

    // Defender ability damage modifier (Filter, Solid Rock, Multiscale, etc.)
    final defAbilityDmg = getDefensiveAbilityDamageModifier(
      defenderAbility: defAbilityName, effectiveness: effectiveness,
      defenderHpPercent: defender.hpPercent, moldBreaks: moldBreaks);
    if (defAbilityDmg.note != null) notes.add(defAbilityDmg.note!);

    // Item: Expert Belt (super effective -> x1.2)
    double expertBeltMod = 1.0;
    if (effectiveItem == 'expert-belt' && isSuperEffective) {
      expertBeltMod = kExpertBeltBoost;
      notes.add('item:expert-belt:×$kExpertBeltBoost');
    }

    // --- Screens (Reflect / Light Screen / Aurora Veil) ---
    final bool bypassScreens = isCritical || bypassesScreens(effectiveAbility);
    double screenMod = 1.0;
    if (!bypassScreens) {
      if (isPhysical && defender.reflect) {
        screenMod = kScreenReduction;
        notes.add('screen:reflect');
      } else if (!isPhysical && defender.lightScreen) {
        screenMod = kScreenReduction;
        notes.add('screen:light_screen');
      }
    } else if (defender.reflect || defender.lightScreen) {
      if (isCritical) notes.add('screen:bypass_crit');
      if (effectiveAbility == 'Infiltrator') notes.add('screen:bypass_infiltrator');
    }

    // --- Type-resist berry ---
    double berryMod = 1.0;
    if (defender.selectedItem != null) {
      berryMod = getResistBerryModifier(defender.selectedItem, moveType, effectiveness);
      if (berryMod != 1.0) {
        notes.add('item:${defender.selectedItem}:×$berryMod');
      }
    }

    // --- Moves that require defender to have an item ---
    if (effectiveMove.hasTag(MoveTags.requiresDefItem) && defender.selectedItem == null) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defMaxHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['상대 아이템 없음: 실패'],
      );
    }

    // --- Move-specific power modifiers based on defender state ---
    double movePowerMod = 1.0;

    if (effectiveMove.hasTag(MoveTags.knockOff) && defender.selectedItem != null) {
      final defItem = defender.selectedItem!;
      final bool isFixedItem = _isUnremovableItem(defItem);
      if (!isFixedItem) {
        movePowerMod = kKnockOffBoost;
        notes.add('move:knock_off:×$kKnockOffBoost');
      }
    }
    if (effectiveMove.hasTag(MoveTags.doubleOnStatus) && defender.status != StatusCondition.none) {
      movePowerMod *= kDoubleMovePower;
      notes.add('move:hex:×$kDoubleMovePower');
    }
    if (effectiveMove.hasTag(MoveTags.doubleOnPoison) &&
        (defender.status == StatusCondition.poison || defender.status == StatusCondition.badlyPoisoned)) {
      movePowerMod *= kDoubleMovePower;
      notes.add('move:venoshock:×$kDoubleMovePower');
    }
    if (effectiveMove.hasTag(MoveTags.doubleOnHalfHp) && defender.hpPercent <= 50) {
      movePowerMod *= kDoubleMovePower;
      notes.add('move:brine:×$kDoubleMovePower');
    }

    // Dynamax Cannon / Behemoth Blade / Behemoth Bash: x2 vs Dynamaxed target
    if (effectiveMove.hasTag(MoveTags.doubleDynamax) &&
        defender.dynamax != DynamaxState.none) {
      movePowerMod *= kDoubleMovePower;
      notes.add('다이맥스 상대 ×$kDoubleMovePower');
    }

    // Solar Beam/Blade weather halve now handled in transformMove

    // Grav Apple: gravity boost now handled in transformMove

    // Wake-Up Slap: doubled on sleeping target
    if (effectiveMove.hasTag(MoveTags.doubleOnSleep) &&
        defender.status == StatusCondition.sleep) {
      movePowerMod *= kDoubleMovePower;
      notes.add('move:wake_up_slap:×$kDoubleMovePower');
    }

    // Smelling Salts: doubled on paralyzed target
    if (effectiveMove.hasTag(MoveTags.doubleOnParalysis) &&
        defender.status == StatusCondition.paralysis) {
      movePowerMod *= kDoubleMovePower;
      notes.add('move:smelling_salts:×$kDoubleMovePower');
    }

    // Barb Barrage: doubled on poisoned target
    if (effectiveMove.hasTag(MoveTags.doubleOnPoison) &&
        (defender.status == StatusCondition.poison ||
         defender.status == StatusCondition.badlyPoisoned)) {
      movePowerMod *= kDoubleMovePower;
      notes.add('move:barb_barrage:×$kDoubleMovePower');
    }

    // Bolt Beak / Fishious Rend / Payback / Revenge / Avalanche:
    // Turn-order power doubling is now handled in move_transform.dart

    // Target-HP-based power is now handled in transformMove (_applyTargetHpPower)
    final int dynamicPower = effectiveMove.power;

    // Terastal minimum power: Tera STAB moves below threshold become threshold
    // Exceptions: multi-hit moves and priority moves are not boosted
    final bool teraMinPower = isTeraStab &&
        attacker.terastal.teraType != PokemonType.stellar &&
        !effectiveMove.isMultiHit &&
        effectiveMove.priority <= 0 &&
        dynamicPower < kTeraMinPower && dynamicPower > 0;
    final int basePower = teraMinPower ? kTeraMinPower : dynamicPower;

    // --- Base damage: official Gen V+ formula ---
    final int level = attacker.level.clamp(1, 100);
    final int power = (basePower * movePowerMod).floor();
    if (D == 0) D = 1; // prevent division by zero

    final int baseDmg = ((2 * level ~/ 5 + 2) * power * A ~/ D) ~/ 50 + 2;

    // --- Aura abilities (Fairy Aura / Dark Aura / Aura Break) ---
    final aura = getAuraModifier(
      moveType: moveType,
      attackerAbility: atkAbilityRaw,
      defenderAbility: defAbilityRaw,
    );
    if (aura.note != null) notes.add(aura.note!);

    // --- Collision Course / Electro Drift: x1.3333 on super effective ---
    double collisionMod = 1.0;
    if (isSuperEffective &&
        effectiveMove.hasTag(MoveTags.superEffectiveBoost)) {
      collisionMod = kCollisionCourseBoost;
      notes.add('move:collision:×1.33');
    }

    // --- Apply modifiers sequentially with pokeRound after each ---
    // Official Gen V+ order:
    //   baseDmg × Targets × PB × Weather × GlaiveRush × Critical
    //   × random × STAB × Type × Burn × other × ZMove × TeraShield
    // pokeRound = round to nearest, rounding DOWN at 0.5
    // Random factor uses floor (integer division by 100).
    // Parameterized for multi-hit: first hit may differ from subsequent hits
    // due to Multiscale/Shadow Shield, Tera Shell, and resist berries.
    int applyModifiers(int baseDmgInput, int randomRoll, {
      double effectivenessHit = -1,
      double defAbilityDmgHit = -1,
      double berryModHit = -1,
    }) {
      final eff = effectivenessHit < 0 ? effectiveness : effectivenessHit;
      final defAbi = defAbilityDmgHit < 0 ? defAbilityDmg.multiplier : defAbilityDmgHit;
      final berry = berryModHit < 0 ? berryMod : berryModHit;

      int d = baseDmgInput;
      // Pre-random modifiers
      d = _pokeRound(d * weatherMod);
      d = _pokeRound(d * critMod);
      // Random factor (floor, not pokeRound)
      d = d * randomRoll ~/ 100;
      // Post-random modifiers
      d = _pokeRound(d * stab);
      d = _pokeRound(d * eff);
      d = _pokeRound(d * burnMod);
      // "other" bucket: terrain, abilities, items, screens, berries
      d = _pokeRound(d * terrainMod);
      d = _pokeRound(d * powerMod);
      d = _pokeRound(d * defAbilityDmgMod);
      if (atkAbilityDmg.multiplier != 1.0) {
        d = _pokeRound(d * atkAbilityDmg.multiplier);
      }
      if (defAbi != 1.0) {
        d = _pokeRound(d * defAbi);
      }
      d = _pokeRound(d * expertBeltMod);
      d = _pokeRound(d * screenMod);
      d = _pokeRound(d * berry);
      if (aura.multiplier != 1.0) {
        d = _pokeRound(d * aura.multiplier);
      }
      d = _pokeRound(d * collisionMod);
      return d;
    }

    final int baseDamage = applyModifiers(baseDmg, RandomFactor.maxRoll);

    // --- Multi-hit: compute per-hit base damages ---
    final int hitCount = effectiveMove.isMultiHit
        ? (attacker.hitOverrides[moveIndex] ?? effectiveMove.maxHits) : 1;
    final bool isEscalating = effectiveMove.hasTag(MoveTags.escalatingHits);

    // Helper: compute all 16 roll results for a given baseDmg and modifier overrides
    List<int> allRolls(int dmg, {
      double effectivenessHit = -1,
      double defAbilityDmgHit = -1,
      double berryModHit = -1,
    }) => [
      for (int r = RandomFactor.minRoll; r <= RandomFactor.maxRoll; r++)
        applyModifiers(dmg, r,
          effectivenessHit: effectivenessHit,
          defAbilityDmgHit: defAbilityDmgHit,
          berryModHit: berryModHit,
        )
    ];

    // Single-hit: 16 possible damage values
    final singleHitRolls = allRolls(baseDmg);

    // Disguise (Disguised form): first hit deals exactly 1/8 max HP damage
    // (Ice Face works the same way). Mold Breaker bypasses this.
    final bool disguiseActive = !moldBreaks &&
        (defAbilityName == 'Disguise Disguised' || defAbilityName == 'Ice Face');
    final int disguiseDamage = disguiseActive
        ? (defMaxHp / 8).floor().clamp(1, defMaxHp)
        : 0;
    final List<int> disguiseRolls = disguiseActive
        ? List.filled(16, disguiseDamage)
        : singleHitRolls;

    // Multi-hit per-hit rolls (each hit has 16 possible values)
    List<List<int>>? perHitAllRolls;
    if (hitCount > 1) {
      // Determine which modifiers change after the first hit
      final bool hasMultiscale = defAbilityDmg.multiplier < 1.0 &&
          defender.hpPercent >= 100 &&
          (defAbilityName == 'Multiscale' || defAbilityName == 'Shadow Shield');
      final bool hasTeraShell = defAbilityName == 'Tera Shell' &&
          defender.hpPercent >= 100 && effectiveness < 1.0;
      final bool hasBerry = berryMod != 1.0;

      // On-hit stat-change effects on defender, split into:
      //   - oneTimeDefChange: consumed after first trigger (berries)
      //   - perHitDefChange:  activates on every qualifying hit (abilities)
      // Gen 7+ rule: per-hit abilities (Stamina, Weak Armor, Water Compaction)
      // compound stage-by-stage across multi-hit moves. Berries only flip once.
      int oneTimeDefChange = 0;
      int perHitDefChange = 0;
      final List<String> statChangeNotes = [];

      // One-time: Kee Berry (+1 Def vs physical)
      if (defender.selectedItem == 'kee-berry' && isPhysical) {
        oneTimeDefChange += 1;
        statChangeNotes.add('berryDefBoost:kee-berry');
      }
      // One-time: Maranga Berry (+1 SpDef vs special — treated as +Def since D is SpDef here)
      if (defender.selectedItem == 'maranga-berry' && !isPhysical) {
        oneTimeDefChange += 1;
        statChangeNotes.add('berryDefBoost:maranga-berry');
      }
      // Per-hit ability: Stamina (+1 Def on any damaging hit).
      // Not suppressed by Mold Breaker (activates after damage). Only affects
      // subsequent damage when the move targets physical Defense.
      if (defAbilityName == 'Stamina' && targetPhysDef) {
        perHitDefChange += 1;
        statChangeNotes.add('abilityDefChange:Stamina:+1');
      }
      // Per-hit ability: Water Compaction (+2 Def on water hits). Only
      // affects subsequent damage when the move targets physical Defense.
      if (defAbilityName == 'Water Compaction' &&
          moveType == PokemonType.water && targetPhysDef) {
        perHitDefChange += 2;
        statChangeNotes.add('abilityDefChange:Water Compaction:+2');
      }
      // Per-hit ability: Weak Armor (-1 Def on physical hits).
      // Physical implies targetPhysDef, so no extra gate needed.
      if (defAbilityName == 'Weak Armor' && isPhysical) {
        perHitDefChange -= 1;
        statChangeNotes.add('abilityDefChange:Weak Armor:-1');
      }
      notes.addAll(statChangeNotes);

      // Convert stage count to a defense value. +1→×1.5, +2→×2.0, -1→×2/3...
      int dAtStage(int stage) {
        final clamped = stage.clamp(-6, 6);
        if (clamped > 0) return (D * (2 + clamped) ~/ 2);
        if (clamped < 0) return (D * 2 ~/ (2 - clamped));
        return D;
      }

      // Gen 9 rule: if Disguise absorbs hit 0, Kee/Maranga berry does NOT trigger
      // on that hit. Berry activation shifts to after hit 1 (the first post-bust hit).
      // Normal case: berry activates after hit 0, so stages apply from hit 1 onward.
      final int berryActivationIdx = (disguiseActive && oneTimeDefChange != 0) ? 2 : 1;

      // Stages that apply BEFORE hit i (0-indexed). Hit 0: no triggers yet.
      // Per-hit abilities accumulate from every prior qualifying hit. Berry
      // contribution is gated on berryActivationIdx (Gen 9 Disguise rule).
      int stagesBeforeHit(int i) {
        if (i == 0) return 0;
        final int berry = (i >= berryActivationIdx) ? oneTimeDefChange : 0;
        return berry + perHitDefChange * i;
      }

      // Fast path: all hits 2+ share the same stages. Applies when no per-hit
      // accumulation AND berry trigger is at idx=1 (or no berry).
      final bool canUseFastPath = perHitDefChange == 0 && berryActivationIdx == 1;
      final int dForSubHits = dAtStage(oneTimeDefChange + perHitDefChange);
      final bool defChanged = (oneTimeDefChange != 0) || (perHitDefChange != 0);
      final int subBaseDmg = defChanged
          ? ((2 * level ~/ 5 + 2) * power * A ~/ dForSubHits) ~/ 50 + 2
          : baseDmg;

      final double subEff = hasTeraShell ? preTeraShellEffectiveness : -1;
      final double subDef = hasMultiscale ? 1.0 : -1;
      final double subBerry = hasBerry ? 1.0 : -1;

      final bool isParentalBond = effectiveMove.hasTag(MoveTags.parentalBond);

      if (isEscalating) {
        final singleHitPower = effectiveMove.power;
        perHitAllRolls = List.generate(hitCount, (i) {
          final hitPower = (singleHitPower * (i + 1) * movePowerMod).floor();
          final dForHit = dAtStage(stagesBeforeHit(i));
          final hitBaseDmg = ((2 * level ~/ 5 + 2) * hitPower * A ~/ dForHit) ~/ 50 + 2;
          if (i == 0) return allRolls(hitBaseDmg);
          return allRolls(hitBaseDmg,
            effectivenessHit: subEff, defAbilityDmgHit: subDef, berryModHit: subBerry);
        });
      } else if (isParentalBond) {
        // Parental Bond: hit 1 full, hit 2 at 0.25× power.
        final firstHitRolls = disguiseActive ? disguiseRolls : singleHitRolls;

        // Target-HP-dependent power moves (Hard Press=100, Crush Grip/Wring Out=120):
        // Hit 2 recalculates power from remaining HP after hit 1.
        final bool hpDependent120 = effectiveMove.hasTag(MoveTags.powerByTargetHp120);
        final bool hpDependent100 = effectiveMove.hasTag(MoveTags.powerByTargetHp100);

        if (hpDependent120 || hpDependent100) {
          final int maxPower = hpDependent120 ? 120 : 100;
          final int initialCurrentHp =
              (defMaxHp * defender.hpPercent / 100).floor().clamp(1, defMaxHp);
          // 16 aligned pairs: hit 2 at random roll i uses power from remaining HP
          // after hit 1's damage at roll i. This is a simplification vs the true
          // 16×16 independent random rolls, but gives a sensible per-hit display.
          // Convention matches other multi-hit moves: show full hit 2 damage even
          // when hit 1 would KO (mid-attack KO doesn't zero out the display).
          final secondHitRolls = List<int>.generate(
              RandomFactor.maxRoll - RandomFactor.minRoll + 1, (idx) {
            final int randomRoll = RandomFactor.minRoll + idx;
            final int hit1Dmg = firstHitRolls[idx];
            final int remainingHp = (initialCurrentHp - hit1Dmg).clamp(0, defMaxHp);
            final int hit2BasePower = (maxPower * remainingHp / defMaxHp).floor().clamp(1, maxPower);
            final int hit2PbPower = (hit2BasePower * kParentalBondSecondHit).floor().clamp(1, 999);
            final int hit2PowerMod = (hit2PbPower * movePowerMod).floor().clamp(1, 9999);
            final int hit2BaseDmg =
                ((2 * level ~/ 5 + 2) * hit2PowerMod * A ~/ dForSubHits) ~/ 50 + 2;
            return applyModifiers(hit2BaseDmg, randomRoll,
                effectivenessHit: subEff, defAbilityDmgHit: subDef, berryModHit: subBerry);
          });
          perHitAllRolls = [firstHitRolls, secondHitRolls];
        } else {
          final int pbPower = (effectiveMove.power * kParentalBondSecondHit).floor().clamp(1, 999);
          final int pbPowerMod = (pbPower * movePowerMod).floor().clamp(1, 9999);
          final int pbBaseDmg = ((2 * level ~/ 5 + 2) * pbPowerMod * A ~/ dForSubHits) ~/ 50 + 2;
          final secondHitRolls = allRolls(pbBaseDmg,
              effectivenessHit: subEff, defAbilityDmgHit: subDef, berryModHit: subBerry);
          perHitAllRolls = [firstHitRolls, secondHitRolls];
        }
      } else {
        final firstHitRolls = disguiseActive ? disguiseRolls : singleHitRolls;
        if (!canUseFastPath) {
          // Per-hit stage changes (abilities) or Gen 9 Disguise-delayed berry:
          // each hit gets its own damage rolls based on stagesBeforeHit(i).
          final hits = <List<int>>[firstHitRolls];
          for (int i = 1; i < hitCount; i++) {
            final dForHit = dAtStage(stagesBeforeHit(i));
            final hitBaseDmg = ((2 * level ~/ 5 + 2) * power * A ~/ dForHit) ~/ 50 + 2;
            hits.add(allRolls(hitBaseDmg,
                effectivenessHit: subEff, defAbilityDmgHit: subDef, berryModHit: subBerry));
          }
          perHitAllRolls = hits;
        } else {
          // Fast path: hits 2+ share a single subHitRolls (Multiscale, Tera
          // Shell, resist berry, Kee/Maranga berry without Disguise).
          final subHitRolls = (hasMultiscale || hasTeraShell || hasBerry || disguiseActive || defChanged)
              ? allRolls(subBaseDmg,
                  effectivenessHit: subEff, defAbilityDmgHit: subDef, berryModHit: subBerry)
              : singleHitRolls;
          perHitAllRolls = [firstHitRolls, ...List.filled(hitCount - 1, subHitRolls)];
        }
      }
    }

    // --- Compute min/max damage ---
    final int minDamage, maxDamage;
    if (perHitAllRolls != null) {
      int minSum = 0, maxSum = 0;
      for (final rolls in perHitAllRolls) {
        minSum += rolls.reduce(math.min);
        maxSum += rolls.reduce(math.max);
      }
      minDamage = minSum;
      maxDamage = maxSum;
    } else if (disguiseActive) {
      // Single-hit against Disguise: damage is fixed at 1/8 max HP
      minDamage = disguiseDamage;
      maxDamage = disguiseDamage;
    } else {
      minDamage = singleHitRolls.reduce(math.min);
      maxDamage = singleHitRolls.reduce(math.max);
    }

    // Use current HP (based on hpPercent) for KO calculations
    final int currentHp = (defMaxHp * defender.hpPercent / 100).floor();

    // Add Disguise note when active
    if (disguiseActive) {
      notes.add('disguise:$defAbilityName');
    }

    return DamageResult(
      baseDamage: disguiseActive && perHitAllRolls == null ? disguiseDamage : baseDamage,
      minDamage: minDamage,
      maxDamage: maxDamage,
      defenderHp: currentHp > 0 ? currentHp : defMaxHp,
      effectiveness: effectiveness,
      isPhysical: isPhysical,
      targetPhysDef: targetPhysDef,
      move: effectiveMove,
      modifierNotes: notes,
      allRolls: disguiseActive && perHitAllRolls == null ? disguiseRolls : singleHitRolls,
      perHitAllRolls: perHitAllRolls,
    );
  }

  /// Fixed damage moves bypass the normal damage formula.
  /// - fixedLevel: damage = attacker's level (Night Shade, Seismic Toss)
  /// OHKO moves deal damage equal to the defender's current HP.
  /// Blocked by: type immunity, Sturdy, Dynamax, Sheer Cold vs Ice-type.
  static DamageResult _calcOhkoDamage({
    required BattlePokemonState attacker,
    required BattlePokemonState defender,
    required Move move,
    String? defenderAbility,
    required RoomConditions room,
  }) {
    final defStats = StatCalculator.calculate(
      baseStats: defender.baseStats, iv: defender.iv, ev: defender.ev,
      nature: defender.nature, level: defender.level,
    );
    final defHp = defender.dynamax != DynamaxState.none
        ? defStats.hp * 2 : defStats.hp;
    final isPhysical = move.category == MoveCategory.physical;

    DamageResult immune(List<String> notes) => DamageResult(
      baseDamage: 0, minDamage: 0, maxDamage: 0,
      defenderHp: defHp, effectiveness: 0.0,
      isPhysical: isPhysical, move: move,
      modifierNotes: notes,
    );

    // Dynamax targets are immune to OHKO
    if (defender.dynamax != DynamaxState.none) {
      return immune(['다이맥스 상대에게 일격기 무효']);
    }

    // Resolve defender's effective types (Terastal overrides)
    final defEffType1 = (defender.terastal.active && defender.terastal.teraType != null)
        ? defender.terastal.teraType! : defender.type1;
    final PokemonType? defEffType2 = (defender.terastal.active && defender.terastal.teraType != null)
        ? null : defender.type2;

    // Ground OHKO (Fissure): ungrounded targets are immune
    if (move.type == PokemonType.ground) {
      final defIsGrounded = isGrounded(
        type1: defEffType1, type2: defEffType2,
        ability: defenderAbility,
        item: defender.selectedItem,
        gravity: room.gravity,
      );
      if (!defIsGrounded) {
        return immune(['ground:ungrounded']);
      }
    }

    // Type immunity (Normal→Ghost, etc.) — Ground→Flying handled above
    if (hasTypeImmunity(move.type, defEffType1, defEffType2) &&
        move.type != PokemonType.ground) {
      return immune(['type:immune']);
    }

    // Sheer Cold: Ice-type targets are immune (Gen 7+)
    if (move.hasTag(MoveTags.ohkoIceImmune) &&
        (defEffType1 == PokemonType.ice ||
         defEffType2 == PokemonType.ice)) {
      return immune(['얼음 타입에게 절대영도 무효']);
    }

    // Sturdy: immune to OHKO moves
    if (isSturdyOhkoImmune(defenderAbility)) {
      return immune(['ability:Sturdy:일격기 무효']);
    }

    // Disguise: intercepts damage formula, deals exactly 1/8 max HP instead.
    // (Reaches here only if Mold Breaker didn't bypass it, since earlyDefAbility is null then.)
    if (defenderAbility == 'Disguise Disguised') {
      final disguiseDamage = (defHp / 8).floor().clamp(1, defHp);
      return DamageResult(
        baseDamage: disguiseDamage,
        minDamage: disguiseDamage,
        maxDamage: disguiseDamage,
        defenderHp: defHp,
        effectiveness: 1.0,
        isPhysical: isPhysical,
        move: move,
        modifierNotes: ['disguise:$defenderAbility'],
      );
    }

    // OHKO: damage = defender's current HP
    final currentHp = (defHp * defender.hpPercent / 100).ceil().clamp(1, defHp);
    return DamageResult(
      baseDamage: currentHp,
      minDamage: currentHp,
      maxDamage: currentHp,
      defenderHp: defHp,
      effectiveness: 1.0,
      isPhysical: isPhysical,
      move: move,
      modifierNotes: ['일격기: 상대 HP 전량'],
    );
  }

  /// - fixedHalfHp: damage = defender's HP / 2 (Super Fang)
  /// Type immunities still apply; stat/item modifiers do not.
  static DamageResult _calcFixedDamage({
    required BattlePokemonState attacker,
    required BattlePokemonState defender,
    required Move move,
    required Weather weather,
    required RoomConditions room,
    String? defenderAbility,
  }) {
    final defStats = StatCalculator.calculate(
      baseStats: defender.baseStats, iv: defender.iv, ev: defender.ev,
      nature: defender.nature, level: defender.level,
    );
    final defHp = defender.dynamax != DynamaxState.none
        ? defStats.hp * 2
        : defStats.hp;
    final isPhysical = move.category == MoveCategory.physical;

    // Type immunity check
    final effectiveness = getCombinedEffectiveness(
      move.type, defender.type1, defender.type2);
    if (effectiveness == 0.0) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: move,
        modifierNotes: ['type:immune'],
      );
    }

    // Ability type immunity
    if (defenderAbility != null &&
        isAbilityTypeImmune(defenderAbility, move.type)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: move,
        modifierNotes: ['ability:$defenderAbility:immune'],
      );
    }

    // Disguise: intercepts damage formula, replaces fixed damage with 1/8 max HP.
    // (Reaches here only if Mold Breaker didn't bypass it, since earlyDefAbility is null then.)
    // Parental Bond + Disguise: only the first hit is absorbed; 2nd hit deals full
    // fixed damage against the busted form, based on HP remaining after hit 1.
    if (defenderAbility == 'Disguise Disguised') {
      final int currentBaseHpForDisguise =
          (defStats.hp * defender.hpPercent / 100).ceil().clamp(1, defStats.hp);
      final disguiseDamage = (defHp / 8).floor().clamp(1, defHp);
      final bool pbFixed = move.hasTag(MoveTags.parentalBondFixed);
      // Hit 2 uses remaining CURRENT HP (not max HP), clamped to min 1 to keep
      // display consistent with other multi-hit moves when hit 1 would KO.
      final int secondHit;
      if (!pbFixed) {
        secondHit = 0;
      } else {
        final int remainingCurrent = (currentBaseHpForDisguise - disguiseDamage).clamp(1, defStats.hp);
        if (move.hasTag(MoveTags.fixedLevel)) {
          secondHit = attacker.level.clamp(1, 100);
        } else if (move.hasTag(MoveTags.fixed20)) {
          secondHit = 20;
        } else if (move.hasTag(MoveTags.fixed40)) {
          secondHit = 40;
        } else if (move.hasTag(MoveTags.fixedThreeQuarterHp)) {
          secondHit = (remainingCurrent * 3 / 4).ceil().clamp(1, defHp);
        } else {
          secondHit = (remainingCurrent / 2).ceil().clamp(1, defHp);
        }
      }
      final total = pbFixed ? disguiseDamage + secondHit : disguiseDamage;
      final List<List<int>>? perHit = pbFixed
          ? [List.filled(16, disguiseDamage), List.filled(16, secondHit)]
          : null;
      return DamageResult(
        baseDamage: total,
        minDamage: total,
        maxDamage: total,
        perHitAllRolls: perHit,
        defenderHp: defHp,
        effectiveness: 1.0,
        isPhysical: isPhysical,
        move: move,
        modifierNotes: ['disguise:$defenderAbility'],
      );
    }

    // Compute fixed damage for a given remaining-HP (in base stats scale).
    // For HP-independent variants (fixedLevel/fixed20/fixed40) remainingBaseHp is unused.
    int computeFixed(int remainingBaseHp) {
      if (move.hasTag(MoveTags.fixedLevel)) {
        return attacker.level.clamp(1, 100);
      } else if (move.hasTag(MoveTags.fixed20)) {
        return 20;
      } else if (move.hasTag(MoveTags.fixed40)) {
        return 40;
      } else if (move.hasTag(MoveTags.fixedThreeQuarterHp)) {
        return (remainingBaseHp * 3 / 4).ceil().clamp(1, defHp);
      } else {
        // fixedHalfHp
        return (remainingBaseHp / 2).ceil().clamp(1, defHp);
      }
    }

    final int baseHp = defStats.hp;
    final int currentBaseHp = (baseHp * defender.hpPercent / 100).ceil().clamp(1, baseHp);
    final int fixedDamage = computeFixed(currentBaseHp);

    final notes = <String>[];
    if (move.hasTag(MoveTags.fixedHalfHp) && defender.dynamax != DynamaxState.none) {
      notes.add('다이맥스: 비다이맥스 HP 기준 50%');
    }

    // Parental Bond on fixed-damage moves: hit 2 recalculates against remaining HP.
    // Convention matches other multi-hit moves: show full hit 2 damage even when
    // hit 1 would KO. For HP-based variants (Super Fang etc.), remaining HP is
    // clamped to min 1 so the display never collapses to zero.
    final bool pbFixed = move.hasTag(MoveTags.parentalBondFixed);
    final int secondHitFixed = pbFixed
        ? computeFixed((currentBaseHp - fixedDamage).clamp(1, baseHp))
        : 0;
    final int totalFixed = pbFixed ? fixedDamage + secondHitFixed : fixedDamage;
    final List<List<int>>? pbPerHit = pbFixed
        ? [List.filled(16, fixedDamage), List.filled(16, secondHitFixed)]
        : null;

    return DamageResult(
      baseDamage: totalFixed,
      minDamage: totalFixed,
      maxDamage: totalFixed,
      perHitAllRolls: pbPerHit,
      defenderHp: defHp,
      effectiveness: 1.0,
      isPhysical: isPhysical,
      move: move,
      modifierNotes: notes,
    );
  }
}
