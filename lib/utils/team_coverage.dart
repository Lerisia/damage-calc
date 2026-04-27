import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/type.dart';
import 'ability_effects.dart' show canHitGhost, isAbilityTypeImmune;
import 'grounded.dart';
import 'move_transform.dart';
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

/// One move's contribution to offensive coverage. We strip down to
/// the only fields that influence type matchups so tests don't have
/// to hand-roll a full [Move] object.
///
/// **State-dependent moves** are resolved at the caller boundary, not
/// here, since this module doesn't have access to live game state:
///   - Tera Blast → caller passes the user's Tera type when active,
///     else Normal.
///   - Judgment / Multi-Attack / Techno Blast → caller passes the
///     type derived from the held plate / memory / drive.
///   - Revelation Dance → caller passes the user's primary type.
///   - Weather Ball / Aura Wheel → not modelled (no weather/form
///     state in the team-coverage UI).
///   - Hidden Power → no longer in-game (Gen 8+).
///
/// **Move-intrinsic special behavior** is handled here via flags
/// because it can't be expressed as just a type:
///   - [freezeDry]: Ice move that hits Water for 2× (the chart says
///     0.5×).
///   - [flyingPress]: Fighting + Flying combined effectiveness vs
///     each defender type.
class CoverageMove {
  final PokemonType type;
  /// Status moves contribute nothing to offensive coverage; physical
  /// and special damaging moves both count the same.
  final bool isDamaging;
  final bool freezeDry;
  final bool flyingPress;

  const CoverageMove({
    required this.type,
    this.isDamaging = true,
    this.freezeDry = false,
    this.flyingPress = false,
  });
}

/// Inputs needed to compute one team slot's defensive AND offensive
/// coverage rows. Mirrors the trimmed-down team-builder UI (no
/// level/EV/stats — type matchups don't depend on them).
class CoverageSlot {
  final PokemonType type1;
  final PokemonType? type2;
  final PokemonType? type3;
  final String? ability;
  final String? heldItem;
  /// Up to four moves the slot's pokemon knows. Empty / status-only
  /// lists yield an "all-immune" offensive row.
  final List<CoverageMove> moves;

