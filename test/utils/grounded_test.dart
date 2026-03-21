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

    test('Flying/Ground dual type is not grounded', () {
      expect(
        isGrounded(type1: PokemonType.flying, type2: PokemonType.ground),
        isFalse,
      );
    });

    test('Ground/Flying dual type is not grounded (type2 flying)', () {
      expect(
        isGrounded(type1: PokemonType.ground, type2: PokemonType.flying),
        isFalse,
      );
    });

    test('null ability and item defaults to grounded', () {
      expect(
        isGrounded(type1: PokemonType.normal),
        isTrue,
      );
    });

    test('non-Levitate ability is grounded', () {
      expect(
        isGrounded(type1: PokemonType.electric, ability: 'Static'),
        isTrue,
      );
    });

    test('non-Air Balloon item is grounded', () {
      expect(
        isGrounded(type1: PokemonType.steel, item: 'Leftovers'),
        isTrue,
      );
    });

    test('Levitate takes priority even with non-flying type', () {
      expect(
        isGrounded(
          type1: PokemonType.electric,
          type2: PokemonType.ghost,
          ability: 'Levitate',
        ),
        isFalse,
      );
    });

    test('Air Balloon on non-flying type makes ungrounded', () {
      expect(
        isGrounded(
          type1: PokemonType.fire,
          type2: PokemonType.ghost,
          item: 'Air Balloon',
        ),
        isFalse,
      );
    });
  });
}
