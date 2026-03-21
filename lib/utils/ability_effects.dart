import '../models/gender.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';

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

  const AbilityEffect({
    this.statModifiers = const AbilityStatModifiers(),
    this.powerModifier = 1.0,
    this.stabOverride,
    this.criticalOverride,
  });
}

const _defaultEffect = AbilityEffect();

/// Returns the offensive effect of [abilityName] given the [move] being used.
AbilityEffect getAbilityEffect(String abilityName, {
  Move? move,
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
        statModifiers: AbilityStatModifiers(attack: 2.0));
    case 'Gorilla Tactics':
      return const AbilityEffect(
        statModifiers: AbilityStatModifiers(attack: 1.5));
    case 'Hustle':
      return const AbilityEffect(
        statModifiers: AbilityStatModifiers(attack: 1.5));

    // --- Normalize: 1.2x to all Normal-type moves (type change is in move_transform) ---
    case 'Normalize':
      return move != null && move.type == PokemonType.normal
          ? const AbilityEffect(powerModifier: 1.2)
          : _defaultEffect;

    // --- Tag-based power modifiers ---
    case 'Tough Claws':
      return move != null && move.hasTag(MoveTags.contact)
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Iron Fist':
      return move != null && move.hasTag(MoveTags.punch)
          ? const AbilityEffect(powerModifier: 1.2)
          : _defaultEffect;
    case 'Reckless':
      return move != null && move.hasTag(MoveTags.recoil)
          ? const AbilityEffect(powerModifier: 1.2)
          : _defaultEffect;
    case 'Strong Jaw':
      return move != null && move.hasTag(MoveTags.bite)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Mega Launcher':
      return move != null && move.hasTag(MoveTags.pulse)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Sharpness':
      return move != null && move.hasTag(MoveTags.slice)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Technician':
      return move != null && move.power <= 60
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;

    // --- STAB override ---
    case 'Adaptability':
      return const AbilityEffect(stabOverride: 2.0);

    // --- Type-based power modifiers ---
    case 'Steelworker':
      return move != null && move.type == PokemonType.steel
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Transistor':
      return move != null && move.type == PokemonType.electric
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case "Dragon\u2019s Maw":
      return move != null && move.type == PokemonType.dragon
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Rocky Payload':
      return move != null && move.type == PokemonType.rock
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;

    // --- Weather/Terrain stat modifiers ---
    case 'Solar Power':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: 1.5))
          : _defaultEffect;
    case 'Sand Force':
      return (weather == Weather.sandstorm && move != null &&
              (move.type == PokemonType.ground ||
               move.type == PokemonType.rock ||
               move.type == PokemonType.steel))
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Orichalcum Pulse':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: 1.3))
          : _defaultEffect;
    case 'Hadron Engine':
      return terrain == Terrain.electric
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: 1.3))
          : _defaultEffect;
    case 'Flower Gift':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: 1.5, spDefense: 1.5))
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
      return (hpPercent <= 33 && move != null && move.type == PokemonType.fire)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Overgrow':
      return (hpPercent <= 33 && move != null && move.type == PokemonType.grass)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Torrent':
      return (hpPercent <= 33 && move != null && move.type == PokemonType.water)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Swarm':
      return (hpPercent <= 33 && move != null && move.type == PokemonType.bug)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;

    // --- Other power modifiers ---
    case 'Water Bubble':
      return move != null && move.type == PokemonType.water
          ? const AbilityEffect(powerModifier: 2.0)
          : _defaultEffect;
    case 'Punk Rock':
      return move != null && move.hasTag(MoveTags.sound)
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Sheer Force':
      return move != null && move.hasTag(MoveTags.hasSecondary)
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;

    // --- Parental Bond (Mega Kangaskhan) ---
    case 'Parental Bond':
      // 1.0x + 0.25x = 1.25x total for single-target moves
      // Does not activate on multi-hit moves
      if (move != null && _isMultiHit(move)) return _defaultEffect;
      return const AbilityEffect(powerModifier: 1.25);

    // --- Critical override ---
    case 'Sniper':
      return const AbilityEffect(criticalOverride: 2.25);

    // --- Status conditional ---
    case 'Guts':
      return status != StatusCondition.none
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: 1.5))
          : _defaultEffect;
    case 'Toxic Boost':
      return (status == StatusCondition.poison || status == StatusCondition.badlyPoisoned)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: 1.5))
          : _defaultEffect;
    case 'Flare Boost':
      return status == StatusCondition.burn
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: 1.5))
          : _defaultEffect;

    // --- Speed conditional ---
    case 'Analytic':
      if (actualStats != null && opponentSpeed != null &&
          actualStats.speed < opponentSpeed) {
        return const AbilityEffect(powerModifier: 1.3);
      }
      return _defaultEffect;

    // --- Gender conditional ---
    case 'Rivalry':
      final hasGender = myGender == Gender.male || myGender == Gender.female;
      final oppHasGender = opponentGender == Gender.male || opponentGender == Gender.female;
      if (hasGender && oppHasGender) {
        if (myGender == opponentGender) {
          return const AbilityEffect(powerModifier: 1.25);
        } else {
          return const AbilityEffect(powerModifier: 0.75);
        }
      }
      return _defaultEffect;

    // --- Speed stat modifiers ---
    case 'Swift Swim':
      return (weather == Weather.rain || weather == Weather.heavyRain)
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: 2.0))
          : _defaultEffect;
    case 'Chlorophyll':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: 2.0))
          : _defaultEffect;
    case 'Sand Rush':
      return weather == Weather.sandstorm
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: 2.0))
          : _defaultEffect;
    case 'Slush Rush':
      return weather == Weather.snow
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: 2.0))
          : _defaultEffect;
    case 'Surge Surfer':
      return terrain == Terrain.electric
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: 2.0))
          : _defaultEffect;
    case 'Quick Feet':
      return status != StatusCondition.none
          ? const AbilityEffect(statModifiers: AbilityStatModifiers(speed: 1.5))
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
}) {
  switch (abilityName) {
    case 'Fur Coat':
      return const DefensiveAbilityEffect(defModifier: 2.0);
    case 'Ice Scales':
      return const DefensiveAbilityEffect(spdModifier: 2.0);
    case 'Fluffy':
      return const DefensiveAbilityEffect(defModifier: 2.0);
    case 'Marvel Scale':
      return status != StatusCondition.none
          ? const DefensiveAbilityEffect(defModifier: 1.5)
          : _defaultDefensiveEffect;
    default:
      return _defaultDefensiveEffect;
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
}) {
  return getAbilityEffect(abilityName,
    weather: weather, terrain: terrain, status: status,
  ).statModifiers.speed;
}

