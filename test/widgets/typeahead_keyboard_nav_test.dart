import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/typeahead_helpers.dart';

/// Keyboard navigation through a typeahead's suggestions.
///
/// flutter_typeahead moves focus from the text field INTO the
/// suggestions box on ↓ (items are focusable), and back on ↑. Our field
/// wrapper used to treat any focus loss as "the user tapped away" and
/// restored the previous value, which re-ran the search and replaced
/// the list under the user's cursor — so arrow keys never worked. The
/// wrapper now scopes its save/clear/restore session to the
/// SuggestionsController's blur ↔ (field | box) transitions.
void main() {
  // flutter_typeahead's overlay trips an AnimatedSize layout assertion
  // under the test binding; drain it (and only it) after each pump.
  Future<void> pump(WidgetTester t, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await t.pump();
      final e = t.takeException();
      if (e != null) {
        expect('$e', anyOf(contains('RenderAnimatedSize'), startsWith('Multiple exceptions')));
      }
    }
  }

  Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
    await t.sendKeyDownEvent(k);
    await t.sendKeyUpEvent(k);
    await pump(t, 2);
  }

  late TextEditingController ctl;
  late List<String> picked;

  Widget host() => MaterialApp(
        home: Scaffold(
          body: buildTypeAhead<String>(
            controller: ctl,
            suggestionsCallback: (q) =>
                ['apple', 'apricot', 'banana'].where((s) => s.startsWith(q)).toList(),
            itemBuilder: (_, s) => Padding(padding: const EdgeInsets.all(8), child: Text(s)),
            onSelected: (s) {
              picked.add(s);
              ctl.text = s;
              FocusManager.instance.primaryFocus?.unfocus();
            },
            decoration: const InputDecoration(),
          ),
        ),
      );

  setUp(() {
    ctl = TextEditingController(text: 'banana'); // the field's current pick
    picked = [];
  });

  Future<void> typeQuery(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byType(TextField));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'ap');
    await pump(tester);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('apricot'), findsOneWidget);
  }

  testWidgets('↓ keeps the query and the list; Enter picks the focused item', (tester) async {
    await typeQuery(tester);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(ctl.text, 'ap', reason: 'moving into the list must not rewrite the query');
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('apricot'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.enter);
    expect(picked, ['apple']);
  });

  testWidgets('↓↓ then Enter picks the second suggestion', (tester) async {
    await typeQuery(tester);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.enter);
    expect(picked, ['apricot']);
  });

  testWidgets('↓ then ↑ returns to the field with the query intact', (tester) async {
    await typeQuery(tester);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(ctl.text, 'ap');
    expect(find.text('apple'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isA<Focus>());
  });

  testWidgets('tapping away without a pick still restores the previous value', (tester) async {
    await typeQuery(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await pump(tester, 2);
    expect(ctl.text, 'banana');
    expect(picked, isEmpty);
  });
}
