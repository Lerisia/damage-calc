import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/poke_paste.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/data/sample_storage.dart' show StoredSample;
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/gender.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/models/type.dart';

void main() {
  late final Map<String, dynamic> dexes;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moves = await loadMovedex();
    final items = await loadItemdex();
    dexes = {
      'byName': {for (final p in pokedex) p.name: p},
      'items': items,
      'displayToId': {
        for (final e in items.entries)
          if (e.value.nameEn != null) e.value.nameEn!.toLowerCase(): e.key,
      },
      'moves': moves,
    };
  });

  StoredSample buildGarchomp() {
    final state = BattlePokemonState()..applyPokemon(dexes['byName']['Garchomp']);
    state.level = 100;
    state.gender = Gender.male;
    state.selectedAbility = 'Rough Skin';
    state.selectedItem = 'choice-scarf';
    state.nature = NatureProfile.fromNature(Nature.adamant);
    state.ev = const Stats(
        hp: 0, attack: 252, defense: 0, spAttack: 0, spDefense: 4, speed: 252);
    state.iv = const Stats(
        hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);
    state.terastal = const TerastalState(teraType: PokemonType.fire);
    state.moves = [
      dexes['moves']['Earthquake'],
      dexes['moves']['Dragon Claw'],
      dexes['moves']['Stone Edge'],
      dexes['moves']['Fire Fang'],
    ];
    return StoredSample(id: '', name: 'Speed Demon', state: state);
  }

  group('PokePaste encode', () {
    test('renders a typical Garchomp set', () {
      final text = PokePaste.encodeSample(buildGarchomp(), itemsById: dexes['items']);
      expect(text, contains('Speed Demon (Garchomp) (M) @ Choice Scarf'));
      expect(text, contains('Ability: Rough Skin'));
      expect(text, contains('Tera Type: Fire'));
      expect(text, contains('EVs: 252 Atk / 4 SpD / 252 Spe'));
      expect(text, contains('Adamant Nature'));
      expect(text, isNot(contains('IVs:')));  // all 31 → omitted
      expect(text, isNot(contains('Level:'))); // 100 default → omitted
      expect(text, contains('- Earthquake'));
      expect(text, contains('- Fire Fang'));
    });

    test('omits nickname when equal to species', () {
      final s = buildGarchomp();
      final renamed = StoredSample(id: '', name: s.state.pokemonName, state: s.state);
      final text = PokePaste.encodeSample(renamed, itemsById: dexes['items']);
      expect(text.split('\n').first, startsWith('Garchomp (M)'));
    });

    test('shows Level: line only when not 100', () {
      final s = buildGarchomp();
      s.state.level = 50;
      final text = PokePaste.encodeSample(s, itemsById: dexes['items']);
      expect(text, contains('Level: 50'));
    });

    test('lists non-31 IVs only', () {
      final s = buildGarchomp();
      s.state.iv = const Stats(
          hp: 31, attack: 0, defense: 31, spAttack: 31, spDefense: 31, speed: 31);
      final text = PokePaste.encodeSample(s, itemsById: dexes['items']);
      expect(text, contains('IVs: 0 Atk'));
    });
  });

  group('PokePaste round-trip', () {
    test('encode → decode preserves team-builder state', () {
      final original = buildGarchomp();
      final text = PokePaste.encodeSample(original, itemsById: dexes['items']);
      final decoded = PokePaste.decodeSample(
        text,
        pokemonByName: dexes['byName'],
        itemDisplayToId: dexes['displayToId'],
        moveByName: dexes['moves'],
      );
      expect(decoded.name, equals('Speed Demon'));
      expect(decoded.state.pokemonName, equals('Garchomp'));
      expect(decoded.state.gender, equals(Gender.male));
      expect(decoded.state.selectedAbility, equals('Rough Skin'));
      expect(decoded.state.selectedItem, equals('choice-scarf'));
      expect(decoded.state.nature.asNature(), equals(Nature.adamant));
      expect(decoded.state.ev.attack, equals(252));
      expect(decoded.state.ev.spDefense, equals(4));
      expect(decoded.state.ev.speed, equals(252));
      expect(decoded.state.iv.attack, equals(31));
      expect(decoded.state.terastal.teraType, equals(PokemonType.fire));
      expect(decoded.state.terastal.active, isFalse);  // battle state — fresh
      expect(decoded.state.moves[0]?.name, equals('Earthquake'));
      expect(decoded.state.moves[3]?.name, equals('Fire Fang'));
    });

    test('battle-only state resets on import (HP %, rank, status, …)', () {
      final s = buildGarchomp();
      s.state.hpPercent = 50;
      s.state.tailwind = true;
      // (rank / status / dynamax stay at their applyPokemon defaults)
      final text = PokePaste.encodeSample(s, itemsById: dexes['items']);
      final decoded = PokePaste.decodeSample(
        text,
        pokemonByName: dexes['byName'],
        itemDisplayToId: dexes['displayToId'],
        moveByName: dexes['moves'],
      );
      expect(decoded.state.hpPercent, equals(100));
      expect(decoded.state.tailwind, isFalse);
    });
  });

  group('PokePaste team', () {
    test('round-trip with team header and two members', () {
      final a = buildGarchomp();
      final b = StoredSample(
        id: '',
        name: 'Pika',
        state: BattlePokemonState()..applyPokemon(dexes['byName']['Pikachu']),
      );
      final team = PokePaste.encodeTeam(
        'My Squad',
        [
          (name: a.name, state: a.state),
          (name: b.name, state: b.state),
        ],
        itemsById: dexes['items'],
      );
      expect(team, startsWith('=== My Squad ==='));
      final decoded = PokePaste.decodeTeam(
        team,
        pokemonByName: dexes['byName'],
        itemDisplayToId: dexes['displayToId'],
        moveByName: dexes['moves'],
      );
      expect(decoded.name, equals('My Squad'));
      expect(decoded.members.length, equals(2));
      expect(decoded.members[0].name, equals('Speed Demon'));
      expect(decoded.members[1].name, equals('Pika'));
      expect(decoded.members[1].state.pokemonName, equals('Pikachu'));
    });
  });

  group('PokePaste sniffing', () {
    test('looksLikePokePaste true for a set', () {
      final text = PokePaste.encodeSample(buildGarchomp(), itemsById: dexes['items']);
      expect(PokePaste.looksLikePokePaste(text), isTrue);
    });
    test('looksLikePokePaste rejects legacy damacalc: prefix', () {
      expect(PokePaste.looksLikePokePaste('damacalc:p2:abcd'), isFalse);
    });
    test('looksLikePokePasteTeam needs header or multiple blocks', () {
      final single = PokePaste.encodeSample(buildGarchomp(), itemsById: dexes['items']);
      expect(PokePaste.looksLikePokePasteTeam(single), isFalse);
      expect(PokePaste.looksLikePokePasteTeam('=== Team ===\n\n$single'), isTrue);
    });
  });
}
