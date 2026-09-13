/// The game's 4096-fixed-point multipliers, as Showdown's chainMods
/// encode them. The 결정력 (offensive power) convention, decided
/// 2026-09-12, is to use these verbatim rather than the rounded
/// "×1.1 / ×1.2 / ×1.3" people write by hand — so 결정력 scales exactly
/// as real damage does (a hand calculation with 1.3 lands a few points
/// higher). The damage calculator rounds doubles back to fp with
/// `_toFP`, so these values reach both paths identically.
///
/// Guarded by test/calc/offensive_fp_constants_test.dart, which
/// asserts every offense-side multiplier is an integer over 4096.
library;

/// ×1.1 — Muscle Band / Wise Glasses (4505).
const double kFp1_1 = 4505 / 4096;

/// ×1.2 — type-boost items, Iron Fist / Reckless, -ate abilities,
/// Stellar non-matching STAB (4915).
const double kFp1_2 = 4915 / 4096;

/// ×1.3 — terrain boosts, Tough Claws / Sheer Force / Analytic /
/// Punk Rock class, gems, Power Spot, Battery (5325). Life Orb is the
/// one ×1.3 that is 5324 instead — see `kLifeOrbPower`.
const double kFp1_3 = 5325 / 4096;

/// Supreme Overlord: 4096 + 410 per fainted ally (Showdown
/// `chainModify([4096 + 410 * fallen, 4096])`), so ×1.1001, ×1.2002 …
/// rather than a flat +0.1 each.
double supremeOverlordMultiplier(int fallen) => (4096 + 410 * fallen) / 4096;
