import '../models/room.dart';
import '../models/stats.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import '../models/type.dart';
import '../models/status.dart';
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
    bool finalEvo = true,
    StatusCondition status = StatusCondition.none,
    bool flowerGift = false,
    RoomConditions room = const RoomConditions(),
    bool isDynamaxed = false,
  }) {
    // Wonder Room: swap base Defense and Sp.Def before stat calculation.
    // Rank changes stay on their original stat (not swapped).
    final effectiveBaseStats = room.wonderRoom
        ? Stats(
            hp: baseStats.hp, attack: baseStats.attack,
            defense: baseStats.spDefense, spAttack: baseStats.spAttack,
            spDefense: baseStats.defense, speed: baseStats.speed,
          )
        : baseStats;

    final actualStats = StatCalculator.calculate(
      baseStats: effectiveBaseStats,
      iv: iv,
      ev: ev,
      nature: nature,
      level: level,
      rank: rank,
    );

    // Stat modifiers: applied to individual def/spd stats before HP multiplication
    final weatherMod = getWeatherDefensiveModifier(
      weather, type1: type1, type2: type2,
    );
    double defStatMod = weatherMod.defMod;
    double spdStatMod = weatherMod.spdMod;

    // Ability (modifies the stat itself)
    if (ability != null) {
      final abilityEffect = getDefensiveAbilityEffect(ability, status: status);
      defStatMod *= abilityEffect.defModifier;
      spdStatMod *= abilityEffect.spdModifier;
    }

    // Item (modifies the stat itself)
    if (item != null) {
      final itemEffect = getDefensiveItemEffect(item, finalEvo: finalEvo);
      defStatMod *= itemEffect.defModifier;
      spdStatMod *= itemEffect.spdModifier;
    }

    // Flower Gift (sun/harsh sun: SpDef x1.5 - stat modifier)
    if (flowerGift &&
        (weather == Weather.sun || weather == Weather.harshSun)) {
      spdStatMod *= 1.5;
    }

    // Calculate bulk: HP * modified stat
    final int effectiveDef = (actualStats.defense * defStatMod).floor();
    final int effectiveSpd = (actualStats.spDefense * spdStatMod).floor();
    final int effectiveHp = isDynamaxed ? actualStats.hp * 2 : actualStats.hp;

    return (
      physical: (effectiveHp * effectiveDef / _correctionFactor).floor(),
      special: (effectiveHp * effectiveSpd / _correctionFactor).floor(),
    );
  }
}
