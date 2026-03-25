import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/terrain.dart';
import '../models/type.dart';

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
/// [defenderGrounded]: Misty/Grassy reductions apply when defender is grounded.
double getTerrainModifier(Terrain terrain, {
  required Move move,
  bool attackerGrounded = true,
  bool defenderGrounded = true,
}) {
  switch (terrain) {
    case Terrain.electric:
      if (attackerGrounded && move.type == PokemonType.electric) return 1.3;
    case Terrain.grassy:
      if (defenderGrounded && move.hasTag(MoveTags.grassyHalve)) return 0.5;
      if (attackerGrounded && move.type == PokemonType.grass) return 1.3;
    case Terrain.psychic:
      if (attackerGrounded && move.type == PokemonType.psychic) return 1.3;
    case Terrain.misty:
      if (defenderGrounded && move.type == PokemonType.dragon) return 0.5;
    default:
      break;
  }
  return 1.0;
}
