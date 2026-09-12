// Doubles comparison harness. Sets gameType: Doubles on @smogon/calc's
// Field and the corresponding attacker/defender ally toggles on our
// BattlePokemonState. Spread moves (allAdjacent / allAdjacentFoes)
// auto-apply ×0.75; here we flag `spreadTargets` so our calc
// matches.
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
import 'package:damage_calc/utils/battle_facade.dart';

const _weatherMap = {
  'Sun': Weather.sun, 'Rain': Weather.rain,
  'Sand': Weather.sandstorm, 'Snow': Weather.snow,
};
const _terrainMap = {
  'Electric': Terrain.electric, 'Grassy': Terrain.grassy,
  'Misty': Terrain.misty, 'Psychic': Terrain.psychic,
};
const _natureMap = {
  'Adamant': Nature.adamant,'Modest': Nature.modest,'Jolly': Nature.jolly,
  'Timid': Nature.timid,'Bold': Nature.bold,'Calm': Nature.calm,'Hardy': Nature.hardy,
};
String _itemSlug(String name) => name.isEmpty
    ? '' : name.toLowerCase().replaceAll(' ', '-');

void main() {
  test('Showdown doubles compare', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moveMap = await loadMovedex();
    final pokemonByName = {for (final p in pokedex) p.name: p};

    final scenarios = (jsonDecode(
        File('/tmp/scenarios_doubles.json').readAsStringSync()) as List)
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
        ..criticals = [s['isCrit'] == true, false, false, false]
        ..helpingHand = s['helpingHand'] == true
        ..allyPowerSpot = s['powerSpot'] == true
        ..allyBattery = s['battery'] == true
        // @smogon/calc Doubles applies spread by the move's (possibly
        // terrain-modified) target; our calc gates it on the user's
        // "hitting both foes" toggle AND the transformed move's spread
        // tag, so "both foes" is always on here and the tag decides.
        ..spreadTargets = true;
      final def = BattlePokemonState()
        ..applyPokemon(defP)
        ..ev = Stats(
            hp: s['defEvs']['hp'] as int, attack: 0,
            defense: s['defEvs']['def'] as int, spAttack: 0,
            spDefense: s['defEvs']['spd'] as int, speed: 0)
        ..nature = NatureProfile.fromNature(Nature.hardy)
        ..rank = Rank(defense: s['defBoost'] as int, spDefense: s['defBoost'] as int)
        ..allyFriendGuard = s['friendGuard'] == true;

      final weather = _weatherMap[s['weather']] ?? Weather.none;
      final terrain = _terrainMap[s['terrain']] ?? Terrain.none;
      final room = const RoomConditions();
      // Through the facade, like the screens — and in the doubles
      // format, which is what gates the ×0.75 spread step. The harness
      // used to call DamageCalculator directly without `doubles`, so
      // every spread scenario silently mismatched and the count was
      // only printed, never asserted (that is how Expanding Force's
      // spread bug slipped through).
      final result = BattleFacade.calcDamage(
        attacker: atk, defender: def, moveIndex: 0,
        weather: weather, terrain: terrain, room: room,
        doubles: true,
      );
      final ours = result.allRolls;
      final theirs = (s['rolls'] as List).cast<int>();
      if (ours.length == 16 &&
          List.generate(16, (i) => ours[i] == theirs[i]).every((b) => b)) {
        matched++;
      } else {
        diffs.add(
          'DIFF ${s['atkSpec']} ${s['move']} (hh=${s['helpingHand']} ps=${s['powerSpot']} bt=${s['battery']}) → ${s['defSpec']} fg=${s['friendGuard']}\n'
          '  ours:    $ours\n'
          '  showdown:$theirs',
        );
      }
    }
    // ignore: avoid_print
    print('doubles matched=$matched / total=$total');
    // Every scenario must match — a printed count nobody reads let the
    // Expanding Force spread bug through (2026-09-10).
    expect(matched, total, reason: 'Showdown mismatches — see the diffs above');
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
