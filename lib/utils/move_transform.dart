import 'dart:math' as math;

import '../models/dynamax.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/rank.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import 'ability_effects.dart' show isParentalBondEligible, isParentalBondFixedFullPower;
import 'damage_calculator.dart' show isUnremovableItem, kKnockOffBoost;

/// Which stat the move should use for offense
enum OffensiveStat {
  attack,
  spAttack,
  defense,
  higherAttack,
  opponentAttack,
}

/// Context for move transformation
class MoveContext {
  final Weather weather;
  final Terrain terrain;
  final Rank rank;
  final double hpPercent;
  final bool hasItem;

  final String? ability;
  final StatusCondition status;

  final DynamaxState dynamax;
  final String? pokemonName; // for G-Max move lookup

  final bool terastallized;
  final PokemonType? teraType;

  final int? mySpeed;
  final int? opponentSpeed;

  /// Actual (rank-applied) Attack stat — needed for Tera Blast category check.
  final int? actualAttack;

  /// Actual (rank-applied) Sp.Attack stat — needed for Tera Blast category check.
  final int? actualSpAttack;

  /// User's weight in kg (after ability modifiers).
  final double? myWeight;

  /// Opponent's weight in kg (after ability modifiers).
  final double? opponentWeight;

  /// Opponent's remaining HP percentage (0–100).
  final double? opponentHpPercent;

  /// User's current and maximum HP (post-Dynamax scaling, matching
  /// @smogon/calc's maxHP() / curHP() conventions). Both are needed
  /// so HP-scaled BP moves (Eruption / Water Spout / Dragon Energy /
  /// Reversal / Flail) can compute `floor(N * curHP / maxHP)` bit-
  /// for-bit. Passing pct + maxHp would lose precision under Dynamax
  /// because @smogon/calc derives Dynamax curHP from the pre-Dynamax
  /// curHP (then ceil-scales), not from pct against the doubled
  /// maxHP.
  final int? myMaxHp;
  final int? myCurHp;

  /// Opponent's current and maximum HP. Same purpose for target-
  /// HP-scaled moves (Hard Press / Crush Grip / Wring Out).
  final int? opponentMaxHp;
  final int? opponentCurHp;

  /// User's primary type (for Revelation Dance).
  final PokemonType? userType1;

  /// User's held item name (for Judgment, Multi-Attack).
  final String? heldItem;

  /// Opponent's held item name (for Knock Off power boost).
  final String? opponentItem;

  /// Hit count for multi-hit moves (user override or maxHits).
  final int? hitCount;

  /// Whether gravity is active.
  final bool gravity;

  /// Whether the attacker is grounded (for terrain power boosts).
  final bool attackerGrounded;

  /// Whether the defender is grounded (for terrain power reductions).
  final bool defenderGrounded;

  const MoveContext({
    this.weather = Weather.none,
    this.terrain = Terrain.none,
    this.rank = const Rank(),
    this.hpPercent = 100.0,
    this.hasItem = false,
    this.ability,
    this.status = StatusCondition.none,
    this.dynamax = DynamaxState.none,
    this.pokemonName,
    this.terastallized = false,
    this.teraType,
    this.mySpeed,
    this.opponentSpeed,
    this.gravity = false,
    this.attackerGrounded = true,
    this.defenderGrounded = true,
    this.actualAttack,
    this.actualSpAttack,
    this.myWeight,
    this.opponentWeight,
    this.userType1,
    this.heldItem,
    this.opponentItem,
    this.hitCount,
    this.opponentHpPercent,
    this.myMaxHp,
    this.myCurHp,
    this.opponentMaxHp,
    this.opponentCurHp,
    this.zMove = false,
    this.isMega = false,
  });

  /// Whether this move should be converted to a Z-Move.
  final bool zMove;

  /// Whether the attacker is a Mega Evolution.
  final bool isMega;
}

/// Result of move transformation: the modified move + which stat to use
class TransformedMove {
  final Move move;
  final OffensiveStat offensiveStat;

  const TransformedMove(this.move, this.offensiveStat);

  /// Resolve the actual stat value from calculated stats.
  /// [opponentAttack] is needed for Foul Play (uses opponent's Attack stat).
  int resolveStat(Stats actualStats, {int? opponentAttack}) {
    switch (offensiveStat) {
      case OffensiveStat.attack:
        return actualStats.attack;
      case OffensiveStat.spAttack:
        return actualStats.spAttack;
      case OffensiveStat.defense:
        return actualStats.defense;
      case OffensiveStat.higherAttack:
        return math.max(actualStats.attack, actualStats.spAttack);
      case OffensiveStat.opponentAttack:
        return opponentAttack ?? actualStats.attack;
    }
  }
}

