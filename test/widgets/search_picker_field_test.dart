import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/views/widgets/search_picker/search_picker.dart';

/// The closed state of a search picker. An optional leading widget (the
/// picked item's icon) sits left of the label without changing the
/// field's height.
void main() {
  Widget host({Widget? leading, String text = 'Life Orb', VoidCallback? onTap}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: SearchPickerField(
                text: text,
                labelText: 'Item',
                leading: leading,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      );

  const icon = SizedBox(key: Key('icon'), width: 20, height: 20);

  testWidgets('the leading widget sits left of the label', (tester) async {
    await tester.pumpWidget(host(leading: icon));
    final iconRect = tester.getRect(find.byKey(const Key('icon')));
    final textRect = tester.getRect(find.text('Life Orb'));
    expect(iconRect.right, lessThanOrEqualTo(textRect.left));
    expect((iconRect.center.dy - textRect.center.dy).abs(), lessThan(1.5),
        reason: 'vertically centred on the text line');
  });

  testWidgets('the field is the same height with and without it', (tester) async {
    await tester.pumpWidget(host());
    final plain = tester.getSize(find.byType(SearchPickerField));
    await tester.pumpWidget(host(leading: icon));
    expect(tester.getSize(find.byType(SearchPickerField)), plain);
  });

  testWidgets('a long label is ellipsized, not wrapped', (tester) async {
    await tester.pumpWidget(host());
    final plain = tester.getSize(find.byType(SearchPickerField));
    await tester.pumpWidget(host(
        leading: icon, text: 'An extremely long item name that cannot fit'));
    expect(tester.getSize(find.byType(SearchPickerField)), plain);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap anywhere on the field fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(leading: icon, onTap: () => taps++));
    await tester.tap(find.byKey(const Key('icon')), warnIfMissed: false);
    await tester.tap(find.text('Life Orb'));
    expect(taps, 2);
  });
}
