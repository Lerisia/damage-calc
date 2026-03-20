import '../models/move.dart';

/// Offensive modifiers returned by an ability
class AbilityEffect {
  final double statModifier;
  final double powerModifier;

  const AbilityEffect({
    this.statModifier = 1.0,
    this.powerModifier = 1.0,
  });
}

const _defaultEffect = AbilityEffect();

/// Returns the offensive effect of [abilityName] given the [move] being used.
///
/// Abilities that don't affect offensive power return default modifiers (1.0, 1.0).
AbilityEffect getAbilityEffect(String abilityName, {required Move move}) {
  switch (abilityName) {
    case 'Tough Claws':
      return move.hasTag('contact')
          ? const AbilityEffect(powerModifier: 1.3)
          : _defaultEffect;
    default:
      return _defaultEffect;
  }
}
