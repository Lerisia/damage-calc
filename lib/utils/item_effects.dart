import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/type.dart';

// ---------------------------------------------------------------------------
// Item multiplier constants
// ---------------------------------------------------------------------------

/// Choice Band / Choice Specs: 1.5x to the relevant attacking stat.
const double kChoiceStatBoost = 1.5;

/// Life Orb: 1.3x power at the cost of recoil.
const double kLifeOrbPower = 5324.0 / 4096.0;

/// Muscle Band (physical) / Wise Glasses (special) / Punching Glove (punch):
/// 1.1x power for matching moves.
const double kMinorPowerBoost = 1.1;

/// Normal Gem: 1.3x power for a single Normal-type move.
const double kNormalGemPower = 1.3;

/// Type-boosting held items (Charcoal, Plates, Incenses, etc.): 1.2x power.
const double kTypeBoostPower = 1.2;

/// Light Ball (Pikachu), Thick Club (Cubone/Marowak),
/// Deep Sea Tooth (Clamperl): 2.0x to the relevant stat.
const double kPokemonSpecificStatBoost = 2.0;

/// Legendary signature items (Adamant Orb, Lustrous Orb, etc.): 1.2x power.
const double kLegendaryItemPower = 1.2;

/// Eviolite: 1.5x Def and SpDef for non-final evolutions.
const double kEvioliteBulkBoost = 1.5;

/// Assault Vest: 1.5x SpDef.
const double kAssaultVestSpDef = 1.5;

/// Choice Scarf: 1.5x speed.
const double kChoiceScarfSpeed = 1.5;

/// Iron Ball / Power items: 0.5x speed.
const double kHeavyItemSpeedPenalty = 0.5;

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
          ? const ItemEffect(statModifier: kChoiceStatBoost)
          : _defaultEffect;
    case 'choice-specs':
      return move.category == MoveCategory.special
          ? const ItemEffect(statModifier: kChoiceStatBoost)
          : _defaultEffect;
  }

  // Power modifier items
  switch (itemName) {
    case 'life-orb':
      return const ItemEffect(powerModifier: kLifeOrbPower);
    case 'muscle-band':
      return move.category == MoveCategory.physical
          ? const ItemEffect(powerModifier: kMinorPowerBoost)
          : _defaultEffect;
    case 'wise-glasses':
      return move.category == MoveCategory.special
          ? const ItemEffect(powerModifier: kMinorPowerBoost)
          : _defaultEffect;
    case 'punching-glove':
      return move.hasTag(MoveTags.punch)
          ? const ItemEffect(powerModifier: kMinorPowerBoost)
          : _defaultEffect;
    case 'normal-gem':
      return move.type == PokemonType.normal
          ? const ItemEffect(powerModifier: kNormalGemPower)
          : _defaultEffect;
  }

  // Type-boosting items
  if (_typeBoostItems.containsKey(itemName)) {
    return move.type == _typeBoostItems[itemName]
        ? const ItemEffect(powerModifier: kTypeBoostPower)
        : _defaultEffect;
  }

  // Pokemon-specific items
  final name = pokemonName?.toLowerCase() ?? '';
  switch (itemName) {
    case 'light-ball':
      // Pikachu: 2x Attack and Sp.Atk
      if (name.contains('pikachu')) {
        return const ItemEffect(statModifier: kPokemonSpecificStatBoost);
      }
      return _defaultEffect;
    case 'thick-club':
      // Cubone/Marowak: 2x Attack
      if ((name.contains('cubone') || name.contains('marowak')) &&
          move.category == MoveCategory.physical) {
        return const ItemEffect(statModifier: kPokemonSpecificStatBoost);
      }
      return _defaultEffect;
    case 'deep-sea-tooth':
      // Clamperl: 2x Sp.Atk
      if (name.contains('clamperl') &&
          move.category == MoveCategory.special) {
        return const ItemEffect(statModifier: kPokemonSpecificStatBoost);
      }
      return _defaultEffect;
    case 'adamant-orb':
      // Dialga: 1.2x Dragon/Steel
      if (name.contains('dialga') &&
          (move.type == PokemonType.dragon || move.type == PokemonType.steel)) {
        return const ItemEffect(powerModifier: kLegendaryItemPower);
      }
      return _defaultEffect;
    case 'lustrous-orb':
      // Palkia: 1.2x Dragon/Water
      if (name.contains('palkia') &&
          (move.type == PokemonType.dragon || move.type == PokemonType.water)) {
        return const ItemEffect(powerModifier: kLegendaryItemPower);
      }
      return _defaultEffect;
    case 'griseous-orb':
    case 'griseous-core':
      // Giratina: 1.2x Dragon/Ghost
      if (name.contains('giratina') &&
          (move.type == PokemonType.dragon || move.type == PokemonType.ghost)) {
        return const ItemEffect(powerModifier: kLegendaryItemPower);
      }
      return _defaultEffect;
    case 'soul-dew':
      // Latios/Latias: 1.2x Dragon/Psychic (Gen 7+)
      if ((name.contains('latios') || name.contains('latias')) &&
          (move.type == PokemonType.dragon || move.type == PokemonType.psychic)) {
        return const ItemEffect(powerModifier: kLegendaryItemPower);
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
  String? pokemonName,
}) {
  switch (itemName) {
    case 'eviolite':
      return !finalEvo
          ? const DefensiveItemEffect(
              defModifier: kEvioliteBulkBoost,
              spdModifier: kEvioliteBulkBoost,
            )
          : _defaultDefensiveItemEffect;
    case 'assault-vest':
      return const DefensiveItemEffect(spdModifier: kAssaultVestSpDef);
    case 'deep-sea-scale':
      if (pokemonName != null && pokemonName.toLowerCase().contains('clamperl')) {
        return const DefensiveItemEffect(spdModifier: 2.0);
      }
      return _defaultDefensiveItemEffect;
    default:
      return _defaultDefensiveItemEffect;
  }
}

