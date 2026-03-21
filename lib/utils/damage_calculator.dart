import 'dart:math' as math;

import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/gender.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/rank.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'grounded.dart';
import 'item_effects.dart';
import 'move_transform.dart';
import 'random_factor.dart';
import 'stat_calculator.dart';
import 'terrain_effects.dart';
import 'type_effectiveness.dart';
import 'weather_effects.dart';

/// Result of a single move's damage calculation.
class DamageResult {
  /// Raw base damage before random factor
  final int baseDamage;

  /// Minimum damage (random roll 85)
  final int minDamage;

  /// Maximum damage (random roll 100)
  final int maxDamage;

  /// Defender's actual HP
  final int defenderHp;

  /// Type effectiveness multiplier
  final double effectiveness;

  /// Whether the move is physical
  final bool isPhysical;

  /// Whether the move targets the defender's physical Defense stat.
  /// True for physical moves AND special moves like Psyshock/Psystrike.
  final bool targetPhysDef;

  /// The move used (after transformation)
  final Move move;

  /// Notes explaining special modifiers applied (for UI display)
  final List<String> modifierNotes;

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
  ({int hits, int koCount, int totalCount}) get koInfo =>
      RandomFactor.nHitKo(baseDamage, defenderHp);

  /// Human-readable KO label: "확정 1타", "난수 2타", "고난수 3타", etc.
  String get koLabel {
    final info = koInfo;
    if (info.hits <= 0) return '';
    final label = RandomFactor.koLabel(info.koCount, info.totalCount) ?? '';
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
/// Mega Stones for the matching Pokemon, Z-Crystals, Primal orbs,
/// Memories (Silvally), form-change items are handled via requiredItem
/// in the Pokemon data. This covers generic categories.
bool _isUnremovableItem(String itemName, String pokemonName) {
  // Z-Crystals
  if (itemName.endsWith('--held')) return true;
  // Mega stones (if name ends with 'ite' variants)
  if (itemName.endsWith('ite') || itemName.endsWith('ite-x') || itemName.endsWith('ite-y')) {
    // Only unremovable if the Pokemon can actually use it
    // For simplicity, all mega stones are unremovable
    return true;
  }
  // Memory items (Silvally)
  if (itemName.endsWith('-memory')) return true;
  // Form-change items checked via requiredItem in Pokemon JSON
  // Primal orbs, Rusted Sword/Shield, Ogerpon masks, etc.
  const fixedItems = {
    'blue-orb', 'red-orb', 'rusted-sword', 'rusted-shield',
    'griseous-core', 'griseous-orb', 'adamant-crystal', 'lustrous-globe',
    'adamant-orb', 'lustrous-orb', // these are removable actually, but orbs are not
  };
  if (fixedItems.contains(itemName)) return true;
  // Booster Energy on Paradox Pokemon
  if (itemName == 'booster-energy') {
    final lower = pokemonName.toLowerCase();
    // Paradox Pokemon have specific names; simplify by checking ability later
    // For now, booster energy is always removable (conservative)
    return false;
  }
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

    // --- Fixed damage moves (bypass normal formula entirely) ---
    if (move.hasTag(MoveTags.fixedLevel) || move.hasTag(MoveTags.fixedHalfHp)) {
      return _calcFixedDamage(
        attacker: attacker, defender: defender, move: effectiveMove,
        weather: weather, room: room,
      );
    }

    if (effectiveMove.power == 0) {
      return DamageResult.empty;
    }

    // Transform move (weather ball, terrain pulse, skins, tera blast, etc.)
    final isDmaxed = attacker.dynamax != DynamaxState.none;
    final atkBaseStats = StatCalculator.calculate(
      baseStats: attacker.baseStats, iv: attacker.iv, ev: attacker.ev,
      nature: attacker.nature, level: attacker.level, rank: attacker.rank,
    );
    final moveCtx = MoveContext(
      weather: weather,
      terrain: terrain,
      rank: attacker.rank,
      hpPercent: attacker.hpPercent,
      hasItem: attacker.selectedItem != null,
      ability: attacker.selectedAbility,
      status: attacker.status,
      dynamax: attacker.dynamax,
      pokemonName: attacker.pokemonName,
      terastallized: attacker.terastal.active,
      teraType: attacker.terastal.teraType,
      actualAttack: atkBaseStats.attack,
      actualSpAttack: atkBaseStats.spAttack,
    );
    final transformed = transformMove(effectiveMove, moveCtx);
    effectiveMove = transformed.move;

    final isPhysical = effectiveMove.category == MoveCategory.physical;

    // --- Attacker stat ---
    final isCritical = attacker.criticals[moveIndex];
    final atkStat = transformed.offensiveStat;

    // Unaware (defender) + Critical hit rank adjustments
    var effectiveAtkRank = getEffectiveOffensiveRank(
      rank: attacker.rank,
      offensiveStat: atkStat,
      isCritical: isCritical,
      attackerAbility: attacker.selectedAbility,
      defenderAbility: defender.selectedAbility,
    );

    final atkActual = StatCalculator.calculate(
      baseStats: attacker.baseStats, iv: attacker.iv, ev: attacker.ev,
      nature: attacker.nature, level: attacker.level, rank: effectiveAtkRank,
    );

    // Resolve which stat to use (Foul Play uses opponent's attack)
    int rawA = transformed.resolveStat(atkActual, opponentAttack: opponentAttack);

    // Item effect on attacking stat
    final dmaxNullItems = {'choice-band', 'choice-specs', 'choice-scarf'};
    final effectiveItem = (isDmaxed && dmaxNullItems.contains(attacker.selectedItem))
        ? null : attacker.selectedItem;
    final itemEffect = effectiveItem != null
        ? getItemEffect(effectiveItem, move: effectiveMove, pokemonName: attacker.pokemonName)
        : const ItemEffect();

    // Ability effect
    final dmaxNullAbilities = {'Gorilla Tactics', 'Sheer Force'};
    final effectiveAbility = (isDmaxed && dmaxNullAbilities.contains(attacker.selectedAbility))
        ? null : attacker.selectedAbility;
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

    final double statMod = itemEffect.statModifier * abilityStatMod;
    double powerMod = itemEffect.powerModifier * abilityEffect.powerModifier;

    // Charge: Electric moves deal 2x damage
    if (attacker.charge && effectiveMove.type == PokemonType.electric) {
      powerMod *= 2.0;
    }

    final int A = (rawA * statMod).floor();

    // --- Defender stat ---
    // Unaware (attacker) + Critical hit rank adjustments
    final effectiveDefRank = getEffectiveDefensiveRank(
      rank: defender.rank,
      isCritical: isCritical,
      attackerAbility: effectiveAbility,
      defenderAbility: defender.selectedAbility,
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

    // Psyshock/Psystrike/Secret Sword: special move targeting physical Defense
    final bool targetPhysDef = isPhysical || effectiveMove.hasTag(MoveTags.targetPhysDef);
    int D = targetPhysDef ? defActual.defense : defActual.spDefense;

    // Mold Breaker: ignore defender's ignorable abilities
    final bool moldBreaks = shouldIgnoreAbility(effectiveAbility, defender.selectedAbility);
    final String? effectiveDefAbility = moldBreaks ? null : defender.selectedAbility;

    // Defender ability/item defensive modifiers
    if (effectiveDefAbility != null) {
      final defAbility = getDefensiveAbilityEffect(
        effectiveDefAbility, status: defender.status, weather: weather);
      D = (D * (targetPhysDef ? defAbility.defModifier : defAbility.spdModifier)).floor();
    }
    if (defender.selectedItem != null) {
      final defItem = getDefensiveItemEffect(
        defender.selectedItem!, finalEvo: defender.finalEvo);
      D = (D * (targetPhysDef ? defItem.defModifier : defItem.spdModifier)).floor();
    }
    // Weather defensive (sandstorm rock SpDef, snow ice Def)
    final weatherDef = getWeatherDefensiveModifier(
      weather, type1: defender.type1, type2: defender.type2);
    D = (D * (targetPhysDef ? weatherDef.defMod : weatherDef.spdMod)).floor();

    // --- Immunity checks ---
    final defAbilityName = effectiveDefAbility;
    final moveType = effectiveMove.type;
    final notes = <String>[];
    if (moldBreaks) notes.add('moldbreaker:${attacker.selectedAbility}');

    // Weight-based moves fail against Dynamaxed targets
    if (defender.dynamax != DynamaxState.none &&
        effectiveMove.hasTag(MoveTags.weightBased)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defActual.hp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['다이맥스 상대에게 무게 기반 기술 무효'],
      );
    }

    // Type immunity abilities (Volt Absorb, Water Absorb, Flash Fire, etc.)
    if (defAbilityName != null && isAbilityTypeImmune(defAbilityName, moveType)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defActual.hp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['ability:$defAbilityName:immune'],
      );
    }
    // Move-based immunity (Bulletproof, Soundproof, Overcoat)
    if (defAbilityName != null && isAbilityMoveImmune(defAbilityName, effectiveMove)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defActual.hp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['ability:$defAbilityName:immune'],
      );
    }