/// Applies all move transformations based on battle context.
///
/// Order matters:
/// 1. Type-changing transforms (Weather Ball, Terrain Pulse)
/// 2. Ability type transforms (-ate skins: only affects Normal moves)
/// 3. Conditional power changes (Acrobatics, HP-based)
/// 4. Field-based power boosts (Rising Voltage, etc.)
/// 5. Rank-based power (Stored Power, etc.)
/// 6. Stat selection (Body Press, Photon Geyser, etc.)
TransformedMove transformMove(Move move, MoveContext context) {
  // 1. Type-changing transforms first
  move = _applyWeather(move, context.weather);
  move = _applyTerrain(move, context.terrain, context.attackerGrounded);

  // 1.5. Tera Blast: type/category changes when terastallized
  // Must happen BEFORE skins so Normal Tera Blast can be converted by -ate abilities
  if (context.terastallized && context.teraType != null && move.name == 'Tera Blast') {
    move = _applyTeraBlast(move, context);
  }

  // 1.6. Tera Starstorm: becomes Stellar type ONLY when used by
  // Terapagos in Stellar Form. Other Terapagos forms keep the
  // database type (Normal). Showdown gates this on the exact
  // species name `Terapagos-Stellar` (gen789.ts:320).
  // forms.json stores the display name `Terapagos (Stellar Form)`,
  // while internal code paths still reference the kebab-case
  // `terapagos-stellar` — we accept both so this works regardless
  // of which form-name convention reaches us.
  // The physical/special swap (when Attack > SpAttack) only applies
  // while the user is Terastallized, like Tera Blast — @smogon/calc
  // gates this on `attacker.teraType`. The type change to Stellar is
  // not gated on Terastallization (also matches @smogon/calc).
  if (move.name == 'Tera Starstorm' && context.pokemonName != null) {
    final n = context.pokemonName!.toLowerCase();
    final isStellarForm =
        n == 'terapagos-stellar' || n.contains('stellar form');
    if (isStellarForm) {
      var newCategory = move.category;
      if (context.terastallized &&
          context.actualAttack != null && context.actualSpAttack != null &&
          context.actualAttack! > context.actualSpAttack!) {
        newCategory = MoveCategory.physical;
      }
      move = move.copyWith(type: PokemonType.stellar, category: newCategory);
    }
  }

  // 1.7. Photon Geyser (and Necrozma's signature Z-Move Light That Burns
  // the Sky): become physical when the user's Attack exceeds Sp.Attack.
  // Showdown sets `move.category` BEFORE the damage calc reads the
  // defensive stat, so the move starts hitting Def instead of SpD —
  // not just changing which offensive stat is used.
  if ((move.name == 'Photon Geyser' ||
       move.name == 'Light That Burns the Sky') &&
      context.actualAttack != null && context.actualSpAttack != null &&
      context.actualAttack! > context.actualSpAttack!) {
    move = move.copyWith(category: MoveCategory.physical);
  }

  // 2. Ability type transforms (only if still Normal after step 1/1.5)
  move = _applySkin(move, context.ability,
      terastallized: context.terastallized);

  // 2b. Liquid Voice: sound moves become Water type (no power boost)
  if (context.ability == 'Liquid Voice' && move.hasTag(MoveTags.sound)) {
    move = move.copyWith(type: PokemonType.water);
  }

  // 2.5. Ivy Cudgel: type changes based on Ogerpon form
  if (move.name == 'Ivy Cudgel' && context.pokemonName != null) {
    final n = context.pokemonName!.toLowerCase();
    PokemonType? t;
    if (n.contains('wellspring')) {
      t = PokemonType.water;
    } else if (n.contains('hearthflame')) {
      t = PokemonType.fire;
    } else if (n.contains('cornerstone')) {
      t = PokemonType.rock;
    }
    if (t != null) move = move.copyWith(type: t);
  }

  // 2.51. Judgment (Arceus): type changes based on held Plate
  if (move.name == 'Judgment' && context.heldItem != null) {
    final plateType = _plateTypes[context.heldItem!];
    if (plateType != null) move = move.copyWith(type: plateType);
  }

  // 2.52. Multi-Attack (Silvally): type changes based on held Memory
  if (move.name == 'Multi-Attack' && context.heldItem != null) {
    final memoryType = _memoryType(context.heldItem!);
    if (memoryType != null) move = move.copyWith(type: memoryType);
  }

  // 2.53. Revelation Dance: type matches user's primary type
  if (move.name == 'Revelation Dance' && context.userType1 != null) {
    move = move.copyWith(type: context.userType1);
  }

  // 2.54. Aura Wheel (Morpeko): Electric for base, Dark for Hangry
  if (move.name == 'Aura Wheel' && context.pokemonName != null) {
    final lower = context.pokemonName!.toLowerCase();
    if (lower == 'morpeko-hangry') {
      move = move.copyWith(type: PokemonType.dark);
    } else {
      move = move.copyWith(type: PokemonType.electric);
    }
  }

  // 2.55. Raging Bull (Paldean Tauros): type changes based on breed.
  // Mirrors Ivy Cudgel — substring match on the breed keyword so it
  // works for our display names ("Paldean Tauros (Combat Breed)") as
  // well as Showdown-style ids ("Tauros-Paldea-Combat"). The previous
  // exact `==` against the kebab id / form id never matched the
  // display name that actually reaches the calc, so the move stayed
  // Normal-typed.
  if (move.name == 'Raging Bull' && context.pokemonName != null) {
    final n = context.pokemonName!.toLowerCase();
    PokemonType? t;
    if (n.contains('combat')) {
      t = PokemonType.fighting;
    } else if (n.contains('blaze')) {
      t = PokemonType.fire;
    } else if (n.contains('aqua')) {
      t = PokemonType.water;
    }
    if (t != null) move = move.copyWith(type: t);
  }

  // 2.6. (Tera Blast moved to step 1.5)

  // 2.7. Contact removal: Long Reach (ability) or Punching Glove (item, punch only)
  if (move.hasTag(MoveTags.contact)) {
    if (context.ability == 'Long Reach' ||
        (context.heldItem == 'punching-glove' && move.hasTag(MoveTags.punch))) {
      move = move.copyWith(tags: move.tags.where((t) => t != MoveTags.contact).toList());
    }
  }

  // 3. Conditional power changes
  move = _applyItemCondition(move, context.hasItem);
  move = _applyHpPower(move, context.hpPercent, context.myMaxHp, context.myCurHp);
  move = _applyStatusPower(move, context.status);
  move = _applySpeedPower(move, context.mySpeed, context.opponentSpeed);
  move = _applyTurnOrderPower(move, context.mySpeed, context.opponentSpeed);
  move = _applyWeightPower(move, context.myWeight, context.opponentWeight);
  move = _applyTargetHpPower(move, context.opponentHpPercent, context.opponentMaxHp, context.opponentCurHp);
  move = _applyKnockOff(move, context.opponentItem);
  move = _applyFlingPower(move, context.heldItem);

  // 4. Field-based power boosts
  move = _applyTerrainPowerBoost(move, context.terrain,
      attackerGrounded: context.attackerGrounded,
      defenderGrounded: context.defenderGrounded);

  // 5. Rank-based power
  move = _applyRankPower(move, context.rank);

  // 5b. Grav Apple ×1.5 under gravity, Solar Beam/Blade ×0.5 in
  // bad weather: both are bpMods entries in Showdown
  // (`bpMods.push(6144)` and `bpMods.push(2048)` respectively), not
  // direct BP modifications. damage_calculator now routes them
  // through its bpMods chain — see `isGravApplyBoostApplicable`
  // and `isSolarHalveApplicable`. No transform-side change here.

  // 6. Multi-hit: apply total power (Dynamax-converted Max moves
  // have minHits=maxHits=1 already, so this skips them naturally).
  if (move.isMultiHit && context.hitCount != null && context.hitCount! > 1) {
    final hits = context.hitCount!;
    move = move.copyWith(
      power: move.totalPower(hits),
      tags: move.tags.where((t) => t != MoveTags.escalatingHits).toList(),
    );
  }

  // 6.5. Parental Bond (Mega Kangaskhan): single-hit moves become 2-hit.
  // Eligibility & fixed-damage classification live in ability_effects.
  if (context.ability == 'Parental Bond' && isParentalBondEligible(move)) {
    final extraTag = isParentalBondFixedFullPower(move)
        ? MoveTags.parentalBondFixed
        : MoveTags.parentalBond;
    move = move.copyWith(
      minHits: 2, maxHits: 2,
      tags: [...move.tags, extraTag],
    );
  }

  // 7. Dynamax / Z-Move conversion. Runs LAST so the dynamic power
  // adjustments above (status, HP %, Acrobatics no-item, etc.) get
  // folded into the move's BP first; the Max-move table then uses
  // the adjusted BP. This diverges from @smogon/calc — which locks
  // the Max move at constructor time using the DB BP — but matches
  // the UI expectation that "this move's BP with my Pokémon's
  // current state would map to <Max move BP>". See README note.
  // Z-Move is blocked by Mega/Dynamax/Terastal (3 safety layers).
  if (context.dynamax != DynamaxState.none && move.type != PokemonType.typeless) {
    move = _applyDynamax(move, context.dynamax, context.pokemonName);
  } else if (context.zMove && move.type != PokemonType.typeless &&
      context.dynamax == DynamaxState.none && !context.terastallized &&
      !context.isMega) {
    move = _applyZMove(move, context.pokemonName);
  }

  // 8. Stat selection
  final stat = _resolveOffensiveStat(move);
  return TransformedMove(move, stat);
}

/// Determine which stat the move uses
OffensiveStat _resolveOffensiveStat(Move move) {
  if (move.hasTag(MoveTags.useDefense)) return OffensiveStat.defense;
  if (move.hasTag(MoveTags.useHigherAtk)) return OffensiveStat.higherAttack;
  if (move.hasTag(MoveTags.useOpponentAtk)) return OffensiveStat.opponentAttack;
  return move.category == MoveCategory.physical
      ? OffensiveStat.attack
      : OffensiveStat.spAttack;
}

/// Tera Blast transformations when terastallized:
/// - Type changes to Tera type
/// - If Attack > Sp.Attack, becomes Physical
/// - Stellar Tera: power becomes 100
Move _applyTeraBlast(Move move, MoveContext context) {
  final teraType = context.teraType!;

  // Stellar Tera Blast: power 100, type stays Normal
  if (teraType == PokemonType.stellar) {
    // Category: physical if Attack > SpAttack
    final category = (context.actualAttack != null &&
            context.actualSpAttack != null &&
            context.actualAttack! > context.actualSpAttack!)
        ? MoveCategory.physical
        : move.category;
    return move.copyWith(power: 100, category: category);
  }

  // Normal Tera Blast: change type, and physical if Attack > SpAttack
  final category = (context.actualAttack != null &&
          context.actualSpAttack != null &&
          context.actualAttack! > context.actualSpAttack!)
      ? MoveCategory.physical
      : move.category;
  return move.copyWith(type: teraType, category: category);
}

/// -ate abilities: convert Normal moves to another type with 1.2x power.
const Map<String, PokemonType> _skinAbilities = {
  'Aerilate': PokemonType.flying,
  'Pixilate': PokemonType.fairy,
  'Refrigerate': PokemonType.ice,
  'Galvanize': PokemonType.electric,
  'Steel Skin': PokemonType.steel,
  'Dragonize': PokemonType.dragon,
  'Normalize': PokemonType.normal,
};

/// Moves whose type is determined by another source (weather, terrain,
/// Tera type, plate, memory, etc.) and therefore are not retyped by
/// -ate abilities or Normalize. Mirrors @smogon/calc gen789.ts's
/// `noTypeChange` list, plus Tera Blast (when terastallized).
bool _isTypeChangeBlocked(Move move, bool terastallized) {
  const blocked = {
    'Revelation Dance', 'Judgment', 'Nature Power', 'Techno Blast',
    'Multi-Attack', 'Natural Gift', 'Weather Ball', 'Terrain Pulse',
    'Struggle',
  };
  if (blocked.contains(move.name)) return true;
  if (move.name == 'Tera Blast' && terastallized) return true;
  return false;
}

