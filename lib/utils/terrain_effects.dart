import '../models/move.dart';
import '../models/type.dart';
import '../models/terrain.dart';

/// Returns the power modifier for the given [terrain] and [move].
///
/// Only applies when the attacking Pokemon is grounded.
/// Electric Terrain: Electric 1.3x
/// Grassy Terrain: Grass 1.3x
/// Psychic Terrain: Psychic 1.3x
/// Misty Terrain: Dragon 0.5x
/// Other terrain or non-matching types: 1.0x
double getTerrainModifier(Terrain terrain, {
  required Move move,
  bool grounded = true,
}) {
  if (!grounded) return 1.0;
  switch (terrain) {
    case Terrain.electric:
      return move.type == PokemonType.electric ? 1.3 : 1.0;
    case Terrain.grassy:
      return move.type == PokemonType.grass ? 1.3 : 1.0;
    case Terrain.psychic:
      return move.type == PokemonType.psychic ? 1.3 : 1.0;
    case Terrain.misty:
      return move.type == PokemonType.dragon ? 0.5 : 1.0;
    default:
      return 1.0;
  }
}
