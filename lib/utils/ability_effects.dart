import '../models/move.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';

/// Offensive modifiers returned by an ability
class AbilityEffect {
  final double statModifier;
  final double powerModifier;
  final double? stabOverride;
  final double? criticalOverride;

  const AbilityEffect({
    this.statModifier = 1.0,
    this.powerModifier = 1.0,
    this.stabOverride,
    this.criticalOverride,
  });
}

const _defaultEffect = AbilityEffect();

/// Returns the offensive effect of [abilityName] given the [move] being used.
///
/// Abilities that don't affect offensive power return default modifiers (1.0, 1.0).
AbilityEffect getAbilityEffect(String abilityName, {
  required Move move,
  int hpPercent = 100,
  Weather weather = Weather.none,
  Terrain terrain = Terrain.none,
}) {
  switch (abilityName) {
    // --- Stat modifiers ---
    case 'Huge Power':
    case 'Pure Power':
      return move.category == MoveCategory.physical
          ? const AbilityEffect(statModifier: 2.0)
          : _defaultEffect;
    case 'Gorilla Tactics':
      return move.category == MoveCategory.physical
          ? const AbilityEffect(statModifier: 1.5)
          : _defaultEffect;
    case 'Hustle':
      return move.category == MoveCategory.physical
          ? const AbilityEffect(statModifier: 1.5)
          : _defaultEffect;

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

    // --- Weather/Terrain conditional ---
    case 'Solar Power':
      return (weather == Weather.sun && move.category == MoveCategory.special)
          ? const AbilityEffect(statModifier: 1.5)
          : _defaultEffect;
    case 'Sand Force':
      return (weather == Weather.sandstorm &&
              (move.type == PokemonType.ground ||
               move.type == PokemonType.rock ||
               move.type == PokemonType.steel))
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    case 'Orichalcum Pulse':
      return (weather == Weather.sun && move.category == MoveCategory.physical)
          ? const AbilityEffect(statModifier: 1.3)
          : _defaultEffect;
    case 'Hadron Engine':
      return (terrain == Terrain.electric && move.category == MoveCategory.special)
          ? const AbilityEffect(statModifier: 1.3)
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

    default:
      return _defaultEffect;
  }
}
