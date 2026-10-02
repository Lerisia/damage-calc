import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';
import 'package:damage_calc/views/widgets/search_picker/keyboard_primer.dart';
import 'package:damage_calc/views/widgets/search_picker/search_picker.dart';

/// A mobile browser raises its keyboard only for a focus that happens
/// while the tap is still being handled. The search modal is built a
/// frame after the tap, so on the web its autofocus got the cursor but
/// no keyboard. The tap handler therefore opens a text input connection
/// itself — at once — and the search box takes it over a frame later.
void main() {
  const corpus = ['apple', 'apricot', 'banana'];

  SearchPickerConfig<String> config() => SearchPickerConfig<String>(
        kind: 'fruit',
        hintText: 'Search fruit',
        suggestions: (q) => q.trim().isEmpty
            ? corpus
            : corpus.where((s) => s.startsWith(q.trim())).toList(),
        labelOf: (s) => s,
        idOf: (s) => s,
        fromId: (id) => corpus.contains(id) ? id : null,
      );

  Widget host() => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showSearchPicker<String>(context, config()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  final input = find.byKey(const Key('search_picker_input'));
  Finder tile(String id) => find.byKey(ValueKey('search_picker_item_$id'));

  List<String> calls(WidgetTester tester) =>
      [for (final c in tester.testTextInput.log) c.method];

  int clientIdOf(MethodCall setClient) =>
      (setClient.arguments as List<dynamic>).first as int;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SearchPickerPrefs.instance.load();
    KeyboardPrimer.debugEnabled = true;
  });

  tearDown(() => KeyboardPrimer.debugEnabled = null);

  testWidgets('the tap itself opens the keyboard — before the modal exists',
      (tester) async {
    await tester.pumpWidget(host());
    tester.testTextInput.log.clear();

    // No pump after the tap: nothing has been built yet.
    await tester.tap(find.text('open'));

    expect(input, findsNothing);
    expect(calls(tester), containsAllInOrder(['TextInput.setClient', 'TextInput.show']));
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('the search box takes the connection over without the '
      'keyboard going down in between', (tester) async {
    await tester.pumpWidget(host());
    tester.testTextInput.log.clear();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final setClients = tester.testTextInput.log
        .where((c) => c.method == 'TextInput.setClient')
        .toList();
    expect(setClients, hasLength(2));
    expect(clientIdOf(setClients[0]), isNot(clientIdOf(setClients[1])));
    expect(calls(tester), isNot(contains('TextInput.hide')));
    expect(calls(tester), isNot(contains('TextInput.clearClient')));
    expect(tester.testTextInput.isVisible, isTrue);

    // What is typed now goes to the search box.
    tester.testTextInput.enterText('ap');
    await tester.pump();
    expect(tile('apple'), findsOneWidget);
    expect(tile('banana'), findsNothing);
  });

  testWidgets('dismissing the modal takes the keyboard down', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(input, findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('picking takes the keyboard down', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(tile('apricot'));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('released with nobody having taken over → its own connection '
      'is closed', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      }),
    ));

    final primer = KeyboardPrimer.prime(context);
    expect(primer, isNotNull);
    expect(tester.testTextInput.isVisible, isTrue);

    primer!.release();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);

    // A second release is harmless.
    primer.release();
  });

  testWidgets('released after a text field took over → that field keeps the '
      'keyboard', (tester) async {
    late BuildContext context;
    var showField = false;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (c, setState) {
          context = c;
          rebuild = setState;
          return showField
              ? const TextField(autofocus: true)
              : const SizedBox();
        }),
      ),
    ));

    final primer = KeyboardPrimer.prime(context)!;
    rebuild(() => showField = true);
    await tester.pumpAndSettle();

    primer.release();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });

  testWidgets('off (the native apps): the tap opens no connection of its own',
      (tester) async {
    KeyboardPrimer.debugEnabled = false;
    await tester.pumpWidget(host());
    tester.testTextInput.log.clear();

    await tester.tap(find.text('open'));
    expect(calls(tester), isEmpty);

    // The search box still gets the cursor and the keyboard by itself.
    await tester.pumpAndSettle();
    expect(calls(tester).where((m) => m == 'TextInput.setClient'), hasLength(1));
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
