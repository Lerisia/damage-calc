import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/search/hp_percent_input.dart';

void main() {
  test('empty resets to full', () {
    expect(currentHpFromInput('', 187), 187);
    expect(currentHpFromInput('  ', 187), 187);
  });
  test('a plain number is real HP, clamped to max', () {
    expect(currentHpFromInput('94', 187), 94);
    expect(currentHpFromInput('0', 187), 0);
    expect(currentHpFromInput('999', 187), 187);
    expect(currentHpFromInput('93.6', 187), 94);
  });
  test('a trailing % is a share, snapped to the nearest HP', () {
    expect(currentHpFromInput('40%', 187), 75);
    expect(currentHpFromInput('50 %', 175), 88);
    expect(currentHpFromInput('150%', 187), 187);
  });
  test('garbage leaves the value alone', () {
    expect(currentHpFromInput('abc', 187), isNull);
    expect(currentHpFromInput('%', 187), isNull);
  });
}
