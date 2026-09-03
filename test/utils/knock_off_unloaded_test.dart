import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/damage_calculator.dart';

/// Deliberately does NOT load the pokedex.
///
/// The form-item lookups are backed by indexes built in `loadPokedex`,
/// so before that they report "not a form item". Falling through on
/// that answer would hand Knock Off its ×1.5 against a Mega Stone —
/// exactly the regression that battle_facade_test caught, since it
/// calls the facade without loading the dex. Until the data is up we
/// fall back to the name-shaped guess, which errs towards unremovable.
void main() {
  test('mega stones stay unremovable before the dex loads', () {
    expect(isUnremovableItemFor('Charizard', 'charizardite-x'), isTrue);
    expect(isUnremovableItemFor(null, 'charizardite-x'), isTrue);
    expect(isUnremovableItemFor('Absol', 'absolite-z'), isTrue);
    expect(isUnremovableItemFor('Groudon', 'red-orb'), isTrue);
    expect(isUnremovableItemFor('Ogerpon', 'wellspring-mask'), isTrue);
  });

  test('ordinary items are still removable before the dex loads', () {
    expect(isUnremovableItemFor('Charizard', 'leftovers'), isFalse);
    expect(isUnremovableItemFor('Chansey', 'eviolite'), isFalse);
  });

  test('Z-Crystals and species-bound families need no dex', () {
    expect(isUnremovableItemFor('Pikachu', 'firium-z--held'), isTrue);
    expect(isUnremovableItemFor('Arceus', 'iron-plate'), isTrue);
    expect(isUnremovableItemFor('Pikachu', 'iron-plate'), isFalse);
  });
}
