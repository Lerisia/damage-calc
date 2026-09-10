import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/hp_percent_input.dart';

void main() {
  test('empty resets to 100', () {
    expect(hpPercentFromInput(''), 100.0);
    expect(hpPercentFromInput('  '), 100.0);
  });
  test('numbers parse and clamp', () {
    expect(hpPercentFromInput('76'), 76.0);
    expect(hpPercentFromInput('6.25'), 6.25);
    expect(hpPercentFromInput('1000'), 999.0);
    expect(hpPercentFromInput('0'), 0.0);
  });
  test('garbage leaves the value alone', () {
    expect(hpPercentFromInput('abc'), isNull);
  });
}
