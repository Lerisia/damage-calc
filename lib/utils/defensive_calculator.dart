import '../models/room.dart';
import '../models/stats.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'item_effects.dart';
import 'stat_calculator.dart';
import 'weather_effects.dart';

/// Calculates defensive bulk (내구) as HP * Defense / 0.411.
///
/// The 0.411 correction factor comes from the damage formula,
/// making bulk values directly comparable to 결정력 (offensive power).
class DefensiveCalculator {
  static const double _correctionFactor = 0.411;
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
    String? item,
    String? pokemonName,
    bool finalEvo = true,
    StatusCondition status = StatusCondition.none,
    Terrain terrain = Terrain.none,
    RoomConditions room = const RoomConditions(),
    bool isDynamaxed = false,
  }) {
    final calculatedStats = StatCalculator.calculate(
      baseStats: baseStats,
      iv: iv,
      ev: ev,
      nature: nature,
      level: level,
      rank: rank,
    );

    // Wonder Room: swap the final calculated Defense and Sp.Def values.
    final actualStats = room.wonderRoom
        ? Stats(
            hp: calculatedStats.hp, attack: calculatedStats.attack,
            defense: calculatedStats.spDefense, spAttack: calculatedStats.spAttack,
            spDefense: calculatedStats.defense, speed: calculatedStats.speed,
          )
        : calculatedStats;

    // Stat modifiers: applied to individual def/spd stats before HP multiplication
    final weatherMod = getWeatherDefensiveModifier(
      weather, type1: type1, type2: type2,
    );
    double defStatMod = weatherMod.defMod;
    double spdStatMod = weatherMod.spdMod;

    // Ability (modifies the stat itself)
    if (ability != null) {
      final abilityEffect = getDefensiveAbilityEffect(ability, status: status, weather: weather, terrain: terrain);
      defStatMod *= abilityEffect.defModifier;
      spdStatMod *= abilityEffect.spdModifier;
    }

    // Item (modifies the stat itself)
    if (item != null) {
      final itemEffect = getDefensiveItemEffect(item, finalEvo: finalEvo, pokemonName: pokemonName);
      defStatMod *= itemEffect.defModifier;
      spdStatMod *= itemEffect.spdModifier;
    }

    // Calculate bulk: HP * modified stat
    final int effectiveDef = (actualStats.defense * defStatMod).floor();
    final int effectiveSpd = (actualStats.spDefense * spdStatMod).floor();
    final int effectiveHp = isDynamaxed ? actualStats.hp * 2 : actualStats.hp;

    final phys = effectiveHp * effectiveDef / _correctionFactor;
    final spec = effectiveHp * effectiveSpd / _correctionFactor;
    return (
      physical: phys.isFinite ? phys.floor() : 0,
      special: spec.isFinite ? spec.floor() : 0,
    );
  }
}
