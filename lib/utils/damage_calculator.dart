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
import 'battle_facade.dart' show dmaxNullItems, dmaxNullAbilities, resolveEffectiveItem, resolveEffectiveAbility, BattleFacade;
import 'grounded.dart';
import 'item_effects.dart';
import 'move_transform.dart';
import 'random_factor.dart';
import 'speed_calculator.dart';
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

    // Note: power == 0 check moved AFTER transform, since weight-based
    // and speed-based moves start at 0 and get power from transform.

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
      userType1: attacker.type1,
      heldItem: attacker.selectedItem,
      hitCount: move.isMultiHit
          ? (attacker.hitOverrides[moveIndex] ?? move.maxHits) : null,
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

    // --- Fixed damage moves (checked after transform so Dynamax → Max Guard passes) ---
    if (effectiveMove.hasTag(MoveTags.fixedLevel) || effectiveMove.hasTag(MoveTags.fixedHalfHp) ||
        effectiveMove.hasTag(MoveTags.fixed20) || effectiveMove.hasTag(MoveTags.fixed40)) {
      return _calcFixedDamage(
        attacker: attacker, defender: defender, move: effectiveMove,
        weather: weather, room: room,
        defenderAbility: defAbilityRaw,
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

    // Psyshock/Psystrike/Secret Sword: special move targeting physical Defense
    final bool targetPhysDef = isPhysical || effectiveMove.hasTag(MoveTags.targetPhysDef);
    int D = targetPhysDef ? defActual.defense : defActual.spDefense;

    // Mold Breaker or ability-ignoring moves: ignore defender's ignorable abilities
    final bool moldBreaks = shouldIgnoreAbility(effectiveAbility, defAbilityRaw) ||
        (effectiveMove.hasTag(MoveTags.ignoreAbility) &&
         defAbilityRaw != null && ignorableAbilities.contains(defAbilityRaw));
    final String? effectiveDefAbility = moldBreaks ? null : defAbilityRaw;

    // Shell Armor / Battle Armor: negate critical hit
    String? critNegateNote;
    if (isCritical && isCritImmune(effectiveDefAbility)) {
      isCritical = false;
      critNegateNote = 'ability:$effectiveDefAbility:급소에 맞지 않음';
    }

    // Defender ability/item defensive modifiers
    if (effectiveDefAbility != null) {
      final defAbility = getDefensiveAbilityEffect(
        effectiveDefAbility, status: defender.status, weather: weather, terrain: terrain);
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

    // Priority move immunity (Queenly Majesty, Dazzling, Armor Tail)
    // Mold Breaker ignores this
    if (!moldBreaks && effectiveMove.priority > 0 && defAbilityName != null) {
      const priorityBlockers = {'Queenly Majesty', 'Dazzling', 'Armor Tail'};
      if (priorityBlockers.contains(defAbilityName)) {
        return DamageResult(
          baseDamage: 0, minDamage: 0, maxDamage: 0,
          defenderHp: defActual.hp, effectiveness: 0.0,
          isPhysical: isPhysical, move: effectiveMove,
          modifierNotes: ['ability:$defAbilityName:선공기 무효'],
        );
      }
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
          defenderHp: defActual.hp, effectiveness: 0.0,
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

    // --- Type immunity check ---
    // Each immunity can be overridden by specific mechanics.
    if (hasTypeImmunity(moveType, defType1, defType2)) {
      bool immune = true;

      // Normal/Fighting → Ghost: overridden by Scrappy / Mind's Eye
      if ((moveType == PokemonType.normal || moveType == PokemonType.fighting) &&
          (defType1 == PokemonType.ghost || defType2 == PokemonType.ghost) &&
          (effectiveAbility == 'Scrappy' || effectiveAbility == "Mind's Eye")) {
        immune = false;
        notes.add('ability:$effectiveAbility:고스트에게 적중');
      }

      // Ground → Flying: overridden by grounding or Thousand Arrows
      if (moveType == PokemonType.ground &&
          (defType1 == PokemonType.flying || defType2 == PokemonType.flying)) {
        final defIsGrounded = isGrounded(
          type1: defType1, type2: defType2,
          ability: defAbilityName, item: defender.selectedItem,
          gravity: room.gravity,
        );
        if (defIsGrounded || effectiveMove.hasTag(MoveTags.thousandArrows)) {
          immune = false;
        }
      }

      // Poison → Steel: overridden by Corrosion
      if (moveType == PokemonType.poison &&
          (defType1 == PokemonType.steel || defType2 == PokemonType.steel) &&
          effectiveAbility == 'Corrosion') {
        immune = false;
        notes.add('ability:Corrosion:강철에게 적중');
      }

      if (immune) {
        return DamageResult(
          baseDamage: 0, minDamage: 0, maxDamage: 0,
          defenderHp: defActual.hp, effectiveness: 0.0,
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
    if (defAbilityName == 'Tera Shell' &&
        defender.hpPercent >= 100 &&
        effectiveness > 1.0) {
      effectiveness = kTeraShellReduction;
      notes.add('ability:Tera Shell:×$kTeraShellReduction');
    }

    // Wonder Guard: only super effective moves deal damage
    if (defAbilityName == 'Wonder Guard' && effectiveness <= 1.0) {
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defActual.hp, effectiveness: effectiveness,
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
      } else if (isTeraStab || isOriginalStab) {
        stab = abilityEffect.stabOverride ?? kStandardStab;
      }
    } else {
      final bool hasStab = (abilityEffect.forceStab) || isOriginalStab;
      stab = hasStab ? (abilityEffect.stabOverride ?? kStandardStab) : 1.0;
    }

    // --- Weather/Terrain offensive ---
    final double weatherMod = getWeatherOffensiveModifier(weather, move: effectiveMove);
    if (weatherMod == 0.0) {
      final reason = weather == Weather.harshSun
          ? 'weather:harsh_sun_water' : 'weather:heavy_rain_fire';
      return DamageResult(
        baseDamage: 0, minDamage: 0, maxDamage: 0,
        defenderHp: defActual.hp, effectiveness: 0.0,
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
    final bool hasGuts = atkAbilityRaw == 'Guts';
    final double burnMod = (attacker.status == StatusCondition.burn &&
        isPhysical && !hasGuts) ? kBurnDamageReduction : 1.0;

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
      expertBeltMod = kExpertBeltBoost;
      notes.add('item:expert-belt:×$kExpertBeltBoost');
    }

    // --- Screens (Reflect / Light Screen / Aurora Veil) ---
    final bool bypassScreens = isCritical || effectiveAbility == 'Infiltrator';
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
        defenderHp: defActual.hp, effectiveness: 0.0,
        isPhysical: isPhysical, move: effectiveMove,
        modifierNotes: ['상대 아이템 없음: 실패'],
      );
    }

    // --- Move-specific power modifiers based on defender state ---
    double movePowerMod = 1.0;

    if (effectiveMove.hasTag(MoveTags.knockOff) && defender.selectedItem != null) {
      final defItem = defender.selectedItem!;
      final bool isFixedItem = defItem == defender.pokemonName.toLowerCase().replaceAll(' ', '-') ||
          _isUnremovableItem(defItem, defender.pokemonName);
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

    // Solar Beam / Solar Blade: halved in rain, sandstorm, snow, heavy rain
    if (effectiveMove.hasTag(MoveTags.solarHalve) &&
        (weather == Weather.rain || weather == Weather.sandstorm ||
         weather == Weather.snow || weather == Weather.heavyRain)) {
      movePowerMod *= kSolarBeamWeatherPenalty;
      notes.add('move:solar_halve:×$kSolarBeamWeatherPenalty');
    }

    // Grav Apple: boosted under gravity
    if (effectiveMove.hasTag(MoveTags.gravityBoost) && room.gravity) {
      movePowerMod *= kGravAppleBoost;
      notes.add('move:grav_apple:×$kGravAppleBoost');
    }

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

    // Power scales with target's remaining HP
    int dynamicPower = effectiveMove.power;
    if (effectiveMove.hasTag(MoveTags.powerByTargetHp120)) {
      // Wring Out / Crush Grip: power = 120 × (target current HP / target max HP) + 1
      dynamicPower = (120 * defender.hpPercent / 100).floor().clamp(1, 120) + 1;
    } else if (effectiveMove.hasTag(MoveTags.powerByTargetHp100)) {
      // Hard Press: power = 100 × (target current HP / target max HP) + 1
      dynamicPower = (100 * defender.hpPercent / 100).floor().clamp(1, 100) + 1;
    }

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

    // --- Apply modifiers sequentially with floor after each ---
    // Order follows the official Gen V+ damage formula.
    int baseDamage = baseDmg;
    baseDamage = (baseDamage * stab).floor();
    baseDamage = (baseDamage * effectiveness).floor();
    baseDamage = (baseDamage * weatherMod).floor();
    baseDamage = (baseDamage * terrainMod).floor();
    baseDamage = (baseDamage * burnMod).floor();
    baseDamage = (baseDamage * critMod).floor();
    baseDamage = (baseDamage * powerMod).floor();
    baseDamage = (baseDamage * defAbilityDmgMod).floor();
    if (atkAbilityDmg.multiplier != 1.0) {
      baseDamage = (baseDamage * atkAbilityDmg.multiplier).floor();
    }
    if (defAbilityDmg.multiplier != 1.0) {
      baseDamage = (baseDamage * defAbilityDmg.multiplier).floor();
    }
    baseDamage = (baseDamage * expertBeltMod).floor();
    baseDamage = (baseDamage * screenMod).floor();
    baseDamage = (baseDamage * berryMod).floor();
    if (aura.multiplier != 1.0) {
      baseDamage = (baseDamage * aura.multiplier).floor();
    }
    baseDamage = (baseDamage * collisionMod).floor();

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
