import 'dart:convert';
import 'package:flutter/services.dart';

/// Usage-stats payload for a single Pokémon species, sourced from the
/// Pokémon Champions in-game Battle Data (Singles) menu. Curated by
/// hand — not every species has an entry; each array is **ordered
/// by descending usage** (position 0 = most-used) and can be empty
/// or short when the category doesn't warrant it.
///
/// ID conventions per array:
///   - abilities: English display name (e.g. `"Rough Skin"`) — matches
///     `abilities.json`'s `name` and `BattlePokemonState.selectedAbility`.
///   - items: lowercase-hyphen ID (e.g. `"focus-sash"`) — matches
///     `items.json`'s `name` and `BattlePokemonState.selectedItem`.
///   - moves: English PascalCase (e.g. `"Earthquake"`) — matches
///     `moves/*.json`'s `name` and `Move.name`.
///   - natures: English nature name (e.g. `"Jolly"`) — app maps to
///     [NatureProfile] at call site.
///   - teras: English type name (e.g. `"Steel"`).
class ChampionsUsageEntry {
  final List<UsageRow> abilities;
  final List<UsageRow> items;
  /// All curated damage moves a player might pick. Variation table /
  /// move pickers should source from here.
  final List<UsageRow> moves;
  /// Subset of [moves] that should be auto-loaded when the species is
  /// dropped into an attacker slot. Empty when the curator hasn't
  /// committed a default set yet — caller should fall back to the
  /// first 4 of [moves].
  final List<UsageRow> defaultMoves;
  final List<UsageRow> natures;
  final List<UsageRow> teras;

  const ChampionsUsageEntry({
    this.abilities = const [],
    this.items = const [],
    this.moves = const [],
    this.defaultMoves = const [],
    this.natures = const [],
    this.teras = const [],
  });

  factory ChampionsUsageEntry.fromJson(Map<String, dynamic> json) {
    List<UsageRow> list(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.map((e) => UsageRow.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }
    return ChampionsUsageEntry(
      abilities: list('abilities'),
      items: list('items'),
      moves: list('moves'),
      defaultMoves: list('defaultMoves'),
      natures: list('natures'),
      teras: list('teras'),
    );
  }
}

class UsageRow {
  /// Display name (see [ChampionsUsageEntry] doc for convention per
  /// category).
  final String name;
  /// Usage percent (0-100), or `null` when the curator recorded only
  /// the ranking order. Consumers should rely on list order as the
  /// primary signal; `pct` is metadata.
  final double? pct;

  const UsageRow({required this.name, this.pct});

  factory UsageRow.fromJson(Map<String, dynamic> json) => UsageRow(
        name: json['name'] as String,
        pct: (json['pct'] as num?)?.toDouble(),
      );
}

Map<String, ChampionsUsageEntry>? _cache;
Future<Map<String, ChampionsUsageEntry>>? _loading;

/// Loads and caches the manually-curated Pokémon Champions Singles
/// usage stats. Re-returns the cached map on subsequent calls.
///
/// The returned map is keyed by `Pokemon.name` (English). Species
/// without an entry simply aren't in the map — callers should fall
/// back to their existing defaults.
Future<Map<String, ChampionsUsageEntry>> loadChampionsUsage() {
  if (_cache != null) return Future.value(_cache!);
  return _loading ??= _doLoad();
}

Future<Map<String, ChampionsUsageEntry>> _doLoad() async {
  final jsonString =
      await rootBundle.loadString('assets/champions_usage.json');
  final Map<String, dynamic> raw =
      json.decode(jsonString) as Map<String, dynamic>;
  final out = <String, ChampionsUsageEntry>{};
  for (final entry in raw.entries) {
    if (entry.key.startsWith('_')) continue; // skip _meta
    final v = entry.value;
    if (v is! Map<String, dynamic>) continue;
    out[entry.key] = ChampionsUsageEntry.fromJson(v);
  }
  _cache = out;
  return out;
}

/// Fire-and-forget warmup — call from `main()` / startup to prime the
/// cache before the user hits the dex. No-op if already loaded.
void preloadChampionsUsage() {
  loadChampionsUsage();
}

/// Sync lookup by `Pokemon.name` (English). Returns `null` if the
/// cache hasn't finished loading yet or if the species is uncurated —
/// callers should fall back to their existing defaults in either case.
ChampionsUsageEntry? championsUsageFor(String pokemonName) {
  return _cache?[pokemonName];
}
