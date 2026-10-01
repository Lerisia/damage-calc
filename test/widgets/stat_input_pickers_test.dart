import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/name_maps.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/views/widgets/search_picker/ability_picker_field.dart';
import 'package:damage_calc/views/widgets/search_picker/item_picker_field.dart';
import 'package:damage_calc/views/widgets/stat_input.dart';

/// The Extended Mode ability and item fields on the search modal: a tap
/// opens it with the cursor in the search box, typing filters, ↓ and
/// Enter pick, and the closed field shows the new pick. (Until
/// 2026-10-01 these were text boxes with a dropdown.)
void main() {
  late Map<String, String> abilityKo;
  late Map<String, String> itemKo;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.runAsync(() async {
      abilityKo = abilityNames(await loadAbilitydex());
      itemKo = heldItemNames(await loadItemdex());
    });
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: _Host())));
    // Async dex loads resolve on the real loop.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump();
  }

  final input = find.byKey(const Key('search_picker_input'));
  List<String> shownIds() => [
        for (final e in find.byType(InkWell).evaluate())
          if (e.widget.key case ValueKey<String>(value: final v)
              when v.startsWith('search_picker_item_'))
            v.substring('search_picker_item_'.length),
      ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
  });

  testWidgets('ability: own abilities lead, with their effect text; Enter picks the top hit',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byType(AbilityPickerField));
    await tester.pumpAndSettle();
    expect(shownIds().take(2), ['Rough Skin', 'Sand Veil']);
    expect(find.text(abilityByNameSync('Rough Skin')!.localizedDescription!),
        findsOneWidget);
    // No recent strip for abilities.
    expect(find.text('최근'), findsNothing);
    await tester.enterText(input, 'intimid');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_Host.pickedAbilities, ['Intimidate']);
    expect(find.text(abilityKo['Intimidate']!), findsOneWidget,
        reason: 'the closed field shows the new pick');
  });

  testWidgets('item: ↓ then Enter picks the second hit', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byType(ItemPickerField));
    await tester.pumpAndSettle();
    await tester.enterText(input, 'choice');
    await tester.pump();
    final ids = shownIds();
    expect(ids.length, greaterThan(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_Host.pickedItems, [ids[1]]);
    expect(find.text(itemKo[ids[1]]!), findsOneWidget);
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
  String? _item = 'life-orb';

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
