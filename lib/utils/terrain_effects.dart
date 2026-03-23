import '../models/move.dart';
import '../models/type.dart';
import '../models/terrain.dart';

import '../models/move_tags.dart';

/// Maps abilities that auto-set terrain when sent out.
const abilityTerrainMap = <String, Terrain>{
  'Electric Surge': Terrain.electric,
  'Grassy Surge': Terrain.grassy,
  'Psychic Surge': Terrain.psychic,
  'Misty Surge': Terrain.misty,
  'Hadron Engine': Terrain.electric,
};

/// Abilities that negate all terrain effects while on the field.
const _terrainNegatingAbilities = {'Teraform Zero'};

/// Returns true if [ability] negates terrain effects.
bool isTerrainNegating(String? ability) =>
    ability != null && _terrainNegatingAbilities.contains(ability);

/// Returns the effective terrain considering terrain-negating abilities.
Terrain effectiveTerrain(Terrain terrain, {String? abilityA, String? abilityB}) {
  if (isTerrainNegating(abilityA) || isTerrainNegating(abilityB)) {
    return Terrain.none;
  }
  return terrain;
}

/// Returns the power modifier for the given [terrain] and [move].
///
/// [attackerGrounded]: Electric/Grassy/Psychic boosts apply when attacker is grounded.
/// [defenderGrounded]: Misty Terrain Dragon 0.5x applies when defender is grounded.
double getTerrainModifier(Terrain terrain, {
  required Move move,
  bool attackerGrounded = true,
  bool defenderGrounded = true,
}) {
  switch (terrain) {
    case Terrain.electric:
      return (attackerGrounded && move.type == PokemonType.electric) ? 1.3 : 1.0;
    case Terrain.grassy:
      // Grassy Terrain halves ground-hitting moves (tagged) on grounded targets
      if (defenderGrounded && move.hasTag(MoveTags.grassyHalve)) return 0.5;
      return (attackerGrounded && move.type == PokemonType.grass) ? 1.3 : 1.0;
    case Terrain.psychic:
      return (attackerGrounded && move.type == PokemonType.psychic) ? 1.3 : 1.0;
    case Terrain.misty:
      return (defenderGrounded && move.type == PokemonType.dragon) ? 0.5 : 1.0;
    default:
      return 1.0;
  }
}
