import '../models/type.dart';

/// Returns the type effectiveness multiplier for [attackType] vs [defenderType].
/// 2.0 = super effective, 0.5 = not very effective, 0.0 = immune, 1.0 = neutral
double getTypeEffectiveness(PokemonType attackType, PokemonType defenderType) {
  return _chart[attackType]?[defenderType] ?? 1.0;
}

/// Returns the single-type effectiveness, with Freeze-Dry override.
/// Note: type immunities (0x) are NOT in the chart — handled by damage calculator.
double _getEffectiveness(PokemonType attackType, PokemonType defenderType, {bool freezeDry = false}) {
  if (freezeDry && defenderType == PokemonType.water) return 2.0;
  return _chart[attackType]?[defenderType] ?? 1.0;
}

/// Returns the combined effectiveness against a Pokemon with one or two types.
/// [freezeDry] overrides Water interaction to x2.
/// [flyingPress] calculates Fighting × Flying dual-type effectiveness.
/// Note: type immunities are handled separately in damage_calculator.dart.
double getCombinedEffectiveness(PokemonType attackType, PokemonType defType1, PokemonType? defType2, {bool freezeDry = false, bool flyingPress = false}) {
  if (flyingPress) {
    // Flying Press: combine Fighting AND Flying effectiveness
    double fightMult = _getEffectiveness(PokemonType.fighting, defType1);
    double flyMult = _getEffectiveness(PokemonType.flying, defType1);
    if (defType2 != null) {
      fightMult *= _getEffectiveness(PokemonType.fighting, defType2);
      flyMult *= _getEffectiveness(PokemonType.flying, defType2);
    }
    return fightMult * flyMult;
  }
  double mult = _getEffectiveness(attackType, defType1, freezeDry: freezeDry);
  if (defType2 != null) {
    mult *= _getEffectiveness(attackType, defType2, freezeDry: freezeDry);
  }
  return mult;
}

/// Type immunity pairs: attack type → defender type that would be immune.
/// These are checked separately from the effectiveness chart because
/// various mechanics can override them (Scrappy, grounding, Corrosion, etc.)
const Map<PokemonType, Set<PokemonType>> typeImmunities = {
  PokemonType.normal: {PokemonType.ghost},
  PokemonType.fighting: {PokemonType.ghost},
  PokemonType.electric: {PokemonType.ground},
  PokemonType.poison: {PokemonType.steel},
  PokemonType.ground: {PokemonType.flying},
  PokemonType.psychic: {PokemonType.dark},
  PokemonType.ghost: {PokemonType.normal},
  PokemonType.dragon: {PokemonType.fairy},
};

/// Check if a move type has a type immunity against the defender's types.
/// Returns true if at least one of the defender's types is immune.
bool hasTypeImmunity(PokemonType moveType, PokemonType defType1, PokemonType? defType2) {
  final immuneSet = typeImmunities[moveType];
  if (immuneSet == null) return false;
  if (immuneSet.contains(defType1)) return true;
  if (defType2 != null && immuneSet.contains(defType2)) return true;
  return false;
}

const Map<PokemonType, Map<PokemonType, double>> _chart = {
  PokemonType.normal: {
    PokemonType.rock: 0.5,
    PokemonType.ghost: 1.0, // immunity handled separately
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
    PokemonType.ground: 1.0, // immunity handled separately
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
    PokemonType.ghost: 1.0, // immunity handled separately
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
    PokemonType.steel: 1.0, // immunity handled separately
    PokemonType.fairy: 2.0,
  },
  PokemonType.ground: {
    PokemonType.fire: 2.0,
    PokemonType.electric: 2.0,
    PokemonType.grass: 0.5,
    PokemonType.poison: 2.0,
    PokemonType.flying: 1.0, // immunity handled separately
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
    PokemonType.dark: 1.0, // immunity handled separately
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
    PokemonType.normal: 1.0, // immunity handled separately
    PokemonType.psychic: 2.0,
    PokemonType.ghost: 2.0,
    PokemonType.dark: 0.5,
  },
  PokemonType.dragon: {
    PokemonType.dragon: 2.0,
    PokemonType.steel: 0.5,
    PokemonType.fairy: 1.0, // immunity handled separately
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
