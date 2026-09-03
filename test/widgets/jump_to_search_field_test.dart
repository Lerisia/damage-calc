import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/jump_to_search_field.dart';

/// The search box moves the list rather than filtering it, so the
/// contract worth pinning is which index it asks for and when.
void main() {
  late List<int> jumps;

  Future<void> pump(
    WidgetTester tester,
    List<int> Function(String) find,
  ) async {
    jumps = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: JumpToSearchField(
          findMatches: find,
          onJump: jumps.add,
        ),
      ),
    ));
  }

  testWidgets('typing jumps to the first match', (tester) async {
    await pump(tester, (q) => [4, 9, 12]);
    await tester.enterText(find.byType(TextField), 'gar');
    await tester.pump();
    expect(jumps, equals([4]));
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('submitting walks to the next match', (tester) async {
    await pump(tester, (q) => [4, 9, 12]);
    await tester.enterText(find.byType(TextField), 'gar');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(jumps, equals([4, 9]));
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('walking past the end wraps around', (tester) async {
    await pump(tester, (q) => [4, 9]);
    await tester.enterText(find.byType(TextField), 'gar');
    for (var i = 0; i < 2; i++) {
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }
    expect(jumps, equals([4, 9, 4]));
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('the up arrow walks backwards, wrapping', (tester) async {
    await pump(tester, (q) => [4, 9, 12]);
    await tester.enterText(find.byType(TextField), 'gar');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pump();
    expect(jumps, equals([4, 12]));
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('a miss reports zero and moves nothing', (tester) async {
    await pump(tester, (q) => const []);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(jumps, isEmpty);
    expect(find.text('0'), findsOneWidget);
    // Stepping a miss must not throw or move the list.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(jumps, isEmpty);
  });

  testWidgets('clearing drops the counter without moving', (tester) async {
    await pump(tester, (q) => [4, 9]);
    await tester.enterText(find.byType(TextField), 'gar');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('1/2'), findsNothing);
    expect(jumps, equals([4]), reason: 'clearing is not a jump');
  });

  testWidgets('an empty query is not searched', (tester) async {
    var calls = 0;
    await pump(tester, (q) {
      calls++;
      return [1];
    });
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(calls, isZero);
    expect(jumps, isEmpty);
  });
}
