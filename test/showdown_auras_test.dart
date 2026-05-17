// Aura comparison harness (Fairy Aura / Dark Aura / Aura Break).
// Reads /tmp/scenarios_auras.json from tools/showdown-compare/gen_auras.mjs
// and replays each scenario through DamageCalculator, comparing the
// 16-roll spread against @smogon/calc.
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
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/aura_effects.dart';
import 'package:damage_calc/utils/battle_facade.dart';
import 'package:damage_calc/utils/damage_calculator.dart';
import 'package:damage_calc/utils/ruin_effects.dart';
import 'package:damage_calc/utils/stat_calculator.dart';

const _weatherMap = {
  'Sun': Weather.sun, 'Rain': Weather.rain,
  'Sand': Weather.sandstorm, 'Snow': Weather.snow,
};
const _terrainMap = {
  'Electric': Terrain.electric, 'Grassy': Terrain.grassy,
  'Misty': Terrain.misty, 'Psychic': Terrain.psychic,
};
const _teraTypeMap = {
  'Fairy': PokemonType.fairy, 'Dark': PokemonType.dark,
  'Steel': PokemonType.steel, 'Fire': PokemonType.fire,
};
const _natureMap = {
  'Adamant': Nature.adamant, 'Modest': Nature.modest, 'Jolly': Nature.jolly,
  'Timid': Nature.timid, 'Hardy': Nature.hardy, 'Bold': Nature.bold,
};
String _itemSlug(String n) => n.isEmpty ? '' : n.toLowerCase().replaceAll(' ', '-');

void main() {
  test('Showdown aura compare', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moveMap = await loadMovedex();
    final byName = {for (final p in pokedex) p.name: p};

    final scenarios = (jsonDecode(
        File('/tmp/scenarios_auras.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    int total = 0, matched = 0;
    final diffs = <String>[];

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
        ..ev = Stats(
            hp: s['evs']['hp'] as int, attack: s['evs']['atk'] as int,
            defense: s['evs']['def'] as int, spAttack: s['evs']['spa'] as int,
            spDefense: s['evs']['spd'] as int, speed: s['evs']['spe'] as int)
        ..nature = NatureProfile.fromNature(_natureMap[s['nature']]!)
        ..rank = Rank(attack: s['atkBoost'] as int, spAttack: s['atkBoost'] as int)
        ..selectedItem = (s['item'] as String).isEmpty ? null : _itemSlug(s['item'] as String)
        ..moves = [move, null, null, null]
        ..criticals = [s['isCrit'] == true, false, false, false]
        ..terastal = (s['teraType'] != null
            ? TerastalState(active: true, teraType: _teraTypeMap[s['teraType']])
            : const TerastalState());
      final def = BattlePokemonState()
        ..applyPokemon(defP)
        ..ev = Stats(
            hp: s['defEvs']['hp'] as int, attack: 0,
            defense: s['defEvs']['def'] as int, spAttack: 0,
            spDefense: s['defEvs']['spd'] as int, speed: 0)
        ..nature = NatureProfile.fromNature(Nature.hardy)
        ..rank = Rank(defense: s['defBoost'] as int, spDefense: s['defBoost'] as int)
        ..selectedItem = (s['defItem'] as String?)?.isNotEmpty == true
            ? _itemSlug(s['defItem'] as String)
            : null;
      // Aura abilities are another field-aura source alongside toggles.
      if ((s['atkAbility'] as String).isNotEmpty) {
        atk.selectedAbility = s['atkAbility'] as String;
      }
      if ((s['defAbility'] as String).isNotEmpty) {
        def.selectedAbility = s['defAbility'] as String;
      }
      final weather = _weatherMap[s['weather']] ?? Weather.none;
      final terrain = _terrainMap[s['terrain']] ?? Terrain.none;
      const room = RoomConditions();
      final atkSpeed = BattleFacade.calcSpeed(
          state: atk, weather: weather, terrain: terrain, room: room);
      final defSpeed = BattleFacade.calcSpeed(
          state: def, weather: weather, terrain: terrain, room: room);
      // Foul Play uses the target's Attack stat.
      final defStatsForFP = StatCalculator.calculate(
        baseStats: def.baseStats, iv: def.iv, ev: def.ev,
        nature: def.nature, level: def.level, rank: def.rank,
      );
      final result = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: weather, terrain: terrain, room: room,
        myEffectiveSpeed: atkSpeed, opponentSpeed: defSpeed,
        opponentAttack: defStatsForFP.attack,
        auras: AuraToggles(
          fairyAura: s['fairyAura'] == true,
          darkAura: s['darkAura'] == true,
          auraBreak: s['auraBreak'] == true,
        ),
        ruins: const RuinToggles(),
      );
      final ours = result.allRolls;
      final theirs = (s['rolls'] as List).cast<int>();
      if (ours.length == 16 &&
          List.generate(16, (i) => ours[i] == theirs[i]).every((b) => b)) {
        matched++;
      } else {
        diffs.add(
          'DIFF ${s['atkSpec']} ${s['move']} → ${s['defSpec']}  '
          'fairyAura=${s['fairyAura']} darkAura=${s['darkAura']} '
          'auraBreak=${s['auraBreak']} tera=${s['teraType']} crit=${s['isCrit']}\n'
          '  ours:    $ours\n'
          '  showdown:$theirs',
        );
      }
    }
    // ignore: avoid_print
    print('aura matched=$matched / total=$total');
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
