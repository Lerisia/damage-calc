/// Current HP as an integer, derived from the stored HP share.
///
/// `BattlePokemonState.hpPercent` remembers the user's *intended* share
/// of max HP (so the share survives EV / level / nature edits that
/// change the max). Nothing reads it as HP directly: every consumer
/// converts through [currentHpOf], which rounds to the nearest
/// achievable integer and clamps to 0…max — so "33 % of 175" is 58 HP
/// and the percent shown back is 33.14 %, never a share no real HP
/// can produce. Real-value input goes the other way with
/// [hpPercentOf]; the two round-trip exactly.
///
/// In-game deductions (Stealth Rock) still floor, as the game does —
/// rounding here is only about mapping a typed share onto HP.
library;

/// HP may sit above max — up to 150 % — for Sitrus / heal estimates
/// and mid-turn what-ifs (user decision 2026-09-14); the cap is the
/// largest integer within that share.
const double kHpOverflowFactor = 1.5;

int maxCurrentHp(int maxHp) => (maxHp * kHpOverflowFactor).floor();

int currentHpOf(int maxHp, double hpPercent) {
  if (maxHp <= 0) return 0;
  return (maxHp * hpPercent / 100).round().clamp(0, maxCurrentHp(maxHp));
}

double hpPercentOf(int maxHp, int currentHp) =>
    maxHp <= 0 ? 100.0 : currentHp / maxHp * 100;

/// The nearest share a real HP value can produce.
double snapHpPercent(int maxHp, double hpPercent) =>
    hpPercentOf(maxHp, currentHpOf(maxHp, hpPercent));

/// Game threshold "HP is 1/3 or less", on a share: `hp * 3 <= max`.
/// The epsilon absorbs float noise when the share came from
/// [hpPercentOf] and `hp * 3 == max` exactly.
bool hpAtOrBelowThird(double hpPercent) => hpPercent * 3 <= 100 + 1e-9;
