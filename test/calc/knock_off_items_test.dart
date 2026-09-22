import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/calc/damage_calculator.dart';
import 'package:damage_calc/calc/move_transform.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/type.dart';

/// Knock Off's ×1.5 boost is skipped only for items the *holder itself*
/// cannot lose: its own Mega Stone / Primal orb / forme item, Arceus's
/// own Plate, Silvally's own Memory, and a held Z-Crystal.
///
/// The old implementation matched on the item name alone (`endsWith
/// ('ite')`, `endsWith('-plate')`, …), which was wrong in both
/// directions:
///   * Champions Z-stones (`absolite-z`) fell outside the suffix rules
///     and were treated as removable.
///   * Any species holding someone else's stone/plate/memory was
///     wrongly protected.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadPokedex();
  });

  group('own form items are unremovable', () {
    test('mega stones, including Champions Z stones', () {
      expect(isUnremovableItemFor('Charizard', 'charizardite-x'), isTrue);
      expect(isUnremovableItemFor('Gyarados', 'gyaradosite'), isTrue);
      // Regression: these three end in "-z", not "ite"/"ite-x"/"ite-y".
      expect(isUnremovableItemFor('Absol', 'absolite-z'), isTrue);
      expect(isUnremovableItemFor('Garchomp', 'garchompite-z'), isTrue);
      expect(isUnremovableItemFor('Lucario', 'lucarionite-z'), isTrue);
    });

    test('the mega-evolved form keeps exactly the stone that made it', () {
      // Regression: Mega Garchomp holding Garchompite got the ×1.5.
      expect(isUnremovableItemFor('Mega Garchomp', 'garchompite'), isTrue);
      expect(isUnremovableItemFor('Mega Garchomp Z', 'garchompite-z'), isTrue);
      expect(isUnremovableItemFor('Mega Absol Z', 'absolite-z'), isTrue);
      expect(isUnremovableItemFor('Primal Groudon', 'red-orb'), isTrue);
      // The wrong stone of its own line is just a wrong item.
      expect(isUnremovableItemFor('Mega Garchomp Z', 'garchompite'), isFalse);
      expect(isUnremovableItemFor('Mega Garchomp', 'garchompite-z'), isFalse);
      expect(isUnremovableItemFor('Mega Charizard X', 'charizardite-y'), isFalse);
      // Still a stranger to someone else's stone.
      expect(isUnremovableItemFor('Mega Garchomp', 'gyaradosite'), isFalse);
      // The base species owns every stone of its line.
      expect(isUnremovableItemFor('Charizard', 'charizardite-y'), isTrue);
    });

    test('primal orbs and fixed forme items', () {
      expect(isUnremovableItemFor('Groudon', 'red-orb'), isTrue);
      expect(isUnremovableItemFor('Kyogre', 'blue-orb'), isTrue);
      expect(isUnremovableItemFor('Zacian', 'rusted-sword'), isTrue);
      expect(isUnremovableItemFor('Ogerpon', 'wellspring-mask'), isTrue);
      expect(isUnremovableItemFor('Giratina', 'griseous-core'), isTrue);
    });

    test("Arceus's plates and Silvally's memories", () {
      expect(isUnremovableItemFor('Arceus', 'iron-plate'), isTrue);
      expect(isUnremovableItemFor('Silvally', 'ghost-memory'), isTrue);
    });

    test('a held Z-Crystal is never knocked off', () {
      expect(isUnremovableItemFor('Pikachu', 'firium-z--held'), isTrue);
    });
  });

  group("someone else's item is removable", () {
    test('a stone that is not yours gives the Knock Off boost', () {
      expect(isUnremovableItemFor('Charizard', 'gyaradosite'), isFalse);
      expect(isUnremovableItemFor('Pikachu', 'absolite-z'), isFalse);
      expect(isUnremovableItemFor('Pikachu', 'red-orb'), isFalse);
      // Zamazenta cannot use Zacian's sword.
      expect(isUnremovableItemFor('Zamazenta', 'rusted-sword'), isFalse);
    });

    test('plates and memories on the wrong species', () {
      expect(isUnremovableItemFor('Pikachu', 'iron-plate'), isFalse);
      expect(isUnremovableItemFor('Pikachu', 'ghost-memory'), isFalse);
      expect(isUnremovableItemFor('Arceus', 'ghost-memory'), isFalse);
      expect(isUnremovableItemFor('Silvally', 'iron-plate'), isFalse);
    });

    test('ordinary items are always removable', () {
      expect(isUnremovableItemFor('Charizard', 'leftovers'), isFalse);
      expect(isUnremovableItemFor('Charizard', 'choice-scarf'), isFalse);
      // Eviolite ends in "ite" but is a normal held item.
      expect(isUnremovableItemFor('Chansey', 'eviolite'), isFalse);
    });
  });

  group('Knock Off boost on a mega-evolved defender', () {
    const knockOff = Move(
      name: 'Knock Off', nameKo: '탁쳐서떨어뜨리기', nameJa: 'はたきおとす',
      type: PokemonType.dark, category: MoveCategory.physical,
      power: 65, accuracy: 100, pp: 20,
      tags: [MoveTags.knockOff, MoveTags.contact],
    );
    test('no boost against its own stone, boost against anything else', () {
      expect(isKnockOffBoostApplicable(knockOff, 'garchompite',
          opponentSpecies: 'Mega Garchomp'), isFalse);
      expect(isKnockOffBoostApplicable(knockOff, 'garchompite',
          opponentSpecies: 'Garchomp'), isFalse);
      expect(isKnockOffBoostApplicable(knockOff, 'leftovers',
          opponentSpecies: 'Mega Garchomp'), isTrue);
      expect(isKnockOffBoostApplicable(knockOff, 'garchompite',
          opponentSpecies: 'Mega Lucario'), isTrue);
    });
  });
}
