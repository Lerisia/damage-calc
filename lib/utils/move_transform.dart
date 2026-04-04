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
  final int hpPercent;
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
  final int? opponentHpPercent;

  /// User's primary type (for Revelation Dance).
  final PokemonType? userType1;

  /// User's held item name (for Judgment, Multi-Attack).
  final String? heldItem;

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
    this.hpPercent = 100,
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
    this.hitCount,
    this.opponentHpPercent,
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

  // 1.6. Tera Starstorm: becomes Stellar type when used by Terapagos (Stellar Form)
  // Also becomes physical if Attack > SpAttack
  if (move.name == 'Tera Starstorm' && context.pokemonName != null &&
      context.pokemonName!.toLowerCase().contains('terapagos')) {
    var newType = PokemonType.stellar;
    var newCategory = move.category;
    if (context.actualAttack != null && context.actualSpAttack != null &&
        context.actualAttack! > context.actualSpAttack!) {
      newCategory = MoveCategory.physical;
    }
    move = move.copyWith(type: newType, category: newCategory);
  }

  // 2. Ability type transforms (only if still Normal after step 1/1.5)
  move = _applySkin(move, context.ability);

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

  // 2.55. Raging Bull (Paldean Tauros): type based on breed
  if (move.name == 'Raging Bull' && context.pokemonName != null) {
    final lower = context.pokemonName!.toLowerCase();
    if (lower == 'tauros-paldea-combat' || lower == '10250') {
      move = move.copyWith(type: PokemonType.fighting);
    } else if (lower == 'tauros-paldea-blaze' || lower == '10251') {
      move = move.copyWith(type: PokemonType.fire);
    } else if (lower == 'tauros-paldea-aqua' || lower == '10252') {
      move = move.copyWith(type: PokemonType.water);
    }
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
  move = _applyHpPower(move, context.hpPercent);
  move = _applyStatusPower(move, context.status);
  move = _applySpeedPower(move, context.mySpeed, context.opponentSpeed);
  move = _applyTurnOrderPower(move, context.mySpeed, context.opponentSpeed);
  move = _applyWeightPower(move, context.myWeight, context.opponentWeight);
  move = _applyTargetHpPower(move, context.opponentHpPercent);

  // 4. Field-based power boosts
  move = _applyTerrainPowerBoost(move, context.terrain,
      attackerGrounded: context.attackerGrounded,
      defenderGrounded: context.defenderGrounded);

  // 5. Rank-based power
  move = _applyRankPower(move, context.rank);

  // 5b. Grav Apple: power * 1.5 under gravity
  if (move.hasTag(MoveTags.gravityBoost) && context.gravity) {
    move = move.copyWith(power: (move.power * 1.5).floor());
  }

  // 5c. Solar Beam / Solar Blade: halved in rain, sandstorm, snow, heavy rain
  if (move.hasTag(MoveTags.solarHalve) &&
      (context.weather == Weather.rain || context.weather == Weather.sandstorm ||
       context.weather == Weather.snow || context.weather == Weather.heavyRain)) {
    move = move.copyWith(power: (move.power * 0.5).floor());
  }

  // 6. Multi-hit: apply total power (before Dynamax, which has its own formula)
  if (move.isMultiHit && context.hitCount != null && context.hitCount! > 1) {
    final hits = context.hitCount!;
    move = move.copyWith(
      power: move.totalPower(hits),
      tags: move.tags.where((t) => t != MoveTags.escalatingHits).toList(),
    );
  }

  // 7. Dynamax first, then Z-Move check.
  // Z-Move is blocked by Mega/Dynamax/Terastal (3 safety layers):
  //   Layer 1: UI disables Z checkbox when any of these are active
  //   Layer 2: Logic check below skips Z if Mega/Dynamax/Terastal
  //   Layer 3: Dynamax runs first, so even if Z is on, Dynamax takes priority
  if (context.dynamax != DynamaxState.none && move.type != PokemonType.typeless) {
    move = _applyDynamax(move, context.dynamax, context.pokemonName);
  } else if (context.zMove && move.type != PokemonType.typeless &&
      context.dynamax == DynamaxState.none && !context.terastallized &&
      !context.isMega) {
    move = _applyZMove(move, context.pokemonName);
  }

  // 7. Stat selection
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

Move _applySkin(Move move, String? ability) {
  if (ability == null) return move;

  // Normalize: ALL moves become Normal (type change only, 1.2x is in ability_effects)
  if (ability == 'Normalize') {
    return move.copyWith(type: PokemonType.normal);
  }

  // Other skins: only Normal moves get converted
  final skinType = _skinAbilities[ability];
  if (skinType == null || move.type != PokemonType.normal) return move;

  return move.copyWith(type: skinType, power: (move.power * 1.2).floor());
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

/// HP-based power: Eruption/Water Spout/Dragon Energy, Flail/Reversal.
Move _applyHpPower(Move move, int hpPercent) {
  if (move.hasTag(MoveTags.hpPowerHigh)) {
    return move.copyWith(power: math.max(1, (150 * hpPercent / 100).floor()));
  }
  if (move.hasTag(MoveTags.hpPowerLow)) {
    return move.copyWith(power: _flailPower(hpPercent));
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

/// Target-HP-based power: Crush Grip / Wring Out (120×), Hard Press (100×)
Move _applyTargetHpPower(Move move, int? opponentHpPercent) {
  if (opponentHpPercent == null) return move;

  if (move.hasTag(MoveTags.powerByTargetHp120)) {
    final power = (120 * opponentHpPercent / 100).floor().clamp(1, 120);
    return move.copyWith(power: power);
  }
  if (move.hasTag(MoveTags.powerByTargetHp100)) {
    final power = (100 * opponentHpPercent / 100).floor().clamp(1, 100);
    return move.copyWith(power: power);
  }

  return move;
}

/// Terrain-based power boosts and reductions.
/// - Rising Voltage: 2x in Electric Terrain
/// - Expanding Force: 1.5x in Psychic Terrain
/// - Misty Explosion: 1.5x in Misty Terrain
/// - Earthquake/Bulldoze/Magnitude: 0.5x in Grassy Terrain
Move _applyTerrainPowerBoost(Move move, Terrain terrain, {
  bool attackerGrounded = true,
  bool defenderGrounded = true,
}) {
  // Move-specific terrain boosts — each has its own grounding requirement
  // Rising Voltage: TARGET must be grounded on Electric Terrain
  if (move.hasTag(MoveTags.terrainDoubleElectric) && terrain == Terrain.electric
      && defenderGrounded) {
    return move.copyWith(power: move.power * 2);
  }
  // Expanding Force: USER must be grounded on Psychic Terrain
  if (move.hasTag(MoveTags.terrainBoostPsychic) && terrain == Terrain.psychic
      && attackerGrounded) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }
  // Misty Explosion: USER must be grounded on Misty Terrain
  if (move.hasTag(MoveTags.terrainBoostMisty) && terrain == Terrain.misty
      && attackerGrounded) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }

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
int _flailPower(int hpPercent) {
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
