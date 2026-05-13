// Multi-hit comparison harness. Reads /tmp/scenarios_multihit.json
// produced by tools/showdown-compare/gen_multihit.mjs and replays
// each scenario through DamageCalculator, comparing the per-hit
// 16-roll arrays against @smogon/calc's 2-D damage spread.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/damage_calculator.dart';
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/aura_effects.dart';
import 'package:damage_calc/utils/ruin_effects.dart';
import 'package:damage_calc/utils/battle_facade.dart';
import 'package:damage_calc/utils/stat_calculator.dart';

const _weatherMap = {
  'Sun': Weather.sun,
  'Rain': Weather.rain,
  'Sand': Weather.sandstorm,
  'Snow': Weather.snow,
};
const _terrainMap = {
  'Electric': Terrain.electric,
  'Grassy': Terrain.grassy,
  'Misty': Terrain.misty,
  'Psychic': Terrain.psychic,
};
const _teraTypeMap = {
  'Normal': PokemonType.normal,'Fire': PokemonType.fire,'Water': PokemonType.water,
  'Electric': PokemonType.electric,'Grass': PokemonType.grass,'Ice': PokemonType.ice,
  'Fighting': PokemonType.fighting,'Poison': PokemonType.poison,'Ground': PokemonType.ground,
  'Flying': PokemonType.flying,'Psychic': PokemonType.psychic,'Bug': PokemonType.bug,
  'Rock': PokemonType.rock,'Ghost': PokemonType.ghost,'Dragon': PokemonType.dragon,
  'Dark': PokemonType.dark,'Steel': PokemonType.steel,'Fairy': PokemonType.fairy,
};
const _natureMap = {
  'Adamant': Nature.adamant,'Modest': Nature.modest,'Jolly': Nature.jolly,
  'Timid': Nature.timid,'Bold': Nature.bold,'Calm': Nature.calm,
  'Impish': Nature.impish,'Careful': Nature.careful,'Hardy': Nature.hardy,
  'Naughty': Nature.naughty,
};
String _itemSlug(String name) => name.isEmpty
    ? '' : name.toLowerCase().replaceAll(' ', '-');

void main() {
  test('Showdown multi-hit compare', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moveMap = await loadMovedex();
    final pokemonByName = {for (final p in pokedex) p.name: p};

    final scenarios = (jsonDecode(
        File('/tmp/scenarios_multihit.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    int total = 0, matched = 0;
    final diffs = <String>[];

    for (final s in scenarios) {
      total++;
      final atkP = pokemonByName[s['atkSpec']];
      final defP = pokemonByName[s['defSpec']];
      final move = moveMap[s['move']];
      if (atkP == null || defP == null || move == null) {
        diffs.add('SKIP missing: ${s['atkSpec']} / ${s['defSpec']} / ${s['move']}');
        continue;
      }
      final hits = s['hits'] as int;
      final atk = BattlePokemonState()
        ..applyPokemon(atkP)
        ..ev = Stats(
            hp: s['evs']['hp'] as int, attack: s['evs']['atk'] as int,
            defense: s['evs']['def'] as int, spAttack: s['evs']['spa'] as int,
            spDefense: s['evs']['spd'] as int, speed: s['evs']['spe'] as int)
        ..nature = NatureProfile.fromNature(_natureMap[s['nature']]!)
        ..rank = Rank(attack: s['atkBoost'] as int, spAttack: s['atkBoost'] as int)
        ..selectedItem = (s['item'] as String).isEmpty ? null : _itemSlug(s['item'] as String)
        ..moves = [move, null, null, null]
        ..criticals = [move.hasTag(MoveTags.alwaysCrit), false, false, false]
        ..terastal = (s['teraType'] != null
            ? TerastalState(active: true, teraType: _teraTypeMap[s['teraType']])
            : const TerastalState())
        ..hitOverrides = [hits, null, null, null];
      final def = BattlePokemonState()
        ..applyPokemon(defP)
        ..ev = Stats(
            hp: s['defEvs']['hp'] as int, attack: 0,
            defense: s['defEvs']['def'] as int, spAttack: 0,
            spDefense: s['defEvs']['spd'] as int, speed: 0)
        ..nature = NatureProfile.fromNature(Nature.hardy)
        ..rank = Rank(defense: s['defBoost'] as int, spDefense: s['defBoost'] as int);

      final weather = _weatherMap[s['weather']] ?? Weather.none;
      final terrain = _terrainMap[s['terrain']] ?? Terrain.none;
      final room = const RoomConditions();
      final atkSpeed = BattleFacade.calcSpeed(
          state: atk, weather: weather, terrain: terrain, room: room);
      final defSpeed = BattleFacade.calcSpeed(
          state: def, weather: weather, terrain: terrain, room: room);
      final defStatsForFP = StatCalculator.calculate(
        baseStats: def.baseStats, iv: def.iv, ev: def.ev,
        nature: def.nature, level: def.level, rank: def.rank,
      );
      final result = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: weather, terrain: terrain, room: room,
        myEffectiveSpeed: atkSpeed,
        opponentSpeed: defSpeed,
        opponentAttack: defStatsForFP.attack,
        auras: const AuraToggles(), ruins: const RuinToggles(),
      );

      final ours = result.perHitAllRolls;
      final theirs = (s['rolls'] as List)
          .map((h) => (h as List).cast<int>()).toList();
      bool ok = ours != null && ours.length == theirs.length;
      if (ok) {
        for (int h = 0; h < theirs.length && ok; h++) {
          for (int i = 0; i < 16 && ok; i++) {
            if (ours[h][i] != theirs[h][i]) ok = false;
          }
        }
      }
      if (ok) {
        matched++;
      } else {
        diffs.add(
          'DIFF ${s['atkSpec']} ${s['move']}×${s['hits']} → ${s['defSpec']}\n'
          '  ours:    ${ours?.map((h) => h.toString()).join(" | ") ?? "<null>"}\n'
          '  showdown:${theirs.map((h) => h.toString()).join(" | ")}',
        );
      }
    }
    // ignore: avoid_print
    print('multi-hit matched=$matched / total=$total');
    if (diffs.isNotEmpty) {
      // ignore: avoid_print
      print('First 5 diffs:');
      for (final d in diffs.take(5)) {
        // ignore: avoid_print
        print(d);
      }
    }
  });
}
