import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/stats.dart';
import '../utils/champions_format_controller.dart';

export '../utils/champions_format_controller.dart' show ChampionsFormat;

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

  /// Most-adopted stat-point spread (Champions SP units, 0–32 per
  /// stat) from the in-game Battle Data. `null` when the species
  /// isn't covered — caller should leave EVs at their default (0).
  /// Stored in SP; convert with `ChampionsMode.spToEvStats` before
  /// assigning to [BattlePokemonState.ev].
  final Stats? defaultSp;

  /// Singles in-game usage rank (1 = most-used). `null` for species
  /// outside the ranked roster. Used by the dex's usage-ranking
  /// quick-reference sheet — never affects damage or speed math.
  final int? usageRank;

  const ChampionsUsageEntry({
    this.abilities = const [],
    this.items = const [],
    this.moves = const [],
    this.defaultMoves = const [],
    this.natures = const [],
    this.teras = const [],
    this.defaultSp,
    this.usageRank,
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
      defaultSp: _parseSp(json['defaultSp']),
      usageRank: (json['usageRank'] as num?)?.toInt(),
    );
  }

  /// Parses the `defaultSp` object — keys are the abbreviated stat
  /// names used in `champions_usage.json` (hp/atk/def/spa/spd/spe).
  static Stats? _parseSp(dynamic raw) {
    if (raw is! Map) return null;
    int v(String k) => (raw[k] as num?)?.toInt() ?? 0;
    return Stats(
      hp: v('hp'),
      attack: v('atk'),
      defense: v('def'),
      spAttack: v('spa'),
      spDefense: v('spd'),
      speed: v('spe'),
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

// Per-format cache + in-flight loader. Both formats stay independent
// so flipping the global [ChampionsFormatController] is just a map
// swap, not a re-fetch.
final Map<ChampionsFormat, Map<String, ChampionsUsageEntry>> _caches = {};
final Map<ChampionsFormat, Future<Map<String, ChampionsUsageEntry>>> _loading =
    {};

String _assetPathFor(ChampionsFormat format) =>
    format == ChampionsFormat.doubles
        ? 'assets/champions_usage_doubles.json'
        : 'assets/champions_usage.json';

/// Loads and caches the manually-curated Pokémon Champions usage
/// stats for the requested [format] (singles or doubles). Re-returns
/// the cached map on subsequent calls.
///
/// The returned map is keyed by `Pokemon.name` (English). Species
/// without an entry simply aren't in the map — callers should fall
/// back to their existing defaults.
Future<Map<String, ChampionsUsageEntry>> loadChampionsUsage({
  ChampionsFormat format = ChampionsFormat.singles,
}) {
  final cached = _caches[format];
  if (cached != null) return Future.value(cached);
  return _loading.putIfAbsent(format, () => _doLoad(format));
}

Future<Map<String, ChampionsUsageEntry>> _doLoad(
    ChampionsFormat format) async {
  try {
    final jsonString = await rootBundle.loadString(_assetPathFor(format));
    final raw = json.decode(jsonString) as Map<String, dynamic>;
    final out = <String, ChampionsUsageEntry>{};
    for (final entry in raw.entries) {
      if (entry.key.startsWith('_')) continue; // skip _meta
      final v = entry.value;
      if (v is! Map<String, dynamic>) continue;
      out[entry.key] = ChampionsUsageEntry.fromJson(v);
    }
    _caches[format] = out;
    return out;
  } catch (_) {
    // Doubles asset may not exist yet on builds that haven't shipped
    // the data refresh — return an empty map so callers gracefully
    // fall back to their defaults instead of crashing.
    final empty = <String, ChampionsUsageEntry>{};
    _caches[format] = empty;
    return empty;
  }
}

/// Fire-and-forget warmup — call from `main()` / startup to prime
/// BOTH formats' caches before the user opens the dex. No-op for
/// formats already loaded.
void preloadChampionsUsage() {
  loadChampionsUsage(format: ChampionsFormat.singles);
  loadChampionsUsage(format: ChampionsFormat.doubles);
}

ChampionsFormat _currentFormat() =>
    ChampionsFormatController.instance.format.value;

/// Sync lookup by `Pokemon.name` (English). Returns `null` if the
/// cache hasn't finished loading yet or if the species is uncurated —
/// callers should fall back to their existing defaults in either case.
///
/// Reads from the format chosen via [ChampionsFormatController] by
/// default; pass [format] explicitly to override (e.g. the rank sheet
/// previewing the inactive format).
///
/// Two-tier match: exact `pokemonName` first, then a parenthesised-
/// form fallback that strips ` (…)` and re-looks-up. Lets cosmetic
/// pose forms like "Morpeko (Hangry Mode)" inherit Morpeko's full
/// usage entry without duplicating data, while still letting
/// competitively-distinct forms like "Aegislash (Blade Forme)" or
/// "Paldean Tauros (Blaze Breed)" keep their own dedicated entries
/// (those win at the exact-match step before fallback runs).
ChampionsUsageEntry? championsUsageFor(
  String pokemonName, {
  ChampionsFormat? format,
}) {
  final cache = _caches[format ?? _currentFormat()];
  if (cache == null) return null;
  final exact = cache[pokemonName];
  if (exact != null) return exact;
  return cache[_stripFormSuffix(pokemonName)];
}

/// O(1) presence test — does this Pokémon have a Champions usage
/// entry? Used by dex filter UIs ("show only Pokémon in Champions")
/// to skip full-cache lookups on every visible row. Honours the
/// same parenthesised-form fallback as [championsUsageFor].
///
/// Reads from the current format by default; this means a species
/// ranked in singles but absent from doubles will be hidden from the
/// dex filter when the user switches to doubles. That matches user
/// intent — "Champions roster" means "current-format roster".
bool isInChampions(String pokemonName, {ChampionsFormat? format}) {
  final c = _caches[format ?? _currentFormat()];
  if (c == null) return false;
  if (c.containsKey(pokemonName)) return true;
  return c.containsKey(_stripFormSuffix(pokemonName));
}

/// "Morpeko (Hangry Mode)" → "Morpeko". Returns [name] unchanged
/// when there's no ` (…)` suffix.
String _stripFormSuffix(String name) {
  final idx = name.indexOf(' (');
  return idx < 0 ? name : name.substring(0, idx);
}