/// Determine which stat is highest and boost it by 1.3x (1.5x for speed)
/// Multi-hit moves that don't trigger Parental Bond.
const _multiHitMoves = {
  'Bullet Seed', 'Icicle Spear', 'Rock Blast', 'Pin Missile', 'Tail Slap',
  'Scale Shot', 'Population Bomb', 'Bone Rush', 'Arm Thrust', 'Barrage',
  'Comet Punch', 'Double Slap', 'Fury Attack', 'Fury Swipes', 'Spike Cannon',
  'Water Shuriken', 'Triple Axel', 'Triple Kick', 'Triple Dive',
  'Surging Strikes', 'Double Hit', 'Double Iron Bash', 'Dragon Darts',
  'Dual Wingbeat', 'Twineedle',
};

bool _isMultiHit(Move move) => _multiHitMoves.contains(move.name);

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

  // Speed gets 1.5x, others get 1.3x
  switch (highest) {
    case 'attack':
      return const AbilityStatModifiers(attack: 1.3);
    case 'defense':
      return const AbilityStatModifiers(defense: 1.3);
    case 'spAttack':
      return const AbilityStatModifiers(spAttack: 1.3);
    case 'spDefense':
      return const AbilityStatModifiers(spDefense: 1.3);
    case 'speed':
      return const AbilityStatModifiers(speed: 1.5);
    default:
      return const AbilityStatModifiers();
  }
}
