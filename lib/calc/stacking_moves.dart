import '../models/move.dart';

/// Shared logic for "stacking-power" damage moves — single-hit attacks
/// whose raw power scales linearly by a runtime counter (fainted
/// allies, hits taken, etc.). Mirrors the multi-hit ×N picker UX in
/// the dex, attacker panel, and simple calc so callers don't have to
/// reimplement the same rules.
///
/// Implementation note: these moves aren't [Move.isMultiHit], so their
/// selected tier is expressed as a `powerOverrides[index]` value
/// (basePower × tier) rather than `hitOverrides[index]`. The UI widget
/// is responsible for writing the override and, on reload, deriving
/// the current tier from the override value.

/// Whether [move] scales power by a tier counter.
bool isStackingPower(Move move) => stackingMax(move) != null;

/// Max picker tier for [move]. Returns `null` when the move does not
/// stack.
///
/// - Last Respects: +50 per fainted ally, capped at 5 fainted → ×5.
/// - Rage Fist: +50 per hit taken, capped at 6 hits → ×7.
int? stackingMax(Move move) {
  switch (move.name) {
    case 'Last Respects': return 5;
    case 'Rage Fist': return 7;
    default: return null;
  }
}

/// Effective power for [move] at picker tier [tier] (1-indexed). Tier
/// 1 is the move's base power (no stacking).
int stackingPower(Move move, int tier) {
  if (!isStackingPower(move)) return move.power;
  return move.power * tier;
}

/// Default tier for a freshly-loaded stacking move. Last Respects
/// typically comes down after a couple of teammates have fainted, so
/// ×3 is a realistic baseline; other stackers start at ×1.
int stackingDefaultTier(Move move) {
  if (move.name == 'Last Respects') return 3;
  return 1;
}

/// Derive the current tier from a stored `powerOverrides` value.
/// Returns the default tier when the override is missing or doesn't
/// cleanly divide by the base power (e.g. the user typed a custom
/// number). Callers that want to detect "user-customized" should
/// compare against [stackingPower] themselves.
int currentStackingTier(Move move, int? powerOverride) {
  if (!isStackingPower(move)) return 1;
  if (powerOverride == null || move.power == 0) {
    return stackingDefaultTier(move);
  }
  final tier = (powerOverride / move.power).round();
  final max = stackingMax(move) ?? 1;
  return tier.clamp(1, max);
}
