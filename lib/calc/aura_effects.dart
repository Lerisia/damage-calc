/// Field-state aura effects (Fairy Aura / Dark Aura / Aura Break).
///
/// Auras are field abilities, so the active-state depends on *anyone* in
/// the battle having the ability — attacker, defender, or (in Doubles)
/// an ally slot toggled from the doubles panel. Multiple copies of the
/// same aura don't stack.
///
/// Interaction model:
/// - A matching aura raises damage of Fairy/Dark moves by [kAuraBoost].
/// - If an Aura Break is present anywhere on the field, all matching
///   auras are reversed to [kAuraNerfed] instead.
///
/// Both the damage calc and 결정력 read the aura from [getAuraEffect]
/// alone — it is the single source, applied once as a base-power mod.
import '../models/type.dart';

/// Raw multiplier an active matching aura applies to damage.
/// 5448/4096 ≈ 1.330 — the in-game base-power modifier. Showdown
/// (@smogon/calc) pushes 5448 into the base-power chain for this.
const double kAuraBoost = 5448 / 4096;

/// Reversed multiplier when Aura Break is active (3/4 = 0.75).
const double kAuraNerfed = 3 / 4;

const String kFairyAuraAbility = 'Fairy Aura';
const String kDarkAuraAbility = 'Dark Aura';
const String kAuraBreakAbility = 'Aura Break';

/// User-controllable aura flags set from the battle environment menu.
/// These are the *intent* toggles — the resolved field state
/// ([AuraState]) ORs them together with the attacker/defender abilities.
class AuraToggles {
  final bool fairyAura;
  final bool darkAura;
  final bool auraBreak;

  const AuraToggles({
    this.fairyAura = false,
    this.darkAura = false,
    this.auraBreak = false,
  });

  bool get hasAny => fairyAura || darkAura || auraBreak;

  static const inactive = AuraToggles();

  AuraToggles copyWith({
    bool? fairyAura,
    bool? darkAura,
    bool? auraBreak,
  }) {
    return AuraToggles(
      fairyAura: fairyAura ?? this.fairyAura,
      darkAura: darkAura ?? this.darkAura,
      auraBreak: auraBreak ?? this.auraBreak,
    );
  }
}

/// Resolved field state of all aura abilities.
class AuraState {
  final bool fairyAuraOnField;
  final bool darkAuraOnField;
  final bool auraBreakOnField;

  const AuraState({
    this.fairyAuraOnField = false,
    this.darkAuraOnField = false,
    this.auraBreakOnField = false,
  });

  static const inactive = AuraState();
}

/// Resolves the field-state of each aura from every possible source.
/// Ally toggles are only consulted by the caller when Doubles is on —
/// pass `false` in Singles so they're ignored.
AuraState computeAuraState({
  String? attackerAbility,
  String? defenderAbility,
  bool allyFairyAura = false,
  bool allyDarkAura = false,
  bool allyAuraBreak = false,
}) {
  return AuraState(
    fairyAuraOnField: allyFairyAura ||
        attackerAbility == kFairyAuraAbility ||
        defenderAbility == kFairyAuraAbility,
    darkAuraOnField: allyDarkAura ||
        attackerAbility == kDarkAuraAbility ||
        defenderAbility == kDarkAuraAbility,
    auraBreakOnField: allyAuraBreak ||
        attackerAbility == kAuraBreakAbility ||
        defenderAbility == kAuraBreakAbility,
  );
}

/// The single source of the aura modifier for both the damage calc
/// and 결정력. A matching aura — Fairy Aura on a Fairy move / Dark Aura
/// on a Dark move, from ANY source on the field (attacker, defender,
/// or ally toggle) — multiplies damage by [kAuraBoost]; an Aura Break
/// flips that to [kAuraNerfed]. The attacker's own aura ability is no
/// longer applied separately via getAbilityEffect, so the multiplier
/// is computed and applied exactly once.
///
/// Notes are emitted whenever something is worth telling the user:
/// - Matching aura active → "Fairy/Dark Aura ×1.33" (or ×0.75 if Break)
/// - Aura Break active but no matching aura this turn → just "Aura Break"
///   (lets the user see the field state even though nothing applied)
({double multiplier, List<String> notes}) getAuraEffect({
  required PokemonType moveType,
  required AuraState state,
}) {
  final bool matchingAura =
      (moveType == PokemonType.fairy && state.fairyAuraOnField) ||
      (moveType == PokemonType.dark && state.darkAuraOnField);

  if (!matchingAura) {
    return (
      multiplier: 1.0,
      notes: state.auraBreakOnField
          ? ['ability:$kAuraBreakAbility']
          : const <String>[],
    );
  }

  final String note;
  if (state.auraBreakOnField) {
    note = 'ability:$kAuraBreakAbility:×$kAuraNerfed';
  } else {
    final String auraName = moveType == PokemonType.fairy
        ? kFairyAuraAbility : kDarkAuraAbility;
    note = 'ability:$auraName:×1.33';
  }
  return (
    multiplier: state.auraBreakOnField ? kAuraNerfed : kAuraBoost,
    notes: [note],
  );
}
