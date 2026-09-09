import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentinel for the defaultMoves rule (2026-04-30 role/group formula).
///
/// The rule lives in a derivation step of the usage fetcher, and twice
/// (2026-06-18, 2026-07-30) a fetcher rewrite replaced it with a cruder
/// "top damaging moves" pick without anyone noticing — the second time
/// every species lost its status moves for 41 days in production. Under
/// the real rule a large share of ranked species carry a status move
/// (Stealth Rock, Roost, Protect …) in their four defaults; if that
/// share collapses, the rule has been swapped out again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final asset in const [
    'assets/champions_usage.json',
    'assets/champions_usage_doubles.json',
  ]) {
    test('$asset: ranked defaults still follow the role/group rule', () async {
      final usage = json.decode(await rootBundle.loadString(asset))
          as Map<String, dynamic>;
      final statusMoves = <String>{};
      for (final gen in const ['gen1','gen2','gen3','gen4','gen5','gen6','gen7','gen8','gen9']) {
        final moves = json.decode(
            await rootBundle.loadString('assets/moves/$gen.json')) as List;
        for (final m in moves) {
          if (m['category'] == 'status') statusMoves.add(m['name'] as String);
        }
      }

      var ranked = 0, withStatus = 0;
      for (final e in usage.entries) {
        if (e.key == '_meta' || e.value is! Map) continue;
        final v = e.value as Map<String, dynamic>;
        if (v['usageRank'] == null) continue;
        final defaults = (v['defaultMoves'] as List?) ?? const [];
        expect(defaults.length, inInclusiveRange(1, 4),
            reason: '${e.key} must have 1–4 defaults');
        ranked++;
        if (defaults.any((m) => statusMoves.contains(m['name']))) withStatus++;
      }
      expect(ranked, greaterThan(150), reason: 'usage table looks truncated');
      // 159/235 singles, 209/257 doubles on 2026-09-09. A rewrite that
      // filters to damaging moves drives this to exactly zero, so the
      // bar is deliberately loose — it only has to catch that.
      expect(withStatus, greaterThan(ranked ~/ 4),
          reason: 'only $withStatus of $ranked ranked species have a status '
              'move among their defaults — has the fetcher stopped calling '
              'compute_default_moves?');
    });
  }
}