    // Ground immunity (non-grounded)
    if (moveType == PokemonType.ground) {
      final defGrounded = isGrounded(
        type1: defender.type1, type2: defender.type2,
        ability: defAbilityName, item: defender.selectedItem,
        gravity: room.gravity,
      );
      if (!defGrounded) {
        return DamageResult(
          baseDamage: 0, minDamage: 0, maxDamage: 0,
          defenderHp: defActual.hp, effectiveness: 0.0,
          isPhysical: isPhysical, move: effectiveMove,
          modifierNotes: ['ground:immune'],
        );
      }
    }

    // --- Type effectiveness ---
    final effectiveness = getCombinedEffectiveness(
      moveType, defender.type1, defender.type2,
      freezeDry: effectiveMove.hasTag(MoveTags.freezeDry));

    if (effectiveness == 0.0) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defActual.hp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['type:immune'],
      );
    }

    // --- STAB ---
    // Protean/Libero: force STAB on all moves, but NOT during Terastal
    final bool hasStab = (abilityEffect.forceStab && !attacker.terastal.active) ||
        effectiveMove.type == attacker.type1 ||
        effectiveMove.type == attacker.type2;
    final double stab = hasStab ? (abilityEffect.stabOverride ?? 1.5) : 1.0;

    // --- Weather/Terrain offensive ---
    final double weatherMod = getWeatherOffensiveModifier(weather, move: effectiveMove);
    final atkGrounded = isGrounded(
      type1: attacker.type1, type2: attacker.type2,
      ability: attacker.selectedAbility, item: attacker.selectedItem,
      gravity: room.gravity,
    );
    final defGrounded = isGrounded(
      type1: defender.type1, type2: defender.type2,
      ability: defender.selectedAbility, item: defender.selectedItem,
      gravity: room.gravity,
    );
    final double terrainMod = getTerrainModifier(terrain,
      move: effectiveMove, attackerGrounded: atkGrounded, defenderGrounded: defGrounded);

    // --- Burn ---
    final bool hasGuts = attacker.selectedAbility == 'Guts';
    final double burnMod = (attacker.status == StatusCondition.burn &&
        isPhysical && !hasGuts) ? 0.5 : 1.0;

    // --- Critical ---
    final double critMod = isCritical
        ? (abilityEffect.criticalOverride ?? 1.5) : 1.0;

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
    final bool isNotVeryEffective = effectiveness < 1.0;

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
      expertBeltMod = 1.2;
      notes.add('item:expert-belt:×1.2');
    }

    // --- Screens (Reflect / Light Screen / Aurora Veil) ---
    final bool bypassScreens = isCritical || effectiveAbility == 'Infiltrator';
    double screenMod = 1.0;
    if (!bypassScreens) {
      if (isPhysical && (defender.reflect || defender.auroraVeil)) {
        screenMod = 0.5;
        notes.add(defender.reflect ? 'screen:reflect' : 'screen:aurora_veil');
      } else if (!isPhysical && (defender.lightScreen || defender.auroraVeil)) {
        screenMod = 0.5;
        notes.add(defender.lightScreen ? 'screen:light_screen' : 'screen:aurora_veil');
      }
    } else if (defender.reflect || defender.lightScreen || defender.auroraVeil) {
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

    // --- Poltergeist: fails if defender has no item ---
    if (effectiveMove.name == 'Poltergeist' && defender.selectedItem == null) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defActual.hp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['상대 아이템 없음: 실패'],
      );
    }

    // --- Move-specific power modifiers based on defender state ---
    double movePowerMod = 1.0;

    // Knock Off: x1.5 if defender holds a removable item
    if (effectiveMove.name == 'Knock Off' && defender.selectedItem != null) {
      final defItem = defender.selectedItem!;
      final bool isFixedItem = defItem == defender.pokemonName.toLowerCase().replaceAll(' ', '-') ||
          _isUnremovableItem(defItem, defender.pokemonName);
      if (!isFixedItem) {
        movePowerMod = 1.5;
        notes.add('move:knock_off:×1.5');
      }
    }
    // Hex: x2 if defender has a status condition
    else if (effectiveMove.name == 'Hex' && defender.status != StatusCondition.none) {
      movePowerMod = 2.0;
      notes.add('move:hex:×2.0');
    }
    // Venoshock: x2 if defender is poisoned
    else if (effectiveMove.name == 'Venoshock' &&
        (defender.status == StatusCondition.poison || defender.status == StatusCondition.badlyPoisoned)) {
      movePowerMod = 2.0;
      notes.add('move:venoshock:×2.0');
    }
    // Brine: x2 if defender HP <= 50%
    else if (effectiveMove.name == 'Brine' && defender.hpPercent <= 50) {
      movePowerMod = 2.0;
      notes.add('move:brine:×2.0');
    }

    // --- Base damage: official Gen V+ formula ---
    final int level = attacker.level.clamp(1, 100);
    final int power = (effectiveMove.power * movePowerMod).floor();
    if (D == 0) D = 1; // prevent division by zero

    final int baseDmg = ((2 * level ~/ 5 + 2) * power * A ~/ D) ~/ 50 + 2;

    // --- Apply all modifiers ---
    final double modifiers = stab * effectiveness * weatherMod * terrainMod *
        burnMod * critMod * powerMod * defAbilityDmgMod *
        atkAbilityDmg.multiplier * defAbilityDmg.multiplier * expertBeltMod *
        screenMod * berryMod;

    final int baseDamage = (baseDmg * modifiers).floor();

    // --- Random factor ---
    final range = RandomFactor.range(baseDamage);

    // Use current HP (based on hpPercent) for KO calculations
    final int currentHp = (defActual.hp * defender.hpPercent / 100).floor();

    return DamageResult(
      baseDamage: baseDamage,
      minDamage: range.min,
      maxDamage: range.max,
      defenderHp: currentHp > 0 ? currentHp : defActual.hp,
      effectiveness: effectiveness,
      isPhysical: isPhysical,
      targetPhysDef: targetPhysDef,
      move: effectiveMove,
      modifierNotes: notes,
    );
  }

  /// Fixed damage moves bypass the normal damage formula.
  /// - fixedLevel: damage = attacker's level (Night Shade, Seismic Toss)
  /// - fixedHalfHp: damage = defender's HP / 2 (Super Fang)
  /// Type immunities still apply; stat/item modifiers do not.
  static DamageResult _calcFixedDamage({
    required BattlePokemonState attacker,
    required BattlePokemonState defender,
    required Move move,
    required Weather weather,
    required RoomConditions room,
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
    if (defender.selectedAbility != null &&
        isAbilityTypeImmune(defender.selectedAbility!, move.type)) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defHp, effectiveness: 0.0,
        isPhysical: isPhysical, move: move,
        modifierNotes: ['ability:${defender.selectedAbility}:immune'],
      );
    }

    // Calculate fixed damage
    final int fixedDamage;
    if (move.hasTag(MoveTags.fixedLevel)) {
      fixedDamage = attacker.level.clamp(1, 100);
    } else {
      // fixedHalfHp: half of defender's current HP
      fixedDamage = (defHp * defender.hpPercent / 100 / 2).ceil().clamp(1, defHp);
    }

    return DamageResult(
      baseDamage: fixedDamage,
      minDamage: fixedDamage,
      maxDamage: fixedDamage,
      defenderHp: defHp,
      effectiveness: 1.0,
      isPhysical: isPhysical,
      move: move,
    );
  }
}
