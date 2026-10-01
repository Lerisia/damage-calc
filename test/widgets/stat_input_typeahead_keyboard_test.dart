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
import 'package:damage_calc/views/widgets/search_picker/item_picker_field.dart';
import 'package:damage_calc/views/widgets/stat_input.dart';

/// Keyboard navigation in the Extended Mode ability / item pickers.
/// (The item field moved onto the search modal on 2026-10-01; the
/// ability field is still a typeahead.)
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

  testWidgets('item: the field opens the search modal; ↓ then Enter picks the second hit',
      (tester) async {
    await prime(tester);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Host())));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await pump(tester, 2);
    // The item field is no longer a text box with a dropdown: a tap
    // opens the shared search modal with the cursor in its search box.
    await tester.tap(find.byType(ItemPickerField));
    await pump(tester, 2);
    final input = find.byKey(const Key('search_picker_input'));
    expect(input, findsOneWidget);
    await tester.enterText(input, 'choice');
    await pump(tester, 2);
    final ids = [
      for (final e in find.byType(InkWell).evaluate())
        if (e.widget.key case ValueKey<String>(value: final v)
            when v.startsWith('search_picker_item_'))
          v.substring('search_picker_item_'.length),
    ];
    expect(ids.length, greaterThan(2));
    await key(tester, LogicalKeyboardKey.arrowDown);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pump(tester, 2);
    expect(_Host.pickedItems, [ids[1]]);
    expect(itemKo[ids[1]], isNotNull);
    expect(find.text(itemKo[ids[1]]!), findsOneWidget,
        reason: 'the closed field shows the new pick');
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
