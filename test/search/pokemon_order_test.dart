import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/search/pokemon_order.dart';

/// Default order of the species picker (user decision 2026-10-01):
/// Champions usage rank first — not dex order — and a Mega sits right
/// next to its base species.
void main() {
  late List<Pokemon> visible;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    visible = (await loadPokedex()).where((p) => !p.hidden).toList();
  });

  List<String> ordered(Map<String, int> ranks) {
    final order = usageOrder(visible, (name) => ranks[name]);
    return [for (final p in visible) p.name]
      ..sort((a, b) => order[a]!.compareTo(order[b]!));
  }

  test('ranked species lead, best rank first; each trailed by its megas', () {
    final names = ordered({'Garchomp': 1, 'Primarina': 2, 'Charizard': 3});
    expect(names.take(7), [
      'Garchomp', 'Mega Garchomp', 'Mega Garchomp Z',
      'Primarina',
      'Charizard', 'Mega Charizard X', 'Mega Charizard Y',
    ]);
  });

  test('the unranked follow in dex order, still trailed by their megas', () {
    final names = ordered({'Garchomp': 1});
    // After Garchomp's block: Bulbasaur, Ivysaur, Venusaur, Mega Venusaur…
    expect(names.sublist(3, 7),
        ['Bulbasaur', 'Ivysaur', 'Venusaur', 'Mega Venusaur']);
    expect(names.indexOf('Mega Charizard X'), names.indexOf('Charizard') + 1);
  });

  test('battle and primal forms without a rank sit next to their base too', () {
    final names = ordered({'Aegislash': 1, 'Kyogre': 2});
    expect(names.take(4), [
      'Aegislash', 'Aegislash (Blade Forme)',
      'Kyogre', 'Primal Kyogre',
    ]);
  });

  test('a form with its own rank keeps its own place', () {
    final names = ordered({'Charizard': 1, 'Mega Charizard Y': 2, 'Garchomp': 3});
    expect(names.take(4), [
      'Charizard', 'Mega Charizard X', // unranked mega stays attached
      'Mega Charizard Y', // ranked on its own
      'Garchomp',
    ]);
  });

  test('every species gets a distinct position', () {
    final order = usageOrder(visible, (name) => null);
    expect(order.length, visible.length);
    expect(order.values.toSet().length, visible.length);
  });
}
