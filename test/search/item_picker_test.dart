import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/item.dart';
import 'package:damage_calc/search/item_picker.dart';

/// The shared item picker: ranked search, "no item" pinned, current
/// pick hoisted, Champions scope as an allow-filter that spares the
/// current pick.
void main() {
  const dex = {
    'leftovers': Item(name: 'leftovers', nameKo: '먹다남은음식', nameJa: 'たべのこし', nameEn: 'Leftovers', held: true),
    'choice-scarf': Item(name: 'choice-scarf', nameKo: '구애스카프', nameJa: 'こだわりスカーフ', nameEn: 'Choice Scarf', held: true),
    'choice-specs': Item(name: 'choice-specs', nameKo: '구애안경', nameJa: 'こだわりメガネ', nameEn: 'Choice Specs', held: true),
    'life-orb': Item(name: 'life-orb', nameKo: '생명의구슬', nameJa: 'いのちのたま', nameEn: 'Life Orb', held: true),
  };
  final names = {for (final e in dex.entries) e.key: e.value.nameKo};
  String label(String k) => k.isEmpty ? '없음' : names[k]!;
  final index = buildItemIndex(names, itemDex: dex, noneLabel: '없음');
  bool champ(String k) => k != 'choice-specs';

  test('empty query: current pick, then "no item", then the rest A→Z', () {
    expect(
        itemSuggestions(index, '', selected: 'life-orb', championsOnly: false, labelOf: label),
        ['life-orb', '', 'choice-scarf', 'choice-specs', 'leftovers']);
  });

  test('a query ranks by relevance instead of file order', () {
    final r = itemSuggestions(index, '구애', championsOnly: false, labelOf: label);
    expect(r.take(2).toSet(), {'choice-scarf', 'choice-specs'});
    expect(r, isNot(contains('leftovers')));
    expect(itemSuggestions(index, 'left', championsOnly: false, labelOf: label).first, 'leftovers');
    expect(itemSuggestions(index, 'ㅁㄷㄴ', championsOnly: false, labelOf: label).first, 'leftovers');
  });

  test('Champions scope drops non-legal items but keeps the current pick', () {
    expect(
        itemSuggestions(index, '', championsOnly: true, labelOf: label, isChampions: champ),
        ['', 'choice-scarf', 'leftovers', 'life-orb']);
    expect(
        itemSuggestions(index, '', selected: 'choice-specs', championsOnly: true,
            labelOf: label, isChampions: champ),
        ['choice-specs', '', 'choice-scarf', 'leftovers', 'life-orb']);
    expect(
        itemSuggestions(index, '구애', championsOnly: true, labelOf: label, isChampions: champ),
        ['choice-scarf']);
  });

  test('"no item" is searchable by its label', () {
    expect(itemSuggestions(index, '없', championsOnly: false, labelOf: label), ['']);
  });
}
