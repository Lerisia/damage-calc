import 'dart:math' as math;

import '../models/gender.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/rank.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import 'move_transform.dart';

// ====== Ability modifier constants ======

/// Stat multiplier constants
const double kDoubleStatBoost = 2.0;
const double kMajorStatBoost = 1.5;
const double kMinorStatBoost = 1.3;
const double kHalfStat = 0.5;

/// Power multiplier constants
const double kDoublePower = 2.0;
const double kMajorPowerBoost = 1.5;
const double kMediumPowerBoost = 1.3;
const double kMinorPowerBoost = 1.2;
const double kParentalBondMultiplier = 1.2;
const double kRivalrySameGender = 1.25;
const double kRivalryOppositeGender = 0.75;

/// Critical hit override
const double kSniperCritical = 2.25;

/// STAB override
const double kAdaptabilityStab = 2.0;

/// Technician threshold
const int kTechnicianMaxPower = 60;

/// HP threshold for Blaze/Overgrow/Torrent/Swarm/Defeatist
const int kPinchHpThreshold = 33;
const int kDefeatistHpThreshold = 50;

/// Protosynthesis/Quark Drive boost values
const double kParadoxStatBoost = 5461.0 / 4096.0;
const double kParadoxSpeedBoost = 1.5;

/// Quick Feet speed boost
const double kQuickFeetSpeed = 1.5;

/// Weather/terrain speed boost
const double kWeatherSpeedBoost = 2.0;

/// Per-stat modifiers from an ability
class AbilityStatModifiers {
  final double attack;
  final double defense;
  final double spAttack;
  final double spDefense;
  final double speed;

  const AbilityStatModifiers({
    this.attack = 1.0,
    this.defense = 1.0,
    this.spAttack = 1.0,
    this.spDefense = 1.0,
    this.speed = 1.0,
  });
}

/// Effect of an ability on battle calculations
class AbilityEffect {
  final AbilityStatModifiers statModifiers;
  final double powerModifier;
  final double? stabOverride;
  final double? criticalOverride;
  /// Whether all moves get STAB (Protean, Libero).
  final bool forceStab;

  const AbilityEffect({
    this.statModifiers = const AbilityStatModifiers(),
    this.powerModifier = 1.0,
    this.stabOverride,
    this.criticalOverride,
    this.forceStab = false,
  });
}

const _defaultEffect = AbilityEffect();

