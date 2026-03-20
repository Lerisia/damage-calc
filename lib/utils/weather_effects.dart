import '../models/move.dart';
import '../models/type.dart';
import '../models/weather.dart';

/// Returns the power modifier for the given [weather] and [move].
///
/// Sun/Harsh Sun: Fire 1.5x, Water 0.5x (Harsh Sun: Water 0x)
/// Rain/Heavy Rain: Water 1.5x, Fire 0.5x (Heavy Rain: Fire 0x)
/// Other weather or non-matching types: 1.0x
double getWeatherModifier(Weather weather, {required Move move}) {
  switch (weather) {
    case Weather.sun:
      if (move.hasTag('custom:sun_boost')) return 1.5;
      if (move.type == PokemonType.fire) return 1.5;
      if (move.type == PokemonType.water) return 0.5;
      return 1.0;
    case Weather.harshSun:
      if (move.hasTag('custom:sun_boost')) return 1.5;
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
