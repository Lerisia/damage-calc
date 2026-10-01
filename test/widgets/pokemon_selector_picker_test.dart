import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/views/widgets/pokemon_selector.dart';

/// The species field on the search modal: closed it shows the current
/// species, a tap opens the modal, and the search is the same engine
/// as before (Korean prefix, nicknames, current pick first).
void main() {
  late List<Pokemon> picked;

  Future<void> pumpSelector(WidgetTester tester, {String? initial = 'Garchomp'}) async {
    await tester.runAsync(() async {
      await loadPokedex();
      await loadChampionsUsage();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PokemonSelector(
          initialPokemonName: initial,
          onSelected: picked.add,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final input = find.byKey(const Key('search_picker_input'));

  setUp(() async {
    picked = [];
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
  });

  testWidgets('closed: shows the current species, no text box', (tester) async {
    await pumpSelector(tester);
    expect(find.text('한카리아스'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tap → modal with the cursor in the search box; Enter picks the top hit',
      (tester) async {
    await pumpSelector(tester);
    await tester.tap(find.byType(PokemonSelector));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue);
    await tester.enterText(input, '메한카');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(picked.map((p) => p.name), ['Mega Garchomp']);
    expect(find.text('메가한카리아스'), findsOneWidget);
    expect(input, findsNothing);
  });

  testWidgets('default list: current species, its megas, then the usage ranking; a pick is remembered',
      (tester) async {
    await pumpSelector(tester);
    // The best-ranked species other than the current one — read from
    // the live usage table, which changes daily.
    final next = (await tester.runAsync(loadPokedex))!
        .where((p) => p.name != 'Garchomp' && championsUsageFor(p.name)?.usageRank != null)
        .reduce((a, b) => championsUsageFor(a.name)!.usageRank! <=
                championsUsageFor(b.name)!.usageRank!
            ? a
            : b)
        .name;
    await tester.tap(find.byType(PokemonSelector));
    await tester.pumpAndSettle();
    double top(String name) =>
        tester.getTopLeft(find.byKey(ValueKey('search_picker_item_$name'))).dy;
    // Usage order with megas beside their base: Garchomp's megas come
    // before the next ranked species.
    expect(top('Garchomp'), lessThan(top('Mega Garchomp')));
    expect(top('Mega Garchomp'), lessThan(top('Mega Garchomp Z')));
    expect(top('Mega Garchomp Z'), lessThan(top(next)));
    await tester.tap(find.byKey(ValueKey('search_picker_item_$next')));
    await tester.pumpAndSettle();
    expect(picked.single.name, next);

    await tester.tap(find.byType(PokemonSelector));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('search_picker_recent_$next')), findsOneWidget);
  });

  testWidgets('an empty slot shows the hint and still opens', (tester) async {
    await pumpSelector(tester, initial: null);
    await tester.tap(find.byType(PokemonSelector));
    await tester.pumpAndSettle();
    expect(input, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(picked, isEmpty);
  });
}