Move _applySkin(Move move, String? ability, {bool terastallized = false}) {
  if (ability == null) return move;
  // Showdown's noTypeChange list excludes these moves from -ate and
  // Normalize retyping (gen789.ts). Without this check, Galvanize +
  // Weather Ball would force Electric type, ours diverging from
  // @smogon/calc by both type and the ×1.2 ate boost.
  if (_isTypeChangeBlocked(move, terastallized)) return move;

  // Normalize: ALL moves become Normal type. The ×1.2 BP boost is
  // applied via ability_effects.dart's powerModifier path so it
  // rides the bpMods chain alongside Tough Claws / Sheer Force etc.
  if (ability == 'Normalize') {
    return move.copyWith(type: PokemonType.normal);
  }

  // Other -ate skins: only Normal moves get converted. The ×1.2 BP
  // boost applies to non-Max moves only — Showdown gates the ate
  // boost with `!move.isMax`. Max moves still get the type change.
  // The ×1.2 itself is NOT applied here, only signaled via the
  // `ateBoosted` tag — multiplying inside transformMove silently
  // drops the boost on dynamic-BP moves (Crush Grip, Wring Out,
  // Eruption, Stored Power, …) whose BP is set later by step 3.
  // damage_calculator's bpMods chain reads the tag and pushes
  // 4915 (×1.2) at the right slot; the move-slot display + 결정력
  // calc fold it in via conditionalBpModFp / applyBpModFp.
  final skinType = _skinAbilities[ability];
  if (skinType == null || move.type != PokemonType.normal) return move;
  if (move.moveClass == MoveClass.maxMove) {
    return move.copyWith(type: skinType);
  }
  return move.copyWith(
    type: skinType,
    tags: [...move.tags, MoveTags.ateBoosted],
  );
}

/// Weather Ball: changes type and power based on weather.
Move _applyWeather(Move move, Weather weather) {
  if (move.name != 'Weather Ball' || weather == Weather.none) {
    return move;
  }

  final PokemonType weatherType;
  switch (weather) {
    case Weather.sun:
    case Weather.harshSun:
      weatherType = PokemonType.fire;
    case Weather.rain:
    case Weather.heavyRain:
      weatherType = PokemonType.water;
    case Weather.sandstorm:
      weatherType = PokemonType.rock;
    case Weather.snow:
      weatherType = PokemonType.ice;
    default:
      return move;
  }

  return move.copyWith(type: weatherType, power: 100);
}

/// Terrain Pulse: changes type and power based on terrain.
Move _applyTerrain(Move move, Terrain terrain, bool attackerGrounded) {
  if (move.name != 'Terrain Pulse' || terrain == Terrain.none || !attackerGrounded) {
    return move;
  }

  final PokemonType terrainType;
  switch (terrain) {
    case Terrain.electric:
      terrainType = PokemonType.electric;
    case Terrain.grassy:
      terrainType = PokemonType.grass;
    case Terrain.psychic:
      terrainType = PokemonType.psychic;
    case Terrain.misty:
      terrainType = PokemonType.fairy;
    default:
      return move;
  }

  return move.copyWith(type: terrainType, power: 100);
}

/// Acrobatics: double power when not holding an item.
Move _applyItemCondition(Move move, bool hasItem) {
  if (move.hasTag(MoveTags.doubleNoItem) && !hasItem) {
    return move.copyWith(power: move.power * 2);
  }
  return move;
}

/// HP-based power: Eruption/Water Spout/Dragon Energy (high), Flail/
/// Reversal (low). Showdown computes BP from the user's exact
/// curHP / maxHP ratio (`floor(150 * curHP / maxHP)`), which can
/// diverge by 1 BP from a `floor(150 * pct / 100)` integer-percent
/// approximation whenever maxHP isn't a multiple of 100. We pass
/// [maxHp] so we can round-trip the same way.
///
/// HP above 100 % (e.g., the user manually entered 150 % in the
/// damage-mode field, or a Dynamax target with hpPercent > maxHP)
/// is clamped to 100 % — extra HP doesn't push BP above the
/// move's natural cap.
Move _applyHpPower(Move move, double hpPercent, int? maxHp, int? curHp) {
  if (move.hasTag(MoveTags.hpPowerHigh)) {
    final int bp;
    if (maxHp != null && curHp != null && maxHp > 0 && hpPercent <= 100) {
      // Precise: use the caller-supplied curHP / maxHP — matches
      // @smogon/calc's Dynamax-aware scaling (curHP ceil-scales,
      // maxHP floor-scales separately).
      bp = math.max(1, 150 * curHp ~/ maxHp);
    } else if (maxHp != null && maxHp > 0 && hpPercent <= 100) {
      // No curHp passed in but maxHp is: approximate from pct.
      final int derived = math.max(1, (maxHp * hpPercent / 100).floor());
      bp = math.max(1, 150 * derived ~/ maxHp);
    } else {
      // Fallback / clamp for >100 %: use the percent directly.
      final double clamped = hpPercent > 100 ? 100 : hpPercent;
      bp = math.max(1, (150 * clamped / 100).floor());
    }
    return move.copyWith(power: bp);
  }
  if (move.hasTag(MoveTags.hpPowerLow)) {
    // Flail / Reversal: BP table by % HP. Clamp at 100 % (extra HP
    // doesn't push BP above the lowest-HP tier).
    final double pct = hpPercent > 100 ? 100 : hpPercent;
    return move.copyWith(power: _flailPower(pct));
  }
  return move;
}

/// Facade: doubles power when burned, poisoned, or paralyzed.
Move _applyStatusPower(Move move, StatusCondition status) {
  if (move.hasTag(MoveTags.facade) && status != StatusCondition.none) {
    final isAffected = status == StatusCondition.burn ||
        status == StatusCondition.poison ||
        status == StatusCondition.badlyPoisoned ||
        status == StatusCondition.paralysis;
    if (isAffected) {
      return move.copyWith(power: move.power * 2);
    }
  }
  // Snore: fails (power 0) if the user is not asleep
  if (move.name == 'Snore' && status != StatusCondition.sleep) {
    return move.copyWith(power: 0);
  }
  return move;
}

/// Speed-based power: Gyro Ball, Electro Ball.
Move _applySpeedPower(Move move, int? mySpeed, int? opponentSpeed) {
  if (mySpeed == null || opponentSpeed == null || mySpeed <= 0 || opponentSpeed <= 0) {
    return move;
  }

  // Gyro Ball: min(150, floor(25 * opponent / self) + 1)
  if (move.hasTag(MoveTags.gyroSpeed)) {
    final power = math.min(150, (25 * opponentSpeed / mySpeed).floor() + 1);
    return move.copyWith(power: math.max(1, power));
  }

  // Electro Ball: power based on speed ratio (self / opponent)
  if (move.hasTag(MoveTags.electroSpeed)) {
    final ratio = mySpeed / opponentSpeed;
    final int power;
    if (ratio >= 4) {
      power = 150;
    } else if (ratio >= 3) {
      power = 120;
    } else if (ratio >= 2) {
      power = 80;
    } else if (ratio >= 1) {
      power = 60;
    } else {
      power = 40;
    }
    return move.copyWith(power: power);
  }

  return move;
}

/// Turn-order power: moves that double power based on who moves first.
Move _applyTurnOrderPower(Move move, int? mySpeed, int? opponentSpeed) {
  if (mySpeed == null || opponentSpeed == null) return move;

  // Bolt Beak / Fishious Rend: x2 power when moving first
  if ((move.name == 'Bolt Beak' || move.name == 'Fishious Rend') &&
      mySpeed > opponentSpeed) {
    return move.copyWith(power: move.power * 2);
  }

  // Payback: x2 power when moving second
  if (move.name == 'Payback' && mySpeed < opponentSpeed) {
    return move.copyWith(power: move.power * 2);
  }

  // Revenge / Avalanche: x2 power when moving second
  if ((move.name == 'Revenge' || move.name == 'Avalanche') &&
      mySpeed < opponentSpeed) {
    return move.copyWith(power: move.power * 2);
  }

  return move;
}

/// Weight-based power: Heavy Slam/Heat Crash (ratio) and Low Kick/Grass Knot (target weight).
Move _applyWeightPower(Move move, double? myWeight, double? opponentWeight) {
  // Heavy Slam / Heat Crash: power based on user/target weight ratio
  if (move.hasTag(MoveTags.weightRatio)) {
    if (myWeight == null || opponentWeight == null || opponentWeight <= 0) return move;
    final ratio = myWeight / opponentWeight;
    final int power;
    if (ratio >= 5) {
      power = 120;
    } else if (ratio >= 4) {
      power = 100;
    } else if (ratio >= 3) {
      power = 80;
    } else if (ratio >= 2) {
      power = 60;
    } else {
      power = 40;
    }
    return move.copyWith(power: power);
  }

  // Low Kick / Grass Knot: power based on target weight
  if (move.hasTag(MoveTags.weightTarget)) {
    if (opponentWeight == null) return move;
    final w = opponentWeight;
    final int power;
    if (w >= 200) {
      power = 120;
    } else if (w >= 100) {
      power = 100;
    } else if (w >= 50) {
      power = 80;
    } else if (w >= 25) {
      power = 60;
    } else if (w >= 10) {
      power = 40;
    } else {
      power = 20;
    }
    return move.copyWith(power: power);
  }

  return move;
}

