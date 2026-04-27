import 'package:flutter_test/flutter_test.dart';
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
}
