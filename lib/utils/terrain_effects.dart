import '../models/move.dart';
import '../models/terrain.dart';

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
/// Terrain power modifiers are now applied in transformMove for unified display.
/// This function always returns 1.0.
double getTerrainModifier(Terrain terrain, {
  required Move move,
  bool attackerGrounded = true,
  bool defenderGrounded = true,
}) {
  return 1.0;
}
