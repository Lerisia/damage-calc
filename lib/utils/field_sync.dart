import '../models/terrain.dart';
import '../models/weather.dart';
import 'terrain_effects.dart' show abilityTerrainMap;
import 'weather_effects.dart' show abilityWeatherMap;

/// Field state produced by [syncFieldFromAbilities].
typedef FieldState = ({Weather weather, Terrain terrain});

/// Reconciles the battle's weather/terrain when a side's ability
/// changes — the "an ability that sets weather/terrain appeared /
/// disappeared" state rule.
///
/// Extracted from the calculator screen so the rule is pure and
/// testable rather than embedded in a widget. Two transitions:
///
///  * **Auto-set**: a side's ability changed to one that maps to a
///    weather/terrain (Drizzle → Rain, Electric Surge → Electric
///    Terrain, …) → adopt it. The current side's set wins over the
///    other when both changed, matching the original attacker-then-
///    defender application order.
///  * **Auto-clear**: the ability that was *justifying* the current
///    weather/terrain got removed and nothing on the field justifies
///    it any more → clear back to none. A purely user-set value (no
///    ability ever sourced it) is left untouched.
///
/// When neither ability changed the field is returned unchanged.
FieldState syncFieldFromAbilities({
  required Weather weather,
  required Terrain terrain,
  required String? prevAtkAbility,
  required String? prevDefAbility,
  required String? atkAbility,
  required String? defAbility,
}) {
  final atkChanged = atkAbility != prevAtkAbility;
  final defChanged = defAbility != prevDefAbility;
  if (!atkChanged && !defChanged) {
    return (weather: weather, terrain: terrain);
  }

  var w = weather;
  var t = terrain;

  // Auto-set: a newly-appearing ability maps to weather/terrain.
  if (atkChanged && atkAbility != null) {
    w = abilityWeatherMap[atkAbility] ?? w;
    t = abilityTerrainMap[atkAbility] ?? t;
  }
  if (defChanged && defAbility != null) {
    w = abilityWeatherMap[defAbility] ?? w;
    t = abilityTerrainMap[defAbility] ?? t;
  }

  // Auto-clear by transition: the source ability left and no current
  // ability re-justifies the standing value.
  if (w != Weather.none) {
    final prevHadSource = abilityWeatherMap[prevAtkAbility] == w ||
        abilityWeatherMap[prevDefAbility] == w;
    final nowHasSource = abilityWeatherMap[atkAbility] == w ||
        abilityWeatherMap[defAbility] == w;
    if (prevHadSource && !nowHasSource) w = Weather.none;
  }
  if (t != Terrain.none) {
    final prevHadSource = abilityTerrainMap[prevAtkAbility] == t ||
        abilityTerrainMap[prevDefAbility] == t;
    final nowHasSource = abilityTerrainMap[atkAbility] == t ||
        abilityTerrainMap[defAbility] == t;
    if (prevHadSource && !nowHasSource) t = Terrain.none;
  }

  return (weather: w, terrain: t);
}
