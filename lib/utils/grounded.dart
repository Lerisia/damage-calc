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

/// Modifier-note key explaining *why* a Pokémon is ungrounded, for the
/// Ground-type immunity line in the damage tab. Returns the Levitate
/// ability note when Levitate is the (sole) cause — so the list names
/// the hidden ability instead of a generic "ungrounded" — otherwise
/// `'ground:ungrounded'` (Flying type / Air Balloon: visible already).
/// Pass the same [ability] value handed to [isGrounded] (i.e. null
/// when Mold Breaker is suppressing it).
String groundImmunityNote({
  required PokemonType type1,
  PokemonType? type2,
  PokemonType? type3,
  String? ability,
}) {
  final flying = type1 == PokemonType.flying ||
      type2 == PokemonType.flying ||
      type3 == PokemonType.flying;
  if (!flying && ability == 'Levitate') return 'ability:Levitate:immune';
  return 'ground:ungrounded';
}
