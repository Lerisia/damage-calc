import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/calc/aura_effects.dart';
import 'package:damage_calc/calc/ruin_effects.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/champions_moves.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/learnsetdex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/name_maps.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/views/simple_mode_screen.dart';
import 'package:damage_calc/views/widgets/type_chip.dart';

/// Simple Mode's move info row shows the move's type as the shared
/// chip. The row used to be a fixed 16 px slot sized for a line of
/// text, which squashed the 20 px chip (user report, 2026-10-02). The
/// slot now takes its height from the chip itself.
void main() {
  late Map<String, String> abilityKo, itemKo;
  late Set<String> pickable;

  Future<void> pumpSimple(WidgetTester tester, BattlePokemonState atk,
      BattlePokemonState def) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      home: Scaffold(
        body: SafeArea(
          child: SimpleModeView(
            attacker: atk,
            defender: def,
            weather: Weather.none,
            terrain: Terrain.none,
            room: const RoomConditions(),
            auras: const AuraToggles(),
            ruins: const RuinToggles(),
            resetCounter: 0,
            onChanged: () {},
            abilityNameMap: abilityKo,
            itemNameMap: itemKo,
            pickableAbilities: pickable,
            onSaveSide: (_) {},
            onLoadSide: (_) {},
            onResetSide: (_) {},
          ),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
  });

  Future<void> prime(WidgetTester tester) => tester.runAsync(() async {
        await loadPokedex();
        final dex = await loadAbilitydex();
        abilityKo = abilityNames(dex, pickableOnly: false);
        pickable = pickableAbilityKeys(dex);
        itemKo = heldItemNames(await loadItemdex());
        await loadAllMoves();
        await loadChampionsUsage();
        await loadChampionsMoves();
        await loadLearnsets();
      });

  testWidgets('no type chip on the screen is squeezed', (tester) async {
    await prime(tester);
    // A free-standing dense chip: the height every dense chip should have.
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: TypeChip.dense(PokemonType.dragon)))));
    final natural = tester.getSize(find.byType(TypeChip)).height;

    final atk = BattlePokemonState()..applyPokemon(pokedexByName('Garchomp')!);
    final def = BattlePokemonState()..applyPokemon(pokedexByName('Primarina')!);
    await pumpSimple(tester, atk, def);

    final dense = [
      for (final e in find.byType(TypeChip).evaluate())
        if ((e.widget as TypeChip).size == TypeChipSize.dense &&
            tester.any(find.byWidget(e.widget).hitTestable()))
          e,
    ];
    // Attacker's two types, the move's type, the defender's two types.
    expect(dense.length, greaterThanOrEqualTo(5));
    for (final e in dense) {
      expect(e.size!.height, natural,
          reason: '${(e.widget as TypeChip).type} chip is squeezed');
    }
  });

  testWidgets('the move info slot is the same height with and without a move',
      (tester) async {
    await prime(tester);
    final def = BattlePokemonState()..applyPokemon(pokedexByName('Primarina')!);
    final defName = def.localizedPokemonName;

    final withMove = BattlePokemonState()..applyPokemon(pokedexByName('Garchomp')!);
    expect(withMove.moves[0], isNotNull);
    await pumpSimple(tester, withMove, def);
    final y1 = tester.getTopLeft(find.text(defName)).dy;

    final noMove = BattlePokemonState()..applyPokemon(pokedexByName('Garchomp')!);
    noMove.moves[0] = null;
    await pumpSimple(tester, noMove, def);
    final y2 = tester.getTopLeft(find.text(defName)).dy;

    expect(y2, y1, reason: 'clearing the move must not shift the layout');
  });
}
