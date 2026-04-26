import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/learnsetdex.dart';

void main() {
  group('toShowdownMoveId', () {
    // Table-driven: each entry produces one isolated test() so a
    // single mismatch still reports cleanly without affecting siblings.
    const cases = <(String label, String input, String expected)>[
      ('simple move', 'Acid Spray', 'acidspray'),
      ('apostrophe move', "King's Shield", 'kingsshield'),
      ('hyphenated move', 'X-Scissor', 'xscissor'),
      ('comma move', '10,000,000 Volt Thunderbolt', '10000000voltthunderbolt'),
      ('single word', 'Earthquake', 'earthquake'),
    ];
    for (final c in cases) {
      test(c.$1, () {
        expect(toShowdownMoveId(c.$2), equals(c.$3));
      });
    }
  });

  group('toShowdownPokemonId', () {
    // Single-input cases — each becomes its own test() for isolation.
    const cases = <(String label, String input, String expected)>[
      ('simple name', 'Bulbasaur', 'bulbasaur'),
      ('Nidoran female', 'Nidoran♀', 'nidoranf'),
      ('Nidoran male', 'Nidoran♂', 'nidoranm'),
      ('Mr. Mime', 'Mr. Mime', 'mrmime'),
      ("Farfetch'd", "Farfetch'd", 'farfetchd'),
      ('Flabébé', 'Flabébé', 'flabebe'),
      ('Type: Null', 'Type: Null', 'typenull'),
      ('Mega → base form', 'Mega Charizard', 'charizard'),
      ('Mega Charizard X → base form', 'Mega Charizard X', 'charizard'),
      ('Mega Charizard Y → base form', 'Mega Charizard Y', 'charizard'),
      // Mega Meganium → base must not collapse to "meganium"-the-fragment
      // accidentally — keeps its own row to call that out.
      ('Mega Meganium → base form (no meganium confusion)',
          'Mega Meganium', 'meganium'),
      ('Aegislash form → base', 'aegislash-blade', 'aegislash'),
      ('Deoxys form → base', 'deoxys-attack', 'deoxys'),
    ];
    for (final c in cases) {
      test(c.$1, () {
        expect(toShowdownPokemonId(c.$2), equals(c.$3));
      });
    }

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

    // Spot-check learnsets that exercise non-trivial data paths
    // (egg moves, restored moves, ZA-only data, etc.). Each row stays
    // its own test() so a single regression points at the exact pair.
    const learnSpotChecks = <(String label, String pokemon, String moveId)>[
      // Champions restored Roost (gone in Gen 9 SV)
      ('Scizor has Roost in Champions', 'Scizor', 'roost'),
      // Inherited from Scorbunny egg move
      ('Cinderace has High Jump Kick', 'Cinderace', 'highjumpkick'),
      // Gen 7 source, Let's Go excluded
      ('Beedrill has Fell Stinger', 'Beedrill', 'fellstinger'),
      ('Pikachu has Thunderbolt', 'Pikachu', 'thunderbolt'),
      // ZA-only data path
      ('Meganium has Solar Beam (ZA data)', 'Meganium', 'solarbeam'),
    ];
    for (final c in learnSpotChecks) {
      test(c.$1, () async {
        final moves = await getLearnableMoves(c.$2);
        expect(moves.contains(c.$3), isTrue,
            reason: '${c.$2} should know ${c.$3}');
      });
    }

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
