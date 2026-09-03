import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/utils/speed_tier_display_controller.dart';
import 'package:damage_calc/views/widgets/champions_speed_tier_sheet.dart';
import 'package:damage_calc/views/widgets/jump_to_search_field.dart';

/// The speed tier sheet has to keep working once it's driving a
/// positioned list from a search box — the two sheets are the only
/// callers, so a break here is invisible until someone opens them.
void main() {
  setUp(() {
    SpeedTierDisplayController.instance.mode.value =
        SpeedTierDisplayMode.base;
  });

  Future<void> pump(WidgetTester tester) async {
    // Prime the dex / usage caches on the real async loop first —
    // pump() drives fake time and never lets the asset reads finish,
    // so the sheet's FutureBuilder would sit on its spinner forever.
    // Once cached, the future resolves in a microtask.
    await tester.runAsync(() async {
      await loadPokedex();
      await loadChampionsUsage();
    });
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ChampionsSpeedTierSheet()),
    ));
    // Rows arrive from a FutureBuilder over the dex + usage data.
    // pumpAndSettle can't be used: the loading spinner animates
    // forever, so it never settles. Pump until the list appears.
    for (var i = 0; i < 60 && find.byType(JumpToSearchField).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('renders a searchable positioned list', (tester) async {
    await pump(tester);
    expect(find.byType(JumpToSearchField), findsOneWidget);
    expect(find.byType(ScrollablePositionedList), findsOneWidget);
  });

  testWidgets('searching finds a Pokémon and reports a position',
      (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'garchomp');
    await tester.pump();
    // Base mode lists each species once, but a query can still match
    // several species (Garchomp / Mega Garchomp / Mega Garchomp Z).
    final counter = tester.widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .firstWhere((d) => d != null && d.startsWith('1/'));
    expect(counter, isNotNull);
  });

  testWidgets('a miss reports zero', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'zzzznope');
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('realized mode gives a Pokémon several positions',
      (tester) async {
    SpeedTierDisplayController.instance.mode.value =
        SpeedTierDisplayMode.realized;
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'garchomp');
    await tester.pump();
    // Three spreads at minimum, so the counter must show more than one
    // — this is the case the row-per-appearance indexing exists for.
    expect(find.text('1/1'), findsNothing);
    expect(find.textContaining('1/'), findsOneWidget);
  });
}