/// Returns the offensive effect of [abilityName] given the [move] being used.
///
/// [originalBasePower] is the move's base power before any transformation
/// (e.g. Acrobatics 55 before doubling). Used for Technician's ≤60 check.
/// If null, falls back to [move.power].
AbilityEffect getAbilityEffect(String abilityName, {
  Move? move,
  int? originalBasePower,
  int hpPercent = 100,
  Weather weather = Weather.none,
  Terrain terrain = Terrain.none,
  StatusCondition status = StatusCondition.none,
  Stats? actualStats,
  String? heldItem,
  int? opponentSpeed,
  Gender myGender = Gender.unset,
  Gender opponentGender = Gender.unset,
}) {
  switch (abilityName) {
    // --- Stat modifiers (attack) ---
    case 'Huge Power':
    case 'Pure Power':
      return const AbilityEffect(
        statModifiers: AbilityStatModifiers(attack: kDoubleStatBoost));
    case 'Gorilla Tactics':
      return const AbilityEffect(
        statModifiers: AbilityStatModifiers(attack: kMajorStatBoost));
    case 'Hustle':
      return move != null && move.category == MoveCategory.physical
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: kMajorStatBoost))
          : _defaultEffect;

    // --- Normalize: 1.2x to all Normal-type moves (type change is in move_transform) ---
    case 'Normalize':
      return move != null && move.type == PokemonType.normal
          ? const AbilityEffect(powerModifier: kMinorPowerBoost)
          : _defaultEffect;

    // --- Tag-based power modifiers ---
    case 'Tough Claws':
      return move != null && move.hasTag(MoveTags.contact)
          ? const AbilityEffect(powerModifier: kMediumPowerBoost)
          : _defaultEffect;
    case 'Iron Fist':
      return move != null && move.hasTag(MoveTags.punch)
          ? const AbilityEffect(powerModifier: kMinorPowerBoost)
          : _defaultEffect;
    case 'Reckless':
      return move != null && move.hasTag(MoveTags.recoil)
          ? const AbilityEffect(powerModifier: kMinorPowerBoost)
          : _defaultEffect;
    case 'Strong Jaw':
      return move != null && move.hasTag(MoveTags.bite)
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Mega Launcher':
      return move != null && move.hasTag(MoveTags.pulse)
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Sharpness':
      return move != null && move.hasTag(MoveTags.slice)
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Technician':
      final techPower = originalBasePower ?? move?.power ?? 0;
      return move != null && techPower <= kTechnicianMaxPower
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;

    // --- STAB override ---
    case 'Adaptability':
      return const AbilityEffect(stabOverride: kAdaptabilityStab);

    // --- Force STAB on all moves (type changes to match move) ---
    case 'Protean':
    case 'Libero':
      return const AbilityEffect(forceStab: true);

    // --- Type-based power modifiers ---
    case 'Steelworker':
    case 'Steely Spirit':
      return move != null && move.type == PokemonType.steel
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Transistor':
      return move != null && move.type == PokemonType.electric
          ? const AbilityEffect(powerModifier: kMediumPowerBoost)
          : _defaultEffect;
    case "Dragon's Maw":
      return move != null && move.type == PokemonType.dragon
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Rocky Payload':
      return move != null && move.type == PokemonType.rock
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;

    // --- Weather/Terrain stat modifiers ---
    case 'Solar Power':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: kMajorStatBoost))
          : _defaultEffect;
    case 'Sand Force':
      return (weather == Weather.sandstorm && move != null &&
              (move.type == PokemonType.ground ||
               move.type == PokemonType.rock ||
               move.type == PokemonType.steel))
          ? const AbilityEffect(powerModifier: kMediumPowerBoost)
          : _defaultEffect;
    case 'Orichalcum Pulse':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: kParadoxStatBoost))
          : _defaultEffect;
    case 'Hadron Engine':
      return terrain == Terrain.electric
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: kParadoxStatBoost))
          : _defaultEffect;
    case 'Flower Gift':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: kMajorStatBoost, spDefense: kMajorStatBoost))
          : _defaultEffect;

    // --- Protosynthesis / Quark Drive ---
    case 'Protosynthesis':
      final protoActive = (weather == Weather.sun || weather == Weather.harshSun)
          || heldItem == 'booster-energy';
      return protoActive && actualStats != null
          ? AbilityEffect(statModifiers: _boostHighestStat(actualStats))
          : _defaultEffect;
    case 'Quark Drive':
      final quarkActive = terrain == Terrain.electric
          || heldItem == 'booster-energy';
      return quarkActive && actualStats != null
          ? AbilityEffect(statModifiers: _boostHighestStat(actualStats))
          : _defaultEffect;

    // --- HP conditional ---
    case 'Blaze':
      return (hpPercent <= kPinchHpThreshold && move != null && move.type == PokemonType.fire)
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Overgrow':
      return (hpPercent <= kPinchHpThreshold && move != null && move.type == PokemonType.grass)
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Torrent':
      return (hpPercent <= kPinchHpThreshold && move != null && move.type == PokemonType.water)
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;
    case 'Swarm':
      return (hpPercent <= kPinchHpThreshold && move != null && move.type == PokemonType.bug)
          ? const AbilityEffect(powerModifier: kMajorPowerBoost)
          : _defaultEffect;

    // --- Other power modifiers ---
    case 'Water Bubble':
      return move != null && move.type == PokemonType.water
          ? const AbilityEffect(powerModifier: kDoublePower)
          : _defaultEffect;
    case 'Punk Rock':
      return move != null && move.hasTag(MoveTags.sound)
          ? const AbilityEffect(powerModifier: kMediumPowerBoost)
          : _defaultEffect;
    case 'Sheer Force':
      return move != null && move.hasTag(MoveTags.hasSecondary)
          ? const AbilityEffect(powerModifier: kMediumPowerBoost)
          : _defaultEffect;

    // --- Parental Bond (Mega Kangaskhan) ---
    case 'Parental Bond':
      if (move != null && _isMultiHit(move)) return _defaultEffect;
      return const AbilityEffect(powerModifier: kParentalBondMultiplier);

    // --- Critical override ---
    case 'Sniper':
      return const AbilityEffect(criticalOverride: kSniperCritical);

    // --- Status conditional ---
    case 'Guts':
      return status != StatusCondition.none
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: kMajorStatBoost))
          : _defaultEffect;
    case 'Toxic Boost':
      return (status == StatusCondition.poison || status == StatusCondition.badlyPoisoned)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: kMajorStatBoost))
          : _defaultEffect;
    case 'Flare Boost':
      return status == StatusCondition.burn
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: kMajorStatBoost))
          : _defaultEffect;

    // --- HP conditional (stat reduction) ---
    case 'Defeatist':
      return hpPercent <= kDefeatistHpThreshold
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: kHalfStat, spAttack: kHalfStat))
          : _defaultEffect;

    // --- Speed conditional ---
    case 'Analytic':
      if (actualStats != null && opponentSpeed != null &&
          actualStats.speed < opponentSpeed) {
        return const AbilityEffect(powerModifier: kMediumPowerBoost);
      }
      return _defaultEffect;

    // --- Gender conditional ---
    case 'Rivalry':
      final hasGender = myGender == Gender.male || myGender == Gender.female;
      final oppHasGender = opponentGender == Gender.male || opponentGender == Gender.female;
      if (hasGender && oppHasGender) {
        if (myGender == opponentGender) {
          return const AbilityEffect(powerModifier: kRivalrySameGender);
        } else {
          return const AbilityEffect(powerModifier: kRivalryOppositeGender);
        }
      }
      return _defaultEffect;

    // --- Speed stat modifiers ---
    case 'Swift Swim':
      return (weather == Weather.rain || weather == Weather.heavyRain)
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: kWeatherSpeedBoost))
          : _defaultEffect;
    case 'Chlorophyll':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: kWeatherSpeedBoost))
          : _defaultEffect;
    case 'Sand Rush':
      return weather == Weather.sandstorm
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: kWeatherSpeedBoost))
          : _defaultEffect;
    case 'Slush Rush':
      return weather == Weather.snow
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: kWeatherSpeedBoost))
          : _defaultEffect;
    case 'Surge Surfer':
      return terrain == Terrain.electric
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: kWeatherSpeedBoost))
          : _defaultEffect;
    case 'Quick Feet':
      return status != StatusCondition.none
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: kQuickFeetSpeed))
          : _defaultEffect;
    case 'Unburden':
      return heldItem == null
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: kDoubleStatBoost))
          : _defaultEffect;

    // --- Aura abilities (self-boost for 결정력) ---
    // Aura Break reversal is handled in getAuraModifier() during damage calc.
    case 'Fairy Aura':
      return move != null && move.type == PokemonType.fairy
          ? const AbilityEffect(powerModifier: kAuraBoost)
          : _defaultEffect;
    case 'Dark Aura':
      return move != null && move.type == PokemonType.dark
          ? const AbilityEffect(powerModifier: kAuraBoost)
          : _defaultEffect;

    default:
      return _defaultEffect;
  }
}

