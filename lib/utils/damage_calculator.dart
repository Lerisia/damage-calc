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
    final transformed = transformMove(effectiveMove, moveCtx);
    effectiveMove = transformed.move;

    // --- Gravity: certain moves are disabled (checked AFTER transform,
    //     so Dynamax moves are not affected) ---
    if (room.gravity && effectiveMove.hasTag(MoveTags.disabledByGravity)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: 1, effectiveness: 0.0,
        isPhysical: effectiveMove.category == MoveCategory.physical,
        move: effectiveMove,
        modifierNotes: ['중력: 사용 불가'],
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
        abilityStatMod = 1.0;
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

      // Stat-changing items/abilities on hit: not simulated, warn user
      if (defender.selectedItem == 'kee-berry' && isPhysical) {
        notes.add('warning:연속기 악키열매 방어↑ 미반영');
      } else if (defender.selectedItem == 'maranga-berry' && !isPhysical) {
        notes.add('warning:연속기 타라프열매 특방↑ 미반영');
      }
      if (defAbilityName == 'Weak Armor' && isPhysical) {
        notes.add('warning:연속기 깨어진갑옷 방어↓ 미반영');
      } else if (defAbilityName == 'Stamina' && isPhysical) {
        notes.add('warning:연속기 지구력 방어↑ 미반영');
      } else if (defAbilityName == 'Water Compaction' &&
          isPhysical && moveType == PokemonType.water) {
        notes.add('warning:연속기 아쿠아코트 방어↑↑ 미반영');
      }

      final double subEff = hasTeraShell ? preTeraShellEffectiveness : -1;
      final double subDef = hasMultiscale ? 1.0 : -1;
      final double subBerry = hasBerry ? 1.0 : -1;

      if (isEscalating) {
        final singleHitPower = effectiveMove.power;
        perHitAllRolls = List.generate(hitCount, (i) {
          final hitPower = (singleHitPower * (i + 1) * movePowerMod).floor();
          final hitBaseDmg = ((2 * level ~/ 5 + 2) * hitPower * A ~/ D) ~/ 50 + 2;
          if (i == 0) return allRolls(hitBaseDmg);
          return allRolls(hitBaseDmg,
            effectivenessHit: subEff, defAbilityDmgHit: subDef, berryModHit: subBerry);
        });
      } else {
        final firstHitRolls = singleHitRolls;
        final subHitRolls = (hasMultiscale || hasTeraShell || hasBerry)
            ? allRolls(baseDmg,
                effectivenessHit: subEff, defAbilityDmgHit: subDef, berryModHit: subBerry)
            : firstHitRolls;
        perHitAllRolls = [firstHitRolls, ...List.filled(hitCount - 1, subHitRolls)];
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
    } else {
      minDamage = singleHitRolls.reduce(math.min);
      maxDamage = singleHitRolls.reduce(math.max);
    }

    // Use current HP (based on hpPercent) for KO calculations
    final int currentHp = (defMaxHp * defender.hpPercent / 100).floor();

    return DamageResult(
      baseDamage: baseDamage,
      minDamage: minDamage,
      maxDamage: maxDamage,
      defenderHp: currentHp > 0 ? currentHp : defMaxHp,
      effectiveness: effectiveness,
      isPhysical: isPhysical,
      targetPhysDef: targetPhysDef,
      move: effectiveMove,
      modifierNotes: notes,
      allRolls: singleHitRolls,
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

    // Calculate fixed damage
    final int fixedDamage;
    if (move.hasTag(MoveTags.fixedLevel)) {
      fixedDamage = attacker.level.clamp(1, 100);
    } else if (move.hasTag(MoveTags.fixed20)) {
      fixedDamage = 20;
    } else if (move.hasTag(MoveTags.fixed40)) {
      fixedDamage = 40;
    } else if (move.hasTag(MoveTags.fixedThreeQuarterHp)) {
      // fixedThreeQuarterHp: 75% of defender's current HP (Guardian of Alola)
      final baseHp = defStats.hp;
      final currentBaseHp = (baseHp * defender.hpPercent / 100).ceil().clamp(1, baseHp);
      fixedDamage = (currentBaseHp * 3 / 4).ceil().clamp(1, defHp);
    } else {
      // fixedHalfHp: half of defender's current HP (based on non-Dynamax HP)
      final baseHp = defStats.hp;
      final currentBaseHp = (baseHp * defender.hpPercent / 100).ceil().clamp(1, baseHp);
      fixedDamage = (currentBaseHp / 2).ceil().clamp(1, defHp);
    }

    final notes = <String>[];
    if (move.hasTag(MoveTags.fixedHalfHp) && defender.dynamax != DynamaxState.none) {
      notes.add('다이맥스: 비다이맥스 HP 기준 50%');
    }

    return DamageResult(
      baseDamage: fixedDamage,
      minDamage: fixedDamage,
      maxDamage: fixedDamage,
      defenderHp: defHp,
      effectiveness: 1.0,
      isPhysical: isPhysical,
      move: move,
      modifierNotes: notes,
    );
  }
}
