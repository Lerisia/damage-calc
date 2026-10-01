import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/i18n/app_strings.dart';
import 'package:damage_calc/i18n/localization.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/views/widgets/type_chip.dart';

/// The one type chip. Its variants are parameters of a single shape —
/// these pin the parts other screens rely on.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<Container>(find.byType(Container).first).decoration!
          as BoxDecoration;
  TextStyle textStyle(WidgetTester tester, String label) =>
      tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

  testWidgets('a display chip: type colour fill, bold white name', (tester) async {
    await pump(tester, const TypeChip(PokemonType.fire));
    final name = KoStrings.getTypeName(PokemonType.fire);
    expect(decoration(tester).color, KoStrings.getTypeColor(PokemonType.fire));
    expect(decoration(tester).border, isNull);
    expect(textStyle(tester, name).color, Colors.white);
    expect(textStyle(tester, name).fontWeight, FontWeight.bold);
  });

  testWidgets('three sizes of one shape', (tester) async {
    final heights = <TypeChipSize, double>{};
    for (final s in TypeChipSize.values) {
      await pump(tester, TypeChip(PokemonType.water, size: s));
      heights[s] = tester.getSize(find.byType(TypeChip)).height;
    }
    expect(heights[TypeChipSize.dense]!, lessThan(heights[TypeChipSize.regular]!));
    expect(heights[TypeChipSize.regular]!, lessThan(heights[TypeChipSize.large]!));
  });

  testWidgets('a picker option keeps its size between off and on', (tester) async {
    await pump(tester, TypeChip.option(PokemonType.grass, selected: false, onTap: () {}));
    final off = tester.getSize(find.byType(TypeChip));
    final offDeco = decoration(tester);
    expect(offDeco.color, isNot(KoStrings.getTypeColor(PokemonType.grass)),
        reason: 'off = tinted, not filled');
    await pump(tester, TypeChip.option(PokemonType.grass, selected: true, onTap: () {}));
    expect(tester.getSize(find.byType(TypeChip)), off);
    expect(decoration(tester).color, KoStrings.getTypeColor(PokemonType.grass));
  });

  testWidgets('a ring or a corner dot does not change the chip\'s size',
      (tester) async {
    await pump(tester, const TypeChip.dense(PokemonType.dragon));
    final plain = tester.getSize(find.byType(TypeChip));
    await pump(tester,
        const TypeChip.dense(PokemonType.dragon, ringColor: Colors.white));
    expect(tester.getSize(find.byType(TypeChip)), plain);
    await pump(tester,
        const TypeChip.dense(PokemonType.dragon, dotColor: Colors.orange));
    expect(tester.getSize(find.byType(TypeChip)), plain);
  });

  testWidgets('a fixed-width chip is as tall as a free one, even in a tall row',
      (tester) async {
    await pump(tester, const TypeChip.dense(PokemonType.dragon));
    final free = tester.getSize(find.byType(TypeChip)).height;
    // A 44 px list row: the chip must not stretch to fill it.
    await pump(
        tester,
        const SizedBox(
          height: 44,
          width: 200,
          child: Row(children: [TypeChip.dense(PokemonType.dragon, width: 50)]),
        ));
    expect(tester.getSize(find.byType(TypeChip)).height, free);
    expect(tester.getSize(find.byType(TypeChip)).width, 50);
  });

  testWidgets('fixed width: every type is the same width and nothing overflows',
      (tester) async {
    for (final lang in AppLanguage.values) {
      AppStrings.setLanguageForTest(lang);
      for (final t in PokemonType.values) {
        await pump(tester, TypeChip.dense(t, width: 40));
        expect(tester.getSize(find.byType(TypeChip)).width, 40,
            reason: '$t in $lang');
        expect(tester.takeException(), isNull, reason: '$t in $lang');
      }
    }
    AppStrings.setLanguageForTest(AppLanguage.ko);
  });

  testWidgets('typeless is a neutral "none" chip', (tester) async {
    await pump(tester, const TypeChip.dense(PokemonType.typeless));
    expect(find.text(AppStrings.t('type.none')), findsOneWidget);
  });

  testWidgets('onTap fires; a chip without one is inert', (tester) async {
    var taps = 0;
    await pump(tester, TypeChip.dense(PokemonType.ice, onTap: () => taps++));
    await tester.tap(find.byType(TypeChip));
    expect(taps, 1);
    await pump(tester, const TypeChip.dense(PokemonType.ice));
    expect(find.byType(GestureDetector), findsNothing);
  });
}
