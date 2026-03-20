import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/utils/move_transform.dart';

void main() {
  group('applyWeatherToMove', () {
    const weatherBall = Move(
      name: 'Weather Ball', nameKo: '웨더볼', nameJa: 'ウェザーボール',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 50, accuracy: 100, pp: 10,
    );

    const tackle = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35,
    );

    test('Weather Ball becomes Fire/100 in sun', () {
      final result = applyWeatherToMove(weatherBall, Weather.sun);
      expect(result.type, equals(PokemonType.fire));
      expect(result.power, equals(100));
    });

    test('Weather Ball becomes Water/100 in rain', () {
      final result = applyWeatherToMove(weatherBall, Weather.rain);
      expect(result.type, equals(PokemonType.water));
      expect(result.power, equals(100));
    });

    test('Weather Ball becomes Rock/100 in sandstorm', () {
      final result = applyWeatherToMove(weatherBall, Weather.sandstorm);
      expect(result.type, equals(PokemonType.rock));
      expect(result.power, equals(100));
    });

    test('Weather Ball becomes Ice/100 in snow', () {
      final result = applyWeatherToMove(weatherBall, Weather.snow);
      expect(result.type, equals(PokemonType.ice));
      expect(result.power, equals(100));
    });

    test('Weather Ball stays Normal/50 with no weather', () {
      final result = applyWeatherToMove(weatherBall, Weather.none);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(50));
    });

    test('Weather Ball preserves other fields', () {
      final result = applyWeatherToMove(weatherBall, Weather.sun);
      expect(result.name, equals('Weather Ball'));
      expect(result.nameKo, equals('웨더볼'));
      expect(result.category, equals(MoveCategory.special));
      expect(result.accuracy, equals(100));
    });

    test('non-Weather Ball moves are unchanged', () {
      final result = applyWeatherToMove(tackle, Weather.sun);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(40));
    });
  });

  group('applyTerrainToMove', () {
    const terrainPulse = Move(
      name: 'Terrain Pulse', nameKo: '대지의파동', nameJa: 'テレインパルス',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 50, accuracy: 100, pp: 10,
    );

    const tackle = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35,
    );

    test('Terrain Pulse becomes Electric/100 on Electric Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.electric);
      expect(result.type, equals(PokemonType.electric));
      expect(result.power, equals(100));
    });

    test('Terrain Pulse becomes Grass/100 on Grassy Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.grassy);
      expect(result.type, equals(PokemonType.grass));
      expect(result.power, equals(100));
    });

    test('Terrain Pulse becomes Psychic/100 on Psychic Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.psychic);
      expect(result.type, equals(PokemonType.psychic));
      expect(result.power, equals(100));
    });

    test('Terrain Pulse becomes Fairy/100 on Misty Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.misty);
      expect(result.type, equals(PokemonType.fairy));
      expect(result.power, equals(100));
    });

    test('Terrain Pulse stays Normal/50 with no terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.none);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(50));
    });

    test('non-Terrain Pulse moves are unchanged', () {
      final result = applyTerrainToMove(tackle, Terrain.electric);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(40));
    });
  });
}
