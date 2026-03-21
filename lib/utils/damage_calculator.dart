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
    required this.move,
    this.modifierNotes = const [],
  });

  double get minPercent => defenderHp > 0 ? minDamage / defenderHp * 100 : 0;
  double get maxPercent => defenderHp > 0 ? maxDamage / defenderHp * 100 : 0;

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

    if (effectiveMove.category == MoveCategory.status || effectiveMove.power == 0) {
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

    final effectiveAtkRank = isCritical
        ? Rank(
            attack: (atkStat == OffensiveStat.attack || atkStat == OffensiveStat.higherAttack)
                ? math.max(0, attacker.rank.attack) : attacker.rank.attack,
            defense: atkStat == OffensiveStat.defense
                ? math.max(0, attacker.rank.defense) : attacker.rank.defense,
            spAttack: (atkStat == OffensiveStat.spAttack || atkStat == OffensiveStat.higherAttack)
                ? math.max(0, attacker.rank.spAttack) : attacker.rank.spAttack,
            spDefense: attacker.rank.spDefense,
            speed: attacker.rank.speed,
          )
        : attacker.rank;

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
    // Critical hit ignores positive defense ranks
    final effectiveDefRank = isCritical
        ? Rank(
            attack: defender.rank.attack,
            defense: math.min(0, defender.rank.defense),
            spAttack: defender.rank.spAttack,
            spDefense: math.min(0, defender.rank.spDefense),
            speed: defender.rank.speed,
          )
        : defender.rank;

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

    int D = isPhysical ? defActual.defense : defActual.spDefense;

    // Defender ability/item defensive modifiers
    if (defender.selectedAbility != null) {
      final defAbility = getDefensiveAbilityEffect(
        defender.selectedAbility!, status: defender.status, weather: weather);
      D = (D * (isPhysical ? defAbility.defModifier : defAbility.spdModifier)).floor();
    }
    if (defender.selectedItem != null) {
      final defItem = getDefensiveItemEffect(
        defender.selectedItem!, finalEvo: defender.finalEvo);
      D = (D * (isPhysical ? defItem.defModifier : defItem.spdModifier)).floor();
    }
    // Weather defensive (sandstorm rock SpDef, snow ice Def)
    final weatherDef = getWeatherDefensiveModifier(
      weather, type1: defender.type1, type2: defender.type2);
    D = (D * (isPhysical ? weatherDef.defMod : weatherDef.spdMod)).floor();

    // --- Immunity checks ---
    final defAbilityName = defender.selectedAbility;
    final moveType = effectiveMove.type;
    final notes = <String>[];

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
      moveType, defender.type1, defender.type2);

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

    // Attacker: Tinted Lens (not very effective -> x2)
    double tintedLensMod = 1.0;
    if (effectiveAbility == 'Tinted Lens' && isNotVeryEffective) {
      tintedLensMod = 2.0;
      notes.add('ability:Tinted Lens:×2.0');
    }

    // Attacker: Neuroforce (super effective -> x1.25)
    double neuroforceMod = 1.0;
    if (effectiveAbility == 'Neuroforce' && isSuperEffective) {
      neuroforceMod = 1.25;
      notes.add('ability:Neuroforce:×1.25');
    }

    // Defender: Filter / Solid Rock / Prism Armor (super effective -> x0.75)
    double filterMod = 1.0;
    if (defAbilityName != null && isSuperEffective) {
      if (defAbilityName == 'Filter' || defAbilityName == 'Solid Rock' ||
          defAbilityName == 'Prism Armor') {
        filterMod = 0.75;
        notes.add('ability:$defAbilityName:×0.75');
      }
    }

    // Defender: Multiscale / Shadow Shield (full HP -> x0.5)
    double multiscaleMod = 1.0;
    if (defAbilityName != null && defender.hpPercent >= 100) {
      if (defAbilityName == 'Multiscale' || defAbilityName == 'Shadow Shield') {
        multiscaleMod = 0.5;
        notes.add('ability:$defAbilityName:×0.5');
      }
    }

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
        modifierNotes: ['상대 아이템 없음: 폴터가이스트 실패'],
      );
    }

    // --- Knock Off power boost ---
    double knockOffMod = 1.0;
    if (effectiveMove.name == 'Knock Off' && defender.selectedItem != null) {
      // Items that can't be knocked off don't grant the boost
      final defItem = defender.selectedItem!;
      final bool isFixedItem = defItem == defender.pokemonName.toLowerCase().replaceAll(' ', '-') || // requiredItem logic
          _isUnremovableItem(defItem, defender.pokemonName);
      if (!isFixedItem) {
        knockOffMod = 1.5;
        notes.add('move:knock_off:×1.5');
      }
    }

    // --- Base damage: official Gen V+ formula ---
    final int level = attacker.level;
    final int power = (effectiveMove.power * knockOffMod).floor();
    if (D == 0) D = 1; // prevent division by zero

    final int baseDmg = ((2 * level ~/ 5 + 2) * power * A ~/ D) ~/ 50 + 2;

    // --- Apply all modifiers ---
    final double modifiers = stab * effectiveness * weatherMod * terrainMod *
        burnMod * critMod * powerMod * defAbilityDmgMod *
        tintedLensMod * neuroforceMod * filterMod * multiscaleMod * expertBeltMod *
        screenMod * berryMod;

    final int baseDamage = (baseDmg * modifiers).floor();

    // --- Random factor ---
    final range = RandomFactor.range(baseDamage);

    return DamageResult(
      baseDamage: baseDamage,
      minDamage: range.min,
      maxDamage: range.max,
      defenderHp: defActual.hp,
      effectiveness: effectiveness,
      isPhysical: isPhysical,
      move: effectiveMove,
      modifierNotes: notes,
    );
  }
}
