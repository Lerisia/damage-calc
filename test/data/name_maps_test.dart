import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/name_maps.dart';
import 'package:damage_calc/models/ability.dart';
import 'package:damage_calc/models/item.dart';

/// The one definition of what the pickers may offer.
void main() {
  const items = {
    'leftovers': Item(name: 'leftovers', nameKo: '먹다남은음식', nameJa: 'たべのこし', held: true),
    'potion': Item(name: 'potion', nameKo: '상처약', nameJa: 'キズぐすり'),
  };
  const abilities = {
    'Blaze': Ability(name: 'Blaze', nameKo: '맹화', nameJa: 'もうか'),
    'Flash Fire': Ability(name: 'Flash Fire', nameKo: '타오르는불꽃', nameJa: 'もらいび', descriptionOnly: true),
    'Flash Fire Active': Ability(name: 'Flash Fire Active', nameKo: '타오르는불꽃 (발동)', nameJa: 'もらいび (発動)'),
    'Shadow': Ability(name: 'Shadow', nameKo: '섀도', nameJa: 'シャドー', nonMainline: true),
  };

  test('heldItemNames keeps held items only', () {
    expect(heldItemNames(items).keys, ['leftovers']);
  });

  test('pickable abilities exclude spin-off and description-only keys', () {
    expect(pickableAbilityKeys(abilities), {'Blaze', 'Flash Fire Active'});
    expect(abilityNames(abilities).keys, ['Blaze', 'Flash Fire Active']);
  });

  test('display map can label the group keys usage tables carry', () {
    expect(abilityNames(abilities, pickableOnly: false)['Flash Fire'], '타오르는불꽃');
  });
}
