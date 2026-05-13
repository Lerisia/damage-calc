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
import 'aura_effects.dart';
import 'ruin_effects.dart';
import 'battle_facade.dart' show resolveEffectiveItem, resolveEffectiveAbility, BattleFacade;
import 'doubles_effects.dart';
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

/// 4096-fixed-point scale used by Pokemon Showdown's chainMods system.
/// 1.0 = 4096, 0.5 = 2048, 1.5 = 6144, etc. Matches the in-game ROM
/// integer-only chain that the disassemblers reverse-engineered.
const int _kFP = 4096;

/// 4096-fp mod constants used throughout the damage chain. Centralising
/// them keeps the routing readable and matches Showdown's table.
const int _kFP_0_25 = 1024;   // 0.25
const int _kFP_0_5 = 2048;    // 0.5
const int _kFP_0_75 = 3072;   // 0.75
const int _kFP_1 = 4096;      // 1.0
const int _kFP_1_1 = 4506;    // 1.1 (Muscle Band / Wise Glasses / Punching Glove)
const int _kFP_1_2 = 4915;    // 1.2 (Expert Belt / type-boost items)
const int _kFP_1_25 = 5120;   // 1.25 (Dry Skin)
const int _kFP_1_3 = 5325;    // 1.3 (Life Orb / Normal Gem, Sheer Force, Terrain boost)
const int _kFP_1_5 = 6144;    // 1.5 (STAB, Choice Band/Specs, Sun×Fire, Rain×Water)
const int _kFP_1_3333 = 5461; // 4/3 (Collision Course / Electro Drift on SE)
const int _kFP_2 = 8192;      // 2.0 (Huge Power / Pure Power / Tera STAB)

/// Convert a floating-point multiplier to 4096-fp. Used at boundaries
/// where existing helpers still return doubles (weather / terrain /
/// ability effects) — eventually those should return fp ints
/// directly, but this is enough to route them through chainMods.
int _toFP(double mul) => (mul * _kFP).round();

/// Showdown's chainMods: accumulate a list of 4096-fp multipliers into
/// a single integer with rounding-half-up at every step, clamped to
/// [lowerBound, upperBound]. Mirrors @smogon/calc's `util.chainMods`.
int _chainMods(List<int> mods, [int lowerBound = 410, int upperBound = 131172]) {
  int M = _kFP;
  for (final mod in mods) {
    if (mod != _kFP) {
      M = ((M * mod) + 2048) >> 12;
    }
  }
  return M.clamp(lowerBound, upperBound);
}

