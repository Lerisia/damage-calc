import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/i18n/app_strings.dart';
import 'package:damage_calc/models/ability.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/views/widgets/dex_search_filter_dialog.dart';

/// The dex filter's ability and move fields on the search modal.
///
/// These keep their outlined box and their in-field clear button, so
/// the field is a tap target with another tap target inside it: the
/// field opens the modal, the ✕ clears — and must not open the modal.
void main() {
  late Map<String, Ability> abilityDex;
  late List<Move> moves;
  Object? result;

  Future<void> openDialog(WidgetTester tester,
      {DexSearchFilter current = const DexSearchFilter()}) async {
    await tester.runAsync(() async {
      abilityDex = await loadAbilitydex();
      moves = (await loadAllMoves())
          .where((m) => m.moveClass == MoveClass.normal)
          .toList();
    });
    // Tall enough that the whole dialog body is on screen.
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDexSearchFilterDialog(
                context: context,
                current: current,
                abilityDex: abilityDex,
                allMoves: moves,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final input = find.byKey(const Key('search_picker_input'));
  // NB: an InputDecorator keeps its hint in the tree (at opacity 0) once
  // the field has a value, so hints locate fields — they don't tell
  // whether a field is empty. Emptiness is read from the labels and
  // the ✕ buttons.
  Finder hint(String key) => find.text(AppStrings.t(key));
  List<String> shownIds(WidgetTester tester) => [
        for (final e in find.byType(InkWell).evaluate())
          if (e.widget.key case ValueKey<String>(value: final v)
              when v.startsWith('search_picker_item_'))
            v.substring('search_picker_item_'.length),
      ];

  setUp(() async {
    result = null;
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
  });

  testWidgets('ability: the field opens the modal; a pick fills it and applies',
      (tester) async {
    await openDialog(tester);
    expect(find.byIcon(Icons.clear), findsNothing);
    await tester.tap(hint('dex.advAbilityHint'));
    await tester.pumpAndSettle();
    expect(input, findsOneWidget);
    // Rows carry the ability's effect text.
    final first = abilityDex[shownIds(tester).first]!;
    expect(find.text(first.localizedName), findsOneWidget);
    expect(find.text(first.localizedDescription!), findsOneWidget);
    await tester.enterText(input, 'intimid');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(find.text(abilityDex['Intimidate']!.localizedName), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.text(AppStrings.t('action.apply')));
    await tester.pumpAndSettle();
    expect((result as DexSearchFilter).abilityKey, 'Intimidate');
  });

  testWidgets('the in-field ✕ clears the value and does not open the modal',
      (tester) async {
    await openDialog(tester,
        current: const DexSearchFilter(abilityKey: 'Intimidate'));
    expect(find.text(abilityDex['Intimidate']!.localizedName), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(find.text(abilityDex['Intimidate']!.localizedName), findsNothing);
    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.tap(find.text(AppStrings.t('action.apply')));
    await tester.pumpAndSettle();
    expect((result as DexSearchFilter).abilityKey, isNull);
  });

  testWidgets('moves: slots fill in order through the modal; ✕ removes one',
      (tester) async {
    await openDialog(tester);
    expect(hint('dex.advMoveSlot'), findsNWidgets(4));
    await tester.tap(hint('dex.advMoveSlot').first);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'earthquake');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final quake = moves.firstWhere((m) => m.name == 'Earthquake').localizedName;
    expect(find.text(quake), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);

    // Second slot.
    await tester.tap(hint('dex.advMoveSlot').at(1));
    await tester.pumpAndSettle();
    // The first pick is offered again as a recent.
    expect(find.byKey(const ValueKey('search_picker_recent_Earthquake')),
        findsOneWidget);
    await tester.enterText(input, 'outrage');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.clear), findsNWidgets(2));

    // Remove the first slot: the second moves up.
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(find.text(quake), findsNothing);
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.text(AppStrings.t('action.apply')));
    await tester.pumpAndSettle();
    expect((result as DexSearchFilter).moveIds, ['outrage']);
  });

  testWidgets('Esc in the modal leaves the dialog and its draft alone',
      (tester) async {
    await openDialog(tester,
        current: const DexSearchFilter(abilityKey: 'Intimidate'));
    await tester.tap(find.text(abilityDex['Intimidate']!.localizedName));
    await tester.pumpAndSettle();
    expect(input, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(find.text(AppStrings.t('action.apply')), findsOneWidget,
        reason: 'only the modal closed');
    expect(find.text(abilityDex['Intimidate']!.localizedName), findsOneWidget);
  });
}
