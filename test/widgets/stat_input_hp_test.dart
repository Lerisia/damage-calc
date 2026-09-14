import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/calc/hp.dart';
import 'package:damage_calc/calc/stat_calculator.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/views/widgets/stat_input.dart';

/// Extended Mode's HP field takes a real value (user decision
/// 2026-09-14): the box shows the current HP integer, the next column
/// shows max HP with the share it is, and what reaches the parent is
/// the share of the typed integer — never a share no HP can produce.
void main() {
  const base = Stats(hp: 108, attack: 130, defense: 95, spAttack: 80, spDefense: 85, speed: 102);
  const iv = Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);
  const ev = Stats(hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);
  final maxHp = StatCalculator.calculate(
      baseStats: base, iv: iv, ev: ev, nature: NatureProfile.neutral, level: 50).hp;

  late List<double> reported;
  late double hpPercent;
  late bool dynamaxed;

  Widget host() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatInput(
              level: 50,
              nature: NatureProfile.neutral,
              iv: iv,
              ev: ev,
              baseStats: base,
              pokemonAbilities: const ['Rough Skin'],
              rank: const Rank(),
              hpPercent: hpPercent,
              isDynamaxed: dynamaxed,
              status: StatusCondition.none,
              onLevelChanged: (_) {},
              onNatureChanged: (_) {},
              onIvChanged: (_) {},
              onEvChanged: (_) {},
              onAbilityChanged: (_) {},
              onItemChanged: (_) {},
              onRankChanged: (_) {},
              onHpPercentChanged: reported.add,
              onStatusChanged: (_) {},
            ),
          ),
        ),
      );

  setUp(() {
    reported = [];
    hpPercent = 100;
    dynamaxed = false;
  });

  final field = find.byKey(const ValueKey('hp_cur'));

  testWidgets('shows the current HP integer and the share next to max', (tester) async {
    hpPercent = 33; // of 183 → 60 HP = 32.79 %
    await tester.pumpWidget(host());
    expect(maxHp, 183);
    expect(find.descendant(of: field, matching: find.text('60')), findsOneWidget);
    expect(find.text(' 32.79%'), findsOneWidget);
  });

  testWidgets('a typed real value reaches the parent as its share', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(field, '94');
    expect(reported.last, hpPercentOf(maxHp, 94));
    expect(currentHpOf(maxHp, reported.last), 94);
  });

  testWidgets('a typed percent snaps to the nearest HP; empty means full', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(field, '40%');
    expect(currentHpOf(maxHp, reported.last), 73); // 73.2
    await tester.enterText(field, '');
    expect(reported.last, 100);
  });

  testWidgets('a value above max clamps to max', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(field, '999');
    expect(currentHpOf(maxHp, reported.last), maxHp);
  });

  testWidgets('Dynamaxed: the range is the doubled max and the share is kept', (tester) async {
    dynamaxed = true;
    hpPercent = hpPercentOf(2 * maxHp, 300); // typed 300/366 while Dynamaxed
    await tester.pumpWidget(host());
    expect(find.descendant(of: field, matching: find.text('300')), findsOneWidget);
    expect(find.text('366'), findsOneWidget);
    await tester.enterText(field, '350');
    expect(currentHpOf(2 * maxHp, reported.last), 350);
    // Dynamax ends: the same share on the normal max, like the game.
    expect(currentHpOf(maxHp, reported.last), 175); // 350/366 of 183 = 174.9…
  });
}