/// Defensive ability effect on bulk calculation.
class DefensiveAbilityEffect {
  final double defModifier;
  final double spdModifier;

  const DefensiveAbilityEffect({
    this.defModifier = 1.0,
    this.spdModifier = 1.0,
  });
}

const _defaultDefensiveEffect = DefensiveAbilityEffect();

/// Returns the defensive effect of [abilityName] on bulk.
///
/// - Fur Coat: Def x2
/// - Ice Scales: SpDef x2 (special damage halved)
/// - Fluffy: Def x2 (physical damage halved, fire weakness separate)
/// - Marvel Scale: Def x1.5 when statused
DefensiveAbilityEffect getDefensiveAbilityEffect(String abilityName, {
  StatusCondition status = StatusCondition.none,
  Weather weather = Weather.none,
  Terrain terrain = Terrain.none,
}) {
  switch (abilityName) {
    case 'Fur Coat':
      return const DefensiveAbilityEffect(defModifier: 2.0);
    // Ice Scales: handled in getDefensiveAbilityDamageMultiplier (special damage x0.5)
    // Fluffy: handled in getDefensiveAbilityDamageMultiplier (contact-dependent)
    case 'Marvel Scale':
      return status != StatusCondition.none
          ? const DefensiveAbilityEffect(defModifier: 1.5)
          : _defaultDefensiveEffect;
    case 'Flower Gift':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const DefensiveAbilityEffect(spdModifier: 1.5)
          : _defaultDefensiveEffect;
    case 'Grass Pelt':
      return terrain == Terrain.grassy
          ? const DefensiveAbilityEffect(defModifier: 1.5)
          : _defaultDefensiveEffect;
    default:
      return _defaultDefensiveEffect;
  }
}

