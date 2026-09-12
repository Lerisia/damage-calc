import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';

/// Stateful abilities ship as concrete state keys in the species data
/// ("Stakeout Inactive" / "Stakeout Active", "Flash Fire Inactive" /
/// "Flash Fire Active", …) while the bare group entry ("Stakeout",
/// "Flash Fire") is `descriptionOnly` and hidden from pickers. A species
/// still pointing at the bare key would surface an ability the calc has
/// no effect for — so every species ability key must resolve to a real,
/// pickable dex entry, either directly or through
/// `expandAbilityKey` (Supreme Overlord is deliberately listed bare and
/// expanded to "Supreme Overlord 0" on pick). Caught Varoom listing a
/// bare "Slow Start" on 2026-09-12.
void main() {
  test('every species ability key is a pickable ability dex entry', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final abilities = await loadAbilitydex();
    final bad = <String>[];
    for (final p in pokedex) {
      for (final raw in p.abilities) {
        final key = BattlePokemonState.expandAbilityKey(raw) ?? raw;
        final ab = abilities[key];
        if (ab == null) {
          bad.add('${p.name}: "$key" missing from abilities.json');
        } else if (ab.descriptionOnly) {
          bad.add('${p.name}: "$key" is a description-only group key');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
