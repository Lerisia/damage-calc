import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/data/champions_moves.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/views/widgets/move_selector.dart';

/// A move slot on the search modal: closed it shows the move (or the
/// Max / Z name in the accent colour); the modal lists moves with type,
/// category and power, and Enter picks the top hit.
void main() {
  late List<Move> picked;

  Future<void> pumpSelector(WidgetTester tester,
      {String? initial = 'Earthquake', String? override}) async {
    await tester.runAsync(() async {
      await loadAllMoves();
      await loadChampionsUsage();
      await loadChampionsMoves();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MoveSelector(
          initialMoveName: initial,
          displayNameOverride: override,
          forceShowStatus: true,
          onSelected: picked.add,
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  final input = find.byKey(const Key('search_picker_input'));

  setUp(() async {
    picked = [];
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
  });

  testWidgets('closed: shows the current move, no text box', (tester) async {
    await pumpSelector(tester);
    expect(find.text('지진'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a Max / Z name replaces the label in the accent colour',
      (tester) async {
    await pumpSelector(tester, override: '다이어스');
    final text = tester.widget<Text>(find.text('다이어스'));
    expect(text.style?.color, Colors.red.shade700);
    expect(find.text('지진'), findsNothing);
  });

  testWidgets('tap → modal; the current move leads with its type / category / power; Enter picks the top hit',
      (tester) async {
    await pumpSelector(tester);
    await tester.tap(find.byType(MoveSelector));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('search_picker_item_Earthquake'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('100', findRichText: true)),
        findsWidgets);
    await tester.enterText(input, '역린');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(picked.single.name, 'Outrage');
    expect(find.text('역린'), findsOneWidget);
  });

  testWidgets('Esc closes without a pick', (tester) async {
    await pumpSelector(tester);
    await tester.tap(find.byType(MoveSelector));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(picked, isEmpty);
  });
}
