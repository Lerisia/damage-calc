import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';

void main() {
  group('Move', () {
    const tackle = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35, tags: ['contact'],
    );

    test('hasTag returns true for existing tag', () {
      expect(tackle.hasTag('contact'), isTrue);
    });

    test('hasTag returns false for missing tag', () {
      expect(tackle.hasTag('punch'), isFalse);
    });

    test('copyWith overrides specified fields', () {
      final copy = tackle.copyWith(
        type: PokemonType.fire,
        power: 80,
        moveClass: MoveClass.maxMove,
      );
      expect(copy.type, equals(PokemonType.fire));
      expect(copy.power, equals(80));
      expect(copy.moveClass, equals(MoveClass.maxMove));
      expect(copy.name, equals('Tackle'));
      expect(copy.category, equals(MoveCategory.physical));
    });

    test('fromJson parses correctly', () {
      final move = Move.fromJson({
        'name': 'Surf', 'nameKo': '파도타기', 'nameJa': 'なみのり',
        'type': 'water', 'category': 'special',
        'power': 90, 'accuracy': 100, 'pp': 15,
        'tags': ['custom:has_secondary'],
      });
      expect(move.name, equals('Surf'));
      expect(move.type, equals(PokemonType.water));
      expect(move.category, equals(MoveCategory.special));
      expect(move.power, equals(90));
      expect(move.hasTag('custom:has_secondary'), isTrue);
      expect(move.moveClass, equals(MoveClass.normal));
    });

    test('fromJson with moveClass', () {
      final move = Move.fromJson({
        'name': 'Max Geyser', 'nameKo': '다이스트림', 'nameJa': 'ダイストリーム',
        'type': 'water', 'category': 'special',
        'power': 130, 'accuracy': 100, 'pp': 10,
        'moveClass': 'maxMove',
      });
      expect(move.moveClass, equals(MoveClass.maxMove));
    });
  });
}
