import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/grounded.dart';

void main() {
  group('isGrounded', () {
    test('non-flying type without Levitate/Air Balloon is grounded', () {
      expect(isGrounded(type1: PokemonType.normal), isTrue);
    });

    test('Flying type is not grounded', () {
      expect(isGrounded(type1: PokemonType.flying), isFalse);
      expect(isGrounded(type1: PokemonType.fire, type2: PokemonType.flying), isFalse);
    });

    test('Levitate ability is not grounded', () {
      expect(isGrounded(type1: PokemonType.electric, ability: 'Levitate'), isFalse);
    });

    test('Air Balloon item is not grounded', () {
      expect(isGrounded(type1: PokemonType.steel, item: 'Air Balloon'), isFalse);
    });
  });
}