/// Returns a damage multiplier for the defender's ability based on the
/// incoming move's type and tags.
///
/// This handles type-specific damage reduction/increase that can't be
/// expressed as simple def/spd stat modifiers.
double getDefensiveAbilityDamageMultiplier(String abilityName, {
  required Move move,
}) {
  final moveType = move.type;
  switch (abilityName) {
    case 'Ice Scales':
      return move.category == MoveCategory.special ? 0.5 : 1.0;
    case 'Thick Fat':
      return (moveType == PokemonType.fire || moveType == PokemonType.ice)
          ? 0.5 : 1.0;
    case 'Heatproof':
      return moveType == PokemonType.fire ? 0.5 : 1.0;
    case 'Water Bubble':
      return moveType == PokemonType.fire ? 0.5 : 1.0;
    case 'Purifying Salt':
      return moveType == PokemonType.ghost ? 0.5 : 1.0;
    case 'Dry Skin':
      return moveType == PokemonType.fire ? 1.25 : 1.0;
    case 'Fluffy':
      // Fire moves deal double damage
      if (moveType == PokemonType.fire) return 2.0;
      // Contact moves deal half damage
      if (move.hasTag(MoveTags.contact)) return 0.5;
      return 1.0;
    case 'Punk Rock':
      return move.hasTag(MoveTags.sound) ? 0.5 : 1.0;
    default:
      return 1.0;
  }
}

/// Returns true if [abilityName] grants immunity to a specific [move]
/// based on move tags (ball, sound, powder).
bool isAbilityMoveImmune(String abilityName, Move move) {
  switch (abilityName) {
    case 'Bulletproof':
      return move.hasTag(MoveTags.ball);
    case 'Soundproof':
      return move.hasTag(MoveTags.sound);
    case 'Overcoat':
      return move.hasTag(MoveTags.powder);
    default:
      return false;
  }
}

/// Returns true if [abilityName] grants immunity to [moveType].
bool isAbilityTypeImmune(String abilityName, PokemonType moveType) {
  const immunities = {
    'Volt Absorb': PokemonType.electric,
    'Lightning Rod': PokemonType.electric,
    'Motor Drive': PokemonType.electric,
    'Water Absorb': PokemonType.water,
    'Storm Drain': PokemonType.water,
    'Dry Skin': PokemonType.water,
    'Flash Fire': PokemonType.fire,
    'Well-Baked Body': PokemonType.fire,
    'Sap Sipper': PokemonType.grass,
    'Earth Eater': PokemonType.ground,
    // Levitate is handled by isGrounded check, not here
  };
  return immunities[abilityName] == moveType;
}

/// Returns the speed modifier from [abilityName] given battle conditions.
///
/// Convenience wrapper around [getAbilityEffect] that extracts the speed
/// stat modifier.
double getSpeedAbilityModifier(String abilityName, {
  Weather weather = Weather.none,
  Terrain terrain = Terrain.none,
  StatusCondition status = StatusCondition.none,
  String? heldItem,
}) {
  return getAbilityEffect(abilityName,
    weather: weather, terrain: terrain, status: status, heldItem: heldItem,
  ).statModifiers.speed;
}

