import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/views/widgets/dex_search_filter_dialog.dart';

Pokemon _p({
  required String name,
  required PokemonType t1,
  PokemonType? t2,
  Stats? stats,
  List<String> abilities = const [],
}) {
  return Pokemon(
    dexNumber: 1,
    name: name,
    nameKo: name,
    nameJa: name,
    type1: t1,
    type2: t2,
    baseStats: stats ??
        const Stats(
            hp: 100,
            attack: 100,
            defense: 100,
            spAttack: 100,
            spDefense: 100,
            speed: 100),
    abilities: abilities,
    weight: 50.0,
    height: 1.5,
  );
}

void main() {
  group('DexSearchFilter.activeCount', () {
    test('empty filter is empty', () {
      expect(DexSearchFilter.empty.isEmpty, true);
      expect(DexSearchFilter.empty.activeCount, 0);
    });

    test('counts each populated section once', () {
      const f = DexSearchFilter(
        types: [PokemonType.fire],
        bstMin: 500,
        hpMin: 80,
        atkMin: 90,
        defenses: [
          DexDefenseEntry(
              type: PokemonType.water, relation: DexDefenseRelation.weakness),
          DexDefenseEntry(
              type: PokemonType.grass, relation: DexDefenseRelation.resistance),
        ],
        abilityKey: 'Blaze',
        moveIds: ['flamethrower'],
      );
      // types + bst + hp + atk + defense + ability + moves = 7
      // (multiple defense entries still count as a single section)
      expect(f.activeCount, 7);
      expect(f.isEmpty, false);
    });

    test('range counts as one section even if only one bound is set', () {
      const f = DexSearchFilter(bstMin: 500);
      expect(f.activeCount, 1);
    });
  });

  group('matchesDexFilter — types', () {
    final charizard = _p(name: 'Charizard', t1: PokemonType.fire, t2: PokemonType.flying);
    final blaziken = _p(name: 'Blaziken', t1: PokemonType.fire, t2: PokemonType.fighting);
    final ponyta = _p(name: 'Ponyta', t1: PokemonType.fire);
    final blastoise = _p(name: 'Blastoise', t1: PokemonType.water);
    final empty = <String, Set<String>>{};

    test('1 type — Pokémon must include that type (single or dual ok)', () {
      const f = DexSearchFilter(types: [PokemonType.fire]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), true);
      expect(matchesDexFilter(blaziken, f, movesByPokemon: empty), true);
      expect(matchesDexFilter(ponyta, f, movesByPokemon: empty), true);
      expect(matchesDexFilter(blastoise, f, movesByPokemon: empty), false);
    });

    test('2 types — only exact dual-type match', () {
      const f = DexSearchFilter(
          types: [PokemonType.fire, PokemonType.flying]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), true);
      // Same fire but flying != fighting
      expect(matchesDexFilter(blaziken, f, movesByPokemon: empty), false);
      // Single fire doesn't have the second type
      expect(matchesDexFilter(ponyta, f, movesByPokemon: empty), false);
    });

    test('2 types — order-insensitive', () {
      const a = DexSearchFilter(
          types: [PokemonType.fire, PokemonType.flying]);
      const b = DexSearchFilter(
          types: [PokemonType.flying, PokemonType.fire]);
      expect(matchesDexFilter(charizard, a, movesByPokemon: empty), true);
      expect(matchesDexFilter(charizard, b, movesByPokemon: empty), true);
    });
  });

  group('matchesDexFilter — stats', () {
    final tank = _p(
      name: 'Tank',
      t1: PokemonType.steel,
      stats: const Stats(
          hp: 100,
          attack: 50,
          defense: 200,
          spAttack: 50,
          spDefense: 150,
          speed: 30),
    );
    final empty = <String, Set<String>>{};

    test('BST range — both bounds inclusive', () {
      // total BST = 100+50+200+50+150+30 = 580
      expect(matchesDexFilter(tank, const DexSearchFilter(bstMin: 580), movesByPokemon: empty), true);
      expect(matchesDexFilter(tank, const DexSearchFilter(bstMin: 581), movesByPokemon: empty), false);
      expect(matchesDexFilter(tank, const DexSearchFilter(bstMax: 580), movesByPokemon: empty), true);
      expect(matchesDexFilter(tank, const DexSearchFilter(bstMax: 579), movesByPokemon: empty), false);
    });

    test('per-stat ranges — only those stats are checked', () {
      // defense 200 — passes 200, fails 201
      expect(matchesDexFilter(tank, const DexSearchFilter(defMin: 200), movesByPokemon: empty), true);
      expect(matchesDexFilter(tank, const DexSearchFilter(defMin: 201), movesByPokemon: empty), false);
      // speed 30 — fails when asked for ≥100
      expect(matchesDexFilter(tank, const DexSearchFilter(speMin: 100), movesByPokemon: empty), false);
    });
  });

  group('matchesDexFilter — defense type', () {
    final charizard = _p(name: 'Charizard', t1: PokemonType.fire, t2: PokemonType.flying);
    final blastoise = _p(name: 'Blastoise', t1: PokemonType.water);
    final empty = <String, Set<String>>{};

    test('weakness — fire/flying is 4× weak to rock', () {
      const f = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.rock, relation: DexDefenseRelation.weakness),
      ]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), true);
    });

    test('resistance — fire/flying is 0.5× to fighting', () {
      const f = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.fighting,
            relation: DexDefenseRelation.resistance),
      ]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), true);
    });

    test('immunity bucket — flying is immune to ground (0×)', () {
      const f = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.ground, relation: DexDefenseRelation.immunity),
      ]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), true);
    });

    test('resistance bucket excludes 0× immunity matchups', () {
      // Charizard is immune (0×) to ground — that's NOT a "resistance"
      // pick. Selecting resistance should reject it.
      const f = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.ground, relation: DexDefenseRelation.resistance),
      ]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), false);
    });

    test('immunity rejects non-immune matchups', () {
      // Charizard's grass matchup is 0.5× (resistance, not immunity).
      const f = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.grass, relation: DexDefenseRelation.immunity),
      ]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), false);
    });

    test('neutral — water vs fire/flying is 2× → weakness', () {
      const f = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.water, relation: DexDefenseRelation.weakness),
      ]);
      expect(matchesDexFilter(charizard, f, movesByPokemon: empty), true);
    });

    test('multiple entries are ANDed — all must be satisfied', () {
      // Charizard: weak to rock (4×), resistant to fighting (0.5×) — both ✓
      const both = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.rock, relation: DexDefenseRelation.weakness),
        DexDefenseEntry(
            type: PokemonType.fighting,
            relation: DexDefenseRelation.resistance),
      ]);
      expect(matchesDexFilter(charizard, both, movesByPokemon: empty), true);

      // Charizard is NOT weak to grass (0.5×) → fails the AND
      const mixed = DexSearchFilter(defenses: [
        DexDefenseEntry(
            type: PokemonType.rock, relation: DexDefenseRelation.weakness),
        DexDefenseEntry(
            type: PokemonType.grass, relation: DexDefenseRelation.weakness),
      ]);
      expect(matchesDexFilter(charizard, mixed, movesByPokemon: empty), false);

      // Blastoise: not weak to rock → fails first entry
      expect(matchesDexFilter(blastoise, both, movesByPokemon: empty), false);
    });
  });

  group('matchesDexFilter — ability', () {
    final p = _p(
      name: 'Garchomp',
      t1: PokemonType.dragon,
      t2: PokemonType.ground,
      abilities: ['Sand Veil', 'Rough Skin'],
    );
    final empty = <String, Set<String>>{};

    test('matches when potential ability list contains the key', () {
      expect(
          matchesDexFilter(p, const DexSearchFilter(abilityKey: 'Rough Skin'),
              movesByPokemon: empty),
          true);
      expect(
          matchesDexFilter(p, const DexSearchFilter(abilityKey: 'Sand Veil'),
              movesByPokemon: empty),
          true);
    });

    test('does not match when ability not in potential list', () {
      expect(
          matchesDexFilter(p, const DexSearchFilter(abilityKey: 'Levitate'),
              movesByPokemon: empty),
          false);
    });
  });

  group('matchesDexFilter — moves', () {
    final p = _p(name: 'Test', t1: PokemonType.normal);
    final movesByPokemon = {
      'Test': {'flamethrower', 'icebeam', 'thunderbolt'},
    };

    test('AND — all moves must be learnable', () {
      expect(
          matchesDexFilter(
              p,
              const DexSearchFilter(
                  moveIds: ['flamethrower', 'icebeam'],
                  movesMatch: DexMovesMatch.and),
              movesByPokemon: movesByPokemon),
          true);
      expect(
          matchesDexFilter(
              p,
              const DexSearchFilter(
                  moveIds: ['flamethrower', 'earthquake'],
                  movesMatch: DexMovesMatch.and),
              movesByPokemon: movesByPokemon),
          false);
    });

    test('OR — at least one move must be learnable', () {
      expect(
          matchesDexFilter(
              p,
              const DexSearchFilter(
                  moveIds: ['flamethrower', 'earthquake'],
                  movesMatch: DexMovesMatch.or),
              movesByPokemon: movesByPokemon),
          true);
      expect(
          matchesDexFilter(
              p,
              const DexSearchFilter(
                  moveIds: ['earthquake', 'closecombat'],
                  movesMatch: DexMovesMatch.or),
              movesByPokemon: movesByPokemon),
          false);
    });

    test('empty moves filter is a no-op (AND or OR)', () {
      expect(
          matchesDexFilter(p, DexSearchFilter.empty,
              movesByPokemon: movesByPokemon),
          true);
    });

    test('species not in map → treated as learning nothing', () {
      final other = _p(name: 'Unknown', t1: PokemonType.normal);
      expect(
          matchesDexFilter(
              other,
              const DexSearchFilter(
                  moveIds: ['flamethrower'],
                  movesMatch: DexMovesMatch.and),
              movesByPokemon: movesByPokemon),
          false);
    });
  });

  test('empty filter matches every Pokémon', () {
    final p = _p(name: 'Anything', t1: PokemonType.normal);
    expect(
        matchesDexFilter(p, DexSearchFilter.empty,
            movesByPokemon: const {}),
        true);
  });
}
