// Backend tests for the 1.10 reverse-calc feature. The module
// enumerates attacker (offensive EV, nature) combos and returns
// the ones whose computed damage range overlaps an observed value.
//
// Coverage:
//   1. Round-trip: a known competitive setup produces a damage
//      number. Feeding that exact number back through ReverseCalc
//      must surface the original (EV, nature) as a candidate.
//   2. Sort order: with multiple matching candidates, boost-nature
//      / high-EV combos come first (the heuristic that drives the
//      UI's "most likely" badge).
//   3. Impossible observation: damage that's higher than any
//      candidate can produce returns an empty result.
//   4. Status moves: short-circuit to empty.
//   5. Inverted range (observedMin > observedMax): empty result.

import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/damage_calculator.dart';
import 'package:damage_calc/utils/reverse_calc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Pokemon> pokedex;
  late Map<String, Move> moveDex;

  setUpAll(() async {
    pokedex = await loadPokedex();
    moveDex = await loadMovedex();
  });

  Pokemon byName(String name) =>
      pokedex.firstWhere((p) => p.name == name);

  /// Build a defender at level 50 with the given HP / Def EVs and
  /// optional nature. Uses Toxapex as a standard physical wall so
  /// every test starts from the same baseline.
  BattlePokemonState makeDefender({
    int hpEv = 4,
    int defEv = 0,
    NatureProfile nature = NatureProfile.neutral,
  }) {
    final state = BattlePokemonState()..applyPokemon(byName('Toxapex'));
    state.ev = Stats(
      hp: hpEv,
      attack: 0,
      defense: defEv,
      spAttack: 0,
      spDefense: 0,
      speed: 0,
    );
    state.nature = nature;
    return state;
  }

  /// Build a Garchomp attacker with the given Atk EV / nature and
  /// Earthquake in slot 0. The reverse-calc input clones this and
  /// substitutes its own (EV, nature) on each iteration.
  BattlePokemonState makeAttacker({
    int atkEv = 0,
    NatureProfile nature = NatureProfile.neutral,
  }) {
    final state = BattlePokemonState()..applyPokemon(byName('Garchomp'));
    state.ev = Stats(
      hp: 0, attack: atkEv, defense: 0,
      spAttack: 0, spDefense: 0, speed: 0,
    );
    state.nature = nature;
    state.moves[0] = moveDex['Earthquake'];
    return state;
  }

  group('ReverseCalc.run', () {
    test('round-trip: true (EV, nature) is in the candidate list',
        (
    ) {
      // Build the "ground truth": 252+ Adamant Garchomp's Earthquake
      // → some damage range. Then ask ReverseCalc to find that
      // (EV, nature) pair from the observed range.
      final defender = makeDefender();
      final truth = makeAttacker(
        atkEv: 252,
        nature: const NatureProfile(
            up: NatureStat.atk, down: NatureStat.spa),
      );
      final groundTruth = DamageCalculator.calculate(
        attacker: truth,
        defender: defender,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(groundTruth.allRolls, isNotEmpty,
          reason: 'sanity: forward calc produced rolls');

      // Use the EXACT roll range we just observed.
      final result = ReverseCalc.run(
        defender: defender,
        // Template carries Garchomp + Earthquake; EV/nature get
        // overridden each iteration. We pass zero EV / neutral so
        // any non-zero match must come from the search.
        attackerTemplate: makeAttacker(),
        moveIndex: 0,
        observedMin: groundTruth.minDamage,
        observedMax: groundTruth.maxDamage,
      );
      expect(result.searched, 99,
          reason: '33 SP values (0..32) × 3 nature buckets = 99');
      expect(result.candidates, isNotEmpty);
      // 252+ Atk should be SOMEWHERE in the candidate list.
      final matched252Boost = result.candidates.any((c) =>
          c.ev == 252 && c.nature.up == NatureStat.atk);
      expect(matched252Boost, isTrue,
          reason:
              'the true spread that generated the observation must '
              'be among the matches');
    });

    test('sort heuristic: boost natures and high EVs come first', () {
      final defender = makeDefender();
      // Wide observation window so several candidates match.
      final wide = DamageCalculator.calculate(
        attacker: makeAttacker(atkEv: 252, nature: const NatureProfile(
            up: NatureStat.atk, down: NatureStat.spa)),
        defender: defender,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      final loose = ReverseCalc.run(
        defender: defender,
        attackerTemplate: makeAttacker(),
        moveIndex: 0,
        // Stretch the observation so neutral/drop nature combos
        // can also overlap — gives the sort order something to do.
        observedMin: 1,
        observedMax: wide.maxDamage,
      );
      expect(loose.candidates.length, greaterThan(3),
          reason: 'wide window should yield many candidates');
      // First candidate should be a boost-nature one — that's the
      // top bucket per the sort heuristic.
      expect(loose.candidates.first.nature.up, NatureStat.atk,
          reason:
              'plausibility sort puts offensive-boost natures at '
              'the top of the list');
    });

    test('impossible observation: damage above any candidate output → empty',
        () {
      final defender = makeDefender();
      final result = ReverseCalc.run(
        defender: defender,
        attackerTemplate: makeAttacker(),
        moveIndex: 0,
        // Far higher than any (Atk EV, nature) for a 90 BP physical
        // move could produce against a defensive Toxapex.
        observedMin: 100000,
        observedMax: 200000,
      );
      expect(result.candidates, isEmpty);
      expect(result.searched, 99,
          reason: 'we still try every combo before giving up');
    });

    test('status move → empty result (no offensive stat to search)',
        () {
      final defender = makeDefender();
      final att = makeAttacker();
      att.moves[0] = moveDex['Toxic']; // status move
      final result = ReverseCalc.run(
        defender: defender,
        attackerTemplate: att,
        moveIndex: 0,
        observedMin: 1,
        observedMax: 100,
      );
      expect(result.candidates, isEmpty);
      expect(result.searched, 0,
          reason: 'status moves short-circuit before the search loop');
    });

    test('inverted observed range (min > max) → empty result', () {
      final defender = makeDefender();
      final result = ReverseCalc.run(
        defender: defender,
        attackerTemplate: makeAttacker(),
        moveIndex: 0,
        observedMin: 100,
        observedMax: 10,
      );
      expect(result.candidates, isEmpty);
      expect(result.searched, 0);
    });
  });
}
