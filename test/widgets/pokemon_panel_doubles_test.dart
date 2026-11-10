import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/champions_format_controller.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/champions_moves.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/learnsetdex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/i18n/app_strings.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/views/widgets/pokemon_panel.dart';

/// The doubles section of Extended Mode offers the ally's Steely
/// Spirit next to Battery / Power Spot.
void main() {
  late BattlePokemonState state;

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 2400);
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

  setUp(() => ChampionsFormatController.instance.format.value = ChampionsFormat.doubles);
  tearDown(() => ChampionsFormatController.instance.format.value = ChampionsFormat.singles);

  testWidgets('the ally Steely Spirit toggle sits with the other ally abilities',
      (tester) async {
    await pumpPanel(tester);
    final label = find.text(AppStrings.t('damage.allySteelySpirit'));
    await tester.ensureVisible(label);
    await tester.pump();
    expect(label, findsOneWidget);
    expect(state.allySteelySpirit, isFalse);

    await tester.tap(label);
    await tester.pump();
    expect(state.allySteelySpirit, isTrue);

    // Its checkbox reflects the state.
    final box = find.descendant(
      of: find.ancestor(of: label, matching: find.byType(InkWell)).first,
      matching: find.byType(Checkbox),
    );
    expect(tester.widget<Checkbox>(box).value, isTrue);
  });
}
