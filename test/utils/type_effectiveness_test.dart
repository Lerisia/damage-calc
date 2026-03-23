import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/type_effectiveness.dart';

void main() {
  group('getTypeEffectiveness', () {
    test('super effective returns 2.0', () {
      expect(getTypeEffectiveness(PokemonType.fire, PokemonType.grass), 2.0);
      expect(getTypeEffectiveness(PokemonType.water, PokemonType.fire), 2.0);
      expect(getTypeEffectiveness(PokemonType.electric, PokemonType.water), 2.0);
    });

    test('not very effective returns 0.5', () {
      expect(getTypeEffectiveness(PokemonType.fire, PokemonType.water), 0.5);
      expect(getTypeEffectiveness(PokemonType.grass, PokemonType.fire), 0.5);
      expect(getTypeEffectiveness(PokemonType.steel, PokemonType.fire), 0.5);
    });

    test('neutral returns 1.0', () {
      expect(getTypeEffectiveness(PokemonType.fire, PokemonType.fighting), 1.0);
      expect(getTypeEffectiveness(PokemonType.water, PokemonType.psychic), 1.0);
    });

    test('immunity-in-chart returns 1.0 (handled separately)', () {
      expect(getTypeEffectiveness(PokemonType.normal, PokemonType.ghost), 1.0);
      expect(getTypeEffectiveness(PokemonType.ghost, PokemonType.normal), 1.0);
      expect(getTypeEffectiveness(PokemonType.fighting, PokemonType.ghost), 1.0);
      expect(getTypeEffectiveness(PokemonType.electric, PokemonType.ground), 1.0);
      expect(getTypeEffectiveness(PokemonType.poison, PokemonType.steel), 1.0);
      expect(getTypeEffectiveness(PokemonType.ground, PokemonType.flying), 1.0);
      expect(getTypeEffectiveness(PokemonType.psychic, PokemonType.dark), 1.0);
      expect(getTypeEffectiveness(PokemonType.dragon, PokemonType.fairy), 1.0);
    });

    test('same type attack (fire vs fire = 0.5)', () {
      expect(getTypeEffectiveness(PokemonType.fire, PokemonType.fire), 0.5);
      expect(getTypeEffectiveness(PokemonType.water, PokemonType.water), 0.5);
      expect(getTypeEffectiveness(PokemonType.grass, PokemonType.grass), 0.5);
    });
  });

  group('getCombinedEffectiveness', () {
    test('single type returns base effectiveness', () {
      expect(getCombinedEffectiveness(PokemonType.fire, PokemonType.grass, null), 2.0);
      expect(getCombinedEffectiveness(PokemonType.fire, PokemonType.water, null), 0.5);
      expect(getCombinedEffectiveness(PokemonType.fire, PokemonType.fighting, null), 1.0);
    });

    test('dual type multiplies effectiveness', () {
      // fire vs grass/steel = 2.0 * 2.0 = 4.0
      expect(getCombinedEffectiveness(PokemonType.fire, PokemonType.grass, PokemonType.steel), 4.0);
      // fire vs water/rock = 0.5 * 0.5 = 0.25
      expect(getCombinedEffectiveness(PokemonType.fire, PokemonType.water, PokemonType.rock), 0.25);
      // water vs fire/ground = 2.0 * 2.0 = 4.0
      expect(getCombinedEffectiveness(PokemonType.water, PokemonType.fire, PokemonType.ground), 4.0);
    });

    test('dual type 4x weakness (ice vs grass/flying)', () {
      expect(getCombinedEffectiveness(PokemonType.ice, PokemonType.grass, PokemonType.flying), 4.0);
    });

    test('Freeze-Dry overrides ice vs water to 2.0', () {
      // Normal ice vs water = 0.5
      expect(getCombinedEffectiveness(PokemonType.ice, PokemonType.water, null), 0.5);
      // Freeze-Dry ice vs water = 2.0
      expect(getCombinedEffectiveness(PokemonType.ice, PokemonType.water, null, freezeDry: true), 2.0);
    });

    test('Freeze-Dry with dual type', () {
      // Freeze-Dry vs water/ground = 2.0 * 2.0 = 4.0
      expect(getCombinedEffectiveness(PokemonType.ice, PokemonType.water, PokemonType.ground, freezeDry: true), 4.0);
      // Freeze-Dry vs water/fire = 2.0 * 0.5 = 1.0
      expect(getCombinedEffectiveness(PokemonType.ice, PokemonType.water, PokemonType.fire, freezeDry: true), 1.0);
    });

    test('Flying Press combines fighting and flying effectiveness', () {
      // vs normal: fighting 2.0 * flying 1.0 = 2.0
      expect(getCombinedEffectiveness(PokemonType.fighting, PokemonType.normal, null, flyingPress: true), 2.0);
      // vs grass: fighting 0.5(bug chart? no) ... fighting vs grass = 1.0, flying vs grass = 2.0 = 2.0
      expect(getCombinedEffectiveness(PokemonType.fighting, PokemonType.grass, null, flyingPress: true), 2.0);
      // vs rock: fighting 2.0 * flying 0.5 = 1.0
      expect(getCombinedEffectiveness(PokemonType.fighting, PokemonType.rock, null, flyingPress: true), 1.0);
    });

    test('Flying Press with dual type', () {
      // vs normal/dark: fighting(normal)2.0 * fighting(dark)2.0 * flying(normal)1.0 * flying(dark)1.0 = 4.0
      expect(getCombinedEffectiveness(PokemonType.fighting, PokemonType.normal, PokemonType.dark, flyingPress: true), 4.0);
    });
  });

  group('hasTypeImmunity', () {
    test('all 8 immunity pairs return true', () {
      expect(hasTypeImmunity(PokemonType.normal, PokemonType.ghost, null), true);
      expect(hasTypeImmunity(PokemonType.fighting, PokemonType.ghost, null), true);
      expect(hasTypeImmunity(PokemonType.electric, PokemonType.ground, null), true);
      expect(hasTypeImmunity(PokemonType.poison, PokemonType.steel, null), true);
      expect(hasTypeImmunity(PokemonType.ground, PokemonType.flying, null), true);
      expect(hasTypeImmunity(PokemonType.psychic, PokemonType.dark, null), true);
      expect(hasTypeImmunity(PokemonType.ghost, PokemonType.normal, null), true);
      expect(hasTypeImmunity(PokemonType.dragon, PokemonType.fairy, null), true);
    });

    test('non-immune matchups return false', () {
      expect(hasTypeImmunity(PokemonType.fire, PokemonType.grass, null), false);
      expect(hasTypeImmunity(PokemonType.water, PokemonType.fire, null), false);
      expect(hasTypeImmunity(PokemonType.dark, PokemonType.psychic, null), false);
    });

    test('types with no immunities return false', () {
      expect(hasTypeImmunity(PokemonType.fire, PokemonType.ghost, null), false);
      expect(hasTypeImmunity(PokemonType.water, PokemonType.ground, null), false);
      expect(hasTypeImmunity(PokemonType.fairy, PokemonType.normal, null), false);
    });

    test('dual-type immunity via type2', () {
      // fire/ghost defender vs normal attack: ghost is immune
      expect(hasTypeImmunity(PokemonType.normal, PokemonType.fire, PokemonType.ghost), true);
      // water/flying defender vs ground attack: flying is immune
      expect(hasTypeImmunity(PokemonType.ground, PokemonType.water, PokemonType.flying), true);
      // fire/water defender vs normal attack: neither immune
      expect(hasTypeImmunity(PokemonType.normal, PokemonType.fire, PokemonType.water), false);
    });

    test('dual-type immunity via type1', () {
      expect(hasTypeImmunity(PokemonType.electric, PokemonType.ground, PokemonType.rock), true);
    });
  });

  group('typeImmunities', () {
    test('contains exactly 8 entries', () {
      expect(typeImmunities.length, 8);
    });
  });
}
