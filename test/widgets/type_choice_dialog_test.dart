import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/i18n/app_strings.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/views/widgets/battler_type_chips.dart';
import 'package:damage_calc/views/widgets/move_meta.dart';
import 'package:damage_calc/views/widgets/type_chip.dart';
import 'package:damage_calc/views/widgets/type_filter_dialog.dart';

/// One dialog for picking a single type, and the two small helpers that
/// put type chips next to other facts. All of them draw types with
/// [TypeChip].
void main() {
  Object? result;
  const pending = Object();

  Future<void> open(
    WidgetTester tester, {
    PokemonType? current,
    String? noneLabel,
    bool offerNone = true,
    List<PokemonType> options = kMainTypes,
  }) async {
    result = pending;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showTypeFilterDialog(
                context: context,
                current: current,
                title: 'Pick',
                noneLabel: noneLabel,
                offerNone: offerNone,
                options: options,
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

  Finder option(PokemonType t) => find.byKey(ValueKey('type_option_${t.name}'));
  final none = find.byKey(const ValueKey('type_option_none'));

  group('the single-choice type dialog', () {
    testWidgets('offers every option as a chip, the current one filled',
        (tester) async {
      await open(tester, current: PokemonType.fire, options: kTeraTypes);
      for (final t in kTeraTypes) {
        expect(option(t), findsOneWidget, reason: '$t');
      }
      expect(tester.widget<TypeChip>(option(PokemonType.fire)).selected, isTrue);
      expect(tester.widget<TypeChip>(option(PokemonType.water)).selected, isFalse);
      expect(option(PokemonType.typeless), findsNothing);
    });

    testWidgets('a tap returns the type and closes', (tester) async {
      await open(tester);
      await tester.tap(option(PokemonType.dragon));
      await tester.pumpAndSettle();
      expect(result, PokemonType.dragon);
      expect(option(PokemonType.dragon), findsNothing);
    });

    testWidgets('the none row returns null; closing returns the dismissed sentinel',
        (tester) async {
      await open(tester, current: PokemonType.fire, noneLabel: 'No Tera');
      expect(find.text('No Tera'), findsOneWidget);
      await tester.tap(none);
      await tester.pumpAndSettle();
      expect(result, isNull);

      await open(tester, current: PokemonType.fire);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(identical(result, kTypeFilterDismissed), isTrue);
    });

    testWidgets('offerNone: false has no none row', (tester) async {
      await open(tester, offerNone: false);
      expect(none, findsNothing);
    });

    testWidgets('showTypeChoiceDialog: the pick, or null when closed',
        (tester) async {
      PokemonType? picked = PokemonType.normal;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showTypeChoiceDialog(
                    context: context, title: 'Pick', options: PokemonType.values);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Typeless is a pickable move type here, as a neutral chip.
      expect(find.text(AppStrings.t('type.none')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });
  });

  group('BattlerTypeChips', () {
    Future<void> pump(WidgetTester tester, BattlePokemonState s) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(body: Center(child: BattlerTypeChips(s)))));
    List<PokemonType> shown(WidgetTester tester) =>
        [for (final c in tester.widgetList<TypeChip>(find.byType(TypeChip))) c.type];

    testWidgets('one chip per type', (tester) async {
      await pump(tester, BattlePokemonState(type1: PokemonType.dragon, type2: PokemonType.ground));
      expect(shown(tester), [PokemonType.dragon, PokemonType.ground]);
      await pump(tester, BattlePokemonState(type1: PokemonType.water, type2: null));
      expect(shown(tester), [PokemonType.water]);
    });

    testWidgets('Terastallized: the Tera type alone, tagged', (tester) async {
      await pump(
          tester,
          BattlePokemonState(
              type1: PokemonType.dragon,
              type2: PokemonType.flying,
              terastal: const TerastalState(active: true, teraType: PokemonType.normal)));
      expect(shown(tester), [PokemonType.normal]);
      expect(find.textContaining(AppStrings.t('label.terastalShort')), findsOneWidget);
    });

    testWidgets('Stellar Tera keeps the original types', (tester) async {
      await pump(
          tester,
          BattlePokemonState(
              type1: PokemonType.dragon,
              type2: PokemonType.flying,
              terastal: const TerastalState(active: true, teraType: PokemonType.stellar)));
      expect(shown(tester), [PokemonType.dragon, PokemonType.flying]);
    });
  });

  group('MoveMeta', () {
    const quake = Move(
      name: 'Earthquake', nameKo: '지진', nameJa: 'じしん',
      type: PokemonType.ground, category: MoveCategory.physical,
      power: 100, accuracy: 100, pp: 10,
    );
    const dance = Move(
      name: 'Swords Dance', nameKo: '칼춤', nameJa: 'つるぎのまい',
      type: PokemonType.normal, category: MoveCategory.status,
      power: 0, accuracy: 0, pp: 20,
    );

    testWidgets('a type chip, then category and power; a status move shows a dash',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: Column(children: [MoveMeta(quake), MoveMeta(dance)]))));
      final chips = tester.widgetList<TypeChip>(find.byType(TypeChip)).toList();
      expect(chips.map((c) => c.type), [PokemonType.ground, PokemonType.normal]);
      expect(find.textContaining('100'), findsOneWidget);
      expect(find.textContaining('—'), findsOneWidget);
      // Fixed columns: both rows are the same width, so chips line up.
      final w = [for (final e in find.byType(MoveMeta).evaluate()) e.size!.width];
      expect(w, hasLength(2));
      expect(w[0], w[1]);
    });

    testWidgets('dimmed passes through to the chip', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: MoveMeta(quake, dimmed: true))));
      expect(tester.widget<TypeChip>(find.byType(TypeChip)).dimmed, isTrue);
    });
  });
}
