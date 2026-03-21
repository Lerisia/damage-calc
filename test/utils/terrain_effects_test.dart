import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/utils/terrain_effects.dart';

void main() {
  group('TerrainEffect', () {
    const thunderbolt = Move(
      name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    const energyBall = Move(
      name: 'Energy Ball', nameKo: '에너지볼', nameJa: 'エナジーボール',
      type: PokemonType.grass, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10,
    );

    const psychic = Move(
      name: 'Psychic', nameKo: '사이코키네시스', nameJa: 'サイコキネシス',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10,
    );

    const dragonPulse = Move(
      name: 'Dragon Pulse', nameKo: '용의파동', nameJa: 'りゅうのはどう',
      type: PokemonType.dragon, category: MoveCategory.special,
      power: 85, accuracy: 100, pp: 10,
    );

    const flamethrower = Move(
      name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
      type: PokemonType.fire, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    test('Electric Terrain boosts Electric moves by 1.3x', () {
      final mod = getTerrainModifier(Terrain.electric, move: thunderbolt);
      expect(mod, equals(1.3));
    });

    test('Grassy Terrain boosts Grass moves by 1.3x', () {
      final mod = getTerrainModifier(Terrain.grassy, move: energyBall);
      expect(mod, equals(1.3));
    });

    test('Psychic Terrain boosts Psychic moves by 1.3x', () {
      final mod = getTerrainModifier(Terrain.psychic, move: psychic);
      expect(mod, equals(1.3));
    });

    test('Misty Terrain weakens Dragon moves to 0.5x', () {
      final mod = getTerrainModifier(Terrain.misty, move: dragonPulse);
      expect(mod, equals(0.5));
    });

    test('terrain does not affect non-matching types', () {
      final mod = getTerrainModifier(Terrain.electric, move: flamethrower);
      expect(mod, equals(1.0));
    });

    test('no terrain returns 1.0', () {
      final mod = getTerrainModifier(Terrain.none, move: thunderbolt);
      expect(mod, equals(1.0));
    });

    test('ungrounded Pokemon ignores terrain boost', () {
      final mod = getTerrainModifier(Terrain.electric,
          move: thunderbolt, attackerGrounded: false);
      expect(mod, equals(1.0));
    });

    test('ungrounded defender ignores Misty Terrain reduction', () {
      final mod = getTerrainModifier(Terrain.misty,
          move: dragonPulse, defenderGrounded: false);
      expect(mod, equals(1.0));
    });

    test('ungrounded attacker still gets Misty Terrain reduction on grounded defender', () {
      final mod = getTerrainModifier(Terrain.misty,
          move: dragonPulse, attackerGrounded: false, defenderGrounded: true);
      expect(mod, equals(0.5));
    });

    test('Electric Terrain does not affect non-electric moves', () {
      final mod = getTerrainModifier(Terrain.electric, move: psychic);
      expect(mod, equals(1.0));
    });

    test('Grassy Terrain does not affect non-grass moves', () {
      final mod = getTerrainModifier(Terrain.grassy, move: flamethrower);
      expect(mod, equals(1.0));
    });

    test('Psychic Terrain does not affect non-psychic moves', () {
      final mod = getTerrainModifier(Terrain.psychic, move: flamethrower);
      expect(mod, equals(1.0));
    });

    test('Misty Terrain does not affect non-dragon moves', () {
      final mod = getTerrainModifier(Terrain.misty, move: flamethrower);
      expect(mod, equals(1.0));
    });

    test('ungrounded ignores Grassy Terrain boost', () {
      final mod = getTerrainModifier(Terrain.grassy,
          move: energyBall, attackerGrounded: false);
      expect(mod, equals(1.0));
    });

    test('ungrounded ignores Psychic Terrain boost', () {
      final mod = getTerrainModifier(Terrain.psychic,
          move: psychic, attackerGrounded: false);
      expect(mod, equals(1.0));
    });

    test('grounded defaults to true', () {
      final mod = getTerrainModifier(Terrain.electric, move: thunderbolt);
      expect(mod, equals(1.3));
    });
  });
}
