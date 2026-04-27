import '../models/type.dart';
import 'ability_effects.dart' show isAbilityTypeImmune;
import 'grounded.dart';
import 'type_effectiveness.dart';

/// One team-coverage cell — what happens when a move of [attackType]
/// hits a Pokemon with the team-builder's slot configuration.
///
/// `multiplier == 0` means immune (the cell renders blank or "무").
/// `multiplier > 1` is a weakness, `< 1` is a resistance, `1.0` is
/// neutral. The [reason] tag annotates *why* something is 0× — useful
/// for tooltips later.
class CoverageCell {
  final double multiplier;
  /// `null` for non-immune cells; one of `'type'`, `'ability'`, or
  /// `'wonderGuard'` when the multiplier is 0.
  final String? immunityReason;

  const CoverageCell(this.multiplier, {this.immunityReason});

  bool get isImmune => multiplier == 0;
  bool get isWeak => multiplier > 1;
  bool get isResist => multiplier > 0 && multiplier < 1;
}

/// Inputs needed to compute one team slot's defensive coverage row.
/// Mirrors the trimmed-down team-builder UI (no level/EV/stats — type
/// matchups don't depend on them).
class CoverageSlot {
  final PokemonType type1;
  final PokemonType? type2;
  final PokemonType? type3;
  final String? ability;
  final String? heldItem;

  const CoverageSlot({
    required this.type1,
    this.type2,
    this.type3,
    this.ability,
    this.heldItem,
  });
}

/// 18 attack types in dex order. Typeless / shadow are excluded — no
/// real attacker uses them in the team-coverage context.
const List<PokemonType> teamCoverageAttackTypes = [
  PokemonType.normal,
  PokemonType.fire,
  PokemonType.water,
  PokemonType.electric,
  PokemonType.grass,
  PokemonType.ice,
  PokemonType.fighting,
  PokemonType.poison,
  PokemonType.ground,
  PokemonType.flying,
  PokemonType.psychic,
  PokemonType.bug,
  PokemonType.rock,
  PokemonType.ghost,
  PokemonType.dragon,
  PokemonType.dark,
  PokemonType.steel,
  PokemonType.fairy,
];

/// Effectiveness of a move of [attackType] against the [slot]. Layers
/// the immunity sources in a specific order so they don't double-count:
///
/// 1. Pure-type immunity (the 8 chart pairs) — handled via
///    [hasTypeImmunity], which sees all 1-3 defender types.
/// 2. Ability-driven type immunity (Volt Absorb, Sap Sipper, …).
/// 3. Levitate / Air Balloon → Ground move misses (only relevant when
///    the type chart didn't already make Ground immune via Flying).
/// 4. Wonder Guard — any non-super-effective hit deals 0×.
///
/// Then the regular [getCombinedEffectiveness] multiplier is used.
CoverageCell coverageOf(PokemonType attackType, CoverageSlot slot) {
  // Step 1: chart-based type immunity (Normal vs Ghost, Electric vs
  // Ground via Flying, etc.). Includes the 3rd-type slot.
  if (hasTypeImmunity(attackType, slot.type1, slot.type2,
      defType3: slot.type3)) {
    return const CoverageCell(0, immunityReason: 'type');
  }

  // Step 2: ability-driven type immunity. Slot's ability soaks up the
  // matching attack type — e.g. Sap Sipper vs Grass.
  if (slot.ability != null &&
      isAbilityTypeImmune(slot.ability!, attackType)) {
    return const CoverageCell(0, immunityReason: 'ability');
  }

  // Step 3: Ground attacks vs ungrounded targets. Levitate / Air
  // Balloon make ground attacks miss; Iron Ball overrides back to
  // grounded.
  if (attackType == PokemonType.ground) {
    final grounded = isGrounded(
      type1: slot.type1,
      type2: slot.type2,
      type3: slot.type3,
      ability: slot.ability,
      item: slot.heldItem,
    );
    if (!grounded) {
      return const CoverageCell(0, immunityReason: 'ability');
    }
  }

  // Step 4: Wonder Guard — only super-effective hits land. We compute
  // the raw multiplier once and gate it.
  final mult = getCombinedEffectiveness(
    attackType,
    slot.type1,
    slot.type2,
    defType3: slot.type3,
  );

  if (slot.ability == 'Wonder Guard' && mult <= 1.0) {
    return const CoverageCell(0, immunityReason: 'wonderGuard');
  }

  return CoverageCell(mult);
}

/// Defensive coverage matrix for [team]. Returns rows in the same
/// order as the input team. Each row has one [CoverageCell] per
/// attack type, in [teamCoverageAttackTypes] order.
List<List<CoverageCell>> defensiveCoverageMatrix(List<CoverageSlot> team) {
  return team
      .map((slot) => teamCoverageAttackTypes
          .map((t) => coverageOf(t, slot))
          .toList(growable: false))
      .toList(growable: false);
}

/// Per-attack-type counts: how many team members are weak / neutral /
/// resist / immune to a given attack type. Same order as
/// [teamCoverageAttackTypes].
class CoverageColumnSummary {
  final int weak;
  final int neutral;
  final int resist;
  final int immune;

  const CoverageColumnSummary({
    required this.weak,
    required this.neutral,
    required this.resist,
    required this.immune,
  });
}

List<CoverageColumnSummary> summarize(
    List<List<CoverageCell>> matrix) {
  if (matrix.isEmpty) {
    return List.filled(
        teamCoverageAttackTypes.length,
        const CoverageColumnSummary(weak: 0, neutral: 0, resist: 0, immune: 0));
  }
  final out = <CoverageColumnSummary>[];
  for (int col = 0; col < teamCoverageAttackTypes.length; col++) {
    int weak = 0, neutral = 0, resist = 0, immune = 0;
    for (final row in matrix) {
      final c = row[col];
      if (c.isImmune) {
        immune++;
      } else if (c.isWeak) {
        weak++;
      } else if (c.isResist) {
        resist++;
      } else {
        neutral++;
      }
    }
    out.add(CoverageColumnSummary(
        weak: weak, neutral: neutral, resist: resist, immune: immune));
  }
  return out;
}
