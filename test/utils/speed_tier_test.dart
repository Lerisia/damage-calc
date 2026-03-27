import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/speed_tier.dart';
import 'package:damage_calc/utils/app_strings.dart';

void main() {
  group('SpeedTierTable.describe format', () {
    late SpeedTierTable table;

    setUp(() {
      table = SpeedTierTable.forLevel(50);
    });

    test('Korean format includes 족 suffix', () {
      AppStrings.setLanguageForTest(AppLanguage.ko);
      // 최속100족 = 167, so 168 should outspeed it
      final desc = table.describe(168);
      expect(desc, contains('족'));
      expect(desc, contains('최속'));
    });

    test('Japanese format includes 族 suffix', () {
      AppStrings.setLanguageForTest(AppLanguage.ja);
      final desc = table.describe(168);
      expect(desc, contains('族'));
      expect(desc, contains('最速'));
    });

    test('English format uses base keyword', () {
      AppStrings.setLanguageForTest(AppLanguage.en);
      final desc = table.describe(168);
      expect(desc, contains('base'));
      expect(desc, contains('+Spe'));
    });

    test('English ties format', () {
      AppStrings.setLanguageForTest(AppLanguage.en);
      // 최속100족 = 167
      final desc = table.describe(167);
      expect(desc, contains('Ties'));
      expect(desc, contains('+Spe'));
    });

    test('English outspeeds format', () {
      AppStrings.setLanguageForTest(AppLanguage.en);
      // Just verify the describe output contains expected English keywords
      final desc = table.describe(201);
      // Should contain either Outspeeds or Ties with proper format
      expect(desc, matches(RegExp(r'(Outspeeds|Ties) \+Spe base \d+')));
    });
  });
}
