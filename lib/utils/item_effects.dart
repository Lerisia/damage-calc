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

/// Returns the offensive effect of [itemName] given the [move] being used.
///
/// Items that don't affect offensive power return default modifiers (1.0, 1.0).
ItemEffect getItemEffect(String itemName, {required Move move}) {
  switch (itemName) {
    case 'Choice Band':
      return move.category == MoveCategory.physical
          ? const ItemEffect(statModifier: 1.5)
          : _defaultEffect;
    case 'Choice Specs':
      return move.category == MoveCategory.special
          ? const ItemEffect(statModifier: 1.5)
          : _defaultEffect;
    case 'Life Orb':
      return const ItemEffect(powerModifier: 1.3);
    case 'Silk Scarf':
      return move.type == PokemonType.normal
          ? const ItemEffect(powerModifier: 1.2)
          : _defaultEffect;
    case 'Muscle Band':
      return move.category == MoveCategory.physical
          ? const ItemEffect(powerModifier: 1.1)
          : _defaultEffect;
    case 'Wise Glasses':
      return move.category == MoveCategory.special
          ? const ItemEffect(powerModifier: 1.1)
          : _defaultEffect;
    default:
      return _defaultEffect;
  }
}
