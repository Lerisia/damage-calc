/// Ruin abilities (Gen 9 "Ruinous Four"). Each is a field effect that
/// reduces one specific stat of every other Pokemon in battle by 25%.
/// A Pokemon holding the same Ruin ability is self-exempt — it does
/// NOT suffer its own ruin.
///
/// Dex order:
///   1. Tablets of Ruin (Wo-Chien)   → all others' Attack × 0.75
///   2. Sword of Ruin   (Chien-Pao)   → all others' Defense × 0.75
///   3. Vessel of Ruin  (Ting-Lu)     → all others' Sp.Atk × 0.75
///   4. Beads of Ruin   (Chi-Yu)      → all others' Sp.Def × 0.75
///
/// Unlike auras, ruins don't interact with each other — each one just
/// independently reduces its one stat (with self-exempt).
import '../models/move.dart';

const String kTabletsOfRuinAbility = 'Tablets of Ruin';
const String kSwordOfRuinAbility = 'Sword of Ruin';
const String kVesselOfRuinAbility = 'Vessel of Ruin';
const String kBeadsOfRuinAbility = 'Beads of Ruin';

const double kRuinMultiplier = 0.75;

/// User-controllable ruin flags set from the battle environment menu.
/// These are the *intent* toggles — the resolved field state
/// ([RuinState]) ORs them together with the attacker/defender abilities.
class RuinToggles {
  final bool tabletsOfRuin;
  final bool swordOfRuin;
  final bool vesselOfRuin;
  final bool beadsOfRuin;

  const RuinToggles({
    this.tabletsOfRuin = false,
    this.swordOfRuin = false,
    this.vesselOfRuin = false,
    this.beadsOfRuin = false,
  });

  bool get hasAny =>
      tabletsOfRuin || swordOfRuin || vesselOfRuin || beadsOfRuin;

  static const inactive = RuinToggles();

  RuinToggles copyWith({
    bool? tabletsOfRuin,
    bool? swordOfRuin,
    bool? vesselOfRuin,
    bool? beadsOfRuin,
  }) {
    return RuinToggles(
      tabletsOfRuin: tabletsOfRuin ?? this.tabletsOfRuin,
      swordOfRuin: swordOfRuin ?? this.swordOfRuin,
      vesselOfRuin: vesselOfRuin ?? this.vesselOfRuin,
      beadsOfRuin: beadsOfRuin ?? this.beadsOfRuin,
    );
  }
}

/// Resolved field state of every Ruin ability.
class RuinState {
  final bool tabletsOnField;
  final bool swordOnField;
  final bool vesselOnField;
  final bool beadsOnField;

  const RuinState({
    this.tabletsOnField = false,
    this.swordOnField = false,
    this.vesselOnField = false,
    this.beadsOnField = false,
  });

  static const inactive = RuinState();
}

/// Resolves which Ruin abilities are active on the field. Ally toggles
/// are only consulted in Doubles — pass `false` in Singles so they're
/// ignored.
RuinState computeRuinState({
  String? attackerAbility,
  String? defenderAbility,
  bool allyTabletsOfRuin = false,
  bool allySwordOfRuin = false,
  bool allyVesselOfRuin = false,
  bool allyBeadsOfRuin = false,
}) {
  return RuinState(
    tabletsOnField: allyTabletsOfRuin ||
        attackerAbility == kTabletsOfRuinAbility ||
        defenderAbility == kTabletsOfRuinAbility,
    swordOnField: allySwordOfRuin ||
        attackerAbility == kSwordOfRuinAbility ||
        defenderAbility == kSwordOfRuinAbility,
    vesselOnField: allyVesselOfRuin ||
        attackerAbility == kVesselOfRuinAbility ||
        defenderAbility == kVesselOfRuinAbility,
    beadsOnField: allyBeadsOfRuin ||
        attackerAbility == kBeadsOfRuinAbility ||
        defenderAbility == kBeadsOfRuinAbility,
  );
}

/// Per-calc output: which stat mods apply, plus notes for the modifier
/// list. [isPhysical] selects Attack/Tablets vs Sp.Atk/Vessel on the
/// offensive side; [targetPhysDef] selects Def/Sword vs Sp.Def/Beads on
/// the defensive side (so Psyshock-style moves correctly trigger Sword
/// of Ruin even though the move is Special).
({double atkMod, double defMod, List<String> notes}) getRuinEffect({
  required String? attackerAbility,
  required String? defenderAbility,
  required MoveCategory category,
  required bool targetPhysDef,
  required RuinState state,
}) {
  double atkMod = 1.0;
  double defMod = 1.0;
  final notes = <String>[];

  final bool isPhysicalAttack = category == MoveCategory.physical;
  final bool isSpecialAttack = category == MoveCategory.special;

  // Attack-side reductions — attacker self-exempt.
  if (isPhysicalAttack &&
      state.tabletsOnField &&
      attackerAbility != kTabletsOfRuinAbility) {
    atkMod *= kRuinMultiplier;
    notes.add('ability:$kTabletsOfRuinAbility:공격 ×$kRuinMultiplier');
  } else if (isSpecialAttack &&
      state.vesselOnField &&
      attackerAbility != kVesselOfRuinAbility) {
    atkMod *= kRuinMultiplier;
    notes.add('ability:$kVesselOfRuinAbility:특공 ×$kRuinMultiplier');
  }

  // Defense-side reductions — defender self-exempt.
  if (targetPhysDef &&
      state.swordOnField &&
      defenderAbility != kSwordOfRuinAbility) {
    defMod *= kRuinMultiplier;
    notes.add('ability:$kSwordOfRuinAbility:방어 ×$kRuinMultiplier');
  } else if (!targetPhysDef &&
      state.beadsOnField &&
      defenderAbility != kBeadsOfRuinAbility) {
    defMod *= kRuinMultiplier;
    notes.add('ability:$kBeadsOfRuinAbility:특방 ×$kRuinMultiplier');
  }

  return (atkMod: atkMod, defMod: defMod, notes: notes);
}
