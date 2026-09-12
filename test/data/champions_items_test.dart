import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/champions_items.dart';
import 'package:damage_calc/data/itemdex.dart';

/// The Champions item allowlist comes straight from the ROM
/// (tools/fetch_champions_items.py). Users reported Choice Specs and
/// Assault Vest — items Champions doesn't have — in the Champions-only
/// item picker: the picker was keyed off the itemdex's "usable in
/// battle" flag, which says nothing about Champions. These pin the
/// roster's shape so a source or parser change can't quietly ship a
/// list that hides Leftovers or re-admits Choice Specs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Set<String>> allowlist() async {
    final raw = json.decode(
        await rootBundle.loadString('assets/champions_items.json'));
    return (raw['items'] as List).cast<String>().toSet();
  }

  test('staple Champions items are legal, mainline-only ones are not', () async {
    final legal = await allowlist();
    expect(legal.length, greaterThan(100));
    for (final k in const [
      'choice-scarf', 'leftovers', 'life-orb', 'focus-sash', 'kings-rock',
      'sitrus-berry', 'charizardite-x', 'grassy-seed',
    ]) {
      expect(legal, contains(k), reason: k);
    }
    for (final k in const ['choice-specs', 'choice-band', 'assault-vest', 'eviolite']) {
      expect(legal, isNot(contains(k)), reason: k);
    }
  });

  test('every allowlisted key is a held item in the itemdex', () async {
    final legal = await allowlist();
    final dex = await loadItemdex();
    for (final k in legal) {
      expect(dex[k], isNotNull, reason: '$k missing from items.json');
      expect(dex[k]!.held, isTrue, reason: '$k is not a held item');
    }
  });

  group('isChampionsItem', () {
    test('answers from the loaded allowlist', () async {
      await loadChampionsItems();
      expect(isChampionsItem('leftovers'), isTrue);
      expect(isChampionsItem('choice-specs'), isFalse);
    });
  });

  group('filterItemKeysForChampions', () {
    const keys = ['leftovers', 'choice-specs', 'life-orb'];
    bool champ(String k) => k != 'choice-specs';

    test('passes everything through when the scope is off', () {
      expect(filterItemKeysForChampions(keys, championsOnly: false, isChampions: champ),
          keys);
    });

    test('drops non-Champions items when the scope is on', () {
      expect(filterItemKeysForChampions(keys, championsOnly: true, isChampions: champ),
          ['leftovers', 'life-orb']);
    });

    test('keeps the currently selected item even if it is not legal', () {
      expect(
          filterItemKeysForChampions(keys,
              championsOnly: true, isChampions: champ, keep: 'choice-specs'),
          ['leftovers', 'choice-specs', 'life-orb']);
    });
  });
}
