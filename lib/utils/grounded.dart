import '../models/type.dart';

/// Determines whether a Pokemon is grounded (affected by terrain).
///
/// Flying types, Levitate ability, and Air Balloon make a Pokemon ungrounded.
bool isGrounded({
  required PokemonType type1,
  PokemonType? type2,
  String? ability,
  String? item,
}) {
  if (type1 == PokemonType.flying || type2 == PokemonType.flying) return false;
  if (ability == 'Levitate') return false;
  if (item == 'Air Balloon') return false;
  return true;
}
