import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/calc/ability_effects.dart';
import 'package:damage_calc/calc/aura_effects.dart';
import 'package:damage_calc/calc/battle_facade.dart';
import 'package:damage_calc/calc/damage_calculator.dart';
import 'package:damage_calc/calc/doubles_effects.dart';
import 'package:damage_calc/calc/item_effects.dart';
import 'package:damage_calc/calc/terrain_effects.dart';

/// 결정력 convention (decided 2026-09-12): every multiplier is the
/// game's 4096-fixed-point value, used verbatim — Life Orb is
/// 5324/4096, terrain / Tough Claws / gems are 5325/4096, type items
/// are 4915/4096 — not the rounded "1.3" / "1.2" people write by hand.
/// Before this, Life Orb alone was fp-exact while terrain was a flat
/// 1.3, so a user's hand calculation (88 522) and the app (88 508)
/// disagreed by exactly the Life Orb rounding. Every offense-side
/// multiplier must therefore be an integer over 4096.
void main() {
  const fire = Move(name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
      type: PokemonType.fire, category: MoveCategory.special, power: 90, accuracy: 100, pp: 15);
  const punch = Move(name: 'Ice Punch', nameKo: '냉동펀치', nameJa: 'れいとうパンチ',
      type: PokemonType.ice, category: MoveCategory.physical, power: 75, accuracy: 100, pp: 15,
      tags: [MoveTags.contact, MoveTags.punch]);
  const normal = Move(name: 'Return', nameKo: '은혜갚기', nameJa: 'おんがえし',
      type: PokemonType.normal, category: MoveCategory.physical, power: 102, accuracy: 100, pp: 20,
      tags: [MoveTags.contact]);
  const electric = Move(name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
      type: PokemonType.electric, category: MoveCategory.special, power: 90, accuracy: 100, pp: 15);
  const psychic = Move(name: 'Psychic', nameKo: '사이코키네시스', nameJa: 'サイコキネシス',
      type: PokemonType.psychic, category: MoveCategory.special, power: 90, accuracy: 100, pp: 10);
  const dragon = Move(name: 'Dragon Pulse', nameKo: '용의파동', nameJa: 'りゅうのはどう',
      type: PokemonType.dragon, category: MoveCategory.special, power: 85, accuracy: 100, pp: 10);
  const grass = Move(name: 'Energy Ball', nameKo: '에너지볼', nameJa: 'エナジーボール',
      type: PokemonType.grass, category: MoveCategory.special, power: 90, accuracy: 100, pp: 10);

  final multipliers = <String, double>{
    'terrain electric': getTerrainModifier(Terrain.electric, move: electric),
    'terrain grassy': getTerrainModifier(Terrain.grassy, move: grass),
    'terrain psychic': getTerrainModifier(Terrain.psychic, move: psychic),
    'power spot': kPowerSpotMultiplier,
    'battery': kBatteryMultiplier,
    'life orb': kLifeOrbPower,
    'muscle band': kBandGlassesPower,
    'punching glove': kPunchingGlovePower,
    'normal gem': getItemEffect('normal-gem', move: normal).powerModifier,
    'charcoal': getItemEffect('charcoal', move: fire).powerModifier,
    'adamant orb': getItemEffect('adamant-orb', move: dragon, pokemonName: 'Dialga').powerModifier,
    'tough claws': getAbilityEffect('Tough Claws', move: punch).powerModifier,
    'iron fist': getAbilityEffect('Iron Fist', move: punch).powerModifier,
    'transistor': getAbilityEffect('Transistor', move: electric).statModifiers.spAttack,
    'sheer force': getAbilityEffect('Sheer Force', move: punch).powerModifier,
    for (var n = 1; n <= 5; n++)
      'supreme overlord $n': getAbilityEffect('Supreme Overlord $n', move: punch).powerModifier,
    'stellar non-matching stab': kStellarStabNonMatching,
    'aura': kAuraBoost,
    'collision course': kCollisionCourseBoost,
  };

  for (final entry in multipliers.entries) {
    test('${entry.key} is an exact 4096-fp multiplier', () {
      final scaled = entry.value * 4096;
      expect(scaled, scaled.roundToDouble(),
          reason: '${entry.key} = ${entry.value} is not k/4096');
    });
  }

  test('Supreme Overlord is 4096 + 410 per fainted ally', () {
    for (var n = 1; n <= 5; n++) {
      expect(getAbilityEffect('Supreme Overlord $n', move: punch).powerModifier,
          (4096 + 410 * n) / 4096);
    }
  });

  test('Espathra Expanding Force: fp-exact Life Orb AND terrain', () {
    const ef = Move(name: 'Expanding Force', nameKo: '와이드포스', nameJa: 'ワイドフォース',
        type: PokemonType.psychic, category: MoveCategory.special, power: 80, accuracy: 100, pp: 10,
        tags: ['custom:terrain_boost_psychic']);
    final esp = BattlePokemonState(
        pokemonName: 'Espathra', type1: PokemonType.psychic,
        baseStats: const Stats(hp: 95, attack: 60, defense: 60, spAttack: 101, spDefense: 60, speed: 105),
        selectedAbility: 'Opportunist',
        nature: const NatureProfile(up: NatureStat.spa, down: NatureStat.atk),
        selectedItem: 'life-orb', helpingHand: true,
        iv: const Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31),
        ev: const Stats(hp: 0, attack: 0, defense: 0, spAttack: 252, spDefense: 0, speed: 0),
        moves: [ef, null, null, null]);
    final v = BattleFacade.calcOffensivePower(state: esp, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.psychic, room: const RoomConditions());
    // 168 × 120 × 1.5 (STAB) × 5325/4096 (terrain) × 5324/4096 (Life
    // Orb) × 1.5 (Helping Hand) = 76 649.76 → 76 649.
    expect(v, 76649);
  });
}