/// Fling: power is determined by the user's held item (type stays
/// Dark, category stays physical). Items not listed default to 30 —
/// the most common base power across the long tail of utility items
/// in mainline Pokemon. Items with no item held leave power at 0
/// (the move literally has no projectile).
Move _applyFlingPower(Move move, String? heldItem) {
  if (move.name != 'Fling') return move;
  if (heldItem == null || heldItem.isEmpty) return move;
  final power = _flingPower[heldItem] ?? 30;
  return move.copyWith(power: power);
}

const _flingPower = <String, int>{
  // 130
  'iron-ball': 130,
  // 100
  'hard-stone': 100,
  'adamant-orb': 100,
  'lustrous-orb': 100,
  'griseous-orb': 100,
  'macho-brace': 100,
  'damp-rock': 100,
  'heat-rock': 100,
  'icy-rock': 100,
  'smooth-rock': 100,
  'mental-herb': 100,
  'power-anklet': 100,
  'power-band': 100,
  'power-belt': 100,
  'power-bracer': 100,
  'power-lens': 100,
  'power-weight': 100,
  // 90
  'stick': 90,
  // 80
  'assault-vest': 80,
  'choice-band': 80,
  'choice-scarf': 80,
  'choice-specs': 80,
  'eviolite': 80,
  'kings-rock': 80,
  'quick-claw': 80,
  'razor-claw': 80,
  'razor-fang': 80,
  'sharp-beak': 80,
  'heavy-duty-boots': 80,
  'loaded-dice': 80,
  // 70 — all type plates / RKS memories / Genesect drives / Sticky Barb
  'flame-plate': 70,
  'splash-plate': 70,
  'zap-plate': 70,
  'meadow-plate': 70,
  'icicle-plate': 70,
  'fist-plate': 70,
  'toxic-plate': 70,
  'earth-plate': 70,
  'sky-plate': 70,
  'mind-plate': 70,
  'insect-plate': 70,
  'stone-plate': 70,
  'spooky-plate': 70,
  'draco-plate': 70,
  'dread-plate': 70,
  'iron-plate': 70,
  'pixie-plate': 70,
  'bug-memory': 70,
  'dark-memory': 70,
  'dragon-memory': 70,
  'electric-memory': 70,
  'fairy-memory': 70,
  'fighting-memory': 70,
  'fire-memory': 70,
  'flying-memory': 70,
  'ghost-memory': 70,
  'grass-memory': 70,
  'ground-memory': 70,
  'ice-memory': 70,
  'poison-memory': 70,
  'psychic-memory': 70,
  'rock-memory': 70,
  'steel-memory': 70,
  'water-memory': 70,
  'burn-drive': 70,
  'chill-drive': 70,
  'douse-drive': 70,
  'shock-drive': 70,
  'sticky-barb': 70,
  // 60 — type-boost items, incenses
  'black-belt': 60,
  'black-glasses': 60,
  'charcoal': 60,
  'dragon-fang': 60,
  'magnet': 60,
  'metal-coat': 60,
  'miracle-seed': 60,
  'mystic-water': 60,
  'never-melt-ice': 60,
  'poison-barb': 60,
  'rose-incense': 60,
  'rock-incense': 60,
  'sea-incense': 60,
  'wave-incense': 60,
  'silk-scarf': 60,
  'silver-powder': 60,
  'soft-sand': 60,
  'spell-tag': 60,
  'twisted-spoon': 60,
  'fairy-feather': 60,
  // 50
  'dubious-disc': 50,
  'sachet': 50,
  'whipped-dream': 50,
  'shed-shell': 50,
  // 40
  'electirizer': 40,
  'magmarizer': 40,
  'odd-incense': 40,
  'lax-incense': 40,
  'pure-incense': 40,
  'full-incense': 40,
  'protector': 40,
  'reaper-cloth': 40,
  // 30 — most common default; explicit only for items competitive
  // sets routinely care about.
  'amulet-coin': 30,
  'cleanse-tag': 30,
  'destiny-knot': 30,
  'expert-belt': 30,
  'focus-band': 30,
  'focus-sash': 30,
  'leftovers': 30,
  'life-orb': 30,
  'light-clay': 30,
  'light-ball': 30,
  'lucky-egg': 30,
  'metronome': 30,
  'muscle-band': 30,
  'wise-glasses': 30,
  'rocky-helmet': 30,
  'safety-goggles': 30,
  'scope-lens': 30,
  'shell-bell': 30,
  'binding-band': 30,
  'eject-button': 30,
  'eject-pack': 30,
  'red-card': 30,
  'ring-target': 30,
  'utility-umbrella': 30,
  'weakness-policy': 30,
  'flame-orb': 30,
  'toxic-orb': 30,
  'wide-lens': 30,
  'zoom-lens': 30,
  'throat-spray': 30,
  'white-herb': 30,
  'absorb-bulb': 30,
  'cell-battery': 30,
  'snowball': 30,
  'luminous-moss': 30,
  'mirror-herb': 30,
  'punching-glove': 30,
  'covert-cloak': 30,
  'clear-amulet': 30,
  'booster-energy': 30,
  'ability-shield': 30,
  // 10 — berries + a handful of light items
  'air-balloon': 10,
  'float-stone': 10,
  'lagging-tail': 10,
  'big-root': 10,
  'red-orb': 10,
  'blue-orb': 10,
  'oran-berry': 10,
  'sitrus-berry': 10,
  'leppa-berry': 10,
  'lum-berry': 10,
  'chesto-berry': 10,
  'pecha-berry': 10,
  'rawst-berry': 10,
  'aspear-berry': 10,
  'cheri-berry': 10,
  'persim-berry': 10,
  'figy-berry': 10,
  'wiki-berry': 10,
  'mago-berry': 10,
  'aguav-berry': 10,
  'iapapa-berry': 10,
  'salac-berry': 10,
  'liechi-berry': 10,
  'ganlon-berry': 10,
  'petaya-berry': 10,
  'apicot-berry': 10,
  'lansat-berry': 10,
  'starf-berry': 10,
  'micle-berry': 10,
  'custap-berry': 10,
  'jaboca-berry': 10,
  'rowap-berry': 10,
  'kee-berry': 10,
  'maranga-berry': 10,
  'enigma-berry': 10,
  // Type-resist berries
  'occa-berry': 10,
  'passho-berry': 10,
  'wacan-berry': 10,
  'rindo-berry': 10,
  'yache-berry': 10,
  'chople-berry': 10,
  'kebia-berry': 10,
  'shuca-berry': 10,
  'coba-berry': 10,
  'payapa-berry': 10,
  'tanga-berry': 10,
  'charti-berry': 10,
  'kasib-berry': 10,
  'haban-berry': 10,
  'colbur-berry': 10,
  'babiri-berry': 10,
  'roseli-berry': 10,
  'chilan-berry': 10,
};

/// Knock Off: 1.5× power when the target holds a removable item.
/// Knock Off used to multiply [move.power] here, but that bakes the
/// boost in *before* the bpMods chain runs and rounds incompatibly
/// with Showdown's chainMods. The damage calculator now folds the
/// 1.5 × into bpMods directly via [isKnockOffBoostApplicable], so we
/// only return the move unchanged here.
Move _applyKnockOff(Move move, String? opponentItem) {
  return move;
}

/// Whether Knock Off's 1.5 × power bonus should apply. Mirrors
/// @smogon/calc's `move.named('Knock Off') && !resistedKnockOffDamage`.
bool isKnockOffBoostApplicable(Move move, String? opponentItem) {
  if (!move.hasTag(MoveTags.knockOff)) return false;
  if (opponentItem == null) return false;
  if (isUnremovableItem(opponentItem)) return false;
  return true;
}

/// Grav Apple's ×1.5 BP boost under Gravity. Routed through
/// damage_calculator's bpMods chain (`push(6144)`) to match Showdown's
/// chainMods rounding; a direct `power*1.5).floor()` here would
/// diverge by 1 fp at odd-BP combinations once other bpMods stack.
bool isGravApplyBoostApplicable(Move move, bool gravity) {
  return move.hasTag(MoveTags.gravityBoost) && gravity;
}

