import '../models/type.dart';

/// Determines whether a Pokemon is grounded (affected by terrain).
///
/// Flying types, Levitate ability, and Air Balloon make a Pokemon ungrounded.
/// Gravity overrides all of these and forces grounding.
bool isGrounded({
  required PokemonType type1,
  PokemonType? type2,
  PokemonType? type3,
  String? ability,
  String? item,
  bool gravity = false,
}) {
  if (gravity) return true;
  if (item == 'iron-ball') return true;
  if (type1 == PokemonType.flying ||
      type2 == PokemonType.flying ||
      type3 == PokemonType.flying) return false;
  if (ability == 'Levitate') return false;
  if (item == 'air-balloon') return false;
  return true;
}
