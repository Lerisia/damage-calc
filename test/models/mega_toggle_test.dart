import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/dynamax.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/models/type.dart';

/// Mega Evolution / Primal Reversion toggle.
///
/// Unlike picking the mega as a species, toggling must keep the build
/// the user typed in: moves, EVs, IVs, nature, level and the held
/// stone all survive. Only the species identity and what follows from
/// it (stats, typing, ability pool) changes.
void main() {
  late final Map<String, Pokemon> byName;
  late final Map<String, dynamic> moves;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dex = await loadPokedex();
    byName = {for (final p in dex) p.name: p};
    moves = await loadMovedex();
  });

  BattlePokemonState build(String species, {String? item}) {
    final s = BattlePokemonState()..applyPokemon(byName[species]!);
    s.level = 50;
    s.nature = NatureProfile.fromNature(Nature.adamant);
    s.ev = const Stats(
        hp: 4, attack: 252, defense: 0, spAttack: 0, spDefense: 0, speed: 252);
    s.iv = const Stats(
        hp: 31, attack: 31, defense: 31, spAttack: 0, spDefense: 31, speed: 31);
    s.moves[0] = moves['Earthquake'];
    s.moves[1] = moves['Dragon Claw'];
    if (item != null) s.selectedItem = item;
    return s;
  }

  group('toggleMegaForm', () {
    test('base → mega follows the held stone', () {
      final s = build('Charizard', item: 'charizardite-y');
      expect(s.toggleMegaForm(), isTrue);
      expect(s.pokemonName, equals('Mega Charizard Y'));
      expect(s.isMega, isTrue);
      // Y is Fire/Flying with Drought; X would be Fire/Dragon.
      expect(s.type2, equals(PokemonType.flying));
      expect(s.baseStats.spAttack,
          equals(byName['Mega Charizard Y']!.baseStats.spAttack));
      expect(s.pokemonAbilities, contains('Drought'));
    });

    test('the X stone gives the X forme', () {
      final s = build('Charizard', item: 'charizardite-x');
      expect(s.toggleMegaForm(), isTrue);
      expect(s.pokemonName, equals('Mega Charizard X'));
      expect(s.type2, equals(PokemonType.dragon));
    });

    test('mega → base reverts to the original species', () {
      final s = build('Charizard', item: 'charizardite-x');
      s.toggleMegaForm();
      expect(s.toggleMegaForm(), isTrue);
      expect(s.pokemonName, equals('Charizard'));
      expect(s.isMega, isFalse);
      expect(s.type2, equals(PokemonType.flying));
      expect(s.baseStats.attack, equals(byName['Charizard']!.baseStats.attack));
    });

    test('the build survives a round trip', () {
      final s = build('Charizard', item: 'charizardite-x');
      s.toggleMegaForm();
      expect(s.level, equals(50));
      expect(s.nature.asNature(), equals(Nature.adamant));
      expect(s.ev.attack, equals(252));
      expect(s.iv.spAttack, equals(0));
      expect(s.moves[0]?.name, equals('Earthquake'));
      expect(s.moves[1]?.name, equals('Dragon Claw'));
      expect(s.selectedItem, equals('charizardite-x'),
          reason: 'the stone must stay held');

      s.toggleMegaForm();
      expect(s.level, equals(50));
      expect(s.ev.speed, equals(252));
      expect(s.moves[0]?.name, equals('Earthquake'));
      expect(s.selectedItem, equals('charizardite-x'));
    });

    test('primal reversion works the same way', () {
      final s = build('Groudon', item: 'red-orb');
      expect(s.toggleMegaForm(), isTrue);
      expect(s.pokemonName, equals('Primal Groudon'));
      expect(s.pokemonAbilities, contains('Desolate Land'));
      expect(s.toggleMegaForm(), isTrue);
      expect(s.pokemonName, equals('Groudon'));
    });

    test('mega clears Terastal and Dynamax', () {
      final s = build('Charizard', item: 'charizardite-x');
      s.terastal = const TerastalState(active: true, teraType: PokemonType.fire);
      s.dynamax = DynamaxState.dynamax;
      s.toggleMegaForm();
      expect(s.terastal.active, isFalse);
      expect(s.dynamax, equals(DynamaxState.none));
    });

    test('does nothing without a legal stone', () {
      final noItem = build('Charizard');
      expect(noItem.toggleMegaForm(), isFalse);
      expect(noItem.pokemonName, equals('Charizard'));

      final wrongStone = build('Charizard', item: 'gyaradosite');
      expect(wrongStone.toggleMegaForm(), isFalse);
      expect(wrongStone.pokemonName, equals('Charizard'));

      final plainItem = build('Charizard', item: 'leftovers');
      expect(plainItem.toggleMegaForm(), isFalse);
    });

    test('a fixed-forme item is not togglable', () {
      final s = build('Ogerpon', item: 'wellspring-mask');
      expect(s.toggleMegaForm(), isFalse);
      expect(s.pokemonName, equals('Ogerpon'));
    });
  });

  group('canToggleMegaForm', () {
    test('mirrors what the toggle would do', () {
      expect(build('Charizard', item: 'charizardite-x').canToggleMegaForm,
          isTrue);
      expect(build('Groudon', item: 'red-orb').canToggleMegaForm, isTrue);
      expect(build('Charizard').canToggleMegaForm, isFalse);
      expect(build('Charizard', item: 'gyaradosite').canToggleMegaForm, isFalse);
      expect(build('Ogerpon', item: 'wellspring-mask').canToggleMegaForm,
          isFalse);
    });

    test('stays true while already mega, so the user can revert', () {
      final s = build('Charizard', item: 'charizardite-x');
      s.toggleMegaForm();
      expect(s.canToggleMegaForm, isTrue);
    });
  });
}
