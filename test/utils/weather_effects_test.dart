import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/weather_effects.dart';

void main() {
  group('WeatherEffect', () {
    const flamethrower = Move(
      name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
      type: PokemonType.fire, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    const surf = Move(
      name: 'Surf', nameKo: '파도타기', nameJa: 'なみのり',
      type: PokemonType.water, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    const thunderbolt = Move(
      name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    test('sun boosts Fire moves by 1.5x', () {
      final mod = getWeatherOffensiveModifier(Weather.sun, move: flamethrower);
      expect(mod, equals(1.5));
    });

    test('sun weakens Water moves to 0.5x', () {
      final mod = getWeatherOffensiveModifier(Weather.sun, move: surf);
      expect(mod, equals(0.5));
    });

    test('rain boosts Water moves by 1.5x', () {
      final mod = getWeatherOffensiveModifier(Weather.rain, move: surf);
      expect(mod, equals(1.5));
    });

    test('rain weakens Fire moves to 0.5x', () {
      final mod = getWeatherOffensiveModifier(Weather.rain, move: flamethrower);
      expect(mod, equals(0.5));
    });

    test('sun does not affect other types', () {
      final mod = getWeatherOffensiveModifier(Weather.sun, move: thunderbolt);
      expect(mod, equals(1.0));
    });

    test('sandstorm does not affect offensive power', () {
      final mod = getWeatherOffensiveModifier(Weather.sandstorm, move: flamethrower);
      expect(mod, equals(1.0));
    });

    test('snow does not affect offensive power', () {
      final mod = getWeatherOffensiveModifier(Weather.snow, move: surf);
      expect(mod, equals(1.0));
    });

    test('no weather returns 1.0', () {
      final mod = getWeatherOffensiveModifier(Weather.none, move: flamethrower);
      expect(mod, equals(1.0));
    });

    test('custom:sun_boost Water move gets 1.5x in sun instead of 0.5x', () {
      const hydroSteam = Move(
        name: 'Hydro Steam', nameKo: '하이드로스팀', nameJa: 'ハイドロスチーム',
        type: PokemonType.water, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15,
        tags: ['custom:sun_boost'],
      );
      final mod = getWeatherOffensiveModifier(Weather.sun, move: hydroSteam);
      expect(mod, equals(1.5));
    });

    test('custom:sun_boost Water move is normal in rain', () {
      const hydroSteam = Move(
        name: 'Hydro Steam', nameKo: '하이드로스팀', nameJa: 'ハイドロスチーム',
        type: PokemonType.water, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15,
        tags: ['custom:sun_boost'],
      );
      final mod = getWeatherOffensiveModifier(Weather.rain, move: hydroSteam);
      expect(mod, equals(1.5));
    });
  });
}
