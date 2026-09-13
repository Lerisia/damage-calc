import '../data/ability_variants.dart';
import 'korean_search.dart';

/// Shared helpers for the ability typeahead pickers (StatInput, Simple
/// Mode, Team Coverage). These three surfaces were each re-implementing
/// the same "expand numbered variants → own-first, filtered, sorted
/// rest → relevance search" logic; this centralises it on the app-wide
/// [SearchIndex] engine.

/// Expands a species' ability list into the concrete keys a picker can
/// offer: a stateful base (Supreme Overlord) becomes every state the
/// registry lists; [nameMap] gates which keys actually exist in the
/// loaded dex so we never offer a key it doesn't carry.
List<String> expandAbilities(
    List<String> abilities, Map<String, String> nameMap) {
  return [
    for (final a in abilities)
      for (final key in expandAbilityStates(a))
        if (nameMap.containsKey(key)) key,
  ];
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
