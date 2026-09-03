import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/models/type.dart';

/// Form-change item infrastructure.
///
/// `requiredItem` in the dex mixes two mechanically different things:
///
///  * **Toggled in battle** — Mega Stones and the Primal orbs. The
///    Pokémon exists as its base species and transforms mid-battle.
///    These drive the mega/primal toggle button.
///  * **Fixed while held** — Ogerpon masks, Rusted Sword/Shield, the
///    Origin-forme items. The form is simply what the species *is*
///    while holding it; there is nothing to toggle.
///
/// Both kinds share one rule that matters for damage: Knock Off gets
/// no boost only when the holder is the species the item belongs to.
/// A Charizard holding Gyaradosite is knocked off normally.
void main() {
  late final List<Pokemon> dex;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dex = await loadPokedex();
  });

  group('data integrity', () {
    test('every mega entry declares baseSpecies and formChange mega', () {
      final megas = dex.where((p) => p.isMega).toList();
      expect(megas.length, greaterThan(80));
      for (final m in megas) {
        expect(m.baseSpecies, isNotNull,
            reason: '${m.name} is missing baseSpecies');
        expect(m.formChange, equals('mega'),
            reason: '${m.name} should be formChange=mega');
      }
    });

    test('every base species resolves to a real non-mega species', () {
      final byName = {for (final p in dex) p.name: p};
      for (final p in dex.where((p) => p.allBaseSpecies.isNotEmpty)) {
        for (final name in p.allBaseSpecies) {
          final base = byName[name];
          expect(base, isNotNull, reason: '${p.name} → $name does not exist');
          expect(base!.isMega, isFalse,
              reason: '${p.name} → $name must not itself be a mega');
        }
      }
    });

    test('a mega reverts to its primary base, never an alt', () {
      // Primary is whichever form actually runs the stone — the
      // female, in both formats.
      final meowstic = dex.firstWhere((p) => p.name == 'Mega Meowstic');
      expect(meowstic.baseSpecies, equals('Meowstic (Female)'));
      expect(meowstic.altBaseSpecies, contains('Meowstic'));
    });

    test('primal formes are classified as primal, not fixed', () {
      for (final name in ['Primal Groudon', 'Primal Kyogre']) {
        final p = dex.firstWhere((p) => p.name == name);
        expect(p.formChange, equals('primal'), reason: name);
        expect(p.baseSpecies, equals(name.replaceFirst('Primal ', '')));
      }
    });

    test('held-forme items are classified fixed (not togglable)', () {
      const fixed = {
        'Ogerpon (Wellspring Mask)': 'Ogerpon',
        'Zacian (Crowned Sword)': 'Zacian',
        'Giratina (Origin Forme)': 'Giratina',
        'Dialga (Origin Forme)': 'Dialga',
      };
      fixed.forEach((name, base) {
        final p = dex.firstWhere((p) => p.name == name);
        expect(p.formChange, equals('fixed'), reason: name);
        expect(p.baseSpecies, equals(base), reason: name);
      });
    });

    test('one stone maps to exactly one form', () {
      final seen = <String, String>{};
      for (final p in dex.where((p) => p.formChange != null)) {
        final item = p.requiredItem;
        if (item == null) continue; // Mega Rayquaza has no stone
        expect(seen.containsKey(item), isFalse,
            reason: '$item claimed by both ${seen[item]} and ${p.name}');
        seen[item] = p.name;
      }
    });
  });

  group('lookup API', () {
    test('formChangeForStone finds the mega a stone produces', () {
      expect(formChangeForStone('charizardite-x')?.name,
          equals('Mega Charizard X'));
      expect(formChangeForStone('charizardite-y')?.name,
          equals('Mega Charizard Y'));
      // Champions-era Z stones must resolve too — a suffix heuristic
      // (`endsWith('ite')`) misses these.
      expect(formChangeForStone('absolite-z')?.name, equals('Mega Absol Z'));
      expect(formChangeForStone('garchompite-z')?.name,
          equals('Mega Garchomp Z'));
      expect(formChangeForStone('lucarionite-z')?.name,
          equals('Mega Lucario Z'));
      expect(formChangeForStone('red-orb')?.name, equals('Primal Groudon'));
      expect(formChangeForStone('leftovers'), isNull);
    });

    test('togglableMegaFor requires the holder to own the stone', () {
      expect(togglableMegaFor('Charizard', 'charizardite-x')?.name,
          equals('Mega Charizard X'));
      expect(togglableMegaFor('Charizard', 'charizardite-y')?.name,
          equals('Mega Charizard Y'));
      // Someone else's stone does nothing.
      expect(togglableMegaFor('Charizard', 'gyaradosite'), isNull);
      // A regional form is a different species and cannot mega.
      expect(togglableMegaFor('Alolan Raichu', 'raichunite-x'), isNull);
      expect(togglableMegaFor('Raichu', 'raichunite-x')?.name,
          equals('Mega Raichu X'));
      expect(togglableMegaFor('Groudon', 'red-orb')?.name,
          equals('Primal Groudon'));
      expect(togglableMegaFor('Charizard', null), isNull);
    });

    test('togglableMegaFor excludes fixed (held) formes', () {
      // Holding a mask makes you that form already — nothing to toggle.
      expect(togglableMegaFor('Ogerpon', 'wellspring-mask'), isNull);
      expect(togglableMegaFor('Zacian', 'rusted-sword'), isNull);
      expect(togglableMegaFor('Giratina', 'griseous-core'), isNull);
    });

    test('both Meowstic genders can Mega Evolve', () {
      expect(togglableMegaFor('Meowstic', 'meowsticite')?.name,
          equals('Mega Meowstic'));
      expect(togglableMegaFor('Meowstic (Female)', 'meowsticite')?.name,
          equals('Mega Meowstic'));
      expect(isOwnFormItem('Meowstic (Female)', 'meowsticite'), isTrue);
    });

    test('Mega Zygarde comes from the Complete Forme', () {
      expect(togglableMegaFor('Zygarde (Complete Forme)', 'zygardite')?.name,
          equals('Mega Zygarde'));
      expect(togglableMegaFor('Zygarde (10% Forme)', 'zygardite'), isNull);
    });

    test('only Eternal Flower Floette can Mega Evolve', () {
      expect(togglableMegaFor('Floette (Eternal Flower)', 'floettite')?.name,
          equals('Mega Floette'));
      expect(togglableMegaFor('Floette', 'floettite'), isNull);
    });

    test('megaStonesForSpecies lists a species own stones', () {
      expect(megaStonesForSpecies('Charizard'),
          containsAll(['charizardite-x', 'charizardite-y']));
      expect(megaStonesForSpecies('Absol'),
          containsAll(['absolite', 'absolite-z']));
      expect(megaStonesForSpecies('Pikachu'), isEmpty);
    });
  });

  group('isOwnFormItem', () {
    test('true only for the species the item belongs to', () {
      expect(isOwnFormItem('Charizard', 'charizardite-x'), isTrue);
      expect(isOwnFormItem('Charizard', 'charizardite-y'), isTrue);
      expect(isOwnFormItem('Absol', 'absolite-z'), isTrue);
      expect(isOwnFormItem('Groudon', 'red-orb'), isTrue);
      // Fixed formes count too — the item is still unremovable.
      expect(isOwnFormItem('Ogerpon', 'wellspring-mask'), isTrue);
      expect(isOwnFormItem('Zacian', 'rusted-sword'), isTrue);

      expect(isOwnFormItem('Charizard', 'gyaradosite'), isFalse);
      expect(isOwnFormItem('Pikachu', 'red-orb'), isFalse);
      expect(isOwnFormItem('Zamazenta', 'rusted-sword'), isFalse);
      expect(isOwnFormItem('Charizard', 'leftovers'), isFalse);
    });
  });

  group('Champions mega abilities', () {
    // Champions keeps adding megas; each one's ability is curated by
    // hand from in-game data, so pin the ones we've confirmed.
    test('Z megas have their confirmed abilities', () {
      Pokemon m(String n) => dex.firstWhere((p) => p.name == n);
      expect(m('Mega Absol Z').abilities, equals(['Sharpness']));
      expect(m('Mega Garchomp Z').abilities, equals(['Levitate']));
    });

    test('Mega Garchomp Z drops Ground, matching Levitate', () {
      final m = dex.firstWhere((p) => p.name == 'Mega Garchomp Z');
      expect(m.type1, equals(PokemonType.dragon));
      expect(m.type2, isNull);
    });
  });
}