/// Multi-hit moves (used by Parental Bond check and Dynamax power table).
const multiHitMoves = {
  'Bullet Seed', 'Icicle Spear', 'Rock Blast', 'Pin Missile', 'Tail Slap',
  'Scale Shot', 'Population Bomb', 'Bone Rush', 'Arm Thrust', 'Barrage',
  'Comet Punch', 'Double Slap', 'Fury Attack', 'Fury Swipes', 'Spike Cannon',
  'Water Shuriken', 'Triple Axel', 'Triple Kick', 'Triple Dive',
  'Surging Strikes', 'Double Hit', 'Double Iron Bash', 'Dragon Darts',
  'Dual Wingbeat', 'Twineedle',
};

bool _isMultiHit(Move move) => multiHitMoves.contains(move.name);

AbilityStatModifiers _boostHighestStat(Stats stats) {
  // Compare attack, defense, spAttack, spDefense, speed (not HP)
  final values = {
    'attack': stats.attack,
    'defense': stats.defense,
    'spAttack': stats.spAttack,
    'spDefense': stats.spDefense,
    'speed': stats.speed,
  };

  final highest = values.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  // Speed gets kParadoxSpeedBoost, others get kParadoxStatBoost
  switch (highest) {
    case 'attack':
      return const AbilityStatModifiers(attack: kParadoxStatBoost);
    case 'defense':
      return const AbilityStatModifiers(defense: kParadoxStatBoost);
    case 'spAttack':
      return const AbilityStatModifiers(spAttack: kParadoxStatBoost);
    case 'spDefense':
      return const AbilityStatModifiers(spDefense: kParadoxStatBoost);
    case 'speed':
      return const AbilityStatModifiers(speed: kParadoxSpeedBoost);
    default:
      return const AbilityStatModifiers();
  }
}

// ====== Mold Breaker ======

/// Abilities that act as Mold Breaker (ignore defender's ignorable abilities).
const Set<String> moldBreakerAbilities = {
  'Mold Breaker',
  'Teravolt',
  'Turboblaze',
};

/// Returns true if [abilityName] is a Mold Breaker variant.
bool isMoldBreaker(String? abilityName) {
  return abilityName != null && moldBreakerAbilities.contains(abilityName);
}

// ====== Neutralizing Gas (화학변화가스) ======

/// Returns true if Neutralizing Gas is active on either side.
bool hasNeutralizingGas(String? attackerAbility, String? defenderAbility) {
  return attackerAbility == 'Neutralizing Gas' ||
      defenderAbility == 'Neutralizing Gas';
}

/// Returns the effective ability considering Neutralizing Gas.
///
/// If either side has Neutralizing Gas, all other abilities are suppressed.
/// Neutralizing Gas itself is also not treated as having any other effect.
String? resolveAbilityWithGas({
  required String? ability,
  required String? attackerAbility,
  required String? defenderAbility,
}) {
  if (!hasNeutralizingGas(attackerAbility, defenderAbility)) return ability;
  // Neutralizing Gas suppresses everything, including itself
  return null;
}

/// Abilities that are ignored by Mold Breaker during damage calculation.
/// This covers immunities, damage reduction, and defensive stat boosts.
const Set<String> ignorableAbilities = {
  // Type immunities
  'Levitate', 'Flash Fire', 'Lightning Rod', 'Motor Drive',
  'Volt Absorb', 'Water Absorb', 'Sap Sipper', 'Storm Drain',
  'Dry Skin', 'Wonder Guard',
  // Move-based immunities
  'Soundproof', 'Bulletproof', 'Overcoat',
  // Damage reduction
  'Filter', 'Solid Rock', 'Prism Armor',
  'Multiscale', 'Shadow Shield',
  'Fur Coat', 'Ice Scales', 'Fluffy',
  'Thick Fat', 'Heatproof', 'Water Bubble', 'Purifying Salt',
  'Punk Rock',
  'Friend Guard',
  // Type immunities (missing from original list)
  'Earth Eater', 'Well-Baked Body',
  // Defensive stat boosts
  'Marvel Scale', 'Flower Gift', 'Grass Pelt',
  // Crit/accuracy (less relevant but ignorable)
  'Battle Armor', 'Shell Armor',
  'Sand Veil', 'Snow Cloak',
  // Stat protection
  'Clear Body', 'White Smoke', 'Full Metal Body',
  'Hyper Cutter', 'Big Pecks',
  // Damage nullification
  'Tera Shell', 'Ice Face', 'Disguise',
  // Other
  'Sturdy', 'Unaware', 'Wonder Skin',
  'Shield Dust', 'Damp',
};

