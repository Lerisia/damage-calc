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
import 'ability_effects.dart' show multiHitMoves;

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

  /// User's primary type (for Revelation Dance).
  final PokemonType? userType1;

  /// User's held item name (for Judgment, Multi-Attack).
  final String? heldItem;

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
    this.actualAttack,
    this.actualSpAttack,
    this.myWeight,
    this.opponentWeight,
    this.userType1,
    this.heldItem,
  });
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
  move = _applyTerrain(move, context.terrain);

  // 1.5. Tera Blast: type/category changes when terastallized
  // Must happen BEFORE skins so Normal Tera Blast can be converted by -ate abilities
  if (context.terastallized && context.teraType != null && move.name == 'Tera Blast') {
    move = _applyTeraBlast(move, context);
  }

  // 2. Ability type transforms (only if still Normal after step 1/1.5)
  move = _applySkin(move, context.ability);

  // 2b. Liquid Voice: sound moves become Water type (no power boost)
  if (context.ability == 'Liquid Voice' && move.hasTag(MoveTags.sound)) {
    move = move.copyWith(type: PokemonType.water);
  }

  // 2.5. Ivy Cudgel: type changes based on Ogerpon form
  if (move.name == 'Ivy Cudgel' && context.pokemonName != null) {
    const ogerponType = {
      'ogerpon-wellspring-mask': PokemonType.water,
      'ogerpon-hearthflame-mask': PokemonType.fire,
      'ogerpon-cornerstone-mask': PokemonType.rock,
    };
    final t = ogerponType[context.pokemonName!.toLowerCase()];
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

  // 2.7. Long Reach: remove contact tag
  if (context.ability == 'Long Reach' && move.hasTag(MoveTags.contact)) {
    move = move.copyWith(tags: move.tags.where((t) => t != MoveTags.contact).toList());
  }

  // 3. Conditional power changes
  move = _applyItemCondition(move, context.hasItem);
  move = _applyHpPower(move, context.hpPercent);
  move = _applyStatusPower(move, context.status);
  move = _applySpeedPower(move, context.mySpeed, context.opponentSpeed);
  move = _applyTurnOrderPower(move, context.mySpeed, context.opponentSpeed);
  move = _applyWeightPower(move, context.myWeight, context.opponentWeight);

  // 4. Field-based power boosts
  move = _applyTerrainPowerBoost(move, context.terrain);

  // 5. Rank-based power
  move = _applyRankPower(move, context.rank);

  // 6. Dynamax transform (after all other power changes)
  if (context.dynamax != DynamaxState.none) {
    move = _applyDynamax(move, context.dynamax, context.pokemonName);
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
Move _applyTerrain(Move move, Terrain terrain) {
  if (move.name != 'Terrain Pulse' || terrain == Terrain.none) {
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

/// Terrain-based power boosts and reductions.
/// - Rising Voltage: 2x in Electric Terrain
/// - Expanding Force: 1.5x in Psychic Terrain
/// - Misty Explosion: 1.5x in Misty Terrain
/// - Earthquake/Bulldoze/Magnitude: 0.5x in Grassy Terrain
Move _applyTerrainPowerBoost(Move move, Terrain terrain) {
  // Note: Grassy Terrain halving Earthquake/Bulldoze is in terrain_effects.dart
  // (applied as a damage modifier), NOT here, to avoid double application.
  if (move.hasTag(MoveTags.terrainDoubleElectric) && terrain == Terrain.electric) {
    return move.copyWith(power: move.power * 2);
  }
  if (move.hasTag(MoveTags.terrainBoostPsychic) && terrain == Terrain.psychic) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }
  if (move.hasTag(MoveTags.terrainBoostMisty) && terrain == Terrain.misty) {
    return move.copyWith(power: (move.power * 1.5).floor());
  }
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

/// G-Max move mapping: pokemonName -> {type: (name, nameKo, power)}
/// G-Max moves replace the Max Move of their signature type.
/// Starter G-Max moves have fixed power 160.
class _GmaxMove {
  final String name;
  final String nameKo;
  final PokemonType type;
  final int? fixedPower; // null = use normal max move power table

  const _GmaxMove(this.name, this.nameKo, this.type, [this.fixedPower]);
}

const Map<String, _GmaxMove> _gmaxMoves = {
  'charizard': _GmaxMove('G-Max Wildfire', '거다이옥염', PokemonType.fire),
  'butterfree': _GmaxMove('G-Max Befuddle', '거다이고혹', PokemonType.bug),
  'pikachu': _GmaxMove('G-Max Volt Crash', '거다이만뢰', PokemonType.electric),
  'meowth': _GmaxMove('G-Max Gold Rush', '거다이금화', PokemonType.normal),
  'machamp': _GmaxMove('G-Max Chi Strike', '거다이회심격', PokemonType.fighting),
  'gengar': _GmaxMove('G-Max Terror', '거다이환영', PokemonType.ghost),
  'kingler': _GmaxMove('G-Max Foam Burst', '거다이포말', PokemonType.water),
  'lapras': _GmaxMove('G-Max Resonance', '거다이선율', PokemonType.ice),
  'eevee': _GmaxMove('G-Max Cuddle', '거다이포옹', PokemonType.normal),
  'snorlax': _GmaxMove('G-Max Replenish', '거다이재생', PokemonType.normal),
  'garbodor': _GmaxMove('G-Max Malodor', '거다이악취', PokemonType.poison),
  'melmetal': _GmaxMove('G-Max Meltdown', '거다이융격', PokemonType.steel),
  'corviknight': _GmaxMove('G-Max Wind Rage', '거다이풍격', PokemonType.flying),
  'orbeetle': _GmaxMove('G-Max Gravitas', '거다이천도', PokemonType.psychic),
  'drednaw': _GmaxMove('G-Max Stonesurge', '거다이암진', PokemonType.water),
  'coalossal': _GmaxMove('G-Max Volcalith', '거다이분석', PokemonType.rock),
  'flapple': _GmaxMove('G-Max Tartness', '거다이산격', PokemonType.grass),
  'appletun': _GmaxMove('G-Max Sweetness', '거다이감로', PokemonType.grass),
  'sandaconda': _GmaxMove('G-Max Sand Blast', '거다이사진', PokemonType.ground),
  'toxtricity': _GmaxMove('G-Max Stun Shock', '거다이감전', PokemonType.electric),
  'centiskorch': _GmaxMove('G-Max Centiferno', '거다이백화', PokemonType.fire),
  'hatterene': _GmaxMove('G-Max Smite', '거다이천벌', PokemonType.fairy),
  'grimmsnarl': _GmaxMove('G-Max Snooze', '거다이수마', PokemonType.dark),
  'alcremie': _GmaxMove('G-Max Finale', '거다이단원', PokemonType.fairy),
  'copperajah': _GmaxMove('G-Max Steelsurge', '거다이강진', PokemonType.steel),
  'duraludon': _GmaxMove('G-Max Depletion', '거다이감쇠', PokemonType.dragon),
  'venusaur': _GmaxMove('G-Max Vine Lash', '거다이편달', PokemonType.grass, 160),
  'blastoise': _GmaxMove('G-Max Cannonade', '거다이포격', PokemonType.water, 160),
  'rillaboom': _GmaxMove('G-Max Drum Solo', '거다이난타', PokemonType.grass, 160),
  'cinderace': _GmaxMove('G-Max Fireball', '거다이화염구', PokemonType.fire, 160),
  'inteleon': _GmaxMove('G-Max Hydrosnipe', '거다이저격', PokemonType.water, 160),
  'urshifu-single-strike': _GmaxMove('G-Max One Blow', '거다이일격', PokemonType.dark),
  'urshifu-rapid-strike': _GmaxMove('G-Max Rapid Flow', '거다이연격', PokemonType.water),
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

/// Determine the base power for Max Move conversion.
/// Handles special cases: multi-hit, OHKO, variable power, fixed damage.
int _maxMoveBasePower(Move move) {
  // OHKO moves -> 130
  if (move.name == 'Guillotine' || move.name == 'Fissure' ||
      move.name == 'Horn Drill' || move.name == 'Sheer Cold') {
    return 130;
  }

  // Fixed damage / counter moves -> 75
  if (move.name == 'Seismic Toss' || move.name == 'Night Shade' ||
      move.name == 'Dragon Rage' || move.name == 'Sonic Boom' ||
      move.name == 'Counter' || move.name == 'Mirror Coat' ||
      move.name == 'Metal Burst' || move.name == 'Super Fang' ||
      move.name == 'Endeavor') {
    // Super Fang and Endeavor map to 100/130 respectively based on Bulbapedia
    if (move.name == 'Super Fang') return 100;
    if (move.name == 'Endeavor') return 130;
    return 75;
  }

  // Variable power moves (Flail, Reversal, Eruption, etc.) -> 130
  if (move.hasTag(MoveTags.hpPowerHigh) || move.hasTag(MoveTags.hpPowerLow) ||
      move.hasTag(MoveTags.rankPower)) {
    return 130;
  }

  // Weight-based moves -> 130
  if (move.hasTag(MoveTags.weightRatio) || move.hasTag(MoveTags.weightTarget)) {
    return 130;
  }

  // Multi-hit moves -> 130 for Dynamax conversion
  if (multiHitMoves.contains(move.name)) {
    return 130;
  }

  // Normal: use the move's base power
  return move.power;
}

/// Apply Dynamax/Gigantamax transformation to a move.
Move _applyDynamax(Move move, DynamaxState dynamax, String? pokemonName) {
  // Status moves -> Max Guard (no offensive calc needed, but return something)
  if (move.category == MoveCategory.status) {
    return move.copyWith(
      name: 'Max Guard', nameKo: '다이월', nameJa: 'ダイウォール',
      type: PokemonType.normal, power: 0,
      moveClass: MoveClass.maxMove,
    );
  }

  final type = move.type;
  final basePower = _maxMoveBasePower(move);
  final maxPower = _maxMovePower(basePower, type);

  // Check for G-Max move
  if (dynamax == DynamaxState.gigantamax && pokemonName != null) {
    final key = pokemonName.toLowerCase();
    final gmaxMove = _gmaxMoves[key];
    if (gmaxMove != null && type == gmaxMove.type) {
      final gmaxPower = gmaxMove.fixedPower ?? maxPower;
      return move.copyWith(
        name: gmaxMove.name, nameKo: gmaxMove.nameKo,
        power: gmaxPower,
        moveClass: MoveClass.maxMove,
      );
    }
  }

  // Standard Max Move
  final maxName = _maxMoveNames[type] ?? 'Max Strike';
  final maxNameKo = _maxMoveNamesKo[type] ?? '다이어택';
  return move.copyWith(
    name: maxName, nameKo: maxNameKo,
    power: maxPower,
    moveClass: MoveClass.maxMove,
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

// Legacy wrappers for backward compatibility with tests
Move applyWeatherToMove(Move move, Weather weather) => _applyWeather(move, weather);
Move applyTerrainToMove(Move move, Terrain terrain) => _applyTerrain(move, terrain);
