import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/typeahead_helpers.dart';

/// Every search→pick field in the app follows one rule: Enter picks the
/// first suggestion currently shown; an empty query picks nothing.
/// Until 2026-09-12 this lived as a copy-pasted `onSubmittedPick` at
/// each call site, and the dex filter dialog's ability / move fields
/// were missing it — Enter there just dropped focus and the wrapper's
/// focus-loss handler wiped the query. The rule is now the helper's
/// default so no call site can forget it.
void main() {
  List<String> fruits(String q) =>
      ['apple', 'apricot', 'banana'].where((s) => s.startsWith(q)).toList();

  group('typeAheadPickTop (the rule)', () {
    test('picks the first suggestion for the typed text', () {
      expect(typeAheadPickTop('ap', fruits), 'apple');
      expect(typeAheadPickTop('b', fruits), 'banana');
    });
    test('empty or blank query picks nothing', () {
      expect(typeAheadPickTop('', fruits), isNull);
      expect(typeAheadPickTop('   ', fruits), isNull);
    });
    test('no match picks nothing', () {
      expect(typeAheadPickTop('zzz', fruits), isNull);
    });
  });

  // Widget level: Enter on the field built by buildTypeAhead reaches
  // onSelected through the default rule without any call-site code.
  // flutter_typeahead's dropdown overlay trips an AnimatedSize layout
  // assertion under the test binding (it re-dirties itself during
  // performLayout when the zero-duration open animation fires); that
  // is the package's overlay, not the Enter path, so each pump drains
  // it — and only it — with takeException.
  group('buildTypeAhead wires Enter to the rule', () {
    Future<void> pumpDraining(WidgetTester tester) async {
      await tester.pump();
      final e = tester.takeException();
      // The overlay fires the assertion twice per frame; the binding
      // then hands back only its "Multiple exceptions (2)" summary.
      if (e != null) {
        expect('$e', anyOf(contains('RenderAnimatedSize'),
            startsWith('Multiple exceptions (2)')));
      }
    }

    Widget host(TextEditingController ctl, void Function(String) onSelected) {
      return MaterialApp(
        home: Scaffold(
          body: buildTypeAhead<String>(
            controller: ctl,
            suggestionsCallback: fruits,
            itemBuilder: (_, s) => Text(s),
            onSelected: onSelected,
            decoration: const InputDecoration(),
          ),
        ),
      );
    }

    Future<String?> submit(WidgetTester tester, String text) async {
      final ctl = TextEditingController();
      String? picked;
      await tester.pumpWidget(host(ctl, (s) => picked = s));
      await tester.tap(find.byType(TextField));
      await pumpDraining(tester);
      if (text.isNotEmpty) {
        await tester.enterText(find.byType(TextField), text);
        await pumpDraining(tester);
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpDraining(tester);
      return picked;
    }

    testWidgets('Enter picks the first shown suggestion', (tester) async {
      expect(await submit(tester, 'ap'), 'apple');
    });
    testWidgets('Enter on an empty query picks nothing', (tester) async {
      expect(await submit(tester, ''), isNull);
    });
    testWidgets('Enter with no match picks nothing', (tester) async {
      expect(await submit(tester, 'zzz'), isNull);
    });

    // A caller with its own text field (the calculator's move selector)
    // gets the bound Enter handler from the builder instead of writing
    // a local pick — so it follows the same rule.
    testWidgets('a custom builder receives the same Enter handler', (tester) async {
      final ctl = TextEditingController();
      String? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: buildTypeAhead<String>(
            controller: ctl,
            suggestionsCallback: fruits,
            itemBuilder: (_, s) => Text(s),
            onSelected: (s) => picked = s,
            decoration: const InputDecoration(),
            builder: (context, controller, focusNode, onSubmitted) => TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(TextField));
      await pumpDraining(tester);
      await tester.enterText(find.byType(TextField), 'b');
      await pumpDraining(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpDraining(tester);
      expect(picked, 'banana');
    });
  });
}
