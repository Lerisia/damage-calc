/// Constants for move tag strings used across the codebase.
///
/// Three kinds live here, and `test/models/move_tags_test.dart` keeps
/// them honest against `assets/moves/*.json`:
///  * **Data flags** — present in the move data and read by the calc
///    (everything up to the runtime section).
///  * **Data-only flags** ([dataOnly]) — present in the move data and
///    maintained by tooling (ROM flag audit, default-move roles, spread
///    tagging) but not read by the calculator itself.
///  * **Runtime markers** ([runtimeMarkers]) — never in the data;
///    attached to a move by `transformMove` so later stages (bpMods
///    chain, fixed-damage paths) can see what an earlier step decided.
///    [spread] is both: a data flag for always-spread moves and a
///    runtime marker for Expanding Force on Psychic Terrain.
class MoveTags {
  MoveTags._();

  // Standard move tags
  static const String contact = 'contact';
  static const String punch = 'punch';
  static const String sound = 'sound';
  static const String bite = 'bite';
  static const String pulse = 'pulse';
  static const String slice = 'slice';
  static const String recoil = 'recoil';
  static const String ball = 'ball';
  static const String powder = 'powder';

  // Custom tags for special move mechanics
  static const String alwaysCrit = 'custom:always_crit';
  static const String hasSecondary = 'custom:has_secondary';
  static const String useDefense = 'custom:use_defense';
  static const String useHigherAtk = 'custom:use_higher_atk';
  static const String doubleNoItem = 'custom:double_no_item';
  static const String hpPowerHigh = 'custom:hp_power_high';
  static const String hpPowerLow = 'custom:hp_power_low';
  static const String facade = 'custom:facade';
  static const String terrainDoubleElectric = 'custom:terrain_double_electric';
  static const String terrainBoostPsychic = 'custom:terrain_boost_psychic';
  static const String terrainBoostMisty = 'custom:terrain_boost_misty';
  static const String rankPower = 'custom:rank_power';
  static const String sunBoost = 'custom:sun_boost';
  static const String useOpponentAtk = 'custom:use_opponent_atk';
  static const String gyroSpeed = 'custom:gyro_speed';
  static const String electroSpeed = 'custom:electro_speed';
  static const String weightBased = 'custom:weight_based';
  static const String weightRatio = 'custom:weight_ratio';   // Heavy Slam, Heat Crash
  static const String weightTarget = 'custom:weight_target'; // Low Kick, Grass Knot
  static const String grassyHalve = 'custom:grassy_halve';
  static const String doubleDynamax = 'custom:double_dynamax';
  static const String targetPhysDef = 'custom:target_phys_def';
  static const String freezeDry = 'custom:freeze_dry';
  static const String fixedLevel = 'custom:fixed_level';
  static const String fixedHalfHp = 'custom:fixed_half_hp';
  static const String fixed20 = 'custom:fixed_20';
  static const String fixed40 = 'custom:fixed_40';
  static const String ignoreDefRank = 'custom:ignore_def_rank';
  static const String ohko = 'custom:ohko';

  // Move-specific power conditions (based on defender state)
  static const String requiresDefItem = 'custom:requires_def_item';
  static const String knockOff = 'custom:knock_off';
  static const String doubleOnStatus = 'custom:double_on_status';
  static const String doubleOnPoison = 'custom:double_on_poison';
  static const String doubleOnHalfHp = 'custom:double_on_half_hp';
  static const String flyingPress = 'custom:flying_press';
  static const String thousandArrows = 'custom:thousand_arrows';

  // Weather/field power conditions
  static const String solarHalve = 'custom:solar_halve';
  static const String gravityBoost = 'custom:gravity_boost';

  // Status-dependent power doubling (defender state)
  static const String doubleOnSleep = 'custom:double_on_sleep';
  static const String doubleOnParalysis = 'custom:double_on_paralysis';

  // Super-effective bonus
  static const String superEffectiveBoost = 'custom:se_boost';
  static const String escalatingHits = 'custom:escalating_hits';

  // Power scales with target's remaining HP (high HP = high power)
  static const String powerByTargetHp120 = 'custom:power_target_hp_120';
  static const String powerByTargetHp100 = 'custom:power_target_hp_100';

