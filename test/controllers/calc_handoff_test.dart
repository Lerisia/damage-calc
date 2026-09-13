import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/controllers/calc_handoff.dart';

/// The one-shot inbox the team builder uses to push a Pokémon into the
/// calculator: staging notifies, consuming empties.
void main() {
  test('stage notifies; consume returns the payload once', () {
    final h = CalcHandoff.instance;
    var fired = 0;
    void onChange() => fired++;
    h.addListener(onChange);
    final state = BattlePokemonState(pokemonName: 'Garchomp');
    h.stage(side: 1, state: state, loadedSampleName: 'my sample');
    h.removeListener(onChange);
    expect(fired, 1);

    final p = h.consume();
    expect(p, isNotNull);
    expect(p!.side, 1);
    expect(identical(p.state, state), isTrue);
    expect(p.loadedSampleName, 'my sample');
    expect(h.consume(), isNull, reason: 'second consume finds an empty inbox');
  });
}