/// Misty Explosion's ×1.5 BP boost on Misty Terrain (user grounded).
/// bpMods entry — see [isGravApplyBoostApplicable] for why we route
/// instead of multiplying directly.
bool isMistyExplosionBoostApplicable(Move move, Terrain terrain,
    bool attackerGrounded) {
  return move.hasTag(MoveTags.terrainBoostMisty) &&
      terrain == Terrain.misty && attackerGrounded;
}

/// Expanding Force's ×1.5 BP boost on Psychic Terrain (user grounded).
bool isExpandingForceBoostApplicable(Move move, Terrain terrain,
    bool attackerGrounded) {
  return move.hasTag(MoveTags.terrainBoostPsychic) &&
      terrain == Terrain.psychic && attackerGrounded;
}

/// Solar Beam / Solar Blade's ×0.5 BP cut in rain / sand / snow /
/// heavy rain (and Hail in older gens — we lump all four under the
/// snow case our `Weather` enum). bpMods entry (`push(2048)`).
bool isSolarHalveApplicable(Move move, Weather weather) {
  if (!move.hasTag(MoveTags.solarHalve)) return false;
  return weather == Weather.rain ||
      weather == Weather.sandstorm ||
      weather == Weather.snow ||
      weather == Weather.heavyRain;
}

// ───────────────────────────────────────────────────────────────────
// Move-conditional bpMods that live OUTSIDE the printed base power.
//
// damage_calculator applies these inside its 4096-fp bpMods chain.
// The move-slot BP display and the 결정력 calc (OffensiveCalculator)
// don't run that chain, so they call [conditionalBpModFp] to get the
// same multiplier and [applyBpModFp] to fold it in with identical
// rounding. Every entry here is a *named-move* effect, so at most one
// applies at a time — chain order is irrelevant.

const int _kFpx1_5 = 6144; // ×1.5 in 4096-fixed-point
const int _kFpx0_5 = 2048; // ×0.5 in 4096-fixed-point
const int _kFpx1_2 = 4915; // ×1.2 in 4096-fixed-point (-ate boost)

/// Combined 4096-fp multiplier (4096 == ×1) from the move-conditional
/// bpMods that apply to [move] in the given field / matchup state:
/// Knock Off ×1.5, Grav Apple / Misty Explosion / Expanding Force
/// ×1.5, Solar Beam / Solar Blade ×0.5, and the -ate ×1.2 (signaled
/// by the [MoveTags.ateBoosted] tag, set in `_applySkin`).
int conditionalBpModFp(
  Move move, {
  required Weather weather,
  required Terrain terrain,
  required bool gravity,
  required bool attackerGrounded,
  required String? opponentItem,
}) {
  var m = 4096;
  if (isKnockOffBoostApplicable(move, opponentItem)) {
    m = (m * _kFpx1_5 + 2048) >> 12;
  }
  if (isGravApplyBoostApplicable(move, gravity)) {
    m = (m * _kFpx1_5 + 2048) >> 12;
  }
  if (isMistyExplosionBoostApplicable(move, terrain, attackerGrounded)) {
    m = (m * _kFpx1_5 + 2048) >> 12;
  }
  if (move.hasTag(MoveTags.ateBoosted)) {
    m = (m * _kFpx1_2 + 2048) >> 12;
  }
  if (isExpandingForceBoostApplicable(move, terrain, attackerGrounded)) {
    m = (m * _kFpx1_5 + 2048) >> 12;
  }
  if (isSolarHalveApplicable(move, weather)) {
    m = (m * _kFpx0_5 + 2048) >> 12;
  }
  return m;
}

/// Apply a 4096-fp multiplier to [basePower] with Showdown's rounding
/// (`(bp * mod + 2048) >> 12`). Returns [basePower] unchanged when
/// [fpMod] is ×1 (4096).
int applyBpModFp(int basePower, int fpMod) =>
    fpMod == 4096 ? basePower : (basePower * fpMod + 2048) >> 12;

/// Target-HP-based power: Crush Grip / Wring Out (120×), Hard
/// Press (100×). Uses @smogon/calc's fixed-point formula
/// (`100 * floor(curHP * 4096 / maxHP)`, then chain-rounded) so
/// our BP matches Showdown exactly when curHP / maxHP are known.
/// Falls back to the integer-percent approximation otherwise.
/// HP above 100 % is clamped.
Move _applyTargetHpPower(Move move, double? opponentHpPercent,
    int? opponentMaxHp, int? opponentCurHp) {
  if (opponentHpPercent == null) return move;
  final double pct = opponentHpPercent > 100 ? 100 : opponentHpPercent;

  int _bp(int cap) {
    if (opponentMaxHp != null && opponentCurHp != null && opponentMaxHp > 0) {
      final int curHp = opponentCurHp > opponentMaxHp
          ? opponentMaxHp : opponentCurHp;
      // Showdown gen789.ts:
      //   basePower = 100 * floor(curHP * 4096 / maxHP);
      //   basePower = floor(floor((cap * basePower + 2048 - 1) / 4096) / 100)
      //               || 1;
      final int step1 = 100 * (curHp * 4096 ~/ opponentMaxHp);
      final int step2 = (cap * step1 + 2048 - 1) ~/ 4096 ~/ 100;
      return step2 == 0 ? 1 : step2;
    }
    if (opponentMaxHp != null && opponentMaxHp > 0) {
      final int derived = math.max(1, (opponentMaxHp * pct / 100).floor());
      final int step1 = 100 * (derived * 4096 ~/ opponentMaxHp);
      final int step2 = (cap * step1 + 2048 - 1) ~/ 4096 ~/ 100;
      return step2 == 0 ? 1 : step2;
    }
    return (cap * pct / 100).floor().clamp(1, cap);
  }

  if (move.hasTag(MoveTags.powerByTargetHp120)) {
    return move.copyWith(power: _bp(120));
  }
  if (move.hasTag(MoveTags.powerByTargetHp100)) {
    return move.copyWith(power: _bp(100));
  }

  return move;
}

/// Terrain-based power boosts and reductions.
/// - Rising Voltage: 2x in Electric Terrain
/// - Expanding Force / Misty Explosion: ×1.5 via bpMods in
///   damage_calculator (Showdown's chainMods rounds differently
///   from a direct `*1.5).floor()` at certain BPs).
/// - Earthquake/Bulldoze/Magnitude: 0.5x in Grassy Terrain
Move _applyTerrainPowerBoost(Move move, Terrain terrain, {
  bool attackerGrounded = true,
  bool defenderGrounded = true,
}) {
  // Rising Voltage: TARGET must be grounded on Electric Terrain. ×2
  // is exact in fp so we keep this direct (matches Showdown line
  // `basePower = move.bp * 2`).
  if (move.hasTag(MoveTags.terrainDoubleElectric) && terrain == Terrain.electric
      && defenderGrounded) {
    return move.copyWith(power: move.power * 2);
  }

  // Expanding Force / Misty Explosion ×1.5: Showdown pushes 6144
  // into bpMods, not into basePower. Routed via damage_calculator's
  // bpMods chain instead — see `isExpandingForceBoostApplicable` /
  // `isMistyExplosionBoostApplicable`. No direct BP change here.

  // General terrain power modifiers (1.3x boost, 0.5x reduction) are NOT
  // applied here — they don't change the move's base power, only affect
  // damage calculation. Applied in offensive_calculator and damage_calculator.
  return move;
}

/// Rank-based power: Stored Power, Power Trip.
Move _applyRankPower(Move move, Rank rank) {
  if (move.hasTag(MoveTags.rankPower)) {
    final totalBoosts = [rank.attack, rank.defense, rank.spAttack, rank.spDefense, rank.speed]
        .where((r) => r > 0)
        .fold(0, (sum, r) => sum + r);
    return move.copyWith(power: 20 + 20 * totalBoosts);
  }
  return move;
}

/// Flail/Reversal power table.
int _flailPower(double hpPercent) {
  if (hpPercent >= 69) return 20;
  if (hpPercent >= 35) return 40;
  if (hpPercent >= 21) return 80;
  if (hpPercent >= 10) return 100;
  if (hpPercent >= 4) return 150;
  return 200;
}

// ====== Dynamax Transformation ======

/// Max Move names by type
const Map<PokemonType, String> _maxMoveNames = {
  PokemonType.normal: 'Max Strike',
  PokemonType.fighting: 'Max Knuckle',
  PokemonType.flying: 'Max Airstream',
  PokemonType.poison: 'Max Ooze',
  PokemonType.ground: 'Max Quake',
  PokemonType.rock: 'Max Rockfall',
  PokemonType.bug: 'Max Flutterby',
  PokemonType.ghost: 'Max Phantasm',
  PokemonType.steel: 'Max Steelspike',
  PokemonType.fire: 'Max Flare',
  PokemonType.water: 'Max Geyser',
  PokemonType.grass: 'Max Overgrowth',
  PokemonType.electric: 'Max Lightning',
  PokemonType.psychic: 'Max Mindstorm',
  PokemonType.ice: 'Max Hailstorm',
  PokemonType.dragon: 'Max Wyrmwind',
  PokemonType.dark: 'Max Darkness',
  PokemonType.fairy: 'Max Starfall',
};

