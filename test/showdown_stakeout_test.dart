// Stakeout comparison harness. Reads /tmp/scenarios_stakeout.json from
// tools/showdown-compare/gen_stakeout.mjs and replays each scenario
// through DamageCalculator, comparing the 16-roll spread against
// @smogon/calc. `abilityOn` maps to the 'Stakeout Active' (상대 교체
// 시) / 'Stakeout Inactive' (미발동) variant keys.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/aura_effects.dart';
import 'package:damage_calc/utils/damage_calculator.dart';
import 'package:damage_calc/utils/ruin_effects.dart';

const _weatherMap = {
  'Sun': Weather.sun, 'Rain': Weather.rain,
  'Sand': Weather.sandstorm, 'Snow': Weather.snow,
};
const _terrainMap = {
  'Electric': Terrain.electric, 'Grassy': Terrain.grassy,
  'Misty': Terrain.misty, 'Psychic': Terrain.psychic,
};
const _natureMap = {
  'Adamant': Nature.adamant, 'Modest': Nature.modest, 'Jolly': Nature.jolly,
  'Timid': Nature.timid, 'Hardy': Nature.hardy, 'Bold': Nature.bold,
};

void main() {
  test('Showdown Stakeout compare', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moveMap = await loadMovedex();
    final byName = {for (final p in pokedex) p.name: p};

    final scenarios = (jsonDecode(
        File('/tmp/scenarios_stakeout.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    int total = 0, matched = 0;
    final diffs = <String>[];

    Stats evOf(Map<String, dynamic> m) => Stats(
        hp: m['hp'] as int, attack: m['atk'] as int, defense: m['def'] as int,
        spAttack: m['spa'] as int, spDefense: m['spd'] as int,
        speed: m['spe'] as int);

    for (final s in scenarios) {
      total++;
      final atkP = byName[s['atkSpec']];
      final defP = byName[s['defSpec']];
      final move = moveMap[s['move']];
      if (atkP == null || defP == null || move == null) {
        diffs.add('SKIP missing: ${s['atkSpec']} / ${s['defSpec']} / ${s['move']}');
        continue;
      }
      final atk = BattlePokemonState()
        ..applyPokemon(atkP)
        ..ev = evOf(s['evs'] as Map<String, dynamic>)
        ..nature = NatureProfile.fromNature(_natureMap[s['nature']]!)
        ..rank = Rank(attack: s['atkBoost'] as int, spAttack: s['atkBoost'] as int)
        ..selectedAbility =
            (s['abilityOn'] == true) ? 'Stakeout Active' : 'Stakeout Inactive'
        ..moves = [move, null, null, null]
        ..criticals = [s['isCrit'] == true, false, false, false];
      final def = BattlePokemonState()
        ..applyPokemon(defP)
        ..ev = evOf(s['defEvs'] as Map<String, dynamic>)
        ..nature = NatureProfile.fromNature(Nature.hardy)
        ..rank = Rank(defense: s['defBoost'] as int, spDefense: s['defBoost'] as int);
      final weather = _weatherMap[s['weather']] ?? Weather.none;
      final terrain = _terrainMap[s['terrain']] ?? Terrain.none;
      final result = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: weather, terrain: terrain, room: const RoomConditions(),
        auras: const AuraToggles(), ruins: const RuinToggles(),
      );
      final ours = result.allRolls;
      final theirs = (s['rolls'] as List).cast<int>();
      if (ours.length == 16 &&
          List.generate(16, (i) => ours[i] == theirs[i]).every((b) => b)) {
        matched++;
      } else {
        diffs.add(
          'DIFF ${s['atkSpec']}(abilityOn=${s['abilityOn']},${s['nature']},'
          'atkBoost=${s['atkBoost']}) ${s['move']} → ${s['defSpec']}\n'
          '  ours:    $ours\n'
          '  showdown:$theirs',
        );
      }
    }
    // ignore: avoid_print
    print('stakeout matched=$matched / total=$total');
    if (diffs.isNotEmpty) {
      // ignore: avoid_print
      print('First 10 diffs:');
      for (final d in diffs.take(10)) {
        // ignore: avoid_print
        print(d);
      }
    }
  });
}
