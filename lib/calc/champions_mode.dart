import '../models/stats.dart';

/// Constants and conversion utilities for Pokémon Champions stat point system.
///
/// Champions replaces EVs with Stat Points (SP):
///   - Total: 66 SP per Pokémon
///   - Per stat: 0–32 SP
///   - Level: fixed at 50
///   - IVs: fixed at 31
///   - 1 SP ≈ 8 EVs in the traditional formula

class ChampionsMode {
  ChampionsMode._();

  /// Fixed level in Champions mode.
  static const int level = 50;

  /// Fixed IV value for all stats.
  static const int iv = 31;

  /// Maximum total stat points per Pokémon.
  static const int maxTotalSp = 66;

  /// Maximum stat points per individual stat.
  static const int maxPerStat = 32;

  /// EV equivalent per 1 stat point.
  static const int evPerSp = 8;

  /// Fixed IV spread (all 31).
  static const Stats fixedIv = Stats(
    hp: iv, attack: iv, defense: iv,
    spAttack: iv, spDefense: iv, speed: iv,
  );

  /// Zero SP spread.
  static const Stats zeroSp = Stats(
    hp: 0, attack: 0, defense: 0,
    spAttack: 0, spDefense: 0, speed: 0,
  );

  // ---------------------------------------------------------------------------
  // SP ↔ EV conversion
  // ---------------------------------------------------------------------------

  /// Converts SP to EV, accounting for the Lv50 first-4-EV offset.
  /// 0 SP → 0 EV, 1 SP → 4 EV, 32 SP → 252 EV.
  static int spToEv(int sp) {
    if (sp <= 0) return 0;
    return (sp.clamp(1, maxPerStat) * evPerSp - 4);
  }

  /// Converts EV to SP, accounting for the Lv50 first-4-EV offset.
  /// 0 EV → 0 SP, 4 EV → 1 SP, 252 EV → 32 SP.
  static int evToSp(int ev) {
    if (ev <= 0) return 0;
    return ((ev + 4) ~/ evPerSp).clamp(1, maxPerStat);
  }

  /// Converts a full SP spread to EV spread.
  static Stats spToEvStats(Stats sp) => Stats(
    hp: spToEv(sp.hp),
    attack: spToEv(sp.attack),
    defense: spToEv(sp.defense),
    spAttack: spToEv(sp.spAttack),
    spDefense: spToEv(sp.spDefense),
    speed: spToEv(sp.speed),
  );

  /// Converts a full EV spread to SP spread.
  static Stats evToSpStats(Stats ev) => Stats(
    hp: evToSp(ev.hp),
    attack: evToSp(ev.attack),
    defense: evToSp(ev.defense),
    spAttack: evToSp(ev.spAttack),
    spDefense: evToSp(ev.spDefense),
    speed: evToSp(ev.speed),
  );

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Returns the total SP used in a spread.
  static int totalSp(Stats sp) =>
      sp.hp + sp.attack + sp.defense + sp.spAttack + sp.spDefense + sp.speed;

  /// Whether a SP spread is within legal limits.
  static bool isValid(Stats sp) {
    if (totalSp(sp) > maxTotalSp) return false;
    if (sp.hp > maxPerStat || sp.attack > maxPerStat ||
        sp.defense > maxPerStat || sp.spAttack > maxPerStat ||
        sp.spDefense > maxPerStat || sp.speed > maxPerStat) return false;
    if (sp.hp < 0 || sp.attack < 0 || sp.defense < 0 ||
        sp.spAttack < 0 || sp.spDefense < 0 || sp.speed < 0) return false;
    return true;
  }

  /// Remaining SP available for allocation.
  static int remaining(Stats sp) => maxTotalSp - totalSp(sp);

  /// Total SP used, computed from an EV spread (per-stat conversion, then sum).
  static int totalSpFromEv(Stats ev) => totalSp(evToSpStats(ev));

  /// Remaining SP, computed from an EV spread.
  static int remainingFromEv(Stats ev) => maxTotalSp - totalSpFromEv(ev);

  /// Clamps a single stat's SP considering the remaining budget.
  static int clampSp(int value, int currentTotal, int currentStatValue) {
    final available = maxTotalSp - currentTotal + currentStatValue;
    return value.clamp(0, maxPerStat).clamp(0, available);
  }
}