const Map<PokemonType, String> _maxMoveNamesKo = {
  PokemonType.normal: '다이어택',
  PokemonType.fighting: '다이너클',
  PokemonType.flying: '다이제트',
  PokemonType.poison: '다이애시드',
  PokemonType.ground: '다이어스',
  PokemonType.rock: '다이록',
  PokemonType.bug: '다이웜',
  PokemonType.ghost: '다이할로우',
  PokemonType.steel: '다이스틸',
  PokemonType.fire: '다이번',
  PokemonType.water: '다이스트림',
  PokemonType.grass: '다이그래스',
  PokemonType.electric: '다이썬더',
  PokemonType.psychic: '다이사이코',
  PokemonType.ice: '다이아이스',
  PokemonType.dragon: '다이드라군',
  PokemonType.dark: '다이아크',
  PokemonType.fairy: '다이페어리',
};

const Map<PokemonType, String> _maxMoveNamesJa = {
  PokemonType.normal: 'ダイアタック',
  PokemonType.fighting: 'ダイナックル',
  PokemonType.flying: 'ダイジェット',
  PokemonType.poison: 'ダイアシッド',
  PokemonType.ground: 'ダイアース',
  PokemonType.rock: 'ダイロック',
  PokemonType.bug: 'ダイワーム',
  PokemonType.ghost: 'ダイホロウ',
  PokemonType.steel: 'ダイスチル',
  PokemonType.fire: 'ダイバーン',
  PokemonType.water: 'ダイストリーム',
  PokemonType.grass: 'ダイソウゲン',
  PokemonType.electric: 'ダイサンダー',
  PokemonType.psychic: 'ダイサイコ',
  PokemonType.ice: 'ダイアイス',
  PokemonType.dragon: 'ダイドラグーン',
  PokemonType.dark: 'ダイアーク',
  PokemonType.fairy: 'ダイフェアリー',
};

/// G-Max move mapping: pokemonName -> {type: (name, nameKo, power)}
/// G-Max moves replace the Max Move of their signature type.
/// Starter G-Max moves have fixed power 160.
class _GmaxMove {
  final String name;
  final String nameKo;
  final String nameJa;
  final PokemonType type;
  final int? fixedPower; // null = use normal max move power table

  const _GmaxMove(this.name, this.nameKo, this.nameJa, this.type, [this.fixedPower]);
}

const Map<String, _GmaxMove> _gmaxMoves = {
  'charizard': _GmaxMove('G-Max Wildfire', '거다이옥염', 'キョダイゴクエン', PokemonType.fire),
  'butterfree': _GmaxMove('G-Max Befuddle', '거다이고혹', 'キョダイコワク', PokemonType.bug),
  'pikachu': _GmaxMove('G-Max Volt Crash', '거다이만뢰', 'キョダイバンライ', PokemonType.electric),
  'meowth': _GmaxMove('G-Max Gold Rush', '거다이금화', 'キョダイコバン', PokemonType.normal),
  'machamp': _GmaxMove('G-Max Chi Strike', '거다이회심격', 'キョダイシンゲキ', PokemonType.fighting),
  'gengar': _GmaxMove('G-Max Terror', '거다이환영', 'キョダイゲンエイ', PokemonType.ghost),
  'kingler': _GmaxMove('G-Max Foam Burst', '거다이포말', 'キョダイホウマツ', PokemonType.water),
  'lapras': _GmaxMove('G-Max Resonance', '거다이선율', 'キョダイセンリツ', PokemonType.ice),
  'eevee': _GmaxMove('G-Max Cuddle', '거다이포옹', 'キョダイホーヨー', PokemonType.normal),
  'snorlax': _GmaxMove('G-Max Replenish', '거다이재생', 'キョダイサイセイ', PokemonType.normal),
  'garbodor': _GmaxMove('G-Max Malodor', '거다이악취', 'キョダイシュウキ', PokemonType.poison),
  'melmetal': _GmaxMove('G-Max Meltdown', '거다이융격', 'キョダイユウゲキ', PokemonType.steel),
  'corviknight': _GmaxMove('G-Max Wind Rage', '거다이풍격', 'キョダイフウゲキ', PokemonType.flying),
  'orbeetle': _GmaxMove('G-Max Gravitas', '거다이천도', 'キョダイテンドウ', PokemonType.psychic),
  'drednaw': _GmaxMove('G-Max Stonesurge', '거다이암진', 'キョダイガンジン', PokemonType.water),
  'coalossal': _GmaxMove('G-Max Volcalith', '거다이분석', 'キョダイフンセキ', PokemonType.rock),
  'flapple': _GmaxMove('G-Max Tartness', '거다이산격', 'キョダイサンゲキ', PokemonType.grass),
  'appletun': _GmaxMove('G-Max Sweetness', '거다이감로', 'キョダイカンロ', PokemonType.grass),
  'sandaconda': _GmaxMove('G-Max Sand Blast', '거다이사진', 'キョダイサジン', PokemonType.ground),
  'toxtricity': _GmaxMove('G-Max Stun Shock', '거다이감전', 'キョダイカンデン', PokemonType.electric),
  'centiskorch': _GmaxMove('G-Max Centiferno', '거다이백화', 'キョダイヒャッカ', PokemonType.fire),
  'hatterene': _GmaxMove('G-Max Smite', '거다이천벌', 'キョダイテンバツ', PokemonType.fairy),
  'grimmsnarl': _GmaxMove('G-Max Snooze', '거다이수마', 'キョダイスイマ', PokemonType.dark),
  'alcremie': _GmaxMove('G-Max Finale', '거다이단원', 'キョダイダンエン', PokemonType.fairy),
  'copperajah': _GmaxMove('G-Max Steelsurge', '거다이강진', 'キョダイコウジン', PokemonType.steel),
  'duraludon': _GmaxMove('G-Max Depletion', '거다이감쇠', 'キョダイゲンスイ', PokemonType.dragon),
  'venusaur': _GmaxMove('G-Max Vine Lash', '거다이편달', 'キョダイベンタツ', PokemonType.grass, 160),
  'blastoise': _GmaxMove('G-Max Cannonade', '거다이포격', 'キョダイホウゲキ', PokemonType.water, 160),
  'rillaboom': _GmaxMove('G-Max Drum Solo', '거다이난타', 'キョダイコランダ', PokemonType.grass, 160),
  'cinderace': _GmaxMove('G-Max Fireball', '거다이화염구', 'キョダイカキュウ', PokemonType.fire, 160),
  'inteleon': _GmaxMove('G-Max Hydrosnipe', '거다이저격', 'キョダイソゲキ', PokemonType.water, 160),
  'urshifu': _GmaxMove('G-Max One Blow', '거다이일격', 'キョダイイチゲキ', PokemonType.dark),
  'urshifu (rapid strike style)': _GmaxMove('G-Max Rapid Flow', '거다이연격', 'キョダイレンゲキ', PokemonType.water),
};

/// Standard Max Move power conversion table.
int _maxMovePower(int basePower, PokemonType type) {
  // Fighting and Poison types have reduced Max Move power
  final bool reduced = type == PokemonType.fighting || type == PokemonType.poison;

  if (reduced) {
    if (basePower <= 40) return 70;
    if (basePower <= 50) return 75;
    if (basePower <= 60) return 80;
    if (basePower <= 70) return 85;
    if (basePower <= 100) return 90;
    if (basePower <= 120) return 95;
    return 100;
  }

  if (basePower <= 40) return 90;
  if (basePower <= 50) return 100;
  if (basePower <= 60) return 110;
  if (basePower <= 70) return 120;
  if (basePower <= 100) return 130;
  if (basePower <= 120) return 140;
  return 150;
}

