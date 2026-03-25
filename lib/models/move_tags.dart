/// Constants for move tag strings used across the codebase.
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
}
