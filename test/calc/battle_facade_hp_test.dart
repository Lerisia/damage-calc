import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/calc/battle_facade.dart';
import 'package:damage_calc/calc/hp.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/dynamax.dart';

/// Dynamax keeps the HP share (Bulbapedia: "current HP is adjusted to
/// retain the same percentage of HP remaining"), doubling max and
/// current alike; the facade exposes the HP the mon has right now.
void main() {
  test('current HP follows the doubled max while Dynamaxed', () {
    final s = BattlePokemonState();
    final max = BattleFacade.maxHp(s);
    BattleFacade.setCurrentHp(s, 101);
    expect(BattleFacade.currentHp(s), 101);
    s.dynamax = DynamaxState.dynamax;
    expect(BattleFacade.effectiveMaxHp(s), 2 * max);
    expect(BattleFacade.currentHp(s), 202);
  });

  test('a value set while Dynamaxed keeps its share when Dynamax ends', () {
    final s = BattlePokemonState()..dynamax = DynamaxState.dynamax;
    final max = BattleFacade.maxHp(s);
    BattleFacade.setCurrentHp(s, 101); // of 2·max
    expect(BattleFacade.currentHp(s), 101);
    s.dynamax = DynamaxState.none;
    // 101 / (2·max) of max = 50.5 → 51, as the game rounds up.
    expect(BattleFacade.currentHp(s), 51);
    expect(BattleFacade.currentHp(s), lessThanOrEqualTo(max));
  });

  test('setCurrentHp keeps up to 150 % of the max the mon has right now', () {
    final s = BattlePokemonState();
    final max = BattleFacade.maxHp(s);
    BattleFacade.setCurrentHp(s, 10 * max);
    expect(BattleFacade.currentHp(s), maxCurrentHp(max));
    BattleFacade.setCurrentHp(s, max + 10);
    expect(BattleFacade.currentHp(s), max + 10);
  });
}
