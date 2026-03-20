import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/item_effects.dart';

void main() {
  group('ItemEffect', () {
    const tackle = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35,
    );

    const psychic = Move(
      name: 'Psychic', nameKo: '사이코키네시스', nameJa: 'サイコキネシス',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10,
    );

    const flamethrower = Move(
      name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
      type: PokemonType.fire, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    test('choice-band boosts physical stat by 1.5x', () {
      final effect = getItemEffect('choice-band', move: tackle);
      expect(effect.statModifier, equals(1.5));
      expect(effect.powerModifier, equals(1.0));
    });

    test('choice-band does not boost special moves', () {
      final effect = getItemEffect('choice-band', move: psychic);
      expect(effect.statModifier, equals(1.0));
    });

    test('choice-specs boosts special stat by 1.5x', () {
      final effect = getItemEffect('choice-specs', move: psychic);
      expect(effect.statModifier, equals(1.5));
    });

    test('choice-specs does not boost physical moves', () {
      final effect = getItemEffect('choice-specs', move: tackle);
      expect(effect.statModifier, equals(1.0));
    });

    test('life-orb boosts power by 1.3x', () {
      final effect = getItemEffect('life-orb', move: tackle);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, equals(1.3));
    });

    test('silk-scarf boosts Normal-type moves by 1.2x', () {
      final effect = getItemEffect('silk-scarf', move: tackle);
      expect(effect.powerModifier, equals(1.2));
    });

    test('silk-scarf does not boost non-Normal moves', () {
      final effect = getItemEffect('silk-scarf', move: psychic);
      expect(effect.powerModifier, equals(1.0));
    });

    test('muscle-band boosts physical moves by 1.1x', () {
      final effect = getItemEffect('muscle-band', move: tackle);
      expect(effect.powerModifier, equals(1.1));
    });

    test('muscle-band does not boost special moves', () {
      final effect = getItemEffect('muscle-band', move: psychic);
      expect(effect.powerModifier, equals(1.0));
    });

    test('wise-glasses boosts special moves by 1.1x', () {
      final effect = getItemEffect('wise-glasses', move: psychic);
      expect(effect.powerModifier, equals(1.1));
    });

    test('wise-glasses does not boost physical moves', () {
      final effect = getItemEffect('wise-glasses', move: tackle);
      expect(effect.powerModifier, equals(1.0));
    });

    test('unknown item returns default modifiers', () {
      final effect = getItemEffect('focus-sash', move: tackle);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, equals(1.0));
    });
  });
}
