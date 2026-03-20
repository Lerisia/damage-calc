import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/item_effects.dart';

void main() {
  group('ItemEffect', () {
    const tackle = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35,
    );

    const psychic = Move(
      name: 'Psychic', nameKo: '사이코키네시스', nameJa: 'サイコキネシス',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10,
    );

    const flamethrower = Move(
      name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
      type: PokemonType.fire, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    const machPunch = Move(
      name: 'Mach Punch', nameKo: '마하펀치', nameJa: 'マッハパンチ',
      type: PokemonType.fighting, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 30, tags: ['punch'],
    );

    const dragonPulse = Move(
      name: 'Dragon Pulse', nameKo: '용의파동', nameJa: 'りゅうのはどう',
      type: PokemonType.dragon, category: MoveCategory.special,
      power: 85, accuracy: 100, pp: 10,
    );

    const flashCannon = Move(
      name: 'Flash Cannon', nameKo: '러스터캐논', nameJa: 'ラスターカノン',
      type: PokemonType.steel, category: MoveCategory.special,
      power: 80, accuracy: 100, pp: 10,
    );

    const surf = Move(
      name: 'Surf', nameKo: '파도타기', nameJa: 'なみのり',
      type: PokemonType.water, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    // --- Stat modifier items ---
    test('choice-band boosts physical stat by 1.5x', () {
      final effect = getItemEffect('choice-band', move: tackle);
      expect(effect.statModifier, equals(1.5));
      expect(effect.powerModifier, equals(1.0));
    });

    test('choice-band does not boost special moves', () {
      final effect = getItemEffect('choice-band', move: psychic);
      expect(effect.statModifier, equals(1.0));
    });

    test('choice-specs boosts special stat by 1.5x', () {
      final effect = getItemEffect('choice-specs', move: psychic);
      expect(effect.statModifier, equals(1.5));
    });

    test('choice-specs does not boost physical moves', () {
      final effect = getItemEffect('choice-specs', move: tackle);
      expect(effect.statModifier, equals(1.0));
    });

    // --- Power modifier items ---
    test('life-orb boosts power by 1.3x', () {
      final effect = getItemEffect('life-orb', move: tackle);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, equals(1.3));
    });

    test('muscle-band boosts physical moves by 1.1x', () {
      final effect = getItemEffect('muscle-band', move: tackle);
      expect(effect.powerModifier, equals(1.1));
    });

    test('muscle-band does not boost special moves', () {
      final effect = getItemEffect('muscle-band', move: psychic);
      expect(effect.powerModifier, equals(1.0));
    });

    test('wise-glasses boosts special moves by 1.1x', () {
      final effect = getItemEffect('wise-glasses', move: psychic);
      expect(effect.powerModifier, equals(1.1));
    });

    test('wise-glasses does not boost physical moves', () {
      final effect = getItemEffect('wise-glasses', move: tackle);
      expect(effect.powerModifier, equals(1.0));
    });

    test('punching-glove boosts punch moves by 1.1x', () {
      final effect = getItemEffect('punching-glove', move: machPunch);
      expect(effect.powerModifier, equals(1.1));
    });

    test('punching-glove does not boost non-punch moves', () {
      final effect = getItemEffect('punching-glove', move: tackle);
      expect(effect.powerModifier, equals(1.0));
    });

    // --- Type-boosting items ---
    test('charcoal boosts fire moves by 1.2x', () {
      final effect = getItemEffect('charcoal', move: flamethrower);
      expect(effect.powerModifier, equals(1.2));
    });

    test('charcoal does not boost non-fire moves', () {
      final effect = getItemEffect('charcoal', move: tackle);
      expect(effect.powerModifier, equals(1.0));
    });

    test('silk-scarf boosts Normal-type moves by 1.2x', () {
      final effect = getItemEffect('silk-scarf', move: tackle);
      expect(effect.powerModifier, equals(1.2));
    });

    test('mystic-water boosts water moves by 1.2x', () {
      final effect = getItemEffect('mystic-water', move: surf);
      expect(effect.powerModifier, equals(1.2));
    });

    test('flame-plate boosts fire moves by 1.2x', () {
      final effect = getItemEffect('flame-plate', move: flamethrower);
      expect(effect.powerModifier, equals(1.2));
    });

    test('flame-plate does not boost non-fire moves', () {
      final effect = getItemEffect('flame-plate', move: psychic);
      expect(effect.powerModifier, equals(1.0));
    });

    // --- Pokemon-specific items ---
    test('light-ball doubles pikachu stat', () {
      final effect = getItemEffect('light-ball', move: tackle, pokemonName: 'pikachu');
      expect(effect.statModifier, equals(2.0));
    });

    test('light-ball does nothing for non-pikachu', () {
      final effect = getItemEffect('light-ball', move: tackle, pokemonName: 'raichu');
      expect(effect.statModifier, equals(1.0));
    });

    test('thick-club doubles cubone attack', () {
      final effect = getItemEffect('thick-club', move: tackle, pokemonName: 'cubone');
      expect(effect.statModifier, equals(2.0));
    });

    test('thick-club doubles marowak attack', () {
      final effect = getItemEffect('thick-club', move: tackle, pokemonName: 'marowak');
      expect(effect.statModifier, equals(2.0));
    });

    test('thick-club does not boost special moves for marowak', () {
      final effect = getItemEffect('thick-club', move: psychic, pokemonName: 'marowak');
      expect(effect.statModifier, equals(1.0));
    });

    test('deep-sea-tooth doubles clamperl spAtk', () {
      final effect = getItemEffect('deep-sea-tooth', move: surf, pokemonName: 'clamperl');
      expect(effect.statModifier, equals(2.0));
    });

    test('adamant-orb boosts dialga dragon moves', () {
      final effect = getItemEffect('adamant-orb', move: dragonPulse, pokemonName: 'dialga');
      expect(effect.powerModifier, equals(1.2));
    });

    test('adamant-orb boosts dialga steel moves', () {
      final effect = getItemEffect('adamant-orb', move: flashCannon, pokemonName: 'dialga');
      expect(effect.powerModifier, equals(1.2));
    });

    test('adamant-orb does not boost dialga other type moves', () {
      final effect = getItemEffect('adamant-orb', move: flamethrower, pokemonName: 'dialga');
      expect(effect.powerModifier, equals(1.0));
    });

    test('adamant-orb does nothing for non-dialga', () {
      final effect = getItemEffect('adamant-orb', move: dragonPulse, pokemonName: 'garchomp');
      expect(effect.powerModifier, equals(1.0));
    });

    test('lustrous-orb boosts palkia dragon/water', () {
      final effect = getItemEffect('lustrous-orb', move: surf, pokemonName: 'palkia');
      expect(effect.powerModifier, equals(1.2));
    });

    test('soul-dew boosts latios dragon/psychic', () {
      final effect = getItemEffect('soul-dew', move: dragonPulse, pokemonName: 'latios');
      expect(effect.powerModifier, equals(1.2));
    });

    test('soul-dew boosts latias psychic', () {
      final effect = getItemEffect('soul-dew', move: psychic, pokemonName: 'latias');
      expect(effect.powerModifier, equals(1.2));
    });

    // --- Default ---
    test('unknown item returns default modifiers', () {
      final effect = getItemEffect('focus-sash', move: tackle);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, equals(1.0));
    });
  });
}