/// Type-resist berries: halve damage from a super-effective move of the matching type.
/// Chilan Berry halves Normal-type damage (doesn't require super effective).
const Map<String, PokemonType> typeResistBerries = {
  'occa-berry': PokemonType.fire,
  'passho-berry': PokemonType.water,
  'wacan-berry': PokemonType.electric,
  'rindo-berry': PokemonType.grass,
  'yache-berry': PokemonType.ice,
  'chople-berry': PokemonType.fighting,
  'kebia-berry': PokemonType.poison,
  'shuca-berry': PokemonType.ground,
  'coba-berry': PokemonType.flying,
  'payapa-berry': PokemonType.psychic,
  'tanga-berry': PokemonType.bug,
  'charti-berry': PokemonType.rock,
  'kasib-berry': PokemonType.ghost,
  'haban-berry': PokemonType.dragon,
  'colbur-berry': PokemonType.dark,
  'babiri-berry': PokemonType.steel,
  'roseli-berry': PokemonType.fairy,
  'chilan-berry': PokemonType.normal,
};

/// Returns the damage multiplier from a type-resist berry.
/// Returns 0.5 if the berry matches and conditions are met, 1.0 otherwise.
double getResistBerryModifier(String? itemName, PokemonType moveType, double effectiveness) {
  if (itemName == null) return 1.0;
  final berryType = typeResistBerries[itemName];
  if (berryType == null || berryType != moveType) return 1.0;
  // Chilan Berry works on Normal-type (always, no super effective requirement)
  // Other berries only work when the move is super effective
  if (itemName == 'chilan-berry' || effectiveness > 1.0) return 0.5;
  return 1.0;
}

/// Speed item effect.
class SpeedItemEffect {
  final double speedModifier;
  final bool alwaysLast;

  const SpeedItemEffect({
    this.speedModifier = 1.0,
    this.alwaysLast = false,
  });
}

const _defaultSpeedItemEffect = SpeedItemEffect();

/// Returns the speed effect of [itemName].
///
/// - Choice Scarf: speed x1.5
/// - Iron Ball: speed x0.5
/// - Power items: speed x0.5
/// - Full Incense / Lagging Tail: always move last
SpeedItemEffect getSpeedItemEffect(String itemName) {
  switch (itemName) {
    case 'choice-scarf':
      return const SpeedItemEffect(speedModifier: kChoiceScarfSpeed);
    case 'iron-ball':
      return const SpeedItemEffect(speedModifier: kHeavyItemSpeedPenalty);
    case 'power-weight':
    case 'power-bracer':
    case 'power-belt':
    case 'power-lens':
    case 'power-band':
    case 'power-anklet':
      return const SpeedItemEffect(speedModifier: kHeavyItemSpeedPenalty);
    case 'full-incense':
    case 'lagging-tail':
      return const SpeedItemEffect(alwaysLast: true);
    default:
      return _defaultSpeedItemEffect;
  }
}
