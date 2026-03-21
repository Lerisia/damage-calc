import '../models/status.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'item_effects.dart';

/// Status condition speed modifier constants.
const double paralysisSpeedModifier = 0.5;

/// Field effect speed modifier constants.
const double tailwindSpeedModifier = 2.0;

/// Calculates the effective speed after all modifiers.
///
/// Modifier application order: ability → item → paralysis → tailwind.
/// Choice Scarf is nullified during Dynamax.
/// Paralysis is negated by Quick Feet.
int calcEffectiveSpeed({
  required int baseSpeed,
  String? ability,
  String? item,
  StatusCondition status = StatusCondition.none,
  Weather weather = Weather.none,
  Terrain terrain = Terrain.none,
  bool isDynamaxed = false,
  bool tailwind = false,
}) {
  double speed = baseSpeed.toDouble();

  // Ability modifier
  if (ability != null) {
    speed *= getSpeedAbilityModifier(ability,
        weather: weather, terrain: terrain, status: status);
  }

  // Item modifier (Choice Scarf nullified during Dynamax)
  if (item != null) {
    if (!(isDynamaxed && item == 'choice-scarf')) {
      speed *= getSpeedItemEffect(item).speedModifier;
    }
  }

  // Paralysis (Quick Feet negates this)
  if (status == StatusCondition.paralysis && ability != 'Quick Feet') {
    speed *= paralysisSpeedModifier;
  }

  // Tailwind
  if (tailwind) {
    speed *= tailwindSpeedModifier;
  }

  return speed.floor();
}
