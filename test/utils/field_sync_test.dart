import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/field_sync.dart';

void main() {
  group('syncFieldFromAbilities', () {
    FieldState run({
      Weather weather = Weather.none,
      Terrain terrain = Terrain.none,
      String? prevAtk,
      String? prevDef,
      String? atk,
      String? def,
    }) =>
        syncFieldFromAbilities(
          weather: weather,
          terrain: terrain,
          prevAtkAbility: prevAtk,
          prevDefAbility: prevDef,
          atkAbility: atk,
          defAbility: def,
        );

    test('no ability change → field untouched', () {
      final r = run(
        weather: Weather.rain,
        terrain: Terrain.electric,
        prevAtk: 'Drizzle', atk: 'Drizzle',
        prevDef: 'Levitate', def: 'Levitate',
      );
      expect(r.weather, Weather.rain);
      expect(r.terrain, Terrain.electric);
    });

    test('auto-set: weather ability appears on attacker', () {
      final r = run(prevAtk: 'Levitate', atk: 'Drought');
      expect(r.weather, Weather.sun);
    });

    test('auto-set: terrain ability appears on defender', () {
      final r = run(prevDef: null, def: 'Electric Surge');
      expect(r.terrain, Terrain.electric);
    });

    test('auto-set: both sides change, defender applied last wins', () {
      // Original order applies attacker then defender, so defender's
      // weather is the final value when both bring one.
      final r = run(
        prevAtk: 'x', atk: 'Drought', // Sun
        prevDef: 'y', def: 'Drizzle', // Rain — applied after → wins
      );
      expect(r.weather, Weather.rain);
    });

    test('auto-clear: the sourcing ability was removed', () {
      // Rain was set by Drizzle; attacker swaps Drizzle → Levitate,
      // nothing else justifies rain → cleared.
      final r = run(
        weather: Weather.rain,
        prevAtk: 'Drizzle', atk: 'Levitate',
      );
      expect(r.weather, Weather.none);
    });

    test('no auto-clear: another ability still justifies it', () {
      // Attacker drops Drizzle but defender also has Drizzle → rain stays.
      final r = run(
        weather: Weather.rain,
        prevAtk: 'Drizzle', atk: 'Levitate',
        prevDef: 'Drizzle', def: 'Drizzle',
      );
      expect(r.weather, Weather.rain);
    });

    test('user-set weather (no ability ever sourced it) is preserved', () {
      // Weather is Sun but the changed ability has nothing to do with
      // weather and no prev ability sourced Sun → leave it.
      final r = run(
        weather: Weather.sun,
        prevAtk: 'Levitate', atk: 'Intimidate',
      );
      expect(r.weather, Weather.sun);
    });

    test('replacing one weather ability with another switches the field', () {
      final r = run(
        weather: Weather.rain,
        prevAtk: 'Drizzle', atk: 'Drought', // Rain → Sun
      );
      expect(r.weather, Weather.sun);
    });

    test('weather and terrain handled independently in one change', () {
      // Attacker: Electric Surge → Drought. Terrain was electric
      // (sourced by the old ability) so it clears; weather becomes sun.
      final r = run(
        weather: Weather.none,
        terrain: Terrain.electric,
        prevAtk: 'Electric Surge', atk: 'Drought',
      );
      expect(r.weather, Weather.sun);
      expect(r.terrain, Terrain.none);
    });

    test('auto-clear terrain when surge ability removed', () {
      final r = run(
        terrain: Terrain.grassy,
        prevDef: 'Grassy Surge', def: 'Levitate',
      );
      expect(r.terrain, Terrain.none);
    });
  });
}
