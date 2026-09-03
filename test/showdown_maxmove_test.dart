import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/models/dynamax.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/move_transform.dart';

/// Max Move base power, compared against Showdown.
///
/// Fixture is generated from smogon/pokemon-showdown by
/// tools/showdown-compare/gen_maxmove.mjs: each move's
/// `maxMove.basePower` override when it has one, otherwise Showdown's
/// own conversion (`sim/dex-moves.ts`) — base power 0 becomes 100
/// before the type tables are consulted, and Fighting / Poison use a
/// reduced table.
void main() {
  late final Map<String, dynamic> expected;
  late final Map<String, Move> moves;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expected = jsonDecode(
        File('/tmp/max_move_power.json').readAsStringSync())
        as Map<String, dynamic>;
    moves = await loadMovedex();
  });

  int maxPowerOf(Move m) {
    final t = transformMove(
      m,
      MoveContext(
        weather: Weather.none,
        terrain: Terrain.none,
        rank: const Rank(),
        hpPercent: 100,
        status: StatusCondition.none,
        dynamax: DynamaxState.dynamax,
      ),
    );
    return t.move.power;
  }

  test('every move matches Showdown', () {
    final diffs = <String>[];
    var rebalanced = 0;
    for (final entry in expected.entries) {
      final m = moves[entry.key];
      if (m == null) continue; // move not in our dex
      final row = entry.value as Map<String, dynamic>;
      // Champions rebalanced some base powers (Beak Blast, Trop Kick,
      // Mountain Gale, …). Our dex carries those, so Showdown's Max
      // power no longer describes the same move — the conversion is
      // still what's under test, and every other move exercises it.
      if (row['bp'] != null && row['bp'] != m.power) {
        rebalanced++;
        continue;
      }
      // Deliberate divergence, documented at the conversion call
      // site: we fold situational power into the BP before the Max
      // table, so a Pokémon holding no item sees Acrobatics' doubled
      // 110 convert to 140 rather than the game's flat 110. Every
      // other move in that class has a base power of 0 and is now
      // pinned to the game's value instead.
      if (entry.key == 'Acrobatics') continue;
      final got = maxPowerOf(m);
      final want = row['max'] as int;
      if (got != want) {
        diffs.add('${entry.key} (${m.type.name} ${m.power}): '
            'got $got, showdown $want');
      }
    }
    expect(rebalanced, lessThan(30),
        reason: 'too many skipped — the fixture may be stale');
    expect(diffs, isEmpty,
        reason: '${diffs.length} moves differ:\n${diffs.take(40).join('\n')}');
  });

  test('the reported moves specifically', () {
    // github.com/Lerisia/damage-calc/issues/3 — variable-power moves
    // were falling into the "40 or less" band.
    expect(maxPowerOf(moves['Endeavor']!), equals(130));
    expect(maxPowerOf(moves['Final Gambit']!), equals(100));
  });
}