/// Apply a 4096-fp chain modifier to a value, rounding via pokeRound.
/// `pokeRound((value * mod) / 4096)` per Showdown's stat / damage
/// modification pattern.
int _applyChainMod(int value, int mod) =>
    _pokeRound(value * mod / _kFP);

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
bool isUnremovableItem(String itemName) {
  // Z-Crystals
  if (itemName.endsWith('--held')) return true;
  // Eviolite is removable despite ending in "ite" — explicit
  // exception keeps the suffix-based mega-stone check simple.
  if (itemName == 'eviolite') return false;
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
    AuraToggles auras = AuraToggles.inactive,
    RuinToggles ruins = RuinToggles.inactive,
    int? opponentAttack,
    int? opponentSpeed,
    int? myEffectiveSpeed,
    Gender opponentGender = Gender.unset,
  }) {
    final move = attacker.moves[moveIndex];
    if (move == null) return DamageResult.empty;

    // Original DB BP — Showdown checks `move.bp > 0` (the static base
    // power from the move data) when deciding the Tera STAB 60-BP
    // minimum. For callback-BP moves like Gyro Ball / Heat Crash this
    // is 0, so they don't get the boost even though their dynamic BP
    // is positive.
    final int originalMoveDbPower = move.power;

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
    // Tera replaces type set for hasType-based checks (Showdown semantics).
    // Stellar Tera keeps the original types.
    final atkTeraEarly = attacker.terastal.active &&
        attacker.terastal.teraType != null &&
        attacker.terastal.teraType != PokemonType.stellar;
    final defTeraEarly = defender.terastal.active &&
        defender.terastal.teraType != null &&
        defender.terastal.teraType != PokemonType.stellar;
    final atkGroundedEarly = isGrounded(
      type1: atkTeraEarly ? attacker.terastal.teraType! : attacker.type1,
      type2: atkTeraEarly ? null : attacker.type2,
      type3: atkTeraEarly ? null : attacker.type3,
      ability: atkAbilityRaw, item: attacker.selectedItem,
      gravity: room.gravity,
    );
    final defGroundedEarly = isGrounded(
      type1: defTeraEarly ? defender.terastal.teraType! : defender.type1,
      type2: defTeraEarly ? null : defender.type2,
      type3: defTeraEarly ? null : defender.type3,
      ability: defAbilityRaw, item: defender.selectedItem,
      gravity: room.gravity,
    );
    // Compute attacker / defender max HP and current HP up-front so
    // HP-scaled moves (Eruption, Water Spout, Hard Press, Crush
    // Grip, Wring Out, Reversal, Flail) get exact `floor(N * curHP
    // / maxHP)` matching @smogon/calc. Dynamax doubles maxHP
    // (floor-scaled) and curHP (ceil-scaled) per @smogon/calc's
    // pokemon.ts — the two scale separately, which we mirror so
    // pct=95 % Dynamax doesn't round to BP one off.
    final defStatsForCtx = StatCalculator.calculate(
      baseStats: defender.baseStats, iv: defender.iv, ev: defender.ev,
      nature: defender.nature, level: defender.level, rank: defender.rank,
    );
    final int defRawHp = defStatsForCtx.hp;
    final int atkRawHp = atkBaseStats.hp;
    final int defRawCurHp = (defRawHp * defender.hpPercent / 100).floor().clamp(1, defRawHp);
    final int atkRawCurHp = (atkRawHp * attacker.hpPercent / 100).floor().clamp(1, atkRawHp);
    final int defMaxHpForCtx = defender.dynamax != DynamaxState.none
        ? defRawHp * 2 : defRawHp;
    final int atkMaxHpForCtx = attacker.dynamax != DynamaxState.none
        ? atkRawHp * 2 : atkRawHp;
    final int defCurHpForCtx = defender.dynamax != DynamaxState.none
        ? (defRawCurHp * 2) : defRawCurHp;
    final int atkCurHpForCtx = attacker.dynamax != DynamaxState.none
        ? (atkRawCurHp * 2) : atkRawCurHp;
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
      myMaxHp: atkMaxHpForCtx,
      myCurHp: atkCurHpForCtx,
      opponentMaxHp: defMaxHpForCtx,
      opponentCurHp: defCurHpForCtx,
      opponentItem: defender.selectedItem,
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
    // Ability type overrides (Multitype, RKS System, etc.) collapse
    // to a pure single/dual type — they wipe any user-set 3rd type.
    final PokemonType? atkType3 = atkTypeOverride != null ? null : attacker.type3;

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
    // Note: isCritical may be overridden later by Shell Armor / Battle Armor.
    // Merciless: poisoned targets always take critical hits. We treat
    // this the same as if the user explicitly flagged a crit — keeps
    // it visible in the crit path (boost-ignore, 1.5x dmg, screen
    // bypass), and parities @smogon/calc's auto-Merciless handling.
    var isCritical = attacker.criticals[moveIndex];
    if (!isCritical && atkAbilityRaw == 'Merciless' &&
        (defender.status == StatusCondition.poison ||
         defender.status == StatusCondition.badlyPoisoned)) {
      isCritical = true;
    }
    // Always-crit moves: the per-slot crit toggle is pre-checked on
    // Pokemon load (battle_pokemon._applyChampionsUsageDefaults) and
    // on manual move selection, so the calculator just reads the
    // user's toggle here. We don't force-flip the toggle on — that
    // would clobber a user who deliberately unchecked it (e.g., to
    // model an opponent with Shell Armor / Battle Armor).
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
            mySpeed: myEffectiveSpeed,
            myGender: attacker.gender,
            opponentGender: opponentGender,
            actualStats: StatCalculator.calculate(
              baseStats: attacker.baseStats, iv: attacker.iv, ev: attacker.ev,
              nature: attacker.nature, level: attacker.level,
            ))
        : const AbilityEffect();

    // Per Bulbapedia, abilities/items framed as "boosts Attack/SpAtk"
    // (Huge Power, Choice Band, Solar Power, …) are mechanically
    // category-gated stat multipliers — Showdown handles them in the
    // atMods chain. So we pick the right multiplier by *move
    // category* (not the offensive stat OffensiveStat slot) and fold
    // the result into the Atk-stat chain below. This makes Body
    // Press (physical, uses Defense as the stat) get Huge Power × 2,
    // Choice Band × 1.5, burn ÷ 2 just like any normal physical move.
    // Pick ability stat-mod by the move's *category*. Photon Geyser
    // already flipped its category to Physical (when Atk > SpA) in
    // transformMove, so we read it directly here without the legacy
    // useHigherAtk max() hack — which used to mis-apply Guts /
    // Hustle / Solar Power to whichever side had a higher modifier.
    final double abilityStatMod = effectiveMove.category == MoveCategory.physical
        ? abilityEffect.statModifiers.attack
        : abilityEffect.statModifiers.spAttack;

    // Showdown splits these multipliers into two pre-formula chains:
    //   atMods  — Attack-stat boosters (Huge Power, Choice Band, …)
    //              applied to A before the base damage formula.
    //   basePowerMods — power boosters (Silk Scarf, Sheer Force,
    //              Muscle Band, Normal Gem, Charge, …) applied to the
    //              move's power before the formula.
    // Previously we routed all of them through a *post-formula*
    // pokeRound chain, which differs from Showdown by ±1 because the
    // base-damage formula has integer divisions (~/126, ~/50) that
    // are skipped when the multiplier is applied later. Folding them
    // into the right pre-formula chains makes our output match
    // Showdown's calc exactly. See the Kangaskhan-Silk-Scarf-Last
    // Resort case: 140×1.2 = 168 must reach the formula, not the
    // post-floor damage value, for 85 to appear in the 16-roll spread.
    // Defender abilities like Thick Fat / Heatproof / Water Bubble /
    // Purifying Salt / Dry Skin live in Showdown's atMods chain —
    // they halve (or in Dry Skin's case, boost) the attacker's Atk
    // stat for specific move types instead of multiplying the damage
    // value after the formula. Mold Breaker bypasses this just like
    // any other defender ability.
    final double defAtModMul = (defAbilityRaw != null && !earlyMoldBreaks)
        ? getDefenderAtModMultiplier(defAbilityRaw, move: effectiveMove)
        : 1.0;
    // Showdown atMods chain — abilityStatMod (Huge Power / Solar
    // Power / etc.) folded with defender at-side mods (Thick Fat /
    // Heatproof / Water Bubble / Dry Skin), item atkStatModifier
    // (Choice Band / Specs / Light Ball / Thick Club / Deep Sea
    // Tooth), and the ruin Atk multiplier — all 4096-fp integers,
    // single pokeRound after compounding.
    final atMods = <int>[];
    if (abilityStatMod != 1.0) atMods.add(_toFP(abilityStatMod));
    if (defAtModMul != 1.0) atMods.add(_toFP(defAtModMul));
    if (itemEffect.atkStatModifier != 1.0) {
      atMods.add(_toFP(itemEffect.atkStatModifier));
    }
    // (Ruin.atkMod gets appended once it's computed below — declared
    // here so the rest of this block can keep referring to `A` as the
    // chain-applied stat.)
    int A = rawA; // placeholder — finalised after ruin computation.

    // --- Ruin abilities (not affected by Mold Breaker) ---
    // Ruin needs to know which defensive stat is actually used (Def vs
    // SpD) — Psyshock / Secret Sword are special moves but still target
    // Def, so Sword of Ruin should apply even though the move is Special.
    final bool targetPhysDef =
        isPhysical || effectiveMove.hasTag(MoveTags.targetPhysDef);
    final ruinState = computeRuinState(
      attackerAbility: effectiveAbility,
      defenderAbility: defAbilityRaw,
      allyTabletsOfRuin: ruins.tabletsOfRuin,
      allySwordOfRuin: ruins.swordOfRuin,
      allyVesselOfRuin: ruins.vesselOfRuin,
      allyBeadsOfRuin: ruins.beadsOfRuin,
    );
    final ruin = getRuinEffect(
      attackerAbility: effectiveAbility,
      defenderAbility: defAbilityRaw,
      category: effectiveMove.category,
      targetPhysDef: targetPhysDef,
      state: ruinState,
    );
    if (ruin.atkMod != 1.0) atMods.add(_toFP(ruin.atkMod));
    // Final A from the chain — single pokeRound after compounding
    // all atMods at 4096 scale (Showdown's `chainMods(atMods, 410,
    // 131072)` lower/upper bounds).
    A = math.max(1, _applyChainMod(rawA, _chainMods(atMods, 410, 131072)));

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

    // Psyshock/Psystrike/Secret Sword: special move targeting physical
    // Defense. `targetPhysDef` is already computed above for Ruin.
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
    // Ability overrides collapse to a 1-or-2-type form; user's third
    // type only sticks when there is no ability-driven override.
    final defEffType3 = defTypeOverride != null ? null : defender.type3;
    // Mega Sol on the attacker negates defender-side weather buffs
    // during its own attacks (in addition to applying Sun offensively).
    final weatherForDef = effectiveDefensiveWeatherForAttack(
        weather, attackerAbility: atkAbilityRaw);
    final weatherDef = getWeatherDefensiveModifier(
      weatherForDef, type1: defEffType1, type2: defEffType2, type3: defEffType3);
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
    if (moldBreaks) {
      notes.add('moldbreaker:${attacker.selectedAbility}');
      // Name the defender ability that's being suppressed, when it's
      // one that would otherwise touch the damage — "틀깨기" alone
      // doesn't tell the user *what* got skipped.
      if (defAbilityRaw != null && ignorableAbilities.contains(defAbilityRaw)) {
        notes.add('moldbreakerBypass:$defAbilityRaw');
      }
    }
    // Defender abilities that halve the attacker's Atk/SpA for certain
    // move types (Thick Fat / Heatproof / Water Bubble / Purifying
    // Salt — applied above in the atMods chain). They shave damage but
    // appear in neither 결정력 nor 내구력, so without a note the result
    // looks unexplained. Dry Skin's ×1.25 (bpMods) is noted separately.
    if (defAtModMul != 1.0 && defAbilityRaw != null && !moldBreaks) {
      notes.add('ability:$defAbilityRaw:×$defAtModMul');
    }
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
        type1: defEffType1, type2: defEffType2, type3: defEffType3,
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
    final PokemonType? defType3;
    if (defender.terastal.active && defender.terastal.teraType != null &&
        defender.terastal.teraType != PokemonType.stellar) {
      defType1 = defender.terastal.teraType!;
      defType2 = null;
      defType3 = null;
    } else if (defTypeOverride != null) {
      defType1 = defTypeOverride.type1;
      defType2 = defTypeOverride.type2;
      defType3 = null;
    } else {
      defType1 = defender.type1;
      defType2 = defender.type2;
      defType3 = defender.type3;
    }

    // --- Type effectiveness (immunities removed from chart, checked below) ---
    var effectiveness = getCombinedEffectiveness(
      moveType, defType1, defType2,
      defType3: defType3,
      freezeDry: effectiveMove.hasTag(MoveTags.freezeDry),
      flyingPress: effectiveMove.hasTag(MoveTags.flyingPress));

    // --- Ground immunity: ungrounded targets (Flying, Levitate, Air Balloon) ---
    // Thousand Arrows bypasses this. Mold Breaker ignores Levitate.
    if (moveType == PokemonType.ground) {
      final defIsGrounded = isGrounded(
        type1: defType1, type2: defType2, type3: defType3,
        ability: moldBreaks ? null : defAbilityName,
        item: defender.selectedItem,
        gravity: room.gravity,
      );
      if (!defIsGrounded && !effectiveMove.hasTag(MoveTags.thousandArrows)) {
        final groundNote = groundImmunityNote(
          type1: defType1, type2: defType2, type3: defType3,
          ability: moldBreaks ? null : defAbilityName,
        );
        return DamageResult(
          baseDamage: 0, minDamage: 0, maxDamage: 0,
          defenderHp: defMaxHp, effectiveness: 0.0,
          isPhysical: isPhysical, move: effectiveMove,
          modifierNotes: [...notes, groundNote],
        );
      }
    }

    // --- Type immunity check ---
    // Each immunity can be overridden by specific mechanics.
    // Note: Ground→Flying is handled above via isGrounded.
    if (hasTypeImmunity(moveType, defType1, defType2, defType3: defType3) &&
        moveType != PokemonType.ground) {
      bool immune = true;

      // Normal/Fighting → Ghost: overridden by Scrappy / Mind's Eye
      if ((moveType == PokemonType.normal || moveType == PokemonType.fighting) &&
          (defType1 == PokemonType.ghost ||
           defType2 == PokemonType.ghost ||
           defType3 == PokemonType.ghost) &&
          canHitGhost(effectiveAbility)) {
        immune = false;
        notes.add('ability:$effectiveAbility:고스트에게 적중');
      }

      // Poison → Steel: overridden by Corrosion
      if (moveType == PokemonType.poison &&
          (defType1 == PokemonType.steel ||
           defType2 == PokemonType.steel ||
           defType3 == PokemonType.steel) &&
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
        (defType1 == PokemonType.flying ||
         defType2 == PokemonType.flying ||
         defType3 == PokemonType.flying) &&
        effectiveness > 1.0 &&
        (moveType == PokemonType.ice || moveType == PokemonType.electric || moveType == PokemonType.rock)) {
      // Recalculate with the Flying type stripped out so the rest of
      // the type matchup still applies.
      PokemonType? a = defType1 == PokemonType.flying ? null : defType1;
      PokemonType? b = defType2 == PokemonType.flying ? null : defType2;
      PokemonType? c = defType3 == PokemonType.flying ? null : defType3;
      // Compact non-null entries into the (1, 2?, 3?) slots.
      final remaining = [a, b, c].whereType<PokemonType>().toList();
      effectiveness = remaining.isEmpty
          ? 1.0
          : getCombinedEffectiveness(
              moveType,
              remaining[0],
              remaining.length > 1 ? remaining[1] : null,
              defType3: remaining.length > 2 ? remaining[2] : null,
            );
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
    // Per Showdown's `hasType`, a terastallized Pokémon's *type set*
    // becomes the Tera type alone (Stellar Tera still keeps the
    // original types for these checks). So Tera-Flying makes the
    // attacker ungrounded — Psychic Terrain etc. stops boosting.
    final teraActive = attacker.terastal.active &&
        attacker.terastal.teraType != null &&
        attacker.terastal.teraType != PokemonType.stellar;
    final atkGrounded = isGrounded(
      type1: teraActive ? attacker.terastal.teraType! : atkType1,
      type2: teraActive ? null : atkType2,
      type3: teraActive ? null : atkType3,
      ability: atkAbilityRaw, item: attacker.selectedItem,
      gravity: room.gravity,
    );
    // Defender grounding for terrain: use effectiveDefAbility (Mold Breaker
    // applied). Tera-Flying etc. replaces the type set per Showdown's
    // hasType, so a Tera-Flying defender becomes ungrounded.
    final defTeraActive = defender.terastal.active &&
        defender.terastal.teraType != null &&
        defender.terastal.teraType != PokemonType.stellar;
    final defGroundedForTerrain = isGrounded(
      type1: defTeraActive ? defender.terastal.teraType! : defEffType1,
      type2: defTeraActive ? null : defEffType2,
      type3: defTeraActive ? null : defEffType3,
      ability: effectiveDefAbility, item: defender.selectedItem,
      gravity: room.gravity,
    );
    final double terrainMod = getTerrainModifier(terrain,
      move: effectiveMove, attackerGrounded: atkGrounded, defenderGrounded: defGroundedForTerrain);

    // --- Burn ---
    // Facade ignores burn's Atk halving (Gen V+) in addition to its
    // own ×2 power doubling — exempt the move here too.
    final double burnMod = (attacker.status == StatusCondition.burn &&
        isPhysical && !negatesBurn(atkAbilityRaw) &&
        !effectiveMove.hasTag(MoveTags.facade)) ? kBurnDamageReduction : 1.0;

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

    // --- Screens (Reflect / Light Screen) ---
    // Aurora Veil isn't a separate path in our calc — set both
    // Reflect AND Light Screen to model it (they apply per-category
    // to the same 0.5 finalMods entry, so the effect is identical).
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

    // Knock Off power boost is applied via move_transform (so the display
    // shows the boosted power). Here we only emit the note.
    if (effectiveMove.hasTag(MoveTags.knockOff) && defender.selectedItem != null &&
        !isUnremovableItem(defender.selectedItem!)) {
      notes.add('move:knock_off:×$kKnockOffBoost');
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
    // Doubles-only modifiers (spread, helping hand, ally abilities, ...)
    final doublesMods = computeDoublesModifiers(
      attacker: attacker,
      move: effectiveMove,
      isDoubles: true,
      weather: atkWeather,
    );
    movePowerMod *= doublesMods.powerMod;
    A = (A * doublesMods.attackMod).floor();
    notes.addAll(doublesMods.notes);

    // Defender-side doubles (Friend Guard reduces damage taken by 25%).
    // Showdown routes Friend Guard through the finalMods chain
    // (gen789.ts: `finalMods.push(3072)`), not bpMods — we fold it
    // into the finalMods builder below instead of movePowerMod.
    final defenderDoubles = computeDefenderDoublesModifiers(
      defender: defender,
      isDoubles: true,
    );
    final double friendGuardMod = defenderDoubles.powerMod;
    notes.addAll(defenderDoubles.notes);

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

    // Terastal minimum power: when an adapted Tera STAB move (tera-type
    // matches both move-type and one of the user's original types) has
    // base power below 60, it's bumped to 60. The original-type match
    // is what makes this an "adapted" Tera STAB — non-adapted Tera STAB
    // (Tera-into-new-type) doesn't get this boost. Matches @smogon/calc
    // gen789.ts: `move.type === attacker.teraType && attacker.hasType(attacker.teraType)`.
    // Stellar / multi-hit / priority moves are also excluded.
    // Per @smogon/calc gen789.ts (`basePower < 60` check after the
    // bpMods chain), the Tera 60-BP minimum is evaluated on the
    // *post-chain* power. We apply the bump after the chain below.
    //
    // @smogon/calc gates this with `move.type === teraType &&
    // attacker.hasType(teraType)`, but its `hasType` swaps in the
    // Tera type when Tera is active, so the second clause is always
    // true once the first is — the practical rule is "any Tera STAB
    // (matched move type) where the DB has a positive base power and
    // it's a non-multi-hit, non-priority move." Stellar is excluded.
    // Dragon Energy / Eruption / Water Spout are also excluded
    // explicitly in @smogon/calc — their HP-scaled BP is meant to be
    // weakest at low HP and bumping to 60 would defeat that.
    const _kEruptionLikeNames = {
      'Dragon Energy', 'Eruption', 'Water Spout',
    };
    final bool teraMinEligible = isTeraStab &&
        attacker.terastal.teraType != PokemonType.stellar &&
        !effectiveMove.isMultiHit &&
        effectiveMove.priority <= 0 &&
        originalMoveDbPower > 0 &&
        !_kEruptionLikeNames.contains(effectiveMove.name);
    final int basePower = dynamicPower;

    // --- Base damage: official Gen V+ formula ---
    final int level = attacker.level.clamp(1, 100);
    // Showdown bpMods chain — every modifier that boosts the move's
    // *base power* (NOT damage afterward). Includes type-boost items,
    // power-boost abilities (Sheer Force / Iron Fist / Tough Claws /
    // Reckless / Punk Rock / etc.), Charge, terrain boosts (Electric
    // Terrain ×1.3 Electric / Misty Terrain ÷2 Dragon / Grassy ×0.5
    // Earthquake / Bulldoze), Collision Course / Electro Drift on
    // super effective, doubles spread / Helping Hand / Power Spot.
    // Each multiplier becomes a 4096-fp integer; chainMods compounds
    // them with rounding-half-up before applying to basePower with a
    // single pokeRound. Weather offensive mod (Sun×Fire 1.5,
    // Rain×Fire 0.5) is handled separately in the damage chain (it
    // bpMods chain order MATCHES @smogon/calc gen789.ts
    // calculateBpModsSMSSSV. The chain is order-sensitive
    // (intermediate +2048 fp rounding), so even semantically
    // commutative multipliers can end up differing by ±1 fp when
    // a different push order would change a mid-step round.
    final bpMods = <int>[];
    // 1. Doubles ally Helping Hand (first per Showdown).
    if (attacker.helpingHand) bpMods.add(_kFP_1_5);
    // 2. Misc move-power add-ons we aggregate into movePowerMod
    // (Hex / Brine / Charge / Dynamax-Cannon vs Max etc.). Showdown
    // pushes these as individual entries; we approximate by one
    // collapsed entry — small ±1 fp drift remains for cases where
    // two of them stack.
    if (movePowerMod != 1.0) bpMods.add(_toFP(movePowerMod));
    if (attacker.charge && effectiveMove.type == PokemonType.electric) {
      bpMods.add(_toFP(kChargePowerBoost));
    }
    // 3. Terrain (Electric/Grassy/Psychic boost OR Misty/Grassy
    // halving).
    if (terrainMod != 1.0) bpMods.add(_toFP(terrainMod));
    // 4. Ability-side power modifiers (Tough Claws / Strong Jaw /
    // Mega Launcher / Technician / Sharpness / Sheer Force / Punk
    // Rock / Iron Fist / Reckless / Steely Spirit / etc.). Showdown
    // pushes these in distinct positions (6144 for Tech-class,
    // 5325 for Tough-Claws-class, 4915 for Reckless / Iron Fist).
    // We collapse them — small drift again, but the major-stat
    // routings are correct.
    if (abilityEffect.powerModifier != 1.0) bpMods.add(_toFP(abilityEffect.powerModifier));
    // 5. Doubles ally abilities Battery / Power Spot.
    if (attacker.allyBattery &&
        effectiveMove.category == MoveCategory.special) {
      bpMods.add(_kFP_1_3);
    }
    if (attacker.allyPowerSpot) bpMods.add(_kFP_1_3);
    // 6. Collision Course / Electro Drift on super-effective.
    if (isSuperEffective &&
        effectiveMove.hasTag(MoveTags.superEffectiveBoost)) {
      bpMods.add(_kFP_1_3333);
      notes.add('move:collision:×1.33');
    }
    // 7. Defender's Dry Skin: Fire moves do 1.25 × damage.
    if (!earlyMoldBreaks && defAbilityRaw == 'Dry Skin' &&
        effectiveMove.type == PokemonType.fire) {
      bpMods.add(5120);
      notes.add('ability:Dry Skin:×1.25');
    }
    // 8. Knock Off ×1.5 BP when target holds a removable item.
    // Same slot also covers Misty Explosion + Misty terrain, Grav
    // Apple + Gravity, and Expanding Force + Psychic terrain — they
    // are mutually exclusive with Knock Off (different move names)
    // and all push 6144 in Showdown's `calculateBpModsSMSSSV`.
    if (isKnockOffBoostApplicable(effectiveMove, defender.selectedItem) ||
        isMistyExplosionBoostApplicable(effectiveMove, terrain, atkGroundedEarly) ||
        isGravApplyBoostApplicable(effectiveMove, room.gravity) ||
        isExpandingForceBoostApplicable(effectiveMove, terrain, atkGroundedEarly)) {
      bpMods.add(_kFP_1_5);
    }
    // 8b. Solar Beam / Solar Blade ×0.5 BP in rain, sandstorm,
    // snow, or heavy rain. Showdown pushes 2048 right after the
    // ×1.5 slot above.
    if (isSolarHalveApplicable(effectiveMove, atkWeather)) {
      bpMods.add(_kFP_0_5);
    }
    // 9. Type-boost items / Muscle Band / Wise Glasses / Punching
    // Glove. Showdown pushes these LAST in calculateBpModsSMSSSV.
    if (itemEffect.powerModifier != 1.0) bpMods.add(_toFP(itemEffect.powerModifier));
    final int bpChain = _chainMods(bpMods, 1, 1 << 31);
    int power = math.max(1, _applyChainMod(basePower, bpChain));
    // Tera 60-BP minimum (gen 9+): @smogon/calc evaluates this on the
    // *post-chainMod* power. Grassy Terrain halves Earthquake to 50
    // first, then this bumps it to 60 — gives 1.2× the damage we'd
    // get if we evaluated before the chain.
    if (teraMinEligible && power < kTeraMinPower && power > 0) {
      power = kTeraMinPower;
    }
    if (D == 0) D = 1; // prevent division by zero

    int baseDmg = ((2 * level ~/ 5 + 2) * power * A ~/ D) ~/ 50 + 2;
    // Showdown's calculateBaseDamage applies spread / parental-bond
    // / weather / crit modifications *to the base damage* before the
    // random-factor loop. Spread happens FIRST (pokeRound(base ×
    // 3072 / 4096) for doubles allAdjacent / allAdjacentFoes moves).
    if (attacker.spreadTargets && effectiveMove.hasTag(MoveTags.spread)) {
      baseDmg = _applyChainMod(baseDmg, _kFP_0_75);
    }
    if (weatherMod != 1.0) {
      baseDmg = _applyChainMod(baseDmg, _toFP(weatherMod));
    }
    if (critMod != 1.0) {
      // Showdown applies crit as floor(baseDmg * 1.5) — straight floor
      // rather than pokeRound. Match exactly.
      baseDmg = (baseDmg * critMod).floor();
    }

    // --- Aura abilities (Fairy Aura / Dark Aura / Aura Break) ---
    final auraState = computeAuraState(
      attackerAbility: atkAbilityRaw,
      defenderAbility: defAbilityRaw,
      allyFairyAura: auras.fairyAura,
      allyDarkAura: auras.darkAura,
      allyAuraBreak: auras.auraBreak,
    );
    final aura = getAuraEffect(
      moveType: moveType,
      attackerAbility: atkAbilityRaw,
      state: auraState,
    );
    notes.addAll(aura.notes);

    // --- Damage chain mirroring Showdown's getFinalDamage ---
    // Showdown applies the post-baseDamage chain as:
    //   baseDamage (already includes spread, parental-bond, weather,
    //              crit at the calculateBaseDamage step)
    //   → floor(baseDamage * (85 + i) / 100)              [random]
    //   → if STAB != 4096: damage * stabMod / 4096        [no round]
    //   → floor(pokeRound(damage) * effectiveness)        [type eff]
    //   → if burned: floor(damage / 2)
    //   → pokeRound(max(1, damage * finalMod / 4096))     [finalMods]
    //
    // We fold weather into baseDmgInput before this function so the
    // chain mirrors Showdown step-for-step. STAB and finalMods are
    // 4096-fp integers; effectiveness stays as a double (it's an
    // integer ratio so floor matches Showdown's behaviour).
    final int stabFP = _toFP(stab);

    int applyModifiers(int baseDmgInput, int randomRoll, {
      double effectivenessHit = -1,
      double defAbilityDmgHit = -1,
      double berryModHit = -1,
    }) {
      final eff = effectivenessHit < 0 ? effectiveness : effectivenessHit;
      final defAbi = defAbilityDmgHit < 0 ? defAbilityDmg.multiplier : defAbilityDmgHit;
      final berry = berryModHit < 0 ? berryMod : berryModHit;

      // Build the finalMods chain (Showdown's `calculateFinalMods`
      // bucket). Defender at-side mods (Thick Fat / Heatproof / …)
      // already rode atMods upstream and are skipped here.
      final finalMods = <int>[];
      if (defAbilityDmgMod != 1.0) finalMods.add(_toFP(defAbilityDmgMod));
      if (atkAbilityDmg.multiplier != 1.0) {
        finalMods.add(_toFP(atkAbilityDmg.multiplier));
      }
      if (defAbi != 1.0) finalMods.add(_toFP(defAbi));
      if (expertBeltMod != 1.0) finalMods.add(_toFP(expertBeltMod));
      if (itemEffect.damageModifier != 1.0) {
        finalMods.add(_toFP(itemEffect.damageModifier));
      }
      if (screenMod != 1.0) finalMods.add(_toFP(screenMod));
      if (berry != 1.0) finalMods.add(_toFP(berry));
      if (aura.multiplier != 1.0) finalMods.add(_toFP(aura.multiplier));
      if (friendGuardMod != 1.0) finalMods.add(_toFP(friendGuardMod));
      // Sniper: +50 % on critical hits, routed through finalMods so
      // the rounding order matches Showdown (separate from the crit
      // ×1.5 applied to baseDmg).
      if (isCritical && atkAbilityRaw == 'Sniper') {
        finalMods.add(_kFP_1_5);
        notes.add('ability:Sniper:×1.5');
      }
      final int finalModChain = _chainMods(finalMods, 41, 131072);

      // Random factor — floor, not pokeRound.
      int d = baseDmgInput * randomRoll ~/ 100;
      // STAB — Showdown keeps the multiplied value as a float and
      // pokeRounds it together with the type-effectiveness step
      // (gen789.ts: `damageAmount = damageAmount * stabMod / 4096`
      // then `Math.floor(pokeRound(damageAmount) * eff)`). Doing the
      // floor mid-step would mis-round any STAB-multiplied roll that
      // lands on a *.5x or higher fractional part (e.g. 2.25× STAB
      // produces 1907712/4096 = 465.75 — Showdown rounds 466, our
      // earlier floor truncated to 465).
      final num afterStab =
          stabFP == _kFP ? d : (d * stabFP / _kFP);
      // Type effectiveness: floor(pokeRound(afterStab) * eff).
      d = (_pokeRound(afterStab) * eff).floor();
      // Burn — special case in Showdown: floor(d / 2) NOT pokeRound.
      if (burnMod < 1.0) {
        d = d ~/ 2;
      }
      // Final mods — single pokeRound at the end (clamped to ≥1 like
      // Showdown does).
      d = _pokeRound(math.max(1, d * finalModChain / _kFP));
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
        // Triple Axel / Triple Kick: per-hit BP = singleHitBP * (i+1).
        // Showdown applies the full bpMods chain (Muscle Band, terrain
        // boosts, type-boost items, etc.) and the Tera 60-BP minimum
        // to *each* hit's BP separately. Earlier we used the raw move
        // power and skipped both — leaving Muscle Band off escalating
        // hits and underestimating damage by ~10 %.
        final int singleHitPower = effectiveMove.power;
        perHitAllRolls = List.generate(hitCount, (i) {
          final int rawHitBp = singleHitPower * (i + 1);
          int hitPower = math.max(1, _applyChainMod(rawHitBp, bpChain));
          if (teraMinEligible && hitPower < kTeraMinPower && hitPower > 0) {
            hitPower = kTeraMinPower;
          }
          hitPower = (hitPower * movePowerMod).floor().clamp(1, 99999);
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
    final PokemonType? defEffType3 = (defender.terastal.active && defender.terastal.teraType != null)
        ? null : defender.type3;

    // Ground OHKO (Fissure): ungrounded targets are immune
    if (move.type == PokemonType.ground) {
      final defIsGrounded = isGrounded(
        type1: defEffType1, type2: defEffType2, type3: defEffType3,
        ability: defenderAbility,
        item: defender.selectedItem,
        gravity: room.gravity,
      );
      if (!defIsGrounded) {
        return immune([groundImmunityNote(
          type1: defEffType1, type2: defEffType2, type3: defEffType3,
          ability: defenderAbility,
        )]);
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
      move.type, defender.type1, defender.type2,
      defType3: defender.type3);
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
