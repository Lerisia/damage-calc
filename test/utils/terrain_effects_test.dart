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

    // Terrain power modifiers are now handled in transformMove.
    // getTerrainModifier always returns 1.0 (kept for backward compat).

    test('getTerrainModifier always returns 1.0 (terrain handled in transform)', () {
      expect(getTerrainModifier(Terrain.electric, move: thunderbolt), equals(1.0));
      expect(getTerrainModifier(Terrain.misty, move: dragonPulse), equals(1.0));
      expect(getTerrainModifier(Terrain.none, move: thunderbolt), equals(1.0));
    });

    test('terrain does not affect non-matching types', () {
      final mod = getTerrainModifier(Terrain.electric, move: flamethrower);
      expect(mod, equals(1.0));
    });

    test('no terrain returns 1.0', () {
      final mod = getTerrainModifier(Terrain.none, move: thunderbolt);
      expect(mod, equals(1.0));
    });
  });
}
