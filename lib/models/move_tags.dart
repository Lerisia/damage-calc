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
}
