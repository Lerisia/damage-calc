import '../models/move.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';

/// Transforms a move based on battle conditions before damage calculation.
///
/// Weather Ball changes type and power based on active weather.
/// Terrain Pulse changes type and power based on active terrain.
/// Unaffected moves are returned as-is.
Move applyWeatherToMove(Move move, Weather weather) {
  if (move.name != 'Weather Ball' || weather == Weather.none) {
    return move;
  }

  final PokemonType weatherType;
  switch (weather) {
    case Weather.sun:
      weatherType = PokemonType.fire;
    case Weather.rain:
      weatherType = PokemonType.water;
    case Weather.sandstorm:
      weatherType = PokemonType.rock;
    case Weather.snow:
      weatherType = PokemonType.ice;
    default:
      return move;
  }

  return move.copyWith(type: weatherType, power: 100);
}

/// Transforms Terrain Pulse based on active terrain.
Move applyTerrainToMove(Move move, Terrain terrain) {
  if (move.name != 'Terrain Pulse' || terrain == Terrain.none) {
    return move;
  }

  final PokemonType terrainType;
  switch (terrain) {
    case Terrain.electric:
      terrainType = PokemonType.electric;
    case Terrain.grassy:
      terrainType = PokemonType.grass;
    case Terrain.psychic:
      terrainType = PokemonType.psychic;
    case Terrain.misty:
      terrainType = PokemonType.fairy;
    default:
      return move;
  }

  return move.copyWith(type: terrainType, power: 100);
}
