import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression for the Simple Mode species header.
///
/// Its selector and the mega / dynamax / terastal icons share one Row.
/// A `Spacer` was added there to pin the icons right — but the
/// selector is already `Expanded`, so the two split the free space and
/// the name / search field lost half its width. The selector alone
/// pins the icons right, because it absorbs whatever the type chips
/// take.
///
/// This pins the layout arithmetic rather than the widget tree, so it
/// stays readable without standing up the whole screen.
void main() {
  const rowWidth = 400.0;
  const fixedBefore = 120.0; // sprite, gaps, dex button, type chips

  Future<double> selectorWidth(WidgetTester tester,
      {required bool withSpacer}) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: rowWidth,
          child: Row(children: [
            const SizedBox(width: fixedBefore),
            Expanded(child: SizedBox(key: key, height: 20)),
            if (withSpacer) const Spacer(),
            const SizedBox(width: 26 * 3), // the three mechanic icons
          ]),
        ),
      ),
    ));
    return tester.getSize(find.byKey(key)).width;
  }

  testWidgets('a Spacer beside the Expanded selector halves it',
      (tester) async {
    final without = await selectorWidth(tester, withSpacer: false);
    final with_ = await selectorWidth(tester, withSpacer: true);
    expect(with_, lessThan(without));
    expect(with_, closeTo(without / 2, 0.5),
        reason: 'this is exactly the shrink users reported');
  });

  testWidgets('without one the selector keeps the whole remainder',
      (tester) async {
    final width = await selectorWidth(tester, withSpacer: false);
    expect(width, equals(rowWidth - fixedBefore - 26 * 3));
  });
}
