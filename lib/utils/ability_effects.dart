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
  required Move move,
  int hpPercent = 100,
  Weather weather = Weather.none,
  Terrain terrain = Terrain.none,
  StatusCondition status = StatusCondition.none,
  Stats? actualStats,
  String? heldItem,
  int? opponentSpeed,
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

    // --- Tag-based power modifiers ---
    case 'Tough Claws':
      return move.hasTag(MoveTags.contact)
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Iron Fist':
      return move.hasTag(MoveTags.punch)
          ? const AbilityEffect(powerModifier: 1.2)
          : _defaultEffect;
    case 'Reckless':
      return move.hasTag(MoveTags.recoil)
          ? const AbilityEffect(powerModifier: 1.2)
          : _defaultEffect;
    case 'Strong Jaw':
      return move.hasTag(MoveTags.bite)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Mega Launcher':
      return move.hasTag(MoveTags.pulse)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Sharpness':
      return move.hasTag(MoveTags.slice)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Technician':
      return move.power <= 60
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;

    // --- STAB override ---
    case 'Adaptability':
      return const AbilityEffect(stabOverride: 2.0);

    // --- Type-based power modifiers ---
    case 'Steelworker':
      return move.type == PokemonType.steel
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Transistor':
      return move.type == PokemonType.electric
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case "Dragon\u2019s Maw":
      return move.type == PokemonType.dragon
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Rocky Payload':
      return move.type == PokemonType.rock
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;

    // --- Weather/Terrain stat modifiers ---
    case 'Solar Power':
      return (weather == Weather.sun || weather == Weather.harshSun)
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: 1.5))
          : _defaultEffect;
    case 'Sand Force':
      return (weather == Weather.sandstorm &&
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
      return (hpPercent <= 33 && move.type == PokemonType.fire)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Overgrow':
      return (hpPercent <= 33 && move.type == PokemonType.grass)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Torrent':
      return (hpPercent <= 33 && move.type == PokemonType.water)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Swarm':
      return (hpPercent <= 33 && move.type == PokemonType.bug)
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;

    // --- Other power modifiers ---
    case 'Water Bubble':
      return move.type == PokemonType.water
          ? const AbilityEffect(powerModifier: 2.0)
          : _defaultEffect;
    case 'Punk Rock':
      return move.hasTag(MoveTags.sound)
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Sheer Force':
      return move.hasTag(MoveTags.hasSecondary)
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;

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

/// Determine which stat is highest and boost it by 1.3x (1.5x for speed)
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
