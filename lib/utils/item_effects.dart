import '../models/move.dart';
import '../models/type.dart';

/// Offensive modifiers returned by an item
class ItemEffect {
  final double statModifier;
  final double powerModifier;

  const ItemEffect({
    this.statModifier = 1.0,
    this.powerModifier = 1.0,
  });
}

const _defaultEffect = ItemEffect();

/// Type-boosting held items (1.2x)
const _typeBoostItems = {
  // Type-specific items
  'charcoal': PokemonType.fire,
  'mystic-water': PokemonType.water,
  'miracle-seed': PokemonType.grass,
  'magnet': PokemonType.electric,
  'never-melt-ice': PokemonType.ice,
  'black-belt': PokemonType.fighting,
  'poison-barb': PokemonType.poison,
  'soft-sand': PokemonType.ground,
  'sharp-beak': PokemonType.flying,
  'twisted-spoon': PokemonType.psychic,
  'silver-powder': PokemonType.bug,
  'hard-stone': PokemonType.rock,
  'spell-tag': PokemonType.ghost,
  'dragon-fang': PokemonType.dragon,
  'black-glasses': PokemonType.dark,
  'metal-coat': PokemonType.steel,
  'silk-scarf': PokemonType.normal,
  'fairy-feather': PokemonType.fairy,
  // Plates (same 1.2x boost)
  'flame-plate': PokemonType.fire,
  'splash-plate': PokemonType.water,
  'meadow-plate': PokemonType.grass,
  'zap-plate': PokemonType.electric,
  'icicle-plate': PokemonType.ice,
  'fist-plate': PokemonType.fighting,
  'toxic-plate': PokemonType.poison,
  'earth-plate': PokemonType.ground,
  'sky-plate': PokemonType.flying,
  'mind-plate': PokemonType.psychic,
  'insect-plate': PokemonType.bug,
  'stone-plate': PokemonType.rock,
  'spooky-plate': PokemonType.ghost,
  'draco-plate': PokemonType.dragon,
  'dread-plate': PokemonType.dark,
  'iron-plate': PokemonType.steel,
  'pixie-plate': PokemonType.fairy,
  // Incenses
  'sea-incense': PokemonType.water,
  'wave-incense': PokemonType.water,
  'rose-incense': PokemonType.grass,
  'odd-incense': PokemonType.psychic,
  'rock-incense': PokemonType.rock,
};

/// Returns the offensive effect of [itemName] given the [move] being used.
/// [pokemonName] is needed for Pokemon-specific items (Light Ball, Thick Club, etc.)
ItemEffect getItemEffect(
  String itemName, {
  required Move move,
  String? pokemonName,
}) {
  // Stat modifier items
  switch (itemName) {
    case 'choice-band':
      return move.category == MoveCategory.physical
          ? const ItemEffect(statModifier: 1.5)
          : _defaultEffect;
    case 'choice-specs':
      return move.category == MoveCategory.special
          ? const ItemEffect(statModifier: 1.5)
          : _defaultEffect;
  }

  // Power modifier items
  switch (itemName) {
    case 'life-orb':
      return const ItemEffect(powerModifier: 1.3);
    case 'muscle-band':
      return move.category == MoveCategory.physical
          ? const ItemEffect(powerModifier: 1.1)
          : _defaultEffect;
    case 'wise-glasses':
      return move.category == MoveCategory.special
          ? const ItemEffect(powerModifier: 1.1)
          : _defaultEffect;
    case 'punching-glove':
      return move.hasTag('punch')
          ? const ItemEffect(powerModifier: 1.1)
          : _defaultEffect;
    case 'normal-gem':
      return move.type == PokemonType.normal
          ? const ItemEffect(powerModifier: 1.3)
          : _defaultEffect;
  }

  // Type-boosting items (1.2x)
  if (_typeBoostItems.containsKey(itemName)) {
    return move.type == _typeBoostItems[itemName]
        ? const ItemEffect(powerModifier: 1.2)
        : _defaultEffect;
  }

  // Pokemon-specific items
  final name = pokemonName?.toLowerCase() ?? '';
  switch (itemName) {
    case 'light-ball':
      // Pikachu: 2x Attack and Sp.Atk
      if (name.contains('pikachu')) {
        return const ItemEffect(statModifier: 2.0);
      }
      return _defaultEffect;
    case 'thick-club':
      // Cubone/Marowak: 2x Attack
      if ((name.contains('cubone') || name.contains('marowak')) &&
          move.category == MoveCategory.physical) {
        return const ItemEffect(statModifier: 2.0);
      }
      return _defaultEffect;
    case 'deep-sea-tooth':
      // Clamperl: 2x Sp.Atk
      if (name.contains('clamperl') &&
          move.category == MoveCategory.special) {
        return const ItemEffect(statModifier: 2.0);
      }
      return _defaultEffect;
    case 'adamant-orb':
      // Dialga: 1.2x Dragon/Steel
      if (name.contains('dialga') &&
          (move.type == PokemonType.dragon || move.type == PokemonType.steel)) {
        return const ItemEffect(powerModifier: 1.2);
      }
      return _defaultEffect;
    case 'lustrous-orb':
      // Palkia: 1.2x Dragon/Water
      if (name.contains('palkia') &&
          (move.type == PokemonType.dragon || move.type == PokemonType.water)) {
        return const ItemEffect(powerModifier: 1.2);
      }
      return _defaultEffect;
    case 'griseous-orb':
    case 'griseous-core':
      // Giratina: 1.2x Dragon/Ghost
      if (name.contains('giratina') &&
          (move.type == PokemonType.dragon || move.type == PokemonType.ghost)) {
        return const ItemEffect(powerModifier: 1.2);
      }
      return _defaultEffect;
    case 'soul-dew':
      // Latios/Latias: 1.2x Dragon/Psychic (Gen 7+)
      if ((name.contains('latios') || name.contains('latias')) &&
          (move.type == PokemonType.dragon || move.type == PokemonType.psychic)) {
        return const ItemEffect(powerModifier: 1.2);
      }
      return _defaultEffect;
  }

  return _defaultEffect;
}

/// Defensive item effect on bulk calculation.
class DefensiveItemEffect {
  final double defModifier;
  final double spdModifier;

  const DefensiveItemEffect({
    this.defModifier = 1.0,
    this.spdModifier = 1.0,
  });
}

const _defaultDefensiveItemEffect = DefensiveItemEffect();

/// Returns the defensive effect of [itemName] on bulk.
///
/// - Eviolite: Def/SpDef x1.5 (non-final evolution only)
/// - Assault Vest: SpDef x1.5
DefensiveItemEffect getDefensiveItemEffect(String itemName, {
  bool finalEvo = true,
}) {
  switch (itemName) {
    case 'eviolite':
      return !finalEvo
          ? const DefensiveItemEffect(defModifier: 1.5, spdModifier: 1.5)
          : _defaultDefensiveItemEffect;
    case 'assault-vest':
      return const DefensiveItemEffect(spdModifier: 1.5);
    default:
      return _defaultDefensiveItemEffect;
  }
}
