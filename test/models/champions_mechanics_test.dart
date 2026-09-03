import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/dynamax.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/models/type.dart';

/// Pokémon Champions has no Dynamax, no Terastal and no Z-Moves.
///
/// Hiding the buttons alone isn't enough: a state saved in extended
/// mode can still carry an active mechanic, which would then apply to
/// the damage numbers with no visible cause. So switching to
/// Champions-only clears them as well.
void main() {
  late final Map<String, Pokemon> byName;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dex = await loadPokedex();
    byName = {for (final p in dex) p.name: p};
  });

  BattlePokemonState charizard() =>
      BattlePokemonState()..applyPokemon(byName['Charizard']!);

  test('clears an active Dynamax', () {
    final s = charizard()..dynamax = DynamaxState.dynamax;
    expect(s.clearNonChampionsMechanics(), isTrue);
    expect(s.dynamax, equals(DynamaxState.none));
  });

  test('clears Gigantamax too', () {
    final s = charizard()..dynamax = DynamaxState.gigantamax;
    expect(s.clearNonChampionsMechanics(), isTrue);
    expect(s.dynamax, equals(DynamaxState.none));
  });

  test('clears Terastal outright, type included', () {
    final s = charizard()
      ..terastal =
          const TerastalState(active: true, teraType: PokemonType.fire);
    expect(s.clearNonChampionsMechanics(), isTrue);
    expect(s.terastal.active, isFalse);
    // The picker sets type and activation together, and its "no Tera"
    // option resets both — so clearing must land in the same place.
    expect(s.terastal.teraType, isNull);
  });

  test('clears Z-Move flags', () {
    final s = charizard()..zMoves = [true, false, true, false];
    expect(s.clearNonChampionsMechanics(), isTrue);
    expect(s.zMoves, equals([false, false, false, false]));
  });

  test('reports false when there is nothing to clear', () {
    final s = charizard();
    expect(s.clearNonChampionsMechanics(), isFalse);
  });

  test('an inactive state is left alone', () {
    // The UI can't produce a type without activation, but a decoded
    // PokePaste can carry one; it changes no damage, so leave it.
    final s = charizard()
      ..terastal =
          const TerastalState(active: false, teraType: PokemonType.water);
    expect(s.clearNonChampionsMechanics(), isFalse);
    expect(s.terastal.teraType, equals(PokemonType.water));
  });

  test('leaves the rest of the build untouched', () {
    final s = charizard()
      ..dynamax = DynamaxState.dynamax
      ..level = 50
      ..hpPercent = 40;
    final ability = s.selectedAbility;
    s.clearNonChampionsMechanics();
    expect(s.pokemonName, equals('Charizard'));
    expect(s.level, equals(50));
    expect(s.hpPercent, equals(40));
    expect(s.selectedAbility, equals(ability));
  });
}
