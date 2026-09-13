import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/name_maps.dart';
import 'package:damage_calc/i18n/app_strings.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/views/widgets/stat_input.dart';

/// Keyboard navigation in the Extended Mode ability / item pickers.
///
/// The species picker got ↓ / Enter working on 2026-09-13; these two
/// fields host the same typeahead but the parent's build() used to
/// write the current label back into the controller whenever the
/// field's FocusNode had no focus — and ↓ moves focus INTO the
/// suggestions box, so the first rebuild after ↓ replaced the query,
/// re-ran the search and killed the navigation.
void main() {
  Future<void> pump(WidgetTester t, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await t.pump();
      final e = t.takeException();
      if (e != null) {
        expect('$e', anyOf(contains('RenderAnimatedSize'), contains('flutter_keyboard_visibility'), startsWith('Multiple exceptions')));
      }
    }
  }

  Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
    await t.sendKeyDownEvent(k);
    await t.sendKeyUpEvent(k);
    await pump(t, 2);
  }

  late Map<String, String> abilityKo;
  late Map<String, String> itemKo;

  Future<void> prime(WidgetTester tester) async {
    await tester.runAsync(() async {
      abilityKo = abilityNames(await loadAbilitydex());
      itemKo = heldItemNames(await loadItemdex());
    });
  }

  Finder fieldLabeled(String key) => find.byWidgetPredicate((w) =>
      w is TextField && w.decoration?.labelText == AppStrings.t(key));

  Future<void> open(WidgetTester tester, Finder field, String query) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Host())));
    // Async dex loads resolve on the real loop.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await pump(tester, 2);
    await tester.tap(field);
    await pump(tester, 2);
    await tester.enterText(field, query);
    await pump(tester, 2);
  }

  testWidgets('ability: ↓ keeps the query and Enter picks the focused hit',
      (tester) async {
    await prime(tester);
    final field = fieldLabeled('label.ability');
    await open(tester, field, 'intimid');
    expect(find.text(abilityKo['Intimidate']!), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(tester.widget<TextField>(field).controller!.text, 'intimid');
    expect(find.text(abilityKo['Intimidate']!), findsOneWidget);
    await key(tester, LogicalKeyboardKey.enter);
    expect(_Host.pickedAbilities, ['Intimidate']);
  });

  testWidgets('item: ↓↓ then Enter picks the second hit', (tester) async {
    await prime(tester);
    final field = fieldLabeled('label.item');
    await open(tester, field, 'choice');
    final hits = tester
        .widgetList<Text>(find.descendant(of: find.byType(ListView), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(hits.length, greaterThan(2));
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(tester.widget<TextField>(field).controller!.text, 'choice');
    await key(tester, LogicalKeyboardKey.enter);
    expect(_Host.pickedItems.length, 1);
    expect(itemKo[_Host.pickedItems.single], hits[1]);
  });
}

class _Host extends StatefulWidget {
  const _Host();
  static final pickedAbilities = <String>[];
  static final pickedItems = <String?>[];
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String _ability = 'Rough Skin';
  String? _item = 'Life Orb';

  @override
  void initState() {
    super.initState();
    _Host.pickedAbilities.clear();
    _Host.pickedItems.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: StatInput(
        level: 50,
        nature: NatureProfile.neutral,
        iv: const Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31),
        ev: const Stats(hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0),
        baseStats: const Stats(hp: 108, attack: 130, defense: 95, spAttack: 80, spDefense: 85, speed: 102),
        pokemonAbilities: const ['Rough Skin', 'Sand Veil'],
        selectedAbility: _ability,
        selectedItem: _item,
        rank: const Rank(),
        hpPercent: 100,
        status: StatusCondition.none,
        onLevelChanged: (_) {},
        onNatureChanged: (_) {},
        onIvChanged: (_) {},
        onEvChanged: (_) {},
        onAbilityChanged: (v) { _Host.pickedAbilities.add(v); setState(() => _ability = v); },
        onItemChanged: (v) { _Host.pickedItems.add(v); setState(() => _item = v); },
        onRankChanged: (_) {},
        onHpPercentChanged: (_) {},
        onStatusChanged: (_) {},
      ),
    );
  }
}
