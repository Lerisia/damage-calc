import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/dismiss_keyboard.dart';

/// Tapping outside a search box has to close the keyboard. Nothing in
/// Flutter does this by default, and in a dialog there is usually no
/// other field to move focus to, so the keyboard covers the very list
/// the user opened the search to read.
void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onButton}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DismissKeyboard(
          child: Column(
            children: [
              const TextField(),
              TextButton(
                onPressed: onButton ?? () {},
                child: const Text('press me'),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    ));
  }

  testWidgets('tapping blank space drops focus', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.byType(SizedBox).last, warnIfMissed: false);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus;
    expect(focus is FocusScopeNode || focus?.context == null, isTrue,
        reason: 'focus should fall back to the scope, not another field');
  });

  testWidgets('buttons underneath still receive their taps',
      (tester) async {
    // The wrapper is opaque, so it must not swallow the screen's own
    // controls — that would be worse than the bug it fixes.
    var pressed = 0;
    await pump(tester, onButton: () => pressed++);
    await tester.tap(find.text('press me'));
    await tester.pump();
    expect(pressed, equals(1));
  });

  testWidgets('typing still works through the wrapper', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'garchomp');
    await tester.pump();
    expect(find.text('garchomp'), findsOneWidget);
  });
}