/// Returns true if [defenderAbility] should be ignored because
/// the attacker has a Mold Breaker variant ability.
bool shouldIgnoreAbility(String? attackerAbility, String? defenderAbility) {
  if (defenderAbility == null) return false;
  if (!isMoldBreaker(attackerAbility)) return false;
  return ignorableAbilities.contains(defenderAbility);
}

// ====== Unaware (천진) ======

/// Returns the effective offensive rank considering Unaware and critical hits.
///
/// - Unaware (defender): resets attacker's offensive ranks to 0.
/// - Critical hit: clamps negative offensive ranks to 0.
/// - Mold Breaker on attacker ignores defender's Unaware.
Rank getEffectiveOffensiveRank({
  required Rank rank,
  required OffensiveStat offensiveStat,
  required bool isCritical,
  String? attackerAbility,
  String? defenderAbility,
}) {
  var r = rank;

  // Unaware: defender ignores attacker's offensive rank changes
  if (defenderAbility == 'Unaware' &&
      !shouldIgnoreAbility(attackerAbility, defenderAbility)) {
    r = Rank(
      attack: 0, defense: r.defense,
      spAttack: 0, spDefense: r.spDefense,
      speed: r.speed,
    );
  }

  // Critical hit: clamp negative offensive rank to 0
  if (isCritical) {
    r = Rank(
      attack: (offensiveStat == OffensiveStat.attack || offensiveStat == OffensiveStat.higherAttack)
          ? math.max(0, r.attack) : r.attack,
      defense: offensiveStat == OffensiveStat.defense
          ? math.max(0, r.defense) : r.defense,
      spAttack: (offensiveStat == OffensiveStat.spAttack || offensiveStat == OffensiveStat.higherAttack)
          ? math.max(0, r.spAttack) : r.spAttack,
      spDefense: r.spDefense,
      speed: r.speed,
    );
  }

  return r;
}

/// Returns the effective defensive rank considering Unaware and critical hits.
///
/// - Unaware (attacker): resets defender's defensive ranks to 0.
/// - Critical hit: clamps positive defensive ranks to 0.
Rank getEffectiveDefensiveRank({
  required Rank rank,
  required bool isCritical,
  String? attackerAbility,
  String? defenderAbility,
  bool ignoreDefRank = false,
}) {
  var r = rank;

  // Unaware: attacker ignores defender's defensive rank changes
  if (attackerAbility == 'Unaware') {
    r = Rank(
      attack: r.attack, defense: 0,
      spAttack: r.spAttack, spDefense: 0,
      speed: r.speed,
    );
  }

  // Sacred Sword / Chip Away / Darkest Lariat: ignore positive defense ranks
  // Critical hit: also clamp positive defense ranks to 0
  if (ignoreDefRank || isCritical) {
    r = Rank(
      attack: r.attack,
      defense: math.min(0, r.defense),
      spAttack: r.spAttack,
      spDefense: math.min(0, r.spDefense),
      speed: r.speed,
    );
  }

  return r;
}

// ====== Damage-phase ability modifiers ======

/// Returns a damage multiplier for defender abilities that activate
/// based on type effectiveness or HP conditions.
/// These are separate from bulk (stat) modifiers.
({double multiplier, String? note}) getDefensiveAbilityDamageModifier({
  required String? defenderAbility,
  required double effectiveness,
  required int defenderHpPercent,
  required bool moldBreaks,
}) {
  if (defenderAbility == null || moldBreaks) return (multiplier: 1.0, note: null);

  // Filter / Solid Rock / Prism Armor: super effective x0.75
  if (effectiveness > 1.0) {
    if (defenderAbility == 'Filter' || defenderAbility == 'Solid Rock' ||
        defenderAbility == 'Prism Armor') {
      return (multiplier: 0.75, note: 'ability:$defenderAbility:×0.75');
    }
  }

  // Multiscale / Shadow Shield: full HP x0.5
  if (defenderHpPercent >= 100) {
    if (defenderAbility == 'Multiscale' || defenderAbility == 'Shadow Shield') {
      return (multiplier: 0.5, note: 'ability:$defenderAbility:×0.5');
    }
  }

  return (multiplier: 1.0, note: null);
}

