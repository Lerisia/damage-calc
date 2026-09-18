import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/search/hp_percent_input.dart';

void main() {
  test('empty resets to full', () {
    expect(currentHpFromInput('', 187), 187);
    expect(currentHpFromInput('  ', 187), 187);
  });
  test('a plain number is real HP, clamped to 150 % of max', () {
    expect(currentHpFromInput('94', 187), 94);
    expect(currentHpFromInput('0', 187), 0);
    expect(currentHpFromInput('224', 187), 224);
    expect(currentHpFromInput('999', 187), 280);
    expect(currentHpFromInput('93.6', 187), 94);
  });
  test('a trailing % is a share, snapped to the nearest HP', () {
    expect(currentHpFromInput('40%', 187), 75);
    expect(currentHpFromInput('50 %', 175), 88);
    expect(currentHpFromInput('150%', 187), 280);
    expect(currentHpFromInput('200%', 187), 280);
  });
  test('garbage leaves the value alone', () {
    expect(currentHpFromInput('abc', 187), isNull);
    expect(currentHpFromInput('%', 187), isNull);
  });
  test('percent mode: a plain number is a share, snapped to a real HP', () {
    expect(currentHpFromInput('33', 175, percent: true), 58); // 57.75
    expect(currentHpFromInput('50', 175, percent: true), 88);
    expect(currentHpFromInput('6.25', 160, percent: true), 10);
    expect(currentHpFromInput('', 175, percent: true), 175);
    expect(currentHpFromInput('150', 187, percent: true), 280);
    expect(currentHpFromInput('999', 187, percent: true), 280);
  });
  test('formatHpPercent trims like the old chip did', () {
    expect(formatHpPercent(94), '94');
    expect(formatHpPercent(6.25), '6.25');
    expect(formatHpPercent(6.5), '6.5');
    expect(formatHpPercent(32.7869), '32.79');
  });
}
