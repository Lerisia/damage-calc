import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/type.dart';
import '../models/weather.dart';

/// Abilities that negate all weather effects while on the field.
const _weatherNegatingAbilities = {'Cloud Nine', 'Air Lock'};

/// Returns true if [ability] negates weather effects.
bool isWeatherNegating(String? ability) =>
    ability != null && _weatherNegatingAbilities.contains(ability);

/// Returns the effective weather considering weather-negating abilities.
/// If any provided ability negates weather, returns [Weather.none].
Weather effectiveWeather(Weather weather, {String? abilityA, String? abilityB}) {
  if (isWeatherNegating(abilityA) || isWeatherNegating(abilityB)) {
    return Weather.none;
  }
  return weather;
}

/// Returns the defensive stat modifier for the given [weather] and types.
///
/// Sandstorm: Rock-type SpDef x1.5
/// Snow: Ice-type Def x1.5
({double defMod, double spdMod}) getWeatherDefensiveModifier(
  Weather weather, {
  required PokemonType type1,
  PokemonType? type2,
}) {
  final bool isRock = type1 == PokemonType.rock || type2 == PokemonType.rock;
  final bool isIce = type1 == PokemonType.ice || type2 == PokemonType.ice;

  double defMod = 1.0;
  double spdMod = 1.0;

  if (weather == Weather.snow && isIce) defMod *= 1.5;
  if (weather == Weather.sandstorm && isRock) spdMod *= 1.5;

  return (defMod: defMod, spdMod: spdMod);
}

/// Returns the power modifier for the given [weather] and [move].
///
/// Sun/Harsh Sun: Fire 1.5x, Water 0.5x (Harsh Sun: Water 0x)
/// Rain/Heavy Rain: Water 1.5x, Fire 0.5x (Heavy Rain: Fire 0x)
/// Other weather or non-matching types: 1.0x
double getWeatherOffensiveModifier(Weather weather, {required Move move}) {
  switch (weather) {
    case Weather.sun:
      if (move.hasTag(MoveTags.sunBoost)) return 1.5;
      if (move.type == PokemonType.fire) return 1.5;
      if (move.type == PokemonType.water) return 0.5;
      return 1.0;
    case Weather.harshSun:
      if (move.hasTag(MoveTags.sunBoost)) return 1.5;
      if (move.type == PokemonType.fire) return 1.5;
      if (move.type == PokemonType.water) return 0.0;
      return 1.0;
    case Weather.rain:
      if (move.type == PokemonType.water) return 1.5;
      if (move.type == PokemonType.fire) return 0.5;
      return 1.0;
    case Weather.heavyRain:
      if (move.type == PokemonType.water) return 1.5;
      if (move.type == PokemonType.fire) return 0.0;
      return 1.0;
    default:
      return 1.0;
  }
}
