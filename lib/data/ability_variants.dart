/// Stateful abilities: the registry of base ↔ state keys.
///
/// Some abilities have a battle state the calculator must know
/// (Supreme Overlord's fallen-ally count, whether Flash Fire has been
/// absorbed, …). They ship in the ability dex as one description-only
/// base entry (`Flash Fire`) plus concrete, pickable state keys
/// (`Flash Fire Inactive`, `Flash Fire Active`), and species data
/// lists the states — except Supreme Overlord, which is listed bare
/// and expanded on pick.
///
/// This file is the only place that knows which keys belong together
/// and which state is the default. Everything else asks it:
/// `BattlePokemonState.expandAbilityKey`, the dex's base-entry lookup,
/// the ability pickers' own-ability expansion, and the species-data
/// sentinel test. Adding a stateful ability = one entry here + the dex
/// entries + the effect cases; `test/data/ability_variants_test.dart`
/// fails if the dex and this list disagree.
class AbilityVariant {
  /// The description-only dex key.
  final String base;

  /// Concrete state keys, default first.
  final List<String> states;

  const AbilityVariant(this.base, this.states);

  String get defaultState => states.first;
}

const List<AbilityVariant> kAbilityVariants = [
  AbilityVariant('Supreme Overlord', [
    'Supreme Overlord 0', 'Supreme Overlord 1', 'Supreme Overlord 2',
    'Supreme Overlord 3', 'Supreme Overlord 4', 'Supreme Overlord 5',
  ]),
  AbilityVariant('Rivalry', ['Rivalry Same', 'Rivalry Opposite', 'Rivalry None']),
  AbilityVariant('Flash Fire', ['Flash Fire Inactive', 'Flash Fire Active']),
  AbilityVariant('Slow Start', ['Slow Start Active', 'Slow Start Ended']),
  AbilityVariant('Stakeout', ['Stakeout Inactive', 'Stakeout Active']),
  AbilityVariant('Disguise', ['Disguise Disguised', 'Disguise Busted']),
];

final Map<String, AbilityVariant> _byBase = {
  for (final v in kAbilityVariants) v.base: v,
};
final Map<String, AbilityVariant> _byState = {
  for (final v in kAbilityVariants)
    for (final s in v.states) s: v,
};

/// A base key → its default state; any other key unchanged. Used when
/// only the group key is known (species data, usage tables, pastes,
/// older sessions).
String expandAbilityKey(String key) => _byBase[key]?.defaultState ?? key;

/// A state key → its base; null for anything that is not a state.
String? abilityBaseFor(String key) => _byState[key]?.base;

/// A base key → all of its states; any other key → `[key]`.
List<String> expandAbilityStates(String key) =>
    _byBase[key]?.states ?? [key];
