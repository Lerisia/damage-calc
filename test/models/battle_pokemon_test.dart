import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/type.dart';

void main() {
  group('applyPokemon — Terapagos forms', () {
    late List<Pokemon> pokedex;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      pokedex = await loadPokedex();
    });

    Pokemon byName(String name) => pokedex.firstWhere((p) => p.name == name);

    // Terapagos's Stellar Form only exists once it has Terastallized,
    // so loading it must auto-activate Terastal (Stellar). The form's
    // display name is "Terapagos (Stellar Form)" — the previous
    // `== 'terapagos-stellar'` kebab check never matched it.
    test('Stellar Form auto-Terastallizes (Stellar type)', () {
      final state = BattlePokemonState()
        ..applyPokemon(byName('Terapagos (Stellar Form)'));
      expect(state.terastal.active, isTrue);
      expect(state.terastal.teraType, equals(PokemonType.stellar));
    });

    test('base Terapagos is not Terastallized', () {
      final state = BattlePokemonState()..applyPokemon(byName('Terapagos'));
      expect(state.terastal.active, isFalse);
    });

    test('Terastal Form is not auto-Terastallized', () {
      final state = BattlePokemonState()
        ..applyPokemon(byName('Terapagos (Terastal Form)'));
      expect(state.terastal.active, isFalse);
    });
  });
}
