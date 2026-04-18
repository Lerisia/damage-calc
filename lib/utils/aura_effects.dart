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
/// 결정력 (offensive-power display) already applies the attacker's own
/// aura via [getAbilityEffect], so [getAuraCorrection] returns the delta
/// needed to bring the total up to the target multiplier.
import '../models/type.dart';

/// Raw multiplier an active matching aura applies to damage (4/3 ≈ 1.33).
const double kAuraBoost = 4 / 3;

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

/// Correction applied during damage calc, plus any notes to surface.
/// 결정력 already includes [kAuraBoost] when the attacker's own ability
/// matches [moveType]; this delta brings the total to [kAuraBoost] or
/// [kAuraNerfed] as dictated by the field state.
///
/// Notes are emitted whenever something is worth telling the user:
/// - Matching aura active → "Fairy/Dark Aura ×1.33" (or ×0.75 if Break)
/// - Aura Break active but no matching aura this turn → just "Aura Break"
///   (lets the user see the field state even though nothing applied)
({double multiplier, List<String> notes}) getAuraEffect({
  required PokemonType moveType,
  required String? attackerAbility,
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

  final bool attackerHasMatchingAura =
      (attackerAbility == kFairyAuraAbility && moveType == PokemonType.fairy) ||
      (attackerAbility == kDarkAuraAbility && moveType == PokemonType.dark);

  final double target = state.auraBreakOnField ? kAuraNerfed : kAuraBoost;
  final double alreadyApplied = attackerHasMatchingAura ? kAuraBoost : 1.0;
  final double correction = target / alreadyApplied;

  final String note;
  if (state.auraBreakOnField) {
    note = 'ability:$kAuraBreakAbility:×$kAuraNerfed';
  } else {
    final String auraName = moveType == PokemonType.fairy
        ? kFairyAuraAbility : kDarkAuraAbility;
    note = 'ability:$auraName:×1.33';
  }
  return (multiplier: correction, notes: [note]);
}
