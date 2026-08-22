import 'korean_search.dart';

/// Shared helpers for the ability typeahead pickers (StatInput, Simple
/// Mode, Team Coverage). These three surfaces were each re-implementing
/// the same "expand numbered variants → own-first, filtered, sorted
/// rest → relevance search" logic; this centralises it on the app-wide
/// [SearchIndex] engine.

/// Expands abilities that ship as numbered variants into their concrete
/// keys. Currently just Supreme Overlord (0–5 fallen allies); [nameMap]
/// gates which variants actually exist so we don't invent keys the
/// ability dex doesn't carry.
List<String> expandAbilities(
    List<String> abilities, Map<String, String> nameMap) {
  final expanded = <String>[];
  for (final a in abilities) {
    if (a == 'Supreme Overlord') {
      for (int i = 0; i <= 5; i++) {
        final key = 'Supreme Overlord $i';
        if (nameMap.containsKey(key)) expanded.add(key);
      }
    } else {
      expanded.add(a);
    }
  }
  return expanded;
}

/// Builds a [SearchIndex] over ability keys. [keys] is the full ability
/// key set; [koOf]/[enOf]/[jaOf] resolve each key's localized names for
/// matching (EN falls back to the key itself so English-name/internal-
/// key search keeps working).
SearchIndex<String> buildAbilityIndex(
  Iterable<String> keys, {
  required String Function(String key) koOf,
  String Function(String key)? enOf,
  String Function(String key)? jaOf,
}) {
  return SearchIndex<String>([
    for (final k in keys)
      SearchEntry<String>(
        k,
        koOf(k),
        enOf?.call(k) ?? k,
        nameJa: jaOf?.call(k) ?? '',
      ),
  ]);
}
