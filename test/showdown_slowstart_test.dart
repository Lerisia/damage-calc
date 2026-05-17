// Slow Start comparison harness. Reads /tmp/scenarios_slowstart.json
// from tools/showdown-compare/gen_slowstart.mjs and replays each
// scenario through DamageCalculator, comparing the 16-roll spread
// against @smogon/calc. `abilityOn` maps to the 'Slow Start Active'
// (5턴 이내) / 'Slow Start Ended' (5턴 경과) variant keys.
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
import 'package:damage_calc/utils/battle_facade.dart';
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
  'Adamant': Nature.adamant, 'Jolly': Nature.jolly, 'Modest': Nature.modest,
  'Timid': Nature.timid, 'Brave': Nature.brave, 'Quiet': Nature.quiet,
  'Hardy': Nature.hardy,
};

void main() {
  test('Showdown Slow Start compare', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moveMap = await loadMovedex();
    final byName = {for (final p in pokedex) p.name: p};

    final scenarios = (jsonDecode(
        File('/tmp/scenarios_slowstart.json').readAsStringSync()) as List)
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
        ..nature = NatureProfile.fromNature(_natureMap[s['atkNature']]!)
        ..rank = Rank(speed: s['atkSpeedBoost'] as int)
        ..selectedAbility =
            (s['abilityOn'] == true) ? 'Slow Start Active' : 'Slow Start Ended'
        ..moves = [move, null, null, null]
        ..criticals = [s['isCrit'] == true, false, false, false];
      final def = BattlePokemonState()
        ..applyPokemon(defP)
        ..ev = evOf(s['defEvs'] as Map<String, dynamic>)
        ..nature = NatureProfile.fromNature(_natureMap[s['defNature']]!)
        ..rank = Rank(speed: s['defSpeedBoost'] as int);
      final weather = _weatherMap[s['weather']] ?? Weather.none;
      final terrain = _terrainMap[s['terrain']] ?? Terrain.none;
      const room = RoomConditions();
      final atkSpeed = BattleFacade.calcSpeed(
          state: atk, weather: weather, terrain: terrain, room: room);
      final defSpeed = BattleFacade.calcSpeed(
          state: def, weather: weather, terrain: terrain, room: room);
      final result = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: weather, terrain: terrain, room: room,
        myEffectiveSpeed: atkSpeed, opponentSpeed: defSpeed,
        auras: const AuraToggles(), ruins: const RuinToggles(),
      );
      final ours = result.allRolls;
      final theirs = (s['rolls'] as List).cast<int>();
      if (ours.length == 16 &&
          List.generate(16, (i) => ours[i] == theirs[i]).every((b) => b)) {
        matched++;
      } else {
        diffs.add(
          'DIFF ${s['atkSpec']}(abilityOn=${s['abilityOn']},${s['atkNature']},'
          'spe+${s['atkSpeedBoost']}) ${s['move']} → ${s['defSpec']}\n'
          '  ours:    $ours\n'
          '  showdown:$theirs',
        );
      }
    }
    // ignore: avoid_print
    print('slow-start matched=$matched / total=$total');
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