/// Returns the fixed Max Move power for special moves (bypasses the table),
/// or null if the move should use the normal base-power-to-max-power table.
int? _fixedMaxMovePower(Move move) {
  // OHKO moves -> fixed 130
  if (move.hasTag(MoveTags.ohko)) return 130;

  // Half-HP moves (Super Fang, Nature's Madness) -> fixed 100
  if (move.hasTag(MoveTags.fixedHalfHp)) return 100;

  // Variable power: HP-based, rank-based, speed-based -> fixed 130
  if (move.hasTag(MoveTags.hpPowerHigh) || move.hasTag(MoveTags.hpPowerLow) ||
      move.hasTag(MoveTags.rankPower) ||
      move.hasTag(MoveTags.gyroSpeed) || move.hasTag(MoveTags.electroSpeed)) {
    return 130;
  }

  // Weight-based moves -> fixed 130
  if (move.hasTag(MoveTags.weightRatio) || move.hasTag(MoveTags.weightTarget)) {
    return 130;
  }

  // Target HP-based power (Crush Grip, Hard Press) -> fixed 130
  if (move.hasTag(MoveTags.powerByTargetHp120) || move.hasTag(MoveTags.powerByTargetHp100)) {
    return 130;
  }

  // Multi-hit moves -> fixed 130
  if (move.isMultiHit) return 130;

  return null; // use normal table
}

/// Apply Dynamax/Gigantamax transformation to a move.
Move _applyDynamax(Move move, DynamaxState dynamax, String? pokemonName) {
  // Fixed damage moves that don't coexist with Dynamax -> Max Guard
  if (move.hasTag(MoveTags.fixed20) || move.hasTag(MoveTags.fixed40)) {
    return move.copyWith(
      name: 'Max Guard', nameEn: 'Max Guard', nameKo: '다이월', nameJa: 'ダイウォール',
      type: PokemonType.normal, power: 0, priority: 0,
      moveClass: MoveClass.maxMove,
      tags: const [],
      minHits: 1, maxHits: 1,
    );
  }

  // Level-based fixed damage moves -> proper Max Moves
  // Night Shade: Ghost -> Max Phantasm (100), Seismic Toss: Fighting -> Max Knuckle (75)
  if (move.hasTag(MoveTags.fixedLevel)) {
    final maxPower = move.name == 'Night Shade' ? 100 : 75;
    final maxName = _maxMoveNames[move.type] ?? 'Max Strike';
    final maxNameKo = _maxMoveNamesKo[move.type] ?? '다이어택';
    final maxNameJa = _maxMoveNamesJa[move.type] ?? 'ダイアタック';
    return move.copyWith(
      name: maxName, nameEn: maxName, nameKo: maxNameKo, nameJa: maxNameJa,
      power: maxPower, priority: 0,
      moveClass: MoveClass.maxMove,
      tags: const [],
      minHits: 1, maxHits: 1,
    );
  }

  // Status moves -> Max Guard (no offensive calc needed, but return something)
  if (move.category == MoveCategory.status) {
    return move.copyWith(
      name: 'Max Guard', nameEn: 'Max Guard', nameKo: '다이월', nameJa: 'ダイウォール',
      type: PokemonType.normal, power: 0, priority: 0,
      moveClass: MoveClass.maxMove,
      tags: const [],
      minHits: 1, maxHits: 1,
    );
  }

  final type = move.type;
  final fixed = _fixedMaxMovePower(move);
  final maxPower = fixed ?? _maxMovePower(move.power, type);

  // Check for G-Max move
  if (dynamax == DynamaxState.gigantamax && pokemonName != null) {
    final key = pokemonName.toLowerCase();
    final gmaxMove = _gmaxMoves[key];
    if (gmaxMove != null && type == gmaxMove.type) {
      final gmaxPower = gmaxMove.fixedPower ?? maxPower;
      return move.copyWith(
        name: gmaxMove.name, nameEn: gmaxMove.name, nameKo: gmaxMove.nameKo, nameJa: gmaxMove.nameJa,
        power: gmaxPower, priority: 0,
        moveClass: MoveClass.maxMove,
        tags: const [],
        minHits: 1, maxHits: 1,
      );
    }
  }

  // Standard Max Move
  final maxName = _maxMoveNames[type] ?? 'Max Strike';
  final maxNameKo = _maxMoveNamesKo[type] ?? '다이어택';
  final maxNameJa = _maxMoveNamesJa[type] ?? 'ダイアタック';
  return move.copyWith(
    name: maxName, nameEn: maxName, nameKo: maxNameKo, nameJa: maxNameJa,
    power: maxPower, priority: 0,
    moveClass: MoveClass.maxMove,
    tags: const [],
    minHits: 1, maxHits: 1,
  );
}

/// Plate → type mapping for Judgment (Arceus).
const _plateTypes = {
  'flame-plate': PokemonType.fire,
  'splash-plate': PokemonType.water,
  'meadow-plate': PokemonType.grass,
  'zap-plate': PokemonType.electric,
  'icicle-plate': PokemonType.ice,
  'fist-plate': PokemonType.fighting,
  'toxic-plate': PokemonType.poison,
  'earth-plate': PokemonType.ground,
  'sky-plate': PokemonType.flying,
  'mind-plate': PokemonType.psychic,
  'insect-plate': PokemonType.bug,
  'stone-plate': PokemonType.rock,
  'spooky-plate': PokemonType.ghost,
  'draco-plate': PokemonType.dragon,
  'dread-plate': PokemonType.dark,
  'iron-plate': PokemonType.steel,
  'pixie-plate': PokemonType.fairy,
};

/// Extracts PokemonType from a Memory item name (e.g. 'fire-memory' → fire).
PokemonType? _memoryType(String itemName) {
  if (!itemName.endsWith('-memory')) return null;
  final typeName = itemName.substring(0, itemName.length - '-memory'.length);
  for (final t in PokemonType.values) {
    if (t.name == typeName) return t;
  }
  return null;
}

// ====== Z-Move transformation ======

/// Converts a move into its Z-Move form.
/// Status moves are not converted (return as-is).
/// All Z-Moves are non-contact (Tough Claws does not apply).
Move _applyZMove(Move move, String? pokemonName) {
  // Status moves cannot become Z-attacks
  if (move.category == MoveCategory.status) return move;

  // Check for exclusive Z-Move (pokemon + base move match)
  if (pokemonName != null) {
    final key = pokemonName.toLowerCase();
    final exclusive = _exclusiveZMoves[key];
    if (exclusive != null && move.name == exclusive.baseMove) {
      return move.copyWith(
        name: exclusive.name,
        nameKo: exclusive.nameKo,
        nameJa: exclusive.nameJa,
        nameEn: exclusive.name,
        power: exclusive.power,
        tags: [...exclusive.tags],
        priority: 0,
        minHits: 1, maxHits: 1,
      );
    }
  }

  // Generic Z-Move: use zPower field or 100 as fallback
  final zPower = move.zPower ?? 100;
  final zName = _zMoveNames[move.type] ?? 'Breakneck Blitz';
  final zNameKo = _zMoveNamesKo[move.type] ?? '울트라대시어택';
  final zNameJa = _zMoveNamesJa[move.type] ?? 'ウルトラダッシュアタック';

  return move.copyWith(
    name: zName,
    nameKo: zNameKo,
    nameJa: zNameJa,
    nameEn: zName,
    power: zPower,
    tags: const [],
    priority: 0,
    minHits: 1, maxHits: 1,
  );
}

/// Generic Z-Move names by type (English)
const Map<PokemonType, String> _zMoveNames = {
  PokemonType.normal: 'Breakneck Blitz',
  PokemonType.fighting: 'All-Out Pummeling',
  PokemonType.flying: 'Supersonic Skystrike',
  PokemonType.poison: 'Acid Downpour',
  PokemonType.ground: 'Tectonic Rage',
  PokemonType.rock: 'Continental Crush',
  PokemonType.bug: 'Savage Spin-Out',
  PokemonType.ghost: 'Never-Ending Nightmare',
  PokemonType.steel: 'Corkscrew Crash',
  PokemonType.fire: 'Inferno Overdrive',
  PokemonType.water: 'Hydro Vortex',
  PokemonType.grass: 'Bloom Doom',
  PokemonType.electric: 'Gigavolt Havoc',
  PokemonType.psychic: 'Shattered Psyche',
  PokemonType.ice: 'Subzero Slammer',
  PokemonType.dragon: 'Devastating Drake',
  PokemonType.dark: 'Black Hole Eclipse',
  PokemonType.fairy: 'Twinkle Tackle',
};

/// Generic Z-Move names (Korean) — from gen7.json official data
const Map<PokemonType, String> _zMoveNamesKo = {
  PokemonType.normal: '울트라대시어택',
  PokemonType.fighting: '전력무쌍격렬권',
  PokemonType.flying: '파이널다이브클래시',
  PokemonType.poison: '애시드포이즌딜리트',
  PokemonType.ground: '라이징랜드오버',
  PokemonType.rock: '월즈엔드폴',
  PokemonType.bug: '절대포식회전참',
  PokemonType.ghost: '무한암야로의유인',
  PokemonType.steel: '초월나선연격',
  PokemonType.fire: '다이내믹풀플레임',
  PokemonType.water: '슈퍼아쿠아토네이도',
  PokemonType.grass: '블룸샤인엑스트라',
  PokemonType.electric: '스파킹기가볼트',
  PokemonType.psychic: '맥시멈사이브레이커',
  PokemonType.ice: '레이징지오프리즈',
  PokemonType.dragon: '얼티메이트드래곤번',
  PokemonType.dark: '블랙홀이클립스',
  PokemonType.fairy: '러블리스타임팩트',
};