/// Returns a damage multiplier for attacker abilities that activate
/// based on type effectiveness.
({double multiplier, String? note}) getOffensiveAbilityDamageModifier({
  required String? attackerAbility,
  required double effectiveness,
}) {
  if (attackerAbility == null) return (multiplier: 1.0, note: null);

  // Tinted Lens: not very effective x2
  if (effectiveness < 1.0 && attackerAbility == 'Tinted Lens') {
    return (multiplier: 2.0, note: 'ability:Tinted Lens:×2.0');
  }

  // Neuroforce: super effective x1.25
  if (effectiveness > 1.0 && attackerAbility == 'Neuroforce') {
    return (multiplier: 1.25, note: 'ability:Neuroforce:×1.25');
  }

  return (multiplier: 1.0, note: null);
}

// ====== Ruins (재앙) ======

/// Returns stat multipliers from Ruin abilities.
///
/// Ruin abilities reduce the opponent's corresponding stat by 25% (x0.75):
/// - Tablets of Ruin (defender has): attacker's Attack x0.75
/// - Vessel of Ruin (defender has): attacker's Sp.Atk x0.75
/// - Sword of Ruin (attacker has): defender's Defense x0.75
/// - Beads of Ruin (attacker has): defender's Sp.Def x0.75
({double atkMod, double defMod, List<String> notes}) getRuinModifiers({
  required String? attackerAbility,
  required String? defenderAbility,
  required bool isPhysical,
}) {
  double atkMod = 1.0;
  double defMod = 1.0;
  final notes = <String>[];

  // Defender's Ruin abilities reduce attacker's offensive stat
  if (defenderAbility != null) {
    if (isPhysical && defenderAbility == 'Tablets of Ruin') {
      atkMod *= 0.75;
      notes.add('ability:Tablets of Ruin:공격 ×0.75');
    } else if (!isPhysical && defenderAbility == 'Vessel of Ruin') {
      atkMod *= 0.75;
      notes.add('ability:Vessel of Ruin:특공 ×0.75');
    }
  }

  // Attacker's Ruin abilities reduce defender's defensive stat
  if (attackerAbility != null) {
    if (isPhysical && attackerAbility == 'Sword of Ruin') {
      defMod *= 0.75;
      notes.add('ability:Sword of Ruin:방어 ×0.75');
    } else if (!isPhysical && attackerAbility == 'Beads of Ruin') {
      defMod *= 0.75;
      notes.add('ability:Beads of Ruin:특방 ×0.75');
    }
  }

  return (atkMod: atkMod, defMod: defMod, notes: notes);
}

// ====== Ability-based type changes ======

