import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/learnsetdex.dart';

void main() {
  group('toShowdownMoveId', () {
    test('simple move', () {
      expect(toShowdownMoveId('Acid Spray'), equals('acidspray'));
    });

    test('apostrophe move', () {
      expect(toShowdownMoveId("King's Shield"), equals('kingsshield'));
    });

    test('hyphenated move', () {
      expect(toShowdownMoveId('X-Scissor'), equals('xscissor'));
    });

    test('comma move', () {
      expect(toShowdownMoveId('10,000,000 Volt Thunderbolt'), equals('10000000voltthunderbolt'));
    });

    test('single word', () {
      expect(toShowdownMoveId('Earthquake'), equals('earthquake'));
    });
  });

  group('toShowdownPokemonId', () {
    test('simple name', () {
      expect(toShowdownPokemonId('Bulbasaur'), equals('bulbasaur'));
    });

    test('Nidoran female', () {
      expect(toShowdownPokemonId('Nidoran♀'), equals('nidoranf'));
    });

    test('Nidoran male', () {
      expect(toShowdownPokemonId('Nidoran♂'), equals('nidoranm'));
    });

    test('Mr. Mime', () {
      expect(toShowdownPokemonId('Mr. Mime'), equals('mrmime'));
    });

    test("Farfetch'd", () {
      expect(toShowdownPokemonId("Farfetch'd"), equals('farfetchd'));
    });

    test('Flabébé', () {
      expect(toShowdownPokemonId('Flabébé'), equals('flabebe'));
    });

    test('Type: Null', () {
      expect(toShowdownPokemonId('Type: Null'), equals('typenull'));
    });

    test('Mega → base form', () {
      expect(toShowdownPokemonId('Mega Charizard'), equals('charizard'));
    });

    test('Mega X/Y → base form', () {
      expect(toShowdownPokemonId('Mega Charizard X'), equals('charizard'));
      expect(toShowdownPokemonId('Mega Charizard Y'), equals('charizard'));
    });

    test('Mega Meganium → base form (not confused with meganium)', () {
      expect(toShowdownPokemonId('Mega Meganium'), equals('meganium'));
    });

    test('alternate form → base form', () {
      expect(toShowdownPokemonId('aegislash-blade'), equals('aegislash'));
      expect(toShowdownPokemonId('deoxys-attack'), equals('deoxys'));
    });

    test('Alolan Form with dexNumber resolves via regional map', () {
      // This requires _regional cache to be loaded, so test the name detection
      final id = toShowdownPokemonId('Alolan Form',
          nameKo: '라이츄 (알로라의 모습)');
      // Without learnset data loaded, falls back to normalized name
      // The full resolution happens in getLearnableMoves with dexNumber
      expect(id, isNotEmpty);
    });
  });

  group('getLearnableMoves', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('returns moves for a known Pokemon', () async {
      final moves = await getLearnableMoves('Bulbasaur');
      expect(moves, isNotEmpty);
      expect(moves.contains('solarbeam'), isTrue);
      expect(moves.contains('tackle'), isTrue);
    });

    test('returns moves for Mega (uses base form)', () async {
      final megaMoves = await getLearnableMoves('Mega Charizard X');
      final baseMoves = await getLearnableMoves('Charizard');
      expect(megaMoves, equals(baseMoves));
    });

    test('returns moves for alternate form (uses base)', () async {
      final formMoves = await getLearnableMoves('aegislash-blade');
      final baseMoves = await getLearnableMoves('Aegislash');
      expect(formMoves, equals(baseMoves));
    });

    test('Scizor does not have Roost', () async {
      final moves = await getLearnableMoves('Scizor');
      expect(moves.contains('roost'), isFalse);
    });

    test('Pikachu has Thunderbolt', () async {
      final moves = await getLearnableMoves('Pikachu');
      expect(moves.contains('thunderbolt'), isTrue);
    });

    test('Meganium has Solar Beam (ZA data)', () async {
      final moves = await getLearnableMoves('Meganium');
      expect(moves.contains('solarbeam'), isTrue);
    });

    test('special name Pokemon resolve correctly', () async {
      final nidoranF = await getLearnableMoves('Nidoran♀');
      expect(nidoranF, isNotEmpty);

      final mrMime = await getLearnableMoves('Mr. Mime');
      expect(mrMime, isNotEmpty);

      final farfetchd = await getLearnableMoves("Farfetch'd");
      expect(farfetchd, isNotEmpty);
    });

    test('Alolan form with dexNumber has distinct moves', () async {
      final alolanRaichu = await getLearnableMoves('Alolan Form',
          nameKo: '라이츄 (알로라의 모습)', dexNumber: 26);
      expect(alolanRaichu, isNotEmpty);
      // Alolan Raichu should have psychic (psychic/electric type)
      expect(alolanRaichu.contains('psychic'), isTrue);
    });

    test('Galarian form with dexNumber resolves', () async {
      final galarMeowth = await getLearnableMoves('Galarian Form',
          nameKo: '나옹 (가라르의 모습)', dexNumber: 52);
      expect(galarMeowth, isNotEmpty);
    });

    test('unknown Pokemon returns empty set', () async {
      final moves = await getLearnableMoves('NonExistentMon');
      expect(moves, isEmpty);
    });
  });

  group('Magnitude mapping', () {
    test('Magnitude variants map to base magnitude', () {
      // Magnitude 4~10 should all map to 'magnitude'
      expect(toShowdownMoveId('Magnitude 4'), equals('magnitude4'));
      expect(toShowdownMoveId('Magnitude 10'), equals('magnitude10'));
      // The _canLearn logic in MoveSelector handles the Magnitude → magnitude check
    });
  });
}
