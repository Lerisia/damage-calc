import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/speed_calculator.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/models/terrain.dart';

void main() {
  group('calcEffectiveSpeed', () {
    // ---------------------------------------------------------------
    // 1. Base speed calculation
    // ---------------------------------------------------------------
    group('base speed', () {
      test('returns the base speed when no modifiers are applied', () {
        final speed = calcEffectiveSpeed(baseSpeed: 100);
        expect(speed, equals(100));
      });

      test('returns positive value for any positive base speed', () {
        final speed = calcEffectiveSpeed(baseSpeed: 1);
        expect(speed, greaterThan(0));
      });

      test('returns 0 for base speed 0', () {
        final speed = calcEffectiveSpeed(baseSpeed: 0);
        expect(speed, equals(0));
      });
    });

    // ---------------------------------------------------------------
    // 2. Paralysis — 0.5x speed
    // ---------------------------------------------------------------
    group('paralysis', () {
      test('halves speed when paralyzed', () {
        final normal = calcEffectiveSpeed(baseSpeed: 200);
        final paralyzed = calcEffectiveSpeed(
          baseSpeed: 200,
          status: StatusCondition.paralysis,
        );
        expect(paralyzed, equals(normal ~/ 2));
      });

      test('paralysis uses floor division', () {
        // 101 * 0.5 = 50.5 → floor → 50
        final speed = calcEffectiveSpeed(
          baseSpeed: 101,
          status: StatusCondition.paralysis,
        );
        expect(speed, equals(50));
      });

      test('non-paralysis status does not reduce speed', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final burned = calcEffectiveSpeed(
          baseSpeed: 100,
          status: StatusCondition.burn,
        );
        expect(burned, equals(normal));
      });
    });

    // ---------------------------------------------------------------
    // 3. Choice Scarf — 1.5x speed
    // ---------------------------------------------------------------
    group('Choice Scarf', () {
      test('increases speed by 1.5x', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final scarfed = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'choice-scarf',
        );
        expect(scarfed, greaterThan(normal));
        expect(scarfed, equals(150));
      });

      test('Choice Scarf is nullified during Dynamax', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final dynamaxScarfed = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'choice-scarf',
          isDynamaxed: true,
        );
        expect(dynamaxScarfed, equals(normal));
      });
    });

    // ---------------------------------------------------------------
    // 4. Tailwind — 2x speed
    // ---------------------------------------------------------------
    group('Tailwind', () {
      test('doubles speed', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final tailwindSpeed = calcEffectiveSpeed(
          baseSpeed: 100,
          tailwind: true,
        );
        expect(tailwindSpeed, equals(normal * 2));
      });
    });

    // ---------------------------------------------------------------
    // 5. Iron Ball — 0.5x speed
    // ---------------------------------------------------------------
    group('Iron Ball', () {
      test('halves speed', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final ironBall = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'iron-ball',
        );
        expect(ironBall, lessThan(normal));
        expect(ironBall, equals(50));
      });
    });

    // ---------------------------------------------------------------
    // 6. Unburden — 2x speed when item is consumed (null)
    // ---------------------------------------------------------------
    group('Unburden', () {
      test('doubles speed when item is null (consumed)', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final unburdened = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Unburden',
          // item is null → item consumed
        );
        expect(unburdened, equals(normal * 2));
      });

      test('does not boost speed when item is still held', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final withItem = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Unburden',
          item: 'sitrus-berry',
        );
        expect(withItem, equals(normal));
      });
    });

    // ---------------------------------------------------------------
    // 7. Quick Feet — 1.5x when statused, negates paralysis penalty
    // ---------------------------------------------------------------
    group('Quick Feet', () {
      test('boosts speed 1.5x when statused', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final quickFeet = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Quick Feet',
          status: StatusCondition.burn,
        );
        expect(quickFeet, greaterThan(normal));
        expect(quickFeet, equals(150));
      });

      test('paralysis does not reduce speed with Quick Feet', () {
        final quickFeetParalyzed = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Quick Feet',
          status: StatusCondition.paralysis,
        );
        // Quick Feet gives 1.5x AND negates paralysis 0.5x penalty
        // So net effect is 1.5x, not 1.5 * 0.5 = 0.75x
        expect(quickFeetParalyzed, equals(150));
      });

      test('no boost when not statused', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final quickFeetHealthy = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Quick Feet',
        );
        expect(quickFeetHealthy, equals(normal));
      });
    });

    // ---------------------------------------------------------------
    // 8. Weather-based speed abilities
    // ---------------------------------------------------------------
    group('weather speed abilities', () {
      test('Swift Swim doubles speed in rain', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final swiftSwim = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Swift Swim',
          weather: Weather.rain,
        );
        expect(swiftSwim, equals(normal * 2));
      });

      test('Chlorophyll doubles speed in sun', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final chlorophyll = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Chlorophyll',
          weather: Weather.sun,
        );
        expect(chlorophyll, equals(normal * 2));
      });

      test('Sand Rush doubles speed in sandstorm', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final sandRush = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Sand Rush',
          weather: Weather.sandstorm,
        );
        expect(sandRush, equals(normal * 2));
      });

      test('Slush Rush doubles speed in snow', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final slushRush = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Slush Rush',
          weather: Weather.snow,
        );
        expect(slushRush, equals(normal * 2));
      });

      test('Swift Swim has no effect without rain', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final noRain = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Swift Swim',
          weather: Weather.sun,
        );
        expect(noRain, equals(normal));
      });
    });

    // ---------------------------------------------------------------
    // 9. Terrain speed ability
    // ---------------------------------------------------------------
    group('Surge Surfer', () {
      test('doubles speed on Electric Terrain', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final surgeSurfer = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Surge Surfer',
          terrain: Terrain.electric,
        );
        expect(surgeSurfer, equals(normal * 2));
      });

      test('no effect on non-Electric terrain', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final noElectric = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Surge Surfer',
          terrain: Terrain.grassy,
        );
        expect(noElectric, equals(normal));
      });
    });

    // ---------------------------------------------------------------
    // 10. Klutz negates item speed effects
    // ---------------------------------------------------------------
    group('Klutz', () {
      test('negates Choice Scarf speed boost', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final klutzScarf = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Klutz',
          item: 'choice-scarf',
        );
        expect(klutzScarf, equals(normal));
      });

      test('negates Iron Ball speed penalty', () {
        final normal = calcEffectiveSpeed(baseSpeed: 100);
        final klutzIronBall = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Klutz',
          item: 'iron-ball',
        );
        expect(klutzIronBall, equals(normal));
      });
    });

    // ---------------------------------------------------------------
    // 11. Stacking modifiers
    // ---------------------------------------------------------------
    group('stacking modifiers', () {
      test('Choice Scarf + Tailwind stack multiplicatively', () {
        final scarfOnly = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'choice-scarf',
        );
        final tailwindOnly = calcEffectiveSpeed(
          baseSpeed: 100,
          tailwind: true,
        );
        final both = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'choice-scarf',
          tailwind: true,
        );
        expect(both, greaterThan(scarfOnly));
        expect(both, greaterThan(tailwindOnly));
        // 100 * 1.5 * 2.0 = 300
        expect(both, equals(300));
      });

      test('Swift Swim + Tailwind stack', () {
        final both = calcEffectiveSpeed(
          baseSpeed: 100,
          ability: 'Swift Swim',
          weather: Weather.rain,
          tailwind: true,
        );
        // 100 * 2.0 (Swift Swim) * 2.0 (Tailwind) = 400
        expect(both, equals(400));
      });

      test('Paralysis + Tailwind partially cancel out', () {
        final both = calcEffectiveSpeed(
          baseSpeed: 100,
          status: StatusCondition.paralysis,
          tailwind: true,
        );
        // 100 * 0.5 (paralysis) * 2.0 (tailwind) = 100
        expect(both, equals(100));
      });

      test('Choice Scarf + Paralysis', () {
        final both = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'choice-scarf',
          status: StatusCondition.paralysis,
        );
        // 100 * 1.5 (scarf) * 0.5 (paralysis) = 75
        expect(both, equals(75));
      });
    });

    // ---------------------------------------------------------------
    // 12. checkAlwaysLast
    // ---------------------------------------------------------------
    group('checkAlwaysLast', () {
      test('Lagging Tail causes always-last', () {
        expect(checkAlwaysLast(item: 'lagging-tail'), isTrue);
      });

      test('Full Incense causes always-last', () {
        expect(checkAlwaysLast(item: 'full-incense'), isTrue);
      });

      test('normal item does not cause always-last', () {
        expect(checkAlwaysLast(item: 'choice-scarf'), isFalse);
      });

      test('null item does not cause always-last', () {
        expect(checkAlwaysLast(), isFalse);
      });

      test('Dynamax negates always-last', () {
        expect(
          checkAlwaysLast(item: 'lagging-tail', isDynamaxed: true),
          isFalse,
        );
      });

      test('Klutz negates always-last', () {
        expect(
          checkAlwaysLast(item: 'lagging-tail', ability: 'Klutz'),
          isFalse,
        );
      });
    });

    // ---------------------------------------------------------------
    // 13. Quick Powder (Ditto-specific)
    // ---------------------------------------------------------------
    group('Quick Powder', () {
      test('doubles speed for Ditto', () {
        final speed = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'quick-powder',
          pokemonName: 'Ditto',
        );
        expect(speed, equals(200));
      });

      test('no effect for non-Ditto pokemon', () {
        final speed = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'quick-powder',
          pokemonName: 'Pikachu',
        );
        expect(speed, equals(100));
      });
    });

    // ---------------------------------------------------------------
    // 14. Power items — 0.5x speed
    // ---------------------------------------------------------------
    group('Power items', () {
      test('Power Anklet halves speed', () {
        final speed = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'power-anklet',
        );
        expect(speed, equals(50));
      });

      test('Power Bracer halves speed', () {
        final speed = calcEffectiveSpeed(
          baseSpeed: 100,
          item: 'power-bracer',
        );
        expect(speed, equals(50));
      });
    });
  });
}
