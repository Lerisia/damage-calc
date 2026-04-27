import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/team_coverage.dart';

void main() {
  group('coverageOf — type chart immunities', () {
    test('Normal vs Ghost is immune', () {
      final cell = coverageOf(
          PokemonType.normal, const CoverageSlot(type1: PokemonType.ghost));
      expect(cell.isImmune, isTrue);
      expect(cell.immunityReason, equals('type'));
    });

    test('Fighting vs Ghost is immune', () {
      final cell = coverageOf(
          PokemonType.fighting, const CoverageSlot(type1: PokemonType.ghost));
      expect(cell.isImmune, isTrue);
    });

    test('Electric vs Ground is immune', () {
      final cell = coverageOf(
          PokemonType.electric, const CoverageSlot(type1: PokemonType.ground));
      expect(cell.isImmune, isTrue);
    });

    test('Ground vs Flying is immune (via type chart)', () {
      // Ground/Flying immunity is layered via the chart, but we still
      // route through isGrounded after — make sure the chart fires
      // first so the answer is consistent.
      final cell = coverageOf(
          PokemonType.ground, const CoverageSlot(type1: PokemonType.flying));
      expect(cell.isImmune, isTrue);
    });

    test('Dragon vs Fairy is immune', () {
      final cell = coverageOf(
          PokemonType.dragon, const CoverageSlot(type1: PokemonType.fairy));
      expect(cell.isImmune, isTrue);
    });

    test('Poison vs Steel is immune', () {
      final cell = coverageOf(
          PokemonType.poison, const CoverageSlot(type1: PokemonType.steel));
      expect(cell.isImmune, isTrue);
    });

    test('immunity propagates through type2 / type3', () {
      // Gengar = Ghost/Poison → Normal still immune via type1.
      var cell = coverageOf(
          PokemonType.normal,
          const CoverageSlot(
              type1: PokemonType.ghost, type2: PokemonType.poison));
      expect(cell.isImmune, isTrue);

      // Forest's Curse on a Normal-type → adds Grass as type3.
      // Ghost type added to it via Trick-or-Treat (type2)? Test the
      // dual-add Trick-or-Treat path so type3 immunity counts.
      cell = coverageOf(
          PokemonType.normal,
          const CoverageSlot(
              type1: PokemonType.normal,
              type2: PokemonType.grass,
              type3: PokemonType.ghost));
      expect(cell.isImmune, isTrue,
          reason: 'Ghost type3 should still grant Normal-move immunity');
    });
  });

  group('coverageOf — ability immunities', () {
    test('Sap Sipper immunes Grass', () {
      final cell = coverageOf(
          PokemonType.grass,
          const CoverageSlot(
              type1: PokemonType.normal, ability: 'Sap Sipper'));
      expect(cell.isImmune, isTrue);
      expect(cell.immunityReason, equals('ability'));
    });

    test('Volt Absorb immunes Electric', () {
      final cell = coverageOf(
          PokemonType.electric,
          const CoverageSlot(
              type1: PokemonType.water, ability: 'Volt Absorb'));
      expect(cell.isImmune, isTrue);
    });

    test('Flash Fire immunes Fire', () {
      final cell = coverageOf(
          PokemonType.fire,
          const CoverageSlot(
              type1: PokemonType.fire, ability: 'Flash Fire'));
      expect(cell.isImmune, isTrue);
    });

    test('Earth Eater immunes Ground (overrides 2× Ground weakness)', () {
      // Steel/Rock would normally take 4× from Ground; Earth Eater
      // wipes that to 0×.
      final cell = coverageOf(
          PokemonType.ground,
          const CoverageSlot(
              type1: PokemonType.steel,
              type2: PokemonType.rock,
              ability: 'Earth Eater'));
      expect(cell.isImmune, isTrue);
    });

    test('Well-Baked Body immunes Fire', () {
      final cell = coverageOf(
          PokemonType.fire,
          const CoverageSlot(
              type1: PokemonType.steel, ability: 'Well-Baked Body'));
      expect(cell.isImmune, isTrue);
    });
  });

  group('coverageOf — Levitate / Air Balloon', () {
    test('Levitate immunes Ground for non-Flying types', () {
      // Bronzong is Steel/Psychic with Levitate — Ground would 4×
      // it normally; Levitate cancels.
      final cell = coverageOf(
          PokemonType.ground,
          const CoverageSlot(
              type1: PokemonType.steel,
              type2: PokemonType.psychic,
              ability: 'Levitate'));
      expect(cell.isImmune, isTrue);
      expect(cell.immunityReason, equals('ability'));
    });

    test('Air Balloon immunes Ground', () {
      final cell = coverageOf(
          PokemonType.ground,
          const CoverageSlot(
              type1: PokemonType.normal, heldItem: 'air-balloon'));
      expect(cell.isImmune, isTrue);
    });

    test('Iron Ball overrides Levitate (back to grounded)', () {
      // Iron Ball forces grounding → Ground attack lands at the
      // species' natural matchup (1× for Normal type here).
      final cell = coverageOf(
          PokemonType.ground,
          const CoverageSlot(
              type1: PokemonType.normal,
              ability: 'Levitate',
              heldItem: 'iron-ball'));
      expect(cell.isImmune, isFalse);
      expect(cell.multiplier, equals(1.0));
    });
  });

  group('coverageOf — Wonder Guard', () {
    test('Wonder Guard zeroes neutral hits', () {
      // Shedinja is Bug/Ghost → Normal would already be 0× via type
      // chart (Ghost). Test against a neutral matchup instead:
      // Bug/Ghost vs Bug = 0.5× normally, Wonder Guard makes it 0.
      final cell = coverageOf(
          PokemonType.bug,
          const CoverageSlot(
              type1: PokemonType.bug,
              type2: PokemonType.ghost,
              ability: 'Wonder Guard'));
      expect(cell.isImmune, isTrue);
      expect(cell.immunityReason, equals('wonderGuard'));
    });

    test('Wonder Guard zeroes resisted hits', () {
      // Bug/Ghost vs Grass = 0.5× → Wonder Guard makes it 0.
      final cell = coverageOf(
          PokemonType.grass,
          const CoverageSlot(
              type1: PokemonType.bug,
              type2: PokemonType.ghost,
              ability: 'Wonder Guard'));
      expect(cell.isImmune, isTrue);
    });

    test('Wonder Guard lets super-effective hits through unchanged', () {
      // Bug/Ghost vs Fire = 2× → Wonder Guard does not block.
      final cell = coverageOf(
          PokemonType.fire,
          const CoverageSlot(
              type1: PokemonType.bug,
              type2: PokemonType.ghost,
              ability: 'Wonder Guard'));
      expect(cell.isImmune, isFalse);
      expect(cell.multiplier, equals(2.0));
    });
  });

  group('coverageOf — basic multipliers', () {
    test('Fire vs Grass is 2×', () {
      expect(
          coverageOf(PokemonType.fire,
                  const CoverageSlot(type1: PokemonType.grass))
              .multiplier,
          equals(2.0));
    });

    test('Fire vs Grass/Steel is 4×', () {
      expect(
          coverageOf(
                  PokemonType.fire,
                  const CoverageSlot(
                      type1: PokemonType.grass, type2: PokemonType.steel))
              .multiplier,
          equals(4.0));
    });

    test('Water vs Fire/Grass is 1× (2× × 0.5×)', () {
      expect(
          coverageOf(
                  PokemonType.water,
                  const CoverageSlot(
                      type1: PokemonType.fire, type2: PokemonType.grass))
              .multiplier,
          equals(1.0));
    });
  });

  group('matrix + summary', () {
    test('empty team produces empty matrix and zero-summary columns', () {
      final m = defensiveCoverageMatrix(const []);
      expect(m, isEmpty);
      final s = summarize(m);
      expect(s.length, equals(teamCoverageAttackTypes.length));
      for (final col in s) {
        expect(col.weak + col.neutral + col.resist + col.immune, equals(0));
      }
    });

    test('summary correctly buckets weak/neutral/resist/immune', () {
      // 3-mon team: Fire-type, Water-type, Ghost-type
      // vs Fire attack:
      //   Fire   → 0.5× (resist)
      //   Water  → 0.5× (resist)
      //   Ghost  → 1×   (neutral)
      final team = const [
        CoverageSlot(type1: PokemonType.fire),
        CoverageSlot(type1: PokemonType.water),
        CoverageSlot(type1: PokemonType.ghost),
      ];
      final m = defensiveCoverageMatrix(team);
      final s = summarize(m);
      final fireCol = s[teamCoverageAttackTypes.indexOf(PokemonType.fire)];
      expect(fireCol.resist, equals(2));
      expect(fireCol.neutral, equals(1));
      expect(fireCol.weak, equals(0));
      expect(fireCol.immune, equals(0));

      // vs Normal attack:
      //   Fire   → 1× (neutral)
      //   Water  → 1× (neutral)
      //   Ghost  → 0× (immune via type)
      final normalCol = s[teamCoverageAttackTypes.indexOf(PokemonType.normal)];
      expect(normalCol.immune, equals(1));
      expect(normalCol.neutral, equals(2));
    });
  });

  // ────────────────────────────────────────────────────────────────
  // Offensive — best damage multiplier across a slot's damaging
  // moves vs each single defender type.
  // ────────────────────────────────────────────────────────────────
  group('offensiveEffectivenessOf — single-type effectiveness', () {
    test('Fire vs Grass is 2×', () {
      expect(
          offensiveEffectivenessOf(
              PokemonType.fire, PokemonType.grass),
          equals(2.0));
    });

    test('Water vs Fire is 2×', () {
      expect(
          offensiveEffectivenessOf(
              PokemonType.water, PokemonType.fire),
          equals(2.0));
    });

    test('Fire vs Water is 0.5×', () {
      expect(
          offensiveEffectivenessOf(
              PokemonType.fire, PokemonType.water),
          equals(0.5));
    });

    test('Normal vs Ghost is 0× (chart immunity)', () {
      expect(
          offensiveEffectivenessOf(
              PokemonType.normal, PokemonType.ghost),
          equals(0.0));
    });

    test('Ground vs Flying is 0× (chart immunity)', () {
      expect(
          offensiveEffectivenessOf(
              PokemonType.ground, PokemonType.flying),
          equals(0.0));
    });

    test('Dragon vs Fairy is 0×', () {
      expect(
          offensiveEffectivenessOf(
              PokemonType.dragon, PokemonType.fairy),
          equals(0.0));
    });

    test('Normal vs Normal is 1×', () {
      expect(
          offensiveEffectivenessOf(
              PokemonType.normal, PokemonType.normal),
          equals(1.0));
    });
  });

  group('offensiveCoverageRow — best across moves', () {
    test('single super-effective move propagates to its column', () {
      // Pokemon with Fire alone: vs Grass = 2×, vs Water = 0.5×.
      const slot = CoverageSlot(
        type1: PokemonType.fire,
        moves: [CoverageMove(type: PokemonType.fire)],
      );
      final row = offensiveCoverageRow(slot);
      final grassCell =
          row[teamCoverageDefenseTypes.indexOf(PokemonType.grass)];
      final waterCell =
          row[teamCoverageDefenseTypes.indexOf(PokemonType.water)];
      expect(grassCell.multiplier, equals(2.0));
      expect(waterCell.multiplier, equals(0.5));
    });

    test('best of two moves wins per column', () {
      // Fire + Ground: vs Water → Fire 0.5×, Ground 1× → best 1×.
      // vs Steel → Fire 2×, Ground 2× → best 2× (tied).
      const slot = CoverageSlot(
        type1: PokemonType.fire,
        moves: [
          CoverageMove(type: PokemonType.fire),
          CoverageMove(type: PokemonType.ground),
        ],
      );
      final row = offensiveCoverageRow(slot);
      expect(
          row[teamCoverageDefenseTypes.indexOf(PokemonType.water)]
              .multiplier,
          equals(1.0));
      expect(
          row[teamCoverageDefenseTypes.indexOf(PokemonType.steel)]
              .multiplier,
          equals(2.0));
    });

    test('all-immune row when only Normal moves vs Ghost defender', () {
      const slot = CoverageSlot(
        type1: PokemonType.normal,
        moves: [CoverageMove(type: PokemonType.normal)],
      );
      final row = offensiveCoverageRow(slot);
      final ghostCell =
          row[teamCoverageDefenseTypes.indexOf(PokemonType.ghost)];
      expect(ghostCell.isImmune, isTrue);
      expect(ghostCell.immunityReason, equals('allImmune'));
    });

    test('status moves are skipped — Fire (status) gives an empty pool', () {
      const slot = CoverageSlot(
        type1: PokemonType.fire,
        moves: [
          CoverageMove(type: PokemonType.fire, isDamaging: false),
        ],
      );
      final row = offensiveCoverageRow(slot);
      // No damaging moves → every cell marked immune via 'noMoves'.
      for (final c in row) {
        expect(c.isImmune, isTrue);
        expect(c.immunityReason, equals('noMoves'));
      }
    });

    test('empty move list → all cells immune (noMoves)', () {
      const slot = CoverageSlot(type1: PokemonType.fire);
      final row = offensiveCoverageRow(slot);
      for (final c in row) {
        expect(c.isImmune, isTrue);
        expect(c.immunityReason, equals('noMoves'));
      }
    });

    test('move that hits an immunity does not poison the max', () {
      // Fighting + Rock: vs Ghost → Fighting 0×, Rock 1× → best 1×.
      const slot = CoverageSlot(
        type1: PokemonType.fighting,
        moves: [
          CoverageMove(type: PokemonType.fighting),
          CoverageMove(type: PokemonType.rock),
        ],
      );
      final row = offensiveCoverageRow(slot);
      final ghostCell =
          row[teamCoverageDefenseTypes.indexOf(PokemonType.ghost)];
      expect(ghostCell.multiplier, equals(1.0));
      expect(ghostCell.isImmune, isFalse);
    });
  });

  group('offensiveEffectivenessOf — attacker abilities', () {
    test('Scrappy lets Normal hit Ghost for 1×', () {
      expect(
        offensiveEffectivenessOf(PokemonType.normal, PokemonType.ghost,
            attackerAbility: 'Scrappy'),
        equals(1.0),
      );
    });

    test('Scrappy lets Fighting hit Ghost for 1×', () {
      expect(
        offensiveEffectivenessOf(PokemonType.fighting, PokemonType.ghost,
            attackerAbility: 'Scrappy'),
        equals(1.0),
      );
    });

    test("Mind's Eye = Scrappy for type matchup purposes", () {
      expect(
        offensiveEffectivenessOf(PokemonType.normal, PokemonType.ghost,
            attackerAbility: "Mind's Eye"),
        equals(1.0),
      );
    });

    test('Scrappy does NOT bypass other immunities (Ground vs Flying)', () {
      expect(
        offensiveEffectivenessOf(PokemonType.ground, PokemonType.flying,
            attackerAbility: 'Scrappy'),
        equals(0),
      );
    });

    test('Tinted Lens doubles a 0.5× hit to 1×', () {
      // Fire vs Water = 0.5× → ×2 = 1×.
      expect(
        offensiveEffectivenessOf(PokemonType.fire, PokemonType.water,
            attackerAbility: 'Tinted Lens'),
        equals(1.0),
      );
    });

    test('Tinted Lens does NOT modify neutral hits', () {
      expect(
        offensiveEffectivenessOf(PokemonType.normal, PokemonType.normal,
            attackerAbility: 'Tinted Lens'),
        equals(1.0),
      );
    });

    test('Tinted Lens does NOT modify super-effective hits', () {
      expect(
        offensiveEffectivenessOf(PokemonType.fire, PokemonType.grass,
            attackerAbility: 'Tinted Lens'),
        equals(2.0),
      );
    });

    test('Tinted Lens does NOT bypass immunities', () {
      expect(
        offensiveEffectivenessOf(PokemonType.normal, PokemonType.ghost,
            attackerAbility: 'Tinted Lens'),
        equals(0),
      );
    });
  });

  group('offensiveCoverageRow — special moves', () {
    test('Freeze-Dry vs Water is 2× (overrides chart)', () {
      const slot = CoverageSlot(
        type1: PokemonType.ice,
        moves: [CoverageMove(type: PokemonType.ice, freezeDry: true)],
      );
      final row = offensiveCoverageRow(slot);
      expect(
        row[teamCoverageDefenseTypes.indexOf(PokemonType.water)]
            .multiplier,
        equals(2.0),
      );
    });

    test('Freeze-Dry vs Fire is 0.5× (standard Ice resistance)', () {
      const slot = CoverageSlot(
        type1: PokemonType.ice,
        moves: [CoverageMove(type: PokemonType.ice, freezeDry: true)],
      );
      final row = offensiveCoverageRow(slot);
      expect(
        row[teamCoverageDefenseTypes.indexOf(PokemonType.fire)]
            .multiplier,
        equals(0.5),
      );
    });

    test('Flying Press vs Grass is 2× (Flying 2 × Fighting 1)', () {
      const slot = CoverageSlot(
        type1: PokemonType.fighting,
        moves: [CoverageMove(type: PokemonType.fighting, flyingPress: true)],
      );
      final row = offensiveCoverageRow(slot);
      expect(
        row[teamCoverageDefenseTypes.indexOf(PokemonType.grass)]
            .multiplier,
        equals(2.0),
      );
    });

    test('Flying Press vs Bug is 1× (Flying 2 × Fighting 0.5)', () {
      const slot = CoverageSlot(
        type1: PokemonType.fighting,
        moves: [CoverageMove(type: PokemonType.fighting, flyingPress: true)],
      );
      final row = offensiveCoverageRow(slot);
      expect(
        row[teamCoverageDefenseTypes.indexOf(PokemonType.bug)]
            .multiplier,
        equals(1.0),
      );
    });

    test('Flying Press vs Ghost is 0× (Fighting half = 0)', () {
      const slot = CoverageSlot(
        type1: PokemonType.fighting,
        moves: [CoverageMove(type: PokemonType.fighting, flyingPress: true)],
      );
      final row = offensiveCoverageRow(slot);
      final ghostCell =
          row[teamCoverageDefenseTypes.indexOf(PokemonType.ghost)];
      expect(ghostCell.isImmune, isTrue);
    });
  });

  group('offensiveCoverageRow — slot abilities propagate', () {
    test('Scrappy slot turns Normal-only mover into Ghost-coverage', () {
      const slot = CoverageSlot(
        type1: PokemonType.normal,
        ability: 'Scrappy',
        moves: [CoverageMove(type: PokemonType.normal)],
      );
      final row = offensiveCoverageRow(slot);
      final ghostCell =
          row[teamCoverageDefenseTypes.indexOf(PokemonType.ghost)];
      expect(ghostCell.isImmune, isFalse);
      expect(ghostCell.multiplier, equals(1.0));
    });

    test('Tinted Lens slot covers resisted defenders neutrally', () {
      // Fire vs Water = 0.5× normally; Tinted Lens lifts it to 1×.
      const slot = CoverageSlot(
        type1: PokemonType.fire,
        ability: 'Tinted Lens',
        moves: [CoverageMove(type: PokemonType.fire)],
      );
      final row = offensiveCoverageRow(slot);
      expect(
        row[teamCoverageDefenseTypes.indexOf(PokemonType.water)]
            .multiplier,
        equals(1.0),
      );
    });
  });

  group('coverageMoveFromMove — wraps transformMove', () {
    Move makeMove({
      required String name,
      required PokemonType type,
      MoveCategory category = MoveCategory.physical,
      List<String> tags = const [],
    }) =>
        Move(
          name: name,
          nameKo: name,
          nameJa: name,
          type: type,
          category: category,
          power: 80,
          accuracy: 100,
          pp: 10,
          tags: tags,
        );

    test('Tera Blast picks up the user Tera type when terastallized', () {
      final tb = makeMove(name: 'Tera Blast', type: PokemonType.normal);
      final cov = coverageMoveFromMove(
        tb,
        terastallized: true,
        teraType: PokemonType.fairy,
      );
      expect(cov.type, equals(PokemonType.fairy));
    });

    test('Tera Blast stays Normal when not terastallized', () {
      final tb = makeMove(name: 'Tera Blast', type: PokemonType.normal);
      final cov = coverageMoveFromMove(tb);
      expect(cov.type, equals(PokemonType.normal));
    });

    test('Ivy Cudgel reads the wearer mask from pokemonName', () {
      final ic = makeMove(name: 'Ivy Cudgel', type: PokemonType.grass);
      final hearthflame = coverageMoveFromMove(
        ic,
        pokemonName: 'ogerpon-hearthflame',
      );
      expect(hearthflame.type, equals(PokemonType.fire));

      final wellspring = coverageMoveFromMove(
        ic,
        pokemonName: 'ogerpon-wellspring',
      );
      expect(wellspring.type, equals(PokemonType.water));

      final cornerstone = coverageMoveFromMove(
        ic,
        pokemonName: 'ogerpon-cornerstone',
      );
      expect(cornerstone.type, equals(PokemonType.rock));

      // Default form keeps Grass.
      final base = coverageMoveFromMove(ic, pokemonName: 'ogerpon');
      expect(base.type, equals(PokemonType.grass));
    });

    test('Pixilate skin converts Normal moves to Fairy', () {
      final tackle = makeMove(name: 'Tackle', type: PokemonType.normal);
      final cov = coverageMoveFromMove(tackle, ability: 'Pixilate');
      expect(cov.type, equals(PokemonType.fairy));
    });

    test('Status moves report isDamaging = false', () {
      final swords = makeMove(
        name: 'Swords Dance',
        type: PokemonType.normal,
        category: MoveCategory.status,
      );
      final cov = coverageMoveFromMove(swords);
      expect(cov.isDamaging, isFalse);
    });
  });

  group('offensiveCoverageMatrix — shape', () {
    test('empty team yields empty matrix', () {
      expect(offensiveCoverageMatrix(const []), isEmpty);
    });

    test('preserves team order, one row per slot, 18 cols per row', () {
      const team = [
        CoverageSlot(
          type1: PokemonType.fire,
          moves: [CoverageMove(type: PokemonType.fire)],
        ),
        CoverageSlot(
          type1: PokemonType.water,
          moves: [CoverageMove(type: PokemonType.water)],
        ),
      ];
      final m = offensiveCoverageMatrix(team);
      expect(m.length, equals(2));
      for (final row in m) {
        expect(row.length, equals(teamCoverageDefenseTypes.length));
      }
      // Slot 0 (Fire mover) hits Grass for 2×.
      expect(
          m[0][teamCoverageDefenseTypes.indexOf(PokemonType.grass)]
              .multiplier,
          equals(2.0));
      // Slot 1 (Water mover) hits Fire for 2×.
      expect(
          m[1][teamCoverageDefenseTypes.indexOf(PokemonType.fire)]
              .multiplier,
          equals(2.0));
    });
  });
}