  const CoverageSlot({
    required this.type1,
    this.type2,
    this.type3,
    this.ability,
    this.heldItem,
    this.moves = const [],
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

// ──────────────────────────────────────────────────────────────────────
// Offensive coverage — "what's the best damage multiplier my team can
// hit each defensive type with?"
//
// Defender types are evaluated as single types, mirroring the standard
// Pokemon team-builder convention (Marriland, Showdown, …). Dual-type
// defenders aren't shown because the cross-product would be 153 cells
// per pokemon, unreadable in a phone-width matrix. Special move type
// behavior (Tera Blast, Hidden Power, Freeze-Dry, etc.) is left to a
// later pass — this is the basic type-chart pass.
// ──────────────────────────────────────────────────────────────────────

/// Defensive types in the same order [teamCoverageAttackTypes] uses
/// for attack types — same 18 entries, since the matrix is rendered
/// as `team × type` regardless of which axis is being analyzed.
const List<PokemonType> teamCoverageDefenseTypes = teamCoverageAttackTypes;

/// Single-type effectiveness with chart-immunity layered on top, plus
/// attacker-ability overrides:
///   - **Scrappy / Mind's Eye** (`canHitGhost`) lets Normal- and
///     Fighting-type moves bypass the Ghost immunity — the chart
///     entry is 1× so the move lands neutral.
///   - **Tinted Lens** doubles any resisted hit (0 < eff < 1) but
///     does not break immunities.
double offensiveEffectivenessOf(
  PokemonType moveType,
  PokemonType defenderType, {
  String? attackerAbility,
}) {
  final ghostBypass = defenderType == PokemonType.ghost &&
      (moveType == PokemonType.normal ||
          moveType == PokemonType.fighting) &&
      canHitGhost(attackerAbility);

  if (!ghostBypass &&
      (typeImmunities[moveType]?.contains(defenderType) ?? false)) {
    return 0;
  }

  double eff = getTypeEffectiveness(moveType, defenderType);

  if (eff > 0 && eff < 1.0 && attackerAbility == 'Tinted Lens') {
    eff *= 2.0;
  }

  return eff;
}

/// Per-move effective multiplier vs a defender. Folds in the two
/// move-intrinsic specials (Freeze-Dry, Flying Press) on top of the
/// type-and-ability-aware [offensiveEffectivenessOf].
double _effectivenessOfMove(
    CoverageMove move, PokemonType defType, String? ability) {
  if (move.flyingPress) {
    final f = offensiveEffectivenessOf(PokemonType.fighting, defType,
        attackerAbility: ability);
    final fl = offensiveEffectivenessOf(PokemonType.flying, defType,
        attackerAbility: ability);
    return f * fl;
  }
  if (move.freezeDry && defType == PokemonType.water) {
    // Hard 2× override — chart says 0.5× for Ice vs Water but
    // Freeze-Dry exists specifically to invert that. Tinted Lens
    // doesn't compound (only resisted hits get the ×2 boost).
    return 2.0;
  }
  return offensiveEffectivenessOf(move.type, defType,
      attackerAbility: ability);
}

/// Offensive coverage row for a single slot. For each defender type:
///   - skip status moves (no damage contribution)
///   - take the *best* (max) effectiveness across damaging moves
///   - apply slot ability (Scrappy/Mind's Eye/Tinted Lens) per move
///   - a slot with no damaging moves yields 0× across the row
///
/// Single-type defenders normally cap at 2×; Flying Press can yield
/// 4× when both Fighting and Flying are super-effective vs the same
/// defender (e.g. vs Bug → Flying 2× × Fighting 0.5× = 1×, but vs
/// Grass → Flying 2× × Fighting 1× = 2×; true 4× shows only against
/// dual-type defenders, which the matrix doesn't model).
List<CoverageCell> offensiveCoverageRow(CoverageSlot slot) {
  final damaging = slot.moves.where((m) => m.isDamaging).toList();
  return [
    for (final defType in teamCoverageDefenseTypes)
      _bestOffensiveCell(damaging, defType, slot.ability),
  ];
}

CoverageCell _bestOffensiveCell(
    List<CoverageMove> damaging, PokemonType defType, String? ability) {
  if (damaging.isEmpty) {
    return const CoverageCell(0, immunityReason: 'noMoves');
  }
  double best = 0;
  for (final m in damaging) {
    final eff = _effectivenessOfMove(m, defType, ability);
    if (eff > best) best = eff;
  }
  // best = 0 means every move was immune-typed against this defender
  // (e.g., Normal-only mover vs a Ghost). Marked as immune so the
  // renderer paints "무" / "✕" with the gray pill, same as defensive.
  if (best == 0) {
    return const CoverageCell(0, immunityReason: 'allImmune');
  }
  return CoverageCell(best);
}

/// Offensive coverage matrix for [team]. Same shape as
/// [defensiveCoverageMatrix]: rows are pokemon, columns are types
/// (in [teamCoverageDefenseTypes] order).
List<List<CoverageCell>> offensiveCoverageMatrix(List<CoverageSlot> team) {
  return team.map(offensiveCoverageRow).toList(growable: false);
}

/// Build a [CoverageMove] from a calculator [Move] by routing the
/// move + caller-supplied state through the existing
/// [transformMove] pipeline. This single entry point handles every
/// state-dependent move the calculator already knows about — Tera
/// Blast, Ivy Cudgel (Ogerpon masks), Judgment / Multi-Attack /
/// Techno Blast (held items), Revelation Dance (primary type),
/// Aura Wheel (Morpeko form), Raging Bull (Paldean Tauros), the
/// -ate skin abilities (Pixilate / Refrigerate / Aerilate /
/// Galvanize), Liquid Voice (sound → Water), Weather Ball / Terrain
/// Pulse, and Tera Starstorm — so callers don't have to special-case
/// any of them. Move-intrinsic flags ([MoveTags.freezeDry] /
/// [MoveTags.flyingPress]) are forwarded so the matrix renders
/// Freeze-Dry vs Water as 2× and Flying Press as combined
/// Fighting × Flying.
///
/// Defaults match the lightweight team-coverage UI which doesn't
/// track weather / terrain / status — pass those if available so
/// Weather Ball etc. resolve correctly.
CoverageMove coverageMoveFromMove(
  Move move, {
  String? ability,
  String? heldItem,
  PokemonType? userType1,
  String? pokemonName,
  bool terastallized = false,
  PokemonType? teraType,
  MoveContext? context,
}) {
  final ctx = context ??
      MoveContext(
        ability: ability,
        heldItem: heldItem,
        userType1: userType1,
        pokemonName: pokemonName,
        terastallized: terastallized,
        teraType: teraType,
        hasItem: heldItem != null,
      );
  final m = transformMove(move, ctx).move;
  return CoverageMove(
    type: m.type,
    isDamaging: m.category != MoveCategory.status,
    freezeDry: m.hasTag(MoveTags.freezeDry),
    flyingPress: m.hasTag(MoveTags.flyingPress),
  );
}
