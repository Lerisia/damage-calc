import '../models/move.dart' show MoveCategory;
import '../models/room.dart';
import '../models/stats.dart';
import '../models/nature_profile.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'item_effects.dart';
import 'ruin_effects.dart';
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
    required NatureProfile nature,
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
    RuinState ruinState = RuinState.inactive,
    bool allyFlowerGift = false,
    bool allyFriendGuard = false,
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
      final abilityEffect = getDefensiveAbilityEffect(ability, status: status, weather: weather, terrain: terrain,
        heldItem: item, actualStats: actualStats);
      defStatMod *= abilityEffect.defModifier;
      spdStatMod *= abilityEffect.spdModifier;
    }

    // Item (modifies the stat itself)
    if (item != null) {
      final itemEffect = getDefensiveItemEffect(item, finalEvo: finalEvo, pokemonName: pokemonName);
      defStatMod *= itemEffect.defModifier;
      spdStatMod *= itemEffect.spdModifier;
    }

    // Flower Gift (ally Cherrim, in Sun): Sp.Def × 1.5.
    final bool isSun = weather == Weather.sun || weather == Weather.harshSun;
    if (allyFlowerGift && isSun) {
      spdStatMod *= 1.5;
    }

    // Calculate bulk: HP * modified stat
    int effectiveDef = (actualStats.defense * defStatMod).floor();
    int effectiveSpd = (actualStats.spDefense * spdStatMod).floor();

    // Ruin field effect on defensive stats (self-exempt handled inside).
    // Only `defMod` matters here — `atkMod`/category are unused on the
    // defensive side, so we pass a stub category.
    final ruinPhys = getRuinEffect(
      attackerAbility: null, defenderAbility: ability,
      category: MoveCategory.physical, targetPhysDef: true, state: ruinState,
    );
    final ruinSpec = getRuinEffect(
      attackerAbility: null, defenderAbility: ability,
      category: MoveCategory.special, targetPhysDef: false, state: ruinState,
    );
    effectiveDef = (effectiveDef * ruinPhys.defMod).floor();
    effectiveSpd = (effectiveSpd * ruinSpec.defMod).floor();

    final int effectiveHp = isDynamaxed ? actualStats.hp * 2 : actualStats.hp;

    // Friend Guard (ally's ability) — incoming damage × 0.75, so the
    // effective bulk (damage the mon can eat) scales by 1/0.75.
    final double friendGuardBulkMod = allyFriendGuard ? 1.0 / 0.75 : 1.0;

    final phys = effectiveHp * effectiveDef / _correctionFactor * friendGuardBulkMod;
    final spec = effectiveHp * effectiveSpd / _correctionFactor * friendGuardBulkMod;
    return (
      physical: phys.isFinite ? phys.floor() : 0,
      special: spec.isFinite ? spec.floor() : 0,
    );
  }
}
