import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/coverage_display_controller.dart';
import 'package:damage_calc/views/widgets/coverage_display_toggle.dart';
import 'package:damage_calc/views/widgets/matchup_badge.dart';
import 'package:damage_calc/views/widgets/type_chart_sheet.dart';

/// The built-in type chart shares its cell rendering with the party
/// coverage matrix and the dex matchup chart, and reads the same
/// persisted numeric/symbolic setting — so all three always look
/// alike and honour one toggle.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TypeChartSheet()),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    // Each test starts from the shared default.
    CoverageDisplayController.instance.mode.value =
        CoverageDisplayMode.numeric;
  });

  testWidgets('cells render through the shared MatchupBadge', (tester) async {
    await pump(tester);
    expect(find.byType(MatchupBadge), findsWidgets);
  });

  testWidgets('the numeric/symbolic toggle is offered', (tester) async {
    await pump(tester);
    expect(find.byType(CoverageDisplayToggle), findsOneWidget);
  });

  testWidgets('numeric mode shows fractions, not symbols', (tester) async {
    await pump(tester);
    // Fire → Water is ½ ; Normal → Ghost is immune.
    expect(find.text('½'), findsWidgets);
    expect(find.text('△'), findsNothing);
  });

  testWidgets('flipping the shared setting re-renders as symbols',
      (tester) async {
    await pump(tester);
    CoverageDisplayController.instance.mode.value =
        CoverageDisplayMode.symbolic;
    await tester.pumpAndSettle();
    expect(find.text('△'), findsWidgets);
    expect(find.text('½'), findsNothing);
  });
}
