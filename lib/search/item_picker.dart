import '../data/champions_items.dart';
import '../models/item.dart';
import 'korean_search.dart';

/// Shared helpers for the held-item typeahead pickers (StatInput, Simple
/// Mode, the speed tab, the team builder). Until 2026-09-13 each of the
/// six fields re-implemented its own `where(triLanguageScore(...) > 0)`
/// filter — unranked, so results came out in items.json order and Enter
/// picked the first *file-order* match rather than the best one, while
/// the ability pickers next to them ranked properly through
/// [SearchIndex]. This puts items on the same engine.

/// The "no item" entry. Always offered, always at the top.
const String kNoItemKey = '';

/// Builds a [SearchIndex] over item keys. [nameMap] is key → localized
/// label (the pickers' display map); [itemDex] supplies the KO/EN/JA
/// names for matching when available (Simple Mode only has the label
/// map, so EN falls back to the key). [noneLabel] is the label the
/// "no item" entry matches against.
SearchIndex<String> buildItemIndex(
  Map<String, String> nameMap, {
  Map<String, Item> itemDex = const {},
  required String noneLabel,
}) {
  return SearchIndex<String>([
    SearchEntry<String>(kNoItemKey, noneLabel, 'none'),
    for (final k in nameMap.keys)
      SearchEntry<String>(
        k,
        itemDex[k]?.nameKo ?? nameMap[k] ?? k,
        itemDex[k]?.nameEn ?? k,
        nameJa: itemDex[k]?.nameJa ?? '',
      ),
  ]);
}

/// Item suggestions for [query]: the current [selected] item first, then
/// "no item", then the rest — A→Z by [labelOf] on an empty query,
/// relevance-ranked otherwise. With [championsOnly] on, items outside
/// the Champions roster are dropped, except the current pick so a value
/// loaded from a paste or an older session never vanishes from its own
/// field. [isChampions] defaults to [isChampionsItem]; injectable for
/// tests.
List<String> itemSuggestions(
  SearchIndex<String> index,
  String query, {
  String? selected,
  required bool championsOnly,
  required String Function(String key) labelOf,
  bool Function(String key) isChampions = isChampionsItem,
}) {
  bool allow(String k) =>
      k == kNoItemKey || k == selected || !championsOnly || isChampions(k);
  return pickerSuggestions(
    index,
    query,
    hoist: selected,
    pins: const [kNoItemKey],
    allow: allow,
    restSort: (a, b) => labelOf(a).compareTo(labelOf(b)),
  );
}
