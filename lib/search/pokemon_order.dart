import '../models/pokemon.dart';

/// Default (empty-query) order of the species picker: where each
/// Pokémon sits, by name.
///
/// 1. Champions usage rank, best first ([rankOf] → 1 is the most used).
/// 2. A form with no rank of its own that declares a base species — a
///    Mega, a Primal, a battle form — sits right after that base, so
///    Garchomp is followed by Mega Garchomp and Mega Garchomp Z. Forms
///    that are ranked themselves (regional forms, Rotom appliances)
///    keep their own place.
/// 3. Everything unranked follows in the order given ([pokemon] is in
///    dex / file order), each still trailed by its own forms.
///
/// Only the default list uses this; a typed query ranks by relevance.
Map<String, int> usageOrder(
  List<Pokemon> pokemon,
  int? Function(String name) rankOf,
) {
  const unranked = 1 << 30;
  final index = <String, int>{
    for (var i = 0; i < pokemon.length; i++) pokemon[i].name: i,
  };
  // (rank of the anchor, anchor's index, 0 = the anchor itself / 1 = a
  // form attached to it, own index).
  final keys = <String, (int, int, int, int)>{};
  for (final p in pokemon) {
    final base = p.baseSpecies;
    final attached =
        rankOf(p.name) == null && base != null && index.containsKey(base);
    final anchor = attached ? base : p.name;
    keys[p.name] = (
      rankOf(anchor) ?? unranked,
      index[anchor]!,
      attached ? 1 : 0,
      index[p.name]!,
    );
  }
  final sorted = [for (final p in pokemon) p.name]
    ..sort((a, b) {
      final ka = keys[a]!, kb = keys[b]!;
      var c = ka.$1.compareTo(kb.$1);
      if (c != 0) return c;
      c = ka.$2.compareTo(kb.$2);
      if (c != 0) return c;
      c = ka.$3.compareTo(kb.$3);
      if (c != 0) return c;
      return ka.$4.compareTo(kb.$4);
    });
  return {for (var i = 0; i < sorted.length; i++) sorted[i]: i};
}
