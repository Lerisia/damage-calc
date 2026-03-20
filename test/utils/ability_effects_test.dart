import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/ability_effects.dart';

void main() {
  group('AbilityEffect', () {
    const contactMove = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35,
      tags: ['contact'],
    );

    const nonContactMove = Move(
      name: 'Earthquake', nameKo: '지진', nameJa: 'じしん',
      type: PokemonType.ground, category: MoveCategory.physical,
      power: 100, accuracy: 100, pp: 10,
      tags: [],
    );

    test('Tough Claws boosts contact moves by 1.3x', () {
      final effect = getAbilityEffect('Tough Claws', move: contactMove);
      expect(effect.powerModifier, equals(1.3));
      expect(effect.statModifier, equals(1.0));
    });

    test('Tough Claws does not boost non-contact moves', () {
      final effect = getAbilityEffect('Tough Claws', move: nonContactMove);
      expect(effect.powerModifier, equals(1.0));
    });

    test('unknown ability returns default modifiers', () {
      final effect = getAbilityEffect('Overgrow', move: contactMove);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, equals(1.0));
    });
  });
}