/// Returns the effective types for a Pokemon considering ability-based
/// type changes (e.g. Forecast, Protean).
///
/// Returns null if the ability doesn't change the type.
({PokemonType type1, PokemonType? type2})? getAbilityTypeOverride({
  required String? ability,
  required String pokemonName,
  required Weather weather,
  Terrain terrain = Terrain.none,
  String? heldItem,
}) {
  if (ability == null) return null;

  // Forecast: Castform only
  if (ability == 'Forecast' && pokemonName.toLowerCase().contains('castform')) {
    switch (weather) {
      case Weather.sun:
      case Weather.harshSun:
        return (type1: PokemonType.fire, type2: null);
      case Weather.rain:
      case Weather.heavyRain:
        return (type1: PokemonType.water, type2: null);
      case Weather.snow:
        return (type1: PokemonType.ice, type2: null);
      default:
        return (type1: PokemonType.normal, type2: null);
    }
  }

  // Mimicry: type changes based on terrain
  if (ability == 'Mimicry' && terrain != Terrain.none) {
    switch (terrain) {
      case Terrain.electric:
        return (type1: PokemonType.electric, type2: null);
      case Terrain.grassy:
        return (type1: PokemonType.grass, type2: null);
      case Terrain.misty:
        return (type1: PokemonType.fairy, type2: null);
      case Terrain.psychic:
        return (type1: PokemonType.psychic, type2: null);
      default:
        return null;
    }
  }

  // Multitype (Arceus): type changes based on held Plate
  if (ability == 'Multitype' && heldItem != null) {
    const plateTypes = {
      'flame-plate': PokemonType.fire, 'splash-plate': PokemonType.water,
      'meadow-plate': PokemonType.grass, 'zap-plate': PokemonType.electric,
      'icicle-plate': PokemonType.ice, 'fist-plate': PokemonType.fighting,
      'toxic-plate': PokemonType.poison, 'earth-plate': PokemonType.ground,
      'sky-plate': PokemonType.flying, 'mind-plate': PokemonType.psychic,
      'insect-plate': PokemonType.bug, 'stone-plate': PokemonType.rock,
      'spooky-plate': PokemonType.ghost, 'draco-plate': PokemonType.dragon,
      'dread-plate': PokemonType.dark, 'iron-plate': PokemonType.steel,
      'pixie-plate': PokemonType.fairy,
    };
    final t = plateTypes[heldItem];
    if (t != null) return (type1: t, type2: null);
  }

  // RKS System (Silvally): type changes based on held Memory
  if (ability == 'RKS System' && heldItem != null && heldItem.endsWith('-memory')) {
    final typeName = heldItem.substring(0, heldItem.length - '-memory'.length);
    for (final t in PokemonType.values) {
      if (t.name == typeName) return (type1: t, type2: null);
    }
  }

  return null;
}

// ====== Aura abilities ======

/// Aura boost/nerf value
const double kAuraBoost = 4 / 3; // ~1.3333
const double kAuraNerfed = 3 / 4; // 0.75

/// Returns the damage modifier from aura interaction in damage calculation.
///
/// 결정력 already includes attacker's own aura (x1.33).
/// This handles the defender's side only:
///
/// - Attacker has no aura → defender's aura applies (x1.33)
/// - Attacker has same aura as defender → skip (already in 결정력)
/// - Attacker has aura, defender has different aura → apply defender's aura
/// - Attacker has aura, defender has Aura Break → reverse attacker's aura
///   (결정력 had x1.33, correct to x0.75 → multiply by 0.75/1.33)
({double multiplier, String? note}) getAuraModifier({
  required PokemonType moveType,
  required String? attackerAbility,
  required String? defenderAbility,
}) {
  final bool atkHasMatchingAura =
      (attackerAbility == 'Fairy Aura' && moveType == PokemonType.fairy) ||
      (attackerAbility == 'Dark Aura' && moveType == PokemonType.dark);

  final bool defHasMatchingAura =
      (defenderAbility == 'Fairy Aura' && moveType == PokemonType.fairy) ||
      (defenderAbility == 'Dark Aura' && moveType == PokemonType.dark);

  final bool defHasAuraBreak = defenderAbility == 'Aura Break';

  // Case 1: Attacker has no aura → apply defender's aura
  if (!atkHasMatchingAura) {
    if (defHasMatchingAura) {
      return (multiplier: kAuraBoost, note: 'ability:$defenderAbility:×1.33');
    }
    return (multiplier: 1.0, note: null);
  }

  // Case 2: Attacker has aura
  if (defHasMatchingAura) {
    // Same aura → already in 결정력, skip
    return (multiplier: 1.0, note: null);
  }

  if (defHasAuraBreak) {
    // Aura Break reverses: 결정력 had x1.33, should be x0.75
    // Correction = 0.75 / 1.33 = kAuraNerfed / kAuraBoost
    return (
      multiplier: kAuraNerfed / kAuraBoost,
      note: 'ability:Aura Break:×0.75',
    );
  }

  // Defender has unrelated ability → no additional modifier
  return (multiplier: 1.0, note: null);
}
