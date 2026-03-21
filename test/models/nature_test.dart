import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/nature.dart';

void main() {
  group('Nature', () {
    test('adamant boosts attack, lowers spAttack', () {
      expect(Nature.adamant.attackModifier, equals(1.1));
      expect(Nature.adamant.spAttackModifier, equals(0.9));
      expect(Nature.adamant.defenseModifier, equals(1.0));
    });

    test('modest boosts spAttack, lowers attack', () {
      expect(Nature.modest.spAttackModifier, equals(1.1));
      expect(Nature.modest.attackModifier, equals(0.9));
    });

    test('neutral natures have no effect', () {
      for (final n in [Nature.hardy, Nature.docile, Nature.serious, Nature.bashful, Nature.quirky]) {
        expect(n.attackModifier, equals(1.0));
        expect(n.defenseModifier, equals(1.0));
        expect(n.spAttackModifier, equals(1.0));
        expect(n.spDefenseModifier, equals(1.0));
        expect(n.speedModifier, equals(1.0));
      }
    });

    test('nameKo returns Korean name', () {
      expect(Nature.adamant.nameKo, equals('고집'));
      expect(Nature.bold.nameKo, equals('대담'));
    });

    test('nameJa returns Japanese name', () {
      expect(Nature.adamant.nameJa, equals('いじっぱり'));
    });
  });
}
