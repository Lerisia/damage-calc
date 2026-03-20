import '../models/stats.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/status.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'stat_calculator.dart';
import 'weather_effects.dart';

/// Calculates defensive bulk (내구) as HP * Defense or HP * SpDefense.
class DefensiveCalculator {
  static ({int physical, int special}) calculate({
    required Stats baseStats,
    required Stats iv,
    required Stats ev,
    required Nature nature,
    required int level,
    required PokemonType type1,
    PokemonType? type2,
    Rank rank = const Rank(),
    Weather weather = Weather.none,
    String? ability,
    StatusCondition status = StatusCondition.none,
    bool reflect = false,
    bool lightScreen = false,
    bool auroraVeil = false,
    bool friendGuard = false,
    bool flowerGift = false,
  }) {
    final actualStats = StatCalculator.calculate(
      baseStats: baseStats,
      iv: iv,
      ev: ev,
      nature: nature,
      level: level,
      rank: rank,
    );

    final weatherMod = getWeatherDefensiveModifier(
      weather, type1: type1, type2: type2,
    );
    double defMod = weatherMod.defMod;
    double spdMod = weatherMod.spdMod;

    // Ability
    if (ability != null) {
      final abilityEffect = getDefensiveAbilityEffect(ability, status: status);
      defMod *= abilityEffect.defModifier;
      spdMod *= abilityEffect.spdModifier;
    }

    // Screens
    if (reflect || auroraVeil) defMod *= 2.0;
    if (lightScreen || auroraVeil) spdMod *= 2.0;

    // Friend Guard (damage x0.75 = bulk x4/3)
    if (friendGuard) {
      defMod *= 4.0 / 3.0;
      spdMod *= 4.0 / 3.0;
    }

    // Flower Gift (sun/harsh sun: SpDef x1.5)
    if (flowerGift &&
        (weather == Weather.sun || weather == Weather.harshSun)) {
      spdMod *= 1.5;
    }

    return (
      physical: (actualStats.hp * actualStats.defense * defMod).floor(),
      special: (actualStats.hp * actualStats.spDefense * spdMod).floor(),
    );
  }
}
