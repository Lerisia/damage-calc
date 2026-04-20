/// Doubles-battle-only scenario modifiers.
///
/// Aggregates every multiplier / stat tweak that comes from the attacker's
/// Doubles-specific toggles (spread hitting 2 targets, ally has Helping
/// Hand, ally ability effects, ...). Keeps doubles logic contained to a
/// single file so ability_effects / damage_calculator stay readable.
///
/// Usage from damage_calculator:
///   final dm = computeDoublesModifiers(attacker, move, isDoubles: …);
///   movePowerMod *= dm.powerMod;
///   notes.addAll(dm.notes);
///
/// Usage from OffensiveCalculator / BattleFacade:
///   final dm = computeDoublesModifiers(attacker, move, isDoubles: …);
///   powerMod *= dm.powerMod;
///   // statMod *= dm.attackMod;   // when we add Flower Gift / Plus etc.

import '../models/battle_pokemon.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/weather.dart';

/// Bundled multipliers returned by the doubles logic. Values default to 1.0
/// so callers can blindly apply them when the caller isn't sure whether
/// Doubles is on — everything becomes a no-op in that case.
class DoublesModifiers {
  /// Multiplier applied to move damage / offensive-power output.
  final double powerMod;

  /// Multiplier applied to the offensive stat (Attack or Sp.Atk).
  /// Reserved for Flower Gift / Plus-Minus etc. — unused today.
  final double attackMod;

  /// Notes to surface in the modifier list (damage tab). Each entry matches
  /// the `move:<key>:×<value>` format so the existing renderer picks them up.
  final List<String> notes;

  const DoublesModifiers({
    this.powerMod = 1.0,
    this.attackMod = 1.0,
    this.notes = const [],
  });

  static const identity = DoublesModifiers();
}

/// Multiplier applied when an attacker's spread move hits 2 targets.
const double kSpreadMultiplier = 0.75;

/// Multiplier applied when the ally used Helping Hand this turn.
const double kHelpingHandMultiplier = 1.5;

/// Multiplier from the ally's Power Spot ability (all moves).
const double kPowerSpotMultiplier = 1.3;

/// Multiplier from the ally's Battery ability (special moves only).
const double kBatteryMultiplier = 1.3;

/// Attack-stat multiplier from the ally's Flower Gift (in Sun, physical).
const double kFlowerGiftAttackMultiplier = 1.5;

/// SpAtk-stat multiplier from Plus/Minus (attacker + ally).
const double kPlusMinusSpAttackMultiplier = 1.5;

/// Abilities that activate the Plus/Minus synergy (Gen 6+).
const Set<String> kPlusMinusAbilities = {'Plus', 'Minus'};

/// Damage-taken multiplier from the ally's Friend Guard ability.
const double kFriendGuardMultiplier = 0.75;

/// Compute defender-side doubles multipliers (Friend Guard, etc.).
/// Applied on incoming damage to this side.
DoublesModifiers computeDefenderDoublesModifiers({
  required BattlePokemonState defender,
  required bool isDoubles,
}) {
  if (!isDoubles) return DoublesModifiers.identity;
  double powerMod = 1.0;
  final notes = <String>[];
  if (defender.allyFriendGuard) {
    powerMod *= kFriendGuardMultiplier;
    notes.add('move:friendGuard:×$kFriendGuardMultiplier');
  }
  return DoublesModifiers(powerMod: powerMod, notes: notes);
}

/// Compute the combined Doubles modifiers for [attacker] using [move].
///
/// [isDoubles] is the global Doubles-mode flag. When false this returns
/// [DoublesModifiers.identity] — all the attacker's doubles flags are
/// ignored, so the singles damage path is untouched.
DoublesModifiers computeDoublesModifiers({
  required BattlePokemonState attacker,
  required Move move,
  required bool isDoubles,
  Weather weather = Weather.none,
}) {
  if (!isDoubles) return DoublesModifiers.identity;

  double powerMod = 1.0;
  double attackMod = 1.0;
  final notes = <String>[];

  // Spread: 2 targets → 0.75×
  if (attacker.spreadTargets && move.hasTag(MoveTags.spread)) {
    powerMod *= kSpreadMultiplier;
    notes.add('move:spread:×$kSpreadMultiplier');
  }

  // Helping Hand: ally boosts this move → 1.5×
  if (attacker.helpingHand) {
    powerMod *= kHelpingHandMultiplier;
    notes.add('move:helpingHand:×$kHelpingHandMultiplier');
  }

  // Power Spot (ally's ability): 1.3× to every move.
  if (attacker.allyPowerSpot) {
    powerMod *= kPowerSpotMultiplier;
    notes.add('move:powerSpot:×$kPowerSpotMultiplier');
  }

  // Battery (ally's ability): 1.3× to special moves only.
  if (attacker.allyBattery && move.category == MoveCategory.special) {
    powerMod *= kBatteryMultiplier;
    notes.add('move:battery:×$kBatteryMultiplier');
  }

  // Flower Gift (ally Cherrim): in Sun, ally's Attack × 1.5 (physical only).
  final isSun = weather == Weather.sun || weather == Weather.harshSun;
  if (attacker.allyFlowerGift && isSun && move.category == MoveCategory.physical) {
    attackMod *= kFlowerGiftAttackMultiplier;
    notes.add('move:flowerGift:×$kFlowerGiftAttackMultiplier');
  }

  // Plus/Minus: attacker's own ability must be Plus or Minus, and ally
  // holds either Plus or Minus → SpAtk × 1.5 (special moves only).
  final attackerHasPlusMinus =
      kPlusMinusAbilities.contains(attacker.selectedAbility);
  if (attackerHasPlusMinus && attacker.allyPlusMinus &&
      move.category == MoveCategory.special) {
    attackMod *= kPlusMinusSpAttackMultiplier;
    notes.add('move:plusMinus:×$kPlusMinusSpAttackMultiplier');
  }

  return DoublesModifiers(
    powerMod: powerMod,
    attackMod: attackMod,
    notes: notes,
  );
}
