import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/damage_calculator.dart';
import 'package:damage_calc/utils/aura_effects.dart';
import 'package:damage_calc/utils/ruin_effects.dart';

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
const _natureMap = {
  'Adamant': Nature.adamant,
  'Modest': Nature.modest,
  'Jolly': Nature.jolly,
  'Timid': Nature.timid,
  'Bold': Nature.bold,
  'Calm': Nature.calm,
  'Impish': Nature.impish,
  'Careful': Nature.careful,
  'Hardy': Nature.hardy,
  'Naughty': Nature.naughty,
};
String _itemSlug(String name) {
  if (name.isEmpty) return '';
  return name.toLowerCase().replaceAll(' ', '-');
}

void main() {
  test('Showdown compare', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moveMap = await loadMovedex();
    final pokemonByName = {for (final p in pokedex) p.name: p};

    final scenarios = (jsonDecode(File('/tmp/scenarios.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
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
      final atk = BattlePokemonState()
        ..applyPokemon(atkP)
        ..ev = Stats(
            hp: (s['evs']['hp'] as int),
            attack: (s['evs']['atk'] as int),
            defense: (s['evs']['def'] as int),
            spAttack: (s['evs']['spa'] as int),
            spDefense: (s['evs']['spd'] as int),
            speed: (s['evs']['spe'] as int))
        ..nature = NatureProfile.fromNature(_natureMap[s['nature']]!)
        ..rank = Rank(attack: s['atkBoost'] as int, spAttack: s['atkBoost'] as int)
        ..selectedItem = (s['item'] as String).isEmpty ? null : _itemSlug(s['item'] as String)
        ..status = s['status'] == 'brn' ? StatusCondition.burn : StatusCondition.none
        ..moves = [move, null, null, null];
      final def = BattlePokemonState()
        ..applyPokemon(defP)
        ..ev = Stats(
            hp: s['defEvs']['hp'] as int,
            attack: 0,
            defense: s['defEvs']['def'] as int,
            spAttack: 0,
            spDefense: s['defEvs']['spd'] as int,
            speed: 0)
        ..nature = NatureProfile.fromNature(Nature.hardy)
        ..rank = Rank(defense: s['defBoost'] as int, spDefense: s['defBoost'] as int);
      final result = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: _weatherMap[s['weather']] ?? Weather.none,
        terrain: _terrainMap[s['terrain']] ?? Terrain.none,
        room: const RoomConditions(),
        auras: const AuraToggles(), ruins: const RuinToggles(),
      );
      final ours = result.allRolls;
      final theirs = (s['rolls'] as List).cast<int>();
      if (ours.length == 16 &&
          List.generate(16, (i) => ours[i] == theirs[i]).every((b) => b)) {
        matched++;
      } else {
        diffs.add(
          'DIFF ${s['atkSpec']} (${s['nature']}, item=${s['item']}, atkBoost=${s['atkBoost']}, burn=${s['status']}) → '
          '${s['defSpec']} (defBoost=${s['defBoost']}) move=${s['move']} '
          'weather=${s['weather']} terrain=${s['terrain']}\n'
          '  ours:    $ours\n'
          '  showdown:$theirs',
        );
      }
    }
    print('matched=$matched / total=$total');
    if (diffs.isNotEmpty) {
      print('First 10 diffs:');
      for (final d in diffs.take(10)) {
        print(d);
      }
    }
  });
}
