import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
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
      power: 40, accuracy: 100, pp: 30, tags: [MoveTags.punch],
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

    // --- Choice items: 1.5× stat for matching category, 1.0× otherwise ---
    const choiceCases = <(String item, Move match, Move miss)>[
      ('choice-band', tackle, psychic),
      ('choice-specs', psychic, tackle),
    ];
    for (final c in choiceCases) {
      test('${c.$1} boosts matching category stat by 1.5×', () {
        final effect = getItemEffect(c.$1, move: c.$2);
        expect(effect.statModifier, equals(1.5));
        expect(effect.powerModifier, equals(1.0));
      });
      test('${c.$1} does not boost the other category', () {
        final effect = getItemEffect(c.$1, move: c.$3);
        expect(effect.statModifier, equals(1.0));
      });
    }

    // --- Power modifier items ---
    test('life-orb boosts power by ~1.3x (5324/4096)', () {
      final effect = getItemEffect('life-orb', move: tackle);
      expect(effect.statModifier, equals(1.0));
      expect(effect.powerModifier, closeTo(5324/4096, 0.001));
    });

    // --- 1.1× power-modifier items, gated by move category/tag ---
    const oneOnePower = <(String item, Move match, Move miss)>[
      ('muscle-band', tackle, psychic), // physical
      ('wise-glasses', psychic, tackle), // special
      ('punching-glove', machPunch, tackle), // punch tag
    ];
    for (final c in oneOnePower) {
      test('${c.$1} boosts matching move power by 1.1×', () {
        final effect = getItemEffect(c.$1, move: c.$2);
        expect(effect.powerModifier, equals(1.1));
      });
      test('${c.$1} does not boost non-matching moves', () {
        final effect = getItemEffect(c.$1, move: c.$3);
        expect(effect.powerModifier, equals(1.0));
      });
    }

    // (Type-boosting items grouped at the bottom — see "Type-boost
    // items (1.2×)" table below for charcoal / silk-scarf /
    // mystic-water / flame-plate / etc.)

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

    // --- Type-boost items (1.2×): one row per (item, sample matching
    // move). Most failures here mean the item's type-boost mapping
    // dropped a row in item_effects.dart. The "miss" coverage uses a
    // separate non-matching move per type below.
    const moonblast = Move(
      name: 'Moonblast', nameKo: '문포스', nameJa: 'ムーンフォース',
      type: PokemonType.fairy, category: MoveCategory.special,
      power: 95, accuracy: 100, pp: 15,
    );
    const energyBall = Move(
      name: 'Energy Ball', nameKo: '에너지볼', nameJa: 'エナジーボール',
      type: PokemonType.grass, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10,
    );
    const thunderbolt = Move(
      name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );
    const iceBeam = Move(
      name: 'Ice Beam', nameKo: '냉동빔', nameJa: 'れいとうビーム',
      type: PokemonType.ice, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10,
    );
    const stoneEdge = Move(
      name: 'Stone Edge', nameKo: '스톤에지', nameJa: 'ストーンエッジ',
      type: PokemonType.rock, category: MoveCategory.physical,
      power: 100, accuracy: 80, pp: 5,
    );

    const typeBoosts = <(String item, Move match)>[
      // Type-name items
      ('charcoal', flamethrower),
      ('silk-scarf', tackle),
      ('mystic-water', surf),
      ('miracle-seed', energyBall),
      ('magnet', thunderbolt),
      ('never-melt-ice', iceBeam),
      ('black-belt', machPunch),
      ('dragon-fang', dragonPulse),
      ('metal-coat', flashCannon),
      ('fairy-feather', moonblast),
      // Plates (Arceus' type item line)
      ('flame-plate', flamethrower),
      ('splash-plate', surf),
      ('draco-plate', dragonPulse),
      ('iron-plate', flashCannon),
      ('pixie-plate', moonblast),
      // Incenses (gen 4 species items)
      ('sea-incense', surf),
      ('wave-incense', surf),
      ('rose-incense', energyBall),
      ('odd-incense', psychic),
      ('rock-incense', stoneEdge),
    ];
    for (final c in typeBoosts) {
      test('${c.$1} boosts ${c.$2.type.name} moves by 1.2×', () {
        final effect = getItemEffect(c.$1, move: c.$2);
        expect(effect.powerModifier, equals(1.2));
      });
    }

    // Spot miss-cases — exercises the "wrong type → no boost" branch
    // for representative items in each family (type item / plate /
    // incense). Doing each item × each foreign type would be noise.
    const typeBoostMisses = <(String item, Move miss)>[
      ('charcoal', tackle),
      ('flame-plate', psychic),
    ];
    for (final c in typeBoostMisses) {
      test('${c.$1} does not boost non-matching moves', () {
        final effect = getItemEffect(c.$1, move: c.$2);
        expect(effect.powerModifier, equals(1.0));
      });
    }

    // --- Normal Gem (consumable, 1.3×) — distinct multiplier so it
    // gets its own pair instead of joining the 1.2× table.
    test('normal-gem boosts Normal moves by 1.3×', () {
      final effect = getItemEffect('normal-gem', move: tackle);
      expect(effect.powerModifier, equals(1.3));
    });

    test('normal-gem does not boost non-Normal moves', () {
      final effect = getItemEffect('normal-gem', move: flamethrower);
      expect(effect.powerModifier, equals(1.0));
    });

    // --- More Pokemon-specific items ---
    test('deep-sea-tooth does not boost non-clamperl', () {
      final effect = getItemEffect('deep-sea-tooth', move: surf, pokemonName: 'huntail');
      expect(effect.statModifier, equals(1.0));
    });

    test('deep-sea-tooth does not boost physical moves for clamperl', () {
      final effect = getItemEffect('deep-sea-tooth', move: tackle, pokemonName: 'clamperl');
      expect(effect.statModifier, equals(1.0));
    });

    test('thick-club does not boost non-cubone/marowak', () {
      final effect = getItemEffect('thick-club', move: tackle, pokemonName: 'pikachu');
      expect(effect.statModifier, equals(1.0));
    });

    test('griseous-orb boosts giratina dragon moves', () {
      final effect = getItemEffect('griseous-orb', move: dragonPulse, pokemonName: 'giratina');
      expect(effect.powerModifier, equals(1.2));
    });

    test('griseous-orb boosts giratina ghost moves', () {
      const shadowBall = Move(
        name: 'Shadow Ball', nameKo: '섀도볼', nameJa: 'シャドーボール',
        type: PokemonType.ghost, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15,
      );
      final effect = getItemEffect('griseous-orb', move: shadowBall, pokemonName: 'giratina');
      expect(effect.powerModifier, equals(1.2));
    });

    test('griseous-orb does not boost giratina other type moves', () {
      final effect = getItemEffect('griseous-orb', move: flamethrower, pokemonName: 'giratina');
      expect(effect.powerModifier, equals(1.0));
    });

    test('griseous-orb does nothing for non-giratina', () {
      final effect = getItemEffect('griseous-orb', move: dragonPulse, pokemonName: 'garchomp');
      expect(effect.powerModifier, equals(1.0));
    });

    test('griseous-core boosts giratina dragon moves', () {
      final effect = getItemEffect('griseous-core', move: dragonPulse, pokemonName: 'giratina');
      expect(effect.powerModifier, equals(1.2));
    });

    test('lustrous-orb boosts palkia dragon moves', () {
      final effect = getItemEffect('lustrous-orb', move: dragonPulse, pokemonName: 'palkia');
      expect(effect.powerModifier, equals(1.2));
    });

    test('lustrous-orb does not boost palkia other type moves', () {
      final effect = getItemEffect('lustrous-orb', move: flamethrower, pokemonName: 'palkia');
      expect(effect.powerModifier, equals(1.0));
    });

    test('lustrous-orb does nothing for non-palkia', () {
      final effect = getItemEffect('lustrous-orb', move: surf, pokemonName: 'kyogre');
      expect(effect.powerModifier, equals(1.0));
    });

    test('soul-dew does not boost latios non-dragon/psychic moves', () {
      final effect = getItemEffect('soul-dew', move: surf, pokemonName: 'latios');
      expect(effect.powerModifier, equals(1.0));
    });

    test('soul-dew does nothing for non-lati pokemon', () {
      final effect = getItemEffect('soul-dew', move: dragonPulse, pokemonName: 'garchomp');
      expect(effect.powerModifier, equals(1.0));
    });

    test('light-ball works for pikachu variants (contains check)', () {
      final effect = getItemEffect('light-ball', move: tackle, pokemonName: 'pikachu-gmax');
      expect(effect.statModifier, equals(2.0));
    });

  });

  group('DefensiveItemEffect', () {
    test('eviolite boosts Def and SpDef by 1.5x for non-final evo', () {
      final effect = getDefensiveItemEffect('eviolite', finalEvo: false);
      expect(effect.defModifier, equals(1.5));
      expect(effect.spdModifier, equals(1.5));
    });

    test('eviolite does not boost final evolution', () {
      final effect = getDefensiveItemEffect('eviolite', finalEvo: true);
      expect(effect.defModifier, equals(1.0));
      expect(effect.spdModifier, equals(1.0));
    });

    test('assault-vest boosts SpDef by 1.5x', () {
      final effect = getDefensiveItemEffect('assault-vest');
      expect(effect.defModifier, equals(1.0));
      expect(effect.spdModifier, equals(1.5));
    });

  });
}
