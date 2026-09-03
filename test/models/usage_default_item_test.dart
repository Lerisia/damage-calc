import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/pokemon.dart';

/// The Champions usage defaults pick the community's top item.
///
/// Mega Stones used to be skipped there: before the mega toggle
/// existed, a base form holding its stone had no way to actually Mega
/// Evolve, so the loader reached past it for the next item. Now the
/// toggle makes that state meaningful — the stone is the honest #1
/// pick and the user taps the button when they want the mega.
void main() {
  late final Map<String, Pokemon> byName;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dex = await loadPokedex();
    byName = {for (final p in dex) p.name: p};
    await loadChampionsUsage();
  });

  /// Species whose curated #1 item is their own Mega Stone.
  String? topItemOf(String species) {
    final usage = championsUsageFor(species);
    if (usage == null || usage.items.isEmpty) return null;
    return usage.items.first.name;
  }

  test('a base form keeps its Mega Stone when that is the top pick', () {
    // Guard the premise so a data refresh that drops the stone turns
    // into a clear failure here rather than a silently vacuous test.
    expect(topItemOf('Charizard'), equals('charizardite-y'),
        reason: 'usage data premise for this test');

    final s = BattlePokemonState()..applyPokemon(byName['Charizard']!);
    expect(s.selectedItem, equals('charizardite-y'));
    expect(s.pokemonName, equals('Charizard'),
        reason: 'holding the stone must not transform the species');
    expect(s.canToggleMegaForm, isTrue,
        reason: 'the toggle is what makes keeping the stone reasonable');
  });

  test('the stone that wins is the one usage actually ranks first', () {
    // Charizard's top pick is the Y stone, so loading it must not
    // land on X.
    final s = BattlePokemonState()..applyPokemon(byName['Charizard']!);
    expect(s.selectedItem, isNot(equals('charizardite-x')));
    s.toggleMegaForm();
    expect(s.pokemonName, equals('Mega Charizard Y'));
  });

  test('a mega form still pins its own stone', () {
    final s = BattlePokemonState()..applyPokemon(byName['Mega Charizard X']!);
    expect(s.selectedItem, equals('charizardite-x'));
  });

  test('species without a stone are unaffected', () {
    final top = topItemOf('Corviknight');
    if (top == null) return; // uncurated in this data drop
    final s = BattlePokemonState()..applyPokemon(byName['Corviknight']!);
    expect(s.selectedItem, equals(top));
  });
}
