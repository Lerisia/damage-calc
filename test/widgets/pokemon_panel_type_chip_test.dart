import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/champions_moves.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/learnsetdex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/views/widgets/pokemon_panel.dart';
import 'package:damage_calc/views/widgets/type_chip.dart';

/// Extended Mode shows a type the same way in the species header and in
/// each move row — design review: "같은 정보는 동일하게". The move row's
/// type used to be plain text opening a plain text list.
void main() {
  late BattlePokemonState state;

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
    await tester.runAsync(() async {
      await loadPokedex();
      await loadAbilitydex();
      await loadItemdex();
      await loadAllMoves();
      await loadChampionsUsage();
      await loadChampionsMoves();
      await loadLearnsets();
    });
    state = BattlePokemonState()..applyPokemon(pokedexByName('Garchomp')!);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PokemonPanel(
            state: state,
            weather: Weather.none,
            terrain: Terrain.none,
            onChanged: () {},
            resetCounter: 0,
          ),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<TypeChip> chips(WidgetTester tester) =>
      tester.widgetList<TypeChip>(find.byType(TypeChip)).toList();

  testWidgets('species types and move types are all TypeChips of one size',
      (tester) async {
    await pumpPanel(tester);
    final all = chips(tester);
    // Two species chips (Dragon / Ground) + one per move with a type.
    expect(all.take(2).map((c) => c.type), [PokemonType.dragon, PokemonType.ground]);
    final moveTypes = [
      for (final m in state.moves)
        if (m != null) m.type,
    ];
    expect(all.skip(2).map((c) => c.type), moveTypes);
    expect(all.map((c) => c.size).toSet(), {TypeChipSize.dense});
    expect(all.every((c) => c.dotColor == null), isTrue);
    // None of them is squeezed by its cell: every chip is as tall as the
    // species chips, and the move chips share one column width.
    final sizes = [for (final e in find.byType(TypeChip).evaluate()) e.size!];
    expect(sizes.map((s) => s.height).toSet(), hasLength(1));
    expect(sizes.skip(2).map((s) => s.width).toSet(), {40.0});
  });

  testWidgets('a move\'s chip opens the chip dialog; the pick overrides the type and is marked',
      (tester) async {
    await pumpPanel(tester);
    final firstMoveChip = find.byType(TypeChip).at(2);
    await tester.tap(firstMoveChip);
    await tester.pumpAndSettle();
    // The same option chips as every other type dialog — not a text list.
    expect(find.byKey(const ValueKey('type_option_fire')), findsOneWidget);
    expect(find.byType(SimpleDialogOption), findsNothing);
    await tester.tap(find.byKey(const ValueKey('type_option_fire')));
    await tester.pumpAndSettle();
    expect(state.typeOverrides[0], PokemonType.fire);
    final chip = chips(tester)[2];
    expect(chip.type, PokemonType.fire);
    expect(chip.dotColor, Colors.orange, reason: 'a manual override is marked');
  });
}
