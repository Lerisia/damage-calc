import '../models/type.dart';

/// Returns the type effectiveness multiplier for [attackType] vs [defenderType].
/// 2.0 = super effective, 0.5 = not very effective, 0.0 = immune, 1.0 = neutral
double getTypeEffectiveness(PokemonType attackType, PokemonType defenderType) {
  return _chart[attackType]?[defenderType] ?? 1.0;
}

/// Returns the combined effectiveness against a Pokemon with one or two types.
double getCombinedEffectiveness(PokemonType attackType, PokemonType defType1, PokemonType? defType2) {
  double mult = getTypeEffectiveness(attackType, defType1);
  if (defType2 != null) {
    mult *= getTypeEffectiveness(attackType, defType2);
  }
  return mult;
}

const Map<PokemonType, Map<PokemonType, double>> _chart = {
  PokemonType.normal: {
    PokemonType.rock: 0.5,
    PokemonType.ghost: 0.0,
    PokemonType.steel: 0.5,
  },
  PokemonType.fire: {
    PokemonType.fire: 0.5,
    PokemonType.water: 0.5,
    PokemonType.grass: 2.0,
    PokemonType.ice: 2.0,
    PokemonType.bug: 2.0,
    PokemonType.rock: 0.5,
    PokemonType.dragon: 0.5,
    PokemonType.steel: 2.0,
  },
  PokemonType.water: {
    PokemonType.fire: 2.0,
    PokemonType.water: 0.5,
    PokemonType.grass: 0.5,
    PokemonType.ground: 2.0,
    PokemonType.rock: 2.0,
    PokemonType.dragon: 0.5,
  },
  PokemonType.electric: {
    PokemonType.water: 2.0,
    PokemonType.electric: 0.5,
    PokemonType.grass: 0.5,
    PokemonType.ground: 0.0,
    PokemonType.flying: 2.0,
    PokemonType.dragon: 0.5,
  },
  PokemonType.grass: {
    PokemonType.fire: 0.5,
    PokemonType.water: 2.0,
    PokemonType.grass: 0.5,
    PokemonType.poison: 0.5,
    PokemonType.ground: 2.0,
    PokemonType.flying: 0.5,
    PokemonType.bug: 0.5,
    PokemonType.rock: 2.0,
    PokemonType.dragon: 0.5,
    PokemonType.steel: 0.5,
  },
  PokemonType.ice: {
    PokemonType.fire: 0.5,
    PokemonType.water: 0.5,
    PokemonType.grass: 2.0,
    PokemonType.ice: 0.5,
    PokemonType.ground: 2.0,
    PokemonType.flying: 2.0,
    PokemonType.dragon: 2.0,
    PokemonType.steel: 0.5,
  },
  PokemonType.fighting: {
    PokemonType.normal: 2.0,
    PokemonType.ice: 2.0,
    PokemonType.poison: 0.5,
    PokemonType.flying: 0.5,
    PokemonType.psychic: 0.5,
    PokemonType.bug: 0.5,
    PokemonType.rock: 2.0,
    PokemonType.ghost: 0.0,
    PokemonType.dark: 2.0,
    PokemonType.steel: 2.0,
    PokemonType.fairy: 0.5,
  },
  PokemonType.poison: {
    PokemonType.grass: 2.0,
    PokemonType.poison: 0.5,
    PokemonType.ground: 0.5,
    PokemonType.rock: 0.5,
    PokemonType.ghost: 0.5,
    PokemonType.steel: 0.0,
    PokemonType.fairy: 2.0,
  },
  PokemonType.ground: {
    PokemonType.fire: 2.0,
    PokemonType.electric: 2.0,
    PokemonType.grass: 0.5,
    PokemonType.poison: 2.0,
    PokemonType.flying: 0.0,
    PokemonType.bug: 0.5,
    PokemonType.rock: 2.0,
    PokemonType.steel: 2.0,
  },
  PokemonType.flying: {
    PokemonType.electric: 0.5,
    PokemonType.grass: 2.0,
    PokemonType.fighting: 2.0,
    PokemonType.bug: 2.0,
    PokemonType.rock: 0.5,
    PokemonType.steel: 0.5,
  },
  PokemonType.psychic: {
    PokemonType.fighting: 2.0,
    PokemonType.poison: 2.0,
    PokemonType.psychic: 0.5,
    PokemonType.dark: 0.0,
    PokemonType.steel: 0.5,
  },
  PokemonType.bug: {
    PokemonType.fire: 0.5,
    PokemonType.grass: 2.0,
    PokemonType.fighting: 0.5,
    PokemonType.poison: 0.5,
    PokemonType.flying: 0.5,
    PokemonType.psychic: 2.0,
    PokemonType.ghost: 0.5,
    PokemonType.dark: 2.0,
    PokemonType.steel: 0.5,
    PokemonType.fairy: 0.5,
  },
  PokemonType.rock: {
    PokemonType.fire: 2.0,
    PokemonType.ice: 2.0,
    PokemonType.fighting: 0.5,
    PokemonType.ground: 0.5,
    PokemonType.flying: 2.0,
    PokemonType.bug: 2.0,
    PokemonType.steel: 0.5,
  },
  PokemonType.ghost: {
    PokemonType.normal: 0.0,
    PokemonType.psychic: 2.0,
    PokemonType.ghost: 2.0,
    PokemonType.dark: 0.5,
  },
  PokemonType.dragon: {
    PokemonType.dragon: 2.0,
    PokemonType.steel: 0.5,
    PokemonType.fairy: 0.0,
  },
  PokemonType.dark: {
    PokemonType.fighting: 0.5,
    PokemonType.psychic: 2.0,
    PokemonType.ghost: 2.0,
    PokemonType.dark: 0.5,
    PokemonType.fairy: 0.5,
  },
  PokemonType.steel: {
    PokemonType.fire: 0.5,
    PokemonType.water: 0.5,
    PokemonType.electric: 0.5,
    PokemonType.ice: 2.0,
    PokemonType.rock: 2.0,
    PokemonType.fairy: 2.0,
    PokemonType.steel: 0.5,
  },
  PokemonType.fairy: {
    PokemonType.fire: 0.5,
    PokemonType.fighting: 2.0,
    PokemonType.poison: 0.5,
    PokemonType.dragon: 2.0,
    PokemonType.dark: 2.0,
    PokemonType.steel: 0.5,
  },
};