/// Generic Z-Move names (Japanese)
const Map<PokemonType, String> _zMoveNamesJa = {
  PokemonType.normal: 'ウルトラダッシュアタック',
  PokemonType.fighting: 'ぜんりょくむそうげきれつけん',
  PokemonType.flying: 'ファイナルダイブクラッシュ',
  PokemonType.poison: 'アシッドポイズンデリート',
  PokemonType.ground: 'ライジングランドオーバー',
  PokemonType.rock: 'ワールズエンドフォール',
  PokemonType.bug: 'ぜったいほしょくかいてんざん',
  PokemonType.ghost: 'むげんあんやへのいざない',
  PokemonType.steel: 'ちょうぜつらせんれんげき',
  PokemonType.fire: 'ダイナミックフルフレイム',
  PokemonType.water: 'スーパーアクアトルネード',
  PokemonType.grass: 'ブルームシャインエクストラ',
  PokemonType.electric: 'スパーキングギガボルト',
  PokemonType.psychic: 'マキシマムサイブレイカー',
  PokemonType.ice: 'レイジングジオフリーズ',
  PokemonType.dragon: 'アルティメットドラゴンバーン',
  PokemonType.dark: 'ブラックホールイクリプス',
  PokemonType.fairy: 'ラブリースターインパクト',
};

/// Exclusive Z-Move data
class _ExclusiveZMove {
  final String baseMove;  // Original move name required
  final String name;      // Z-Move English name
  final String nameKo;
  final String nameJa;
  final int power;
  final List<String> tags;

  const _ExclusiveZMove(this.baseMove, this.name, this.nameKo, this.nameJa, this.power,
      [this.tags = const []]);
}

/// Exclusive Z-Move mapping: pokemonName (lowercase) → exclusive Z data
/// Names from gen7.json official translations.
const Map<String, _ExclusiveZMove> _exclusiveZMoves = {
  'pikachu': _ExclusiveZMove(
    'Volt Tackle', 'Catastropika', '필살피카슛', 'ひっさつのピカチュート', 210, [MoveTags.contact]),
  // Pikachu with cap uses Pikashunium Z + Thunderbolt
  'pikachu-original': _ExclusiveZMove(
    'Thunderbolt', '10,000,000 Volt Thunderbolt', '1000만볼트', '１０００まんボルト', 195),
  'pikachu-hoenn': _ExclusiveZMove(
    'Thunderbolt', '10,000,000 Volt Thunderbolt', '1000만볼트', '１０００まんボルト', 195),
  'pikachu-sinnoh': _ExclusiveZMove(
    'Thunderbolt', '10,000,000 Volt Thunderbolt', '1000만볼트', '１０００まんボルト', 195),
  'pikachu-unova': _ExclusiveZMove(
    'Thunderbolt', '10,000,000 Volt Thunderbolt', '1000만볼트', '１０００まんボルト', 195),
  'pikachu-kalos': _ExclusiveZMove(
    'Thunderbolt', '10,000,000 Volt Thunderbolt', '1000만볼트', '１０００まんボルト', 195),
  'pikachu-alola': _ExclusiveZMove(
    'Thunderbolt', '10,000,000 Volt Thunderbolt', '1000만볼트', '１０００まんボルト', 195),
  'pikachu-partner': _ExclusiveZMove(
    'Thunderbolt', '10,000,000 Volt Thunderbolt', '1000만볼트', '１０００まんボルト', 195),
  'raichu-alola': _ExclusiveZMove(
    'Thunderbolt', 'Stoked Sparksurfer', '라이트닝서프라이드', 'ライトニングサーフライド', 175),
  'eevee': _ExclusiveZMove(
    'Last Resort', 'Extreme Evoboost', '나인이볼부스트', 'ナインエボルブースト', 0), // Status Z
  'snorlax': _ExclusiveZMove(
    'Giga Impact', 'Pulverizing Pancake', '진심의공격', 'ほんきをだす　こうげき', 210, [MoveTags.contact]),
  'mew': _ExclusiveZMove(
    'Psychic', 'Genesis Supernova', '오리진즈슈퍼노바', 'オリジンズスーパーノヴァ', 185),
  'decidueye': _ExclusiveZMove(
    'Spirit Shackle', 'Sinister Arrow Raid', '섀도애로우즈스트라이크', 'シャドーアローズストライク', 180),
  'incineroar': _ExclusiveZMove(
    'Darkest Lariat', 'Malicious Moonsault', '하이퍼다크크러셔', 'ハイパーダーククラッシャー', 180, [MoveTags.contact]),
  'primarina': _ExclusiveZMove(
    'Sparkling Aria', 'Oceanic Operetta', '바다의심포니', 'わだつみのシンフォニア', 195),
  'lycanroc': _ExclusiveZMove(
    'Stone Edge', 'Splintered Stormshards', '레이디얼에지스톰', 'ラジアルエッジストーム', 190),
  'lycanroc-midnight': _ExclusiveZMove(
    'Stone Edge', 'Splintered Stormshards', '레이디얼에지스톰', 'ラジアルエッジストーム', 190),
  'lycanroc-dusk': _ExclusiveZMove(
    'Stone Edge', 'Splintered Stormshards', '레이디얼에지스톰', 'ラジアルエッジストーム', 190),
  'mimikyu': _ExclusiveZMove(
    'Play Rough', "Let's Snuggle Forever", '투닥투닥프렌드타임', 'ぽかぼかフレンドタイム', 190, [MoveTags.contact]),
  'kommo-o': _ExclusiveZMove(
    'Clanging Scales', 'Clangorous Soulblaze', '브레이징소울비트', 'ブレイジングソウルビート', 185),
  'tapu koko': _ExclusiveZMove(
    "Nature\u2019s Madness", 'Guardian of Alola', '알로라의수호자', 'ガーディアン・デ・アローラ', 0, [MoveTags.fixedThreeQuarterHp]),
  'tapu lele': _ExclusiveZMove(
    "Nature\u2019s Madness", 'Guardian of Alola', '알로라의수호자', 'ガーディアン・デ・アローラ', 0, [MoveTags.fixedThreeQuarterHp]),
  'tapu bulu': _ExclusiveZMove(
    "Nature\u2019s Madness", 'Guardian of Alola', '알로라의수호자', 'ガーディアン・デ・アローラ', 0, [MoveTags.fixedThreeQuarterHp]),
  'tapu fini': _ExclusiveZMove(
    "Nature\u2019s Madness", 'Guardian of Alola', '알로라의수호자', 'ガーディアン・デ・アローラ', 0, [MoveTags.fixedThreeQuarterHp]),
  'solgaleo': _ExclusiveZMove(
    'Sunsteel Strike', 'Searing Sunraze Smash', '선샤인스매셔', 'サンシャインスマッシャー', 200, [MoveTags.contact]),
  'necrozma-dusk-mane': _ExclusiveZMove(
    'Sunsteel Strike', 'Searing Sunraze Smash', '선샤인스매셔', 'サンシャインスマッシャー', 200, [MoveTags.contact]),
  'lunala': _ExclusiveZMove(
    'Moongeist Beam', 'Menacing Moonraze Maelstrom', '문라이트블래스터', 'ムーンライトブラスター', 200),
  'necrozma-dawn-wings': _ExclusiveZMove(
    'Moongeist Beam', 'Menacing Moonraze Maelstrom', '문라이트블래스터', 'ムーンライトブラスター', 200),
  'necrozma-ultra': _ExclusiveZMove(
    'Photon Geyser', 'Light That Burns the Sky', '하늘을태우는멸망의빛', 'てんこがすめつぼうのひかり', 200),
  'marshadow': _ExclusiveZMove(
    'Spectral Thief', 'Soul-Stealing 7-Star Strike', '칠성탈혼퇴', 'しちせいだっこんたい', 195, [MoveTags.contact]),
};

// Legacy wrappers for backward compatibility with tests
Move applyWeatherToMove(Move move, Weather weather) => _applyWeather(move, weather);
Move applyTerrainToMove(Move move, Terrain terrain, {bool attackerGrounded = true}) => _applyTerrain(move, terrain, attackerGrounded);
