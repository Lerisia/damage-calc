import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/views/widgets/stat_input.dart';

/// Companion to ev_sp_cell_focus_test — same recurring bug, the other
/// input.
///
/// The calculator's stat block now tells the parent screen about every
/// EV keystroke, so the opponent's speed comparison keeps up (issue
/// #2). That means the whole screen rebuilds while a field has focus,
/// which is exactly how this input lost the keyboard three times
/// before. Pump it under a parent that echoes the value back and
/// assert the field is never remounted.
void main() {
  testWidgets('EV field keeps focus across a parent value echo',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Echo())));

    final fields = find.byType(TextField);
    expect(fields, findsWidgets, reason: 'stat block should have inputs');

    await tester.tap(fields.first);
    await tester.pump();
    final before = tester.binding.focusManager.primaryFocus;
    expect(before, isNotNull);

    await tester.enterText(fields.first, '4');
    await tester.pump();

    expect(tester.binding.focusManager.primaryFocus, same(before),
        reason: 'a rebuild from the echoed value must not remount the '
            'field — that dismisses the keyboard on a device');
  });
}

/// Mirrors the panel: state lives above, every change round-trips
/// through setState.
class _Echo extends StatefulWidget {
  const _Echo();
  @override
  State<_Echo> createState() => _EchoState();
}

class _EchoState extends State<_Echo> {
  Stats _ev = const Stats(
      hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);
  Stats _iv = const Stats(
      hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: StatInput(
        level: 50,
        nature: NatureProfile.neutral,
        iv: _iv,
        ev: _ev,
        baseStats: const Stats(
            hp: 108, attack: 130, defense: 95, spAttack: 80,
            spDefense: 85, speed: 102),
        pokemonAbilities: const ['Rough Skin'],
        rank: const Rank(),
        hpPercent: 100,
        status: StatusCondition.none,
        onLevelChanged: (_) {},
        onNatureChanged: (_) {},
        onIvChanged: (v) => setState(() => _iv = v),
        onEvChanged: (v) => setState(() => _ev = v),
        onAbilityChanged: (_) {},
        onItemChanged: (_) {},
        onRankChanged: (_) {},
        onHpPercentChanged: (_) {},
        onStatusChanged: (_) {},
      ),
    );
  }
}