  // Move ignores target's ability (same as Mold Breaker)
  static const String ignoreAbility = 'custom:ignore_ability';

  // Move disabled by Gravity
  static const String disabledByGravity = 'custom:disabled_by_gravity';

  // Move requires defender to be asleep (Dream Eater)
  static const String requiresDefSleep = 'custom:requires_def_sleep';

  // OHKO move that Ice-types are immune to (Sheer Cold)
  static const String ohkoIceImmune = 'custom:ohko_ice_immune';

  // Shell Side Arm: physical / special chosen by comparing A*SpD vs C*Def
  // using modified stats (rank stages applied).
  static const String shellSideArm = 'custom:shell_side_arm';

  // Spread: move hits multiple adjacent targets in Doubles. When the user
  // indicates 2-target hit, damage is multiplied by 0.75. Covers both
  // foes-only (Rock Slide, Heat Wave) and all-adjacent (Earthquake, Surf).
  static const String spread = 'custom:spread';

  // Move dex visibility flags. Some moves exist in the calc as multiple
  // numeric variants (Magnitude 4-10, etc.) for power picking, but the
  // Move Dex should only surface a single canonical entry.
  // - [dexHidden]: hide this move from the Move Dex (calc-only variants)
  // - [dexOnly]:   show only in the Move Dex (canonical synthetic
  //                entry, never picked by the calc directly)
  static const String dexHidden = 'custom:dex_hidden';
  static const String dexOnly = 'custom:dex_only';

  // ───────────────────────────────────────────────────────────────────
  // Data-only flags: in assets/moves, not consumed by the calculator.
  // ───────────────────────────────────────────────────────────────────

  // Wind moves (Wind Rider / Wind Power targets). Maintained by
  // tools/audit_move_flags.py from the ROM's classification codes.
  static const String wind = 'wind';

  // Hits the ally too when allAdjacent (Earthquake / Surf / …). Written by
  // tools/apply_spread_tags.py for future 2v2 logic; inert today.
  static const String spreadHitsAlly = 'custom:spread_hits_ally';

  // User switches out after the move (U-turn / Volt Switch / Parting
  // Shot / …). Read by tools/fetch_pokechamdb.py to classify the
  // "switch" role in default-move ordering.
  static const String switchOut = 'custom:switch_out';

  static const Set<String> dataOnly = {wind, spreadHitsAlly, switchOut};

  // ───────────────────────────────────────────────────────────────────
  // Runtime markers: attached by transformMove, never present in data.
  // ───────────────────────────────────────────────────────────────────

  // Parental Bond (Mega Kangaskhan): move becomes 2-hit, 2nd hit at 0.25x power.
  static const String parentalBond = 'custom:parental_bond';
  // Parental Bond on fixed-damage moves: 2nd hit does full damage (no 0.25x).
  static const String parentalBondFixed = 'custom:parental_bond_fixed';

  // Fixed damage: 75% of target's current HP. Attached by the Z-Move
  // table for Guardian of Alola (Tapu exclusives).
  static const String fixedThreeQuarterHp = 'custom:fixed_three_quarter_hp';

  /// Set by `_applySkin` when an `-ate` ability (Aerilate / Pixilate /
  /// Refrigerate / Galvanize) successfully retypes a Normal move.
  /// damage_calculator's bpMods chain reads this to push the ×1.2
  /// boost (4915 fp) at the same chain slot as Showdown's gen789.ts
  /// (`bpMods.push(4915)` after Rivalry, before Reckless / Iron Fist).
  /// Routed via tag instead of multiplied directly inside transform
  /// because dynamic-BP moves (Crush Grip, Wring Out, Eruption, …)
  /// don't have their BP yet when `_applySkin` runs — multiplying the
  /// pre-BP zero would silently drop the boost. Max moves never get
  /// the tag (Showdown gates the boost on `!move.isMax`).
  static const String ateBoosted = 'custom:ate_boosted';

  static const Set<String> runtimeMarkers = {
    parentalBond, parentalBondFixed, fixedThreeQuarterHp, ateBoosted,
  };
}
