import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/app_strings.dart';
import 'package:damage_calc/utils/speed_tier_variants.dart';

/// The Choice Scarf icon ships in the sprite pack, so it can be
/// missing — a user who never imported a pack, or one on a pack from
/// before items/ existed. When it is, the label has to say "Scarf"
/// itself: otherwise a 준스카프 chip reads exactly like the plain
/// 준보정 chip sitting at a different speed, and the table quietly
/// lies about which spread reaches that number.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppStrings.setLanguageForTest(AppLanguage.ko);
  });

  group('with the icon present', () {
    test('scarf tiers show only the spread, the icon carries the rest', () {
      expect(speedVariantLabel(SpeedVariantKind.scarfInvested, withIcon: true),
          equals('준보정'));
      expect(speedVariantLabel(SpeedVariantKind.scarfBoosted, withIcon: true),
          equals('극보정'));
    });
  });

  group('without the icon', () {
    test('scarf tiers name the Scarf', () {
      expect(speedVariantLabel(SpeedVariantKind.scarfInvested, withIcon: false),
          equals('준스카프'));
      expect(speedVariantLabel(SpeedVariantKind.scarfBoosted, withIcon: false),
          equals('극스카프'));
    });

    test('scarf labels stay distinct from their unscarfed spreads', () {
      for (final (scarf, plain) in [
        (SpeedVariantKind.scarfInvested, SpeedVariantKind.invested),
        (SpeedVariantKind.scarfBoosted, SpeedVariantKind.boosted),
      ]) {
        expect(
          speedVariantLabel(scarf, withIcon: false),
          isNot(equals(speedVariantLabel(plain, withIcon: false))),
        );
      }
    });
  });

  test('non-scarf tiers read the same either way', () {
    for (final k in [
      SpeedVariantKind.neutral,
      SpeedVariantKind.invested,
      SpeedVariantKind.boosted,
    ]) {
      expect(speedVariantLabel(k, withIcon: true),
          equals(speedVariantLabel(k, withIcon: false)));
    }
  });

  test('every tier has a non-empty label in each language', () {
    for (final lang in AppLanguage.values) {
      AppStrings.setLanguageForTest(lang);
      for (final k in SpeedVariantKind.values) {
        for (final withIcon in [true, false]) {
          expect(speedVariantLabel(k, withIcon: withIcon), isNotEmpty,
              reason: '$k / $lang / icon=$withIcon');
        }
      }
    }
    AppStrings.setLanguageForTest(AppLanguage.ko);
  });
}
