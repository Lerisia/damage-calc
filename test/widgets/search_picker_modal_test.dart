import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/views/widgets/search_picker/search_picker.dart';

/// The search modal every search→pick field is moving onto.
///
/// It replaces the search-box-plus-dropdown: a tap opens it with the
/// cursor already in the search box, results show as a list or (when
/// the kind has images) a grid, and recent picks sit in a strip at the
/// bottom. The ranking is the caller's — the modal only presents it.
void main() {
  const corpus = ['apple', 'apricot', 'avocado', 'banana', 'cherry'];

  late String? result;
  late bool closed;

  SearchPickerConfig<String> config({required bool images}) =>
      SearchPickerConfig<String>(
        kind: 'fruit',
        hintText: 'Search fruit',
        suggestions: (q) => q.trim().isEmpty
            ? corpus
            : corpus.where((s) => s.startsWith(q.trim())).toList(),
        labelOf: (s) => s,
        idOf: (s) => s,
        fromId: (id) => corpus.contains(id) ? id : null,
        imageOf: images
            ? (context, s, size) =>
                SizedBox(width: size, height: size, child: const Placeholder())
            : null,
      );

  Widget host({bool images = false}) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showSearchPicker<String>(
                      context, config(images: images));
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  final input = find.byKey(const Key('search_picker_input'));
  Finder tile(String id) => find.byKey(ValueKey('search_picker_item_$id'));
  Finder recent(String id) => find.byKey(ValueKey('search_picker_recent_$id'));

  Future<void> open(WidgetTester tester, {bool images = false}) async {
    await tester.pumpWidget(host(images: images));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    result = null;
    closed = false;
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
  });

  testWidgets('opens with the cursor in the search box and the default list',
      (tester) async {
    await open(tester);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue,
        reason: 'no second tap before typing');
    for (final s in corpus) {
      expect(tile(s), findsOneWidget);
    }
  });

  testWidgets('typing filters; Enter picks the top hit', (tester) async {
    await open(tester);
    await tester.enterText(input, 'ap');
    await tester.pump();
    expect(tile('apple'), findsOneWidget);
    expect(tile('apricot'), findsOneWidget);
    expect(tile('banana'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'apple');
    expect(input, findsNothing);
  });

  testWidgets('Enter on an empty query picks nothing and stays open',
      (tester) async {
    await open(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(input, findsOneWidget);
  });

  testWidgets('↓ moves the highlight and Enter picks it', (tester) async {
    await open(tester);
    await tester.enterText(input, 'a');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'apricot');
  });

  testWidgets('↓ on the default list starts at the first row', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'apple');
  });

  testWidgets('a tap picks; closing without a pick returns null',
      (tester) async {
    await open(tester);
    await tester.tap(tile('banana'));
    await tester.pumpAndSettle();
    expect(result, 'banana');

    closed = false;
    result = 'stale';
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search_picker_close')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('a pick shows up in the recent strip next time, and picks from there',
      (tester) async {
    await open(tester);
    expect(find.text('Recent'), findsNothing);
    expect(find.text('최근'), findsNothing);
    await tester.tap(tile('cherry'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(recent('cherry'), findsOneWidget);
    // Still there while a query that doesn't match it is typed.
    await tester.enterText(input, 'ap');
    await tester.pump();
    expect(recent('cherry'), findsOneWidget);
    result = null;
    await tester.tap(recent('cherry'));
    await tester.pumpAndSettle();
    expect(result, 'cherry');
  });

  testWidgets('a text-only kind has no list / grid toggle', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('search_picker_view_grid')), findsNothing);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('a kind with images can switch to a grid, and the choice sticks',
      (tester) async {
    await open(tester, images: true);
    expect(find.byType(GridView), findsNothing);
    await tester.tap(find.byKey(const Key('search_picker_view_grid')));
    await tester.pump();
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(tile('banana'));
    await tester.pumpAndSettle();
    expect(result, 'banana');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget,
        reason: 'the view mode is remembered for the kind');
    await tester.tap(find.byKey(const Key('search_picker_view_list')));
    await tester.pump();
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('the modal keeps its size while the result count changes',
      (tester) async {
    await open(tester);
    final before = tester.getSize(find.byType(Dialog));
    await tester.enterText(input, 'cherr');
    await tester.pump();
    expect(tester.getSize(find.byType(Dialog)), before);
    await tester.enterText(input, 'zzz');
    await tester.pump();
    expect(find.byType(InkWell).evaluate().where((e) {
      final k = e.widget.key;
      return k is ValueKey<String> && k.value.startsWith('search_picker_item_');
    }), isEmpty);
    expect(tester.getSize(find.byType(Dialog)), before);
  });

  group('list-row extras', () {
    SearchPickerConfig<String> rich({bool recents = true}) =>
        SearchPickerConfig<String>(
          kind: 'fruit',
          hintText: 'Search fruit',
          suggestions: (q) => corpus,
          labelOf: (s) => s,
          idOf: (s) => s,
          fromId: (id) => corpus.contains(id) ? id : null,
          descriptionOf: (s) => s == 'apple' ? 'keeps the doctor away' : null,
          trailingOf: (context, s) => Text('T:$s'),
          showRecents: recents,
        );

    Future<void> openRich(WidgetTester tester, {bool recents = true}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showSearchPicker<String>(
                    context, rich(recents: recents));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a description line and a trailing widget render on the row',
        (tester) async {
      await openRich(tester);
      expect(find.text('keeps the doctor away'), findsOneWidget);
      expect(find.text('T:banana'), findsOneWidget);
      // The description sits under its label, inside the same row.
      final row = tester.getRect(tile('apple'));
      final desc = tester.getRect(find.text('keeps the doctor away'));
      expect(desc.top, greaterThan(tester.getRect(find.text('apple')).top));
      expect(desc.bottom, lessThanOrEqualTo(row.bottom));
    });

    testWidgets('showRecents: false — no strip, and picks are not recorded',
        (tester) async {
      await openRich(tester, recents: false);
      await tester.tap(tile('cherry'));
      await tester.pumpAndSettle();
      expect(result, 'cherry');
      expect(SearchPickerPrefs.instance.recents('fruit'), isEmpty);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(recent('cherry'), findsNothing);
    });
  });
}
