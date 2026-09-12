import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/ability_variants.dart';

/// Stateful abilities (Supreme Overlord 0–5, Flash Fire Inactive /
/// Active, …) ship as one description-only "base" dex entry plus
/// concrete state keys the calculator understands. The registry in
/// ability_variants.dart is the single place that knows base ↔ states
/// and the default state; before it, that knowledge was spread over
/// expandAbilityKey, the dex's _baseAbilityFor, expandAbilities and
/// five copy-pasted Supreme Overlord loops, and adding Flash Fire on
/// 2026-09-12 meant editing all of them by hand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registry and abilities.json agree on which entries are bases', () async {
    final dex = await loadAbilitydex();
    final registered = {for (final v in kAbilityVariants) v.base};
    final descriptionOnly = {
      for (final e in dex.entries) if (e.value.descriptionOnly) e.key,
    };
    expect(registered, descriptionOnly,
        reason: 'every description-only dex entry must be registered, '
            'and every registered base must be description-only');
    for (final v in kAbilityVariants) {
      for (final s in v.states) {
        expect(dex[s], isNotNull, reason: '$s missing from abilities.json');
        expect(dex[s]!.descriptionOnly, isFalse, reason: '$s must be pickable');
      }
      expect(v.states, contains(v.defaultState));
    }
  });

  test('expandAbilityKey: base → default state, anything else unchanged', () {
    expect(expandAbilityKey('Supreme Overlord'), 'Supreme Overlord 0');
    expect(expandAbilityKey('Flash Fire'), 'Flash Fire Inactive');
    expect(expandAbilityKey('Rivalry'), 'Rivalry Same');
    expect(expandAbilityKey('Flash Fire Active'), 'Flash Fire Active');
    expect(expandAbilityKey('Blaze'), 'Blaze');
  });

  test('abilityBaseFor: state → base, others null', () {
    expect(abilityBaseFor('Supreme Overlord 3'), 'Supreme Overlord');
    expect(abilityBaseFor('Disguise Busted'), 'Disguise');
    expect(abilityBaseFor('Slow Start Ended'), 'Slow Start');
    expect(abilityBaseFor('Blaze'), isNull);
    expect(abilityBaseFor('Supreme Overlord'), isNull);
  });

  test('expandAbilityStates: base → every state, others → itself', () {
    expect(expandAbilityStates('Supreme Overlord'),
        [for (var i = 0; i <= 5; i++) 'Supreme Overlord $i']);
    expect(expandAbilityStates('Stakeout'), ['Stakeout Inactive', 'Stakeout Active']);
    expect(expandAbilityStates('Blaze'), ['Blaze']);
    expect(expandAbilityStates('Stakeout Active'), ['Stakeout Active']);
  });
}
