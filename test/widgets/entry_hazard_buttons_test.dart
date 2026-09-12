import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/entry_hazard_buttons.dart';

/// The shared 스록 mini-button: every tap fires, as many times as tapped.
void main() {
  testWidgets('every tap fires', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StealthRockButton(onTap: () => taps++))));
    await tester.tap(find.text('스록'));
    await tester.tap(find.text('스록'));
    await tester.tap(find.text('스록'));
    expect(taps, 3);
  });
}
