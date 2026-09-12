import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/move_transform.dart';

/// Fling's power is the held item's own fling power (Showdown
/// data/items.ts + the sim's implicit classes: berries 10, plates 90,
/// drives 70, Mega Stones 80, memories 50). Items with no fling power
/// (gems, Z-Crystals, …) make the move fail, as does holding nothing.
/// Until 2026-09-12 the table was hand-written and wrong for 80 held
/// items — Choice Scarf shipped as 80 instead of 10 (user report).
void main() {
  const fling = Move(name: 'Fling', nameKo: '내던지기', nameJa: 'なげつける',
      type: PokemonType.dark, category: MoveCategory.physical, power: 30, accuracy: 100, pp: 10);
  int power(String? item) =>
      transformMove(fling, MoveContext(heldItem: item, hasItem: item != null)).move.power;

  test('per-item powers follow the game data', () {
    expect(power('choice-scarf'), 10);
    expect(power('choice-band'), 10);
    expect(power('iron-ball'), 130);
    expect(power('rocky-helmet'), 60);
    expect(power('leftovers'), 10);
    expect(power('kings-rock'), 30);
    expect(power('sharp-beak'), 50);
    expect(power('eviolite'), 40);
  });

  test('implicit classes: berries 10, plates 90, Mega Stones 80', () {
    expect(power('sitrus-berry'), 10);
    expect(power('iron-plate'), 90);
    expect(power('charizardite-x'), 80);
    expect(power('absolite-z'), 80); // Champions-only Mega Stone
  });

  test('unflingable item or no item → the move fails (power 0)', () {
    expect(power('normal-gem'), 0);
    expect(power(null), 0);
  });

  test('other moves are untouched', () {
    const tackle = Move(name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
        type: PokemonType.normal, category: MoveCategory.physical, power: 40, accuracy: 100, pp: 35);
    expect(transformMove(tackle, const MoveContext(heldItem: 'iron-ball', hasItem: true)).move.power, 40);
  });
}
