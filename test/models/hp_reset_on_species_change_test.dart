import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/pokemon.dart';

/// Users reported the HP slider carrying over between Pokémon: pick a
/// new species and it starts at whatever percentage the last one was
/// left at. A new Pokémon enters at full HP. A form toggle is not a
/// new Pokémon — the build stays, HP included.
void main() {
  late final Map<String, Pokemon> byName;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    byName = {for (final p in await loadPokedex()) p.name: p};
  });

  test('picking a species resets HP to 100%', () {
    final s = BattlePokemonState()..applyPokemon(byName['Garchomp']!);
    s.hpPercent = 40;
    s.applyPokemon(byName['Hippowdon']!);
    expect(s.hpPercent, 100);
  });

  test('a form toggle keeps the current HP', () {
    final s = BattlePokemonState()..applyPokemon(byName['Aegislash']!);
    s.hpPercent = 55;
    expect(s.toggleForm(), isTrue);
    expect(s.hpPercent, 55);
  });
}
