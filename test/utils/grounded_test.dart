import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/grounded.dart';

void main() {
  group('isGrounded', () {
    test('normal Pokemon is grounded', () {
      expect(
        isGrounded(type1: PokemonType.normal),
        isTrue,
      );
    });

    test('Flying type1 is not grounded', () {
      expect(
        isGrounded(type1: PokemonType.flying),
        isFalse,
      );
    });

    test('Flying type2 is not grounded', () {
      expect(
        isGrounded(type1: PokemonType.fire, type2: PokemonType.flying),
        isFalse,
      );
    });

    test('Levitate ability is not grounded', () {
      expect(
        isGrounded(type1: PokemonType.ghost, ability: 'Levitate'),
        isFalse,
      );
    });

    test('Air Balloon item is not grounded', () {
      expect(
        isGrounded(type1: PokemonType.steel, item: 'Air Balloon'),
        isFalse,
      );
    });

    test('non-Flying type with other ability is grounded', () {
      expect(
        isGrounded(
          type1: PokemonType.psychic,
          ability: 'Synchronize',
          item: 'Life Orb',
        ),
        isTrue,
      );
    });
  });
}
