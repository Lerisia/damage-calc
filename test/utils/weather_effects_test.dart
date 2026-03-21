import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
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
        tags: [MoveTags.sunBoost],
      );
      final mod = getWeatherOffensiveModifier(Weather.sun, move: hydroSteam);
      expect(mod, equals(1.5));
    });

    test('custom:sun_boost Water move is normal in rain', () {
      const hydroSteam = Move(
        name: 'Hydro Steam', nameKo: '하이드로스팀', nameJa: 'ハイドロスチーム',
        type: PokemonType.water, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15,
        tags: [MoveTags.sunBoost],
      );
      final mod = getWeatherOffensiveModifier(Weather.rain, move: hydroSteam);
      expect(mod, equals(1.5));
    });

    // --- Harsh Sun ---
    test('harsh sun boosts Fire moves by 1.5x', () {
      final mod = getWeatherOffensiveModifier(Weather.harshSun, move: flamethrower);
      expect(mod, equals(1.5));
    });

    test('harsh sun nullifies Water moves to 0x', () {
      final mod = getWeatherOffensiveModifier(Weather.harshSun, move: surf);
      expect(mod, equals(0.0));
    });

    test('harsh sun does not affect other types', () {
      final mod = getWeatherOffensiveModifier(Weather.harshSun, move: thunderbolt);
      expect(mod, equals(1.0));
    });

    test('custom:sun_boost gets 1.5x in harsh sun', () {
      const hydroSteam = Move(
        name: 'Hydro Steam', nameKo: '하이드로스팀', nameJa: 'ハイドロスチーム',
        type: PokemonType.water, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15,
        tags: [MoveTags.sunBoost],
      );
      final mod = getWeatherOffensiveModifier(Weather.harshSun, move: hydroSteam);
      expect(mod, equals(1.5));
    });

    // --- Heavy Rain ---
    test('heavy rain boosts Water moves by 1.5x', () {
      final mod = getWeatherOffensiveModifier(Weather.heavyRain, move: surf);
      expect(mod, equals(1.5));
    });

    test('heavy rain nullifies Fire moves to 0x', () {
      final mod = getWeatherOffensiveModifier(Weather.heavyRain, move: flamethrower);
      expect(mod, equals(0.0));
    });

    test('heavy rain does not affect other types', () {
      final mod = getWeatherOffensiveModifier(Weather.heavyRain, move: thunderbolt);
      expect(mod, equals(1.0));
    });

    // --- Strong Winds ---
    test('strong winds does not affect offensive power', () {
      final mod = getWeatherOffensiveModifier(Weather.strongWinds, move: flamethrower);
      expect(mod, equals(1.0));
    });
  });

  group('WeatherDefensiveModifier', () {
    test('sandstorm boosts Rock-type SpDef by 1.5x', () {
      final mod = getWeatherDefensiveModifier(Weather.sandstorm,
          type1: PokemonType.rock);
      expect(mod.spdMod, equals(1.5));
      expect(mod.defMod, equals(1.0));
    });

    test('sandstorm boosts Rock-type SpDef when type2', () {
      final mod = getWeatherDefensiveModifier(Weather.sandstorm,
          type1: PokemonType.ground, type2: PokemonType.rock);
      expect(mod.spdMod, equals(1.5));
    });

    test('sandstorm does not boost non-Rock-type SpDef', () {
      final mod = getWeatherDefensiveModifier(Weather.sandstorm,
          type1: PokemonType.fire);
      expect(mod.spdMod, equals(1.0));
    });

    test('snow boosts Ice-type Def by 1.5x', () {
      final mod = getWeatherDefensiveModifier(Weather.snow,
          type1: PokemonType.ice);
      expect(mod.defMod, equals(1.5));
      expect(mod.spdMod, equals(1.0));
    });

    test('snow boosts Ice-type Def when type2', () {
      final mod = getWeatherDefensiveModifier(Weather.snow,
          type1: PokemonType.water, type2: PokemonType.ice);
      expect(mod.defMod, equals(1.5));
    });

    test('snow does not boost non-Ice-type Def', () {
      final mod = getWeatherDefensiveModifier(Weather.snow,
          type1: PokemonType.water);
      expect(mod.defMod, equals(1.0));
    });

    test('sun does not affect defensive modifiers', () {
      final mod = getWeatherDefensiveModifier(Weather.sun,
          type1: PokemonType.fire);
      expect(mod.defMod, equals(1.0));
      expect(mod.spdMod, equals(1.0));
    });

    test('rain does not affect defensive modifiers', () {
      final mod = getWeatherDefensiveModifier(Weather.rain,
          type1: PokemonType.water);
      expect(mod.defMod, equals(1.0));
      expect(mod.spdMod, equals(1.0));
    });

    test('no weather returns 1.0 for both', () {
      final mod = getWeatherDefensiveModifier(Weather.none,
          type1: PokemonType.rock);
      expect(mod.defMod, equals(1.0));
      expect(mod.spdMod, equals(1.0));
    });
  });
}
