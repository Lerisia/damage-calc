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

    test('Choice Band boosts physical stat by 1.5x', () {
      final effect = getItemEffect('Choice Band', move: tackle);
      expect(effect.statModifier, equals(1.5));
      expect(effect.powerModifier, equals(1.0));
    });

    test('Choice Band does not boost special moves', () {
      final effect = getItemEffect('Choice Band', move: psychic);
      expect(effect.statModifier, equals(1.0));
    });

    test('Choice Specs boosts special stat by 1.5x', () {
      final effect = getItemEffect('Choice Specs', move: psychic);
      expect(effect.statModifier, equals(1.5));
    });

    test('Choice Specs does not boost physical moves', () {
      final effect = getItemEffect('Choice Specs', move: tackle);
      expect(effect.statModifier, equals(1.0));
    });

    test('Life Orb boosts power by 1.3x', () {
      final effect = getItemEffect('Life Orb', move: tackle);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, equals(1.3));
    });

    test('Silk Scarf boosts Normal-type moves by 1.2x', () {
      final effect = getItemEffect('Silk Scarf', move: tackle);
      expect(effect.powerModifier, equals(1.2));
    });

    test('Silk Scarf does not boost non-Normal moves', () {
      final effect = getItemEffect('Silk Scarf', move: psychic);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Muscle Band boosts physical moves by 1.1x', () {
      final effect = getItemEffect('Muscle Band', move: tackle);
      expect(effect.powerModifier, equals(1.1));
    });

    test('Muscle Band does not boost special moves', () {
      final effect = getItemEffect('Muscle Band', move: psychic);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Wise Glasses boosts special moves by 1.1x', () {
      final effect = getItemEffect('Wise Glasses', move: psychic);
      expect(effect.powerModifier, equals(1.1));
    });

    test('Wise Glasses does not boost physical moves', () {
      final effect = getItemEffect('Wise Glasses', move: tackle);
      expect(effect.powerModifier, equals(1.0));
    });

    test('unknown item returns default modifiers', () {
      final effect = getItemEffect('Focus Sash', move: tackle);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, equals(1.0));
    });
  });
}
