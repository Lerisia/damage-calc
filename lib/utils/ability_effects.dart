import '../models/move.dart';
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
      return move.hasTag('contact')
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Iron Fist':
      return move.hasTag('punch')
          ? const AbilityEffect(powerModifier: 1.2)
          : _defaultEffect;
    case 'Reckless':
      return move.hasTag('recoil')
          ? const AbilityEffect(powerModifier: 1.2)
          : _defaultEffect;
    case 'Strong Jaw':
      return move.hasTag('bite')
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Mega Launcher':
      return move.hasTag('pulse')
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Sharpness':
      return move.hasTag('slice')
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
    case "Dragon's Maw":
      return move.type == PokemonType.dragon
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;
    case 'Rocky Payload':
      return move.type == PokemonType.rock
          ? const AbilityEffect(powerModifier: 1.5)
          : _defaultEffect;

    // --- Weather/Terrain stat modifiers ---
    case 'Solar Power':
      return weather == Weather.sun
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
      return weather == Weather.sun
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: 1.3))
          : _defaultEffect;
    case 'Hadron Engine':
      return terrain == Terrain.electric
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(spAttack: 1.3))
          : _defaultEffect;
    case 'Flower Gift':
      return weather == Weather.sun
          ? const AbilityEffect(
              statModifiers: AbilityStatModifiers(attack: 1.5, spDefense: 1.5))
          : _defaultEffect;

    // --- Protosynthesis / Quark Drive ---
    case 'Protosynthesis':
      return weather == Weather.sun && actualStats != null
          ? AbilityEffect(statModifiers: _boostHighestStat(actualStats))
          : _defaultEffect;
    case 'Quark Drive':
      return terrain == Terrain.electric && actualStats != null
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
      return move.hasTag('sound')
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Sheer Force':
      return move.hasTag('custom:has_secondary')
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

    default:
      return _defaultEffect;
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
