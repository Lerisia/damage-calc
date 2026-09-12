import 'dart:convert';
import 'package:flutter/services.dart';

/// Champions-legal held-item allowlist.
///
/// Champions ships a restricted item roster (166 held items at v1.2.0:
/// no Choice Band / Specs, no Assault Vest, no Eviolite, …). The
/// itemdex's `held` flag only says an item is usable in battle at all,
/// so when the global "Champions only" scope is on the item pickers
/// additionally drop anything absent from this set.
///
/// Sourced from `assets/champions_items.json`, built by
/// `tools/fetch_champions_items.py` from the ROM dump
/// (projectpokemon/champout `masterdata/item.json` joined with the
/// English item-name text). Refreshed on the daily data cron next to
/// the move allowlist.

Set<String>? _cache;
Future<Set<String>>? _loading;

/// Loads and caches the Champions-legal item-key set (items.json slugs
/// such as `leftovers`). Re-returns the cache on later calls.
Future<Set<String>> loadChampionsItems() {
  if (_cache != null) return Future.value(_cache!);
  return _loading ??= _doLoad();
}

Future<Set<String>> _doLoad() async {
  try {
    final jsonString =
        await rootBundle.loadString('assets/champions_items.json');
    final raw = json.decode(jsonString) as Map<String, dynamic>;
    final items = (raw['items'] as List?)?.cast<String>() ?? const [];
    _cache = items.toSet();
  } catch (_) {
    // Missing / malformed asset → empty set, which [isChampionsItem]
    // treats as "don't filter" so a bad asset degrades to showing every
    // held item rather than emptying the pickers.
    _cache = <String>{};
  }
  return _cache!;
}

/// Fire-and-forget warmup — call from app startup so the first item
/// picker render has the set in hand.
void preloadChampionsItems() {
  loadChampionsItems();
}

/// Whether [itemKey] (an items.json slug) is legal in Champions.
/// Returns `true` while the cache hasn't loaded OR the allowlist is
/// empty, so callers never hide items on the strength of missing data.
bool isChampionsItem(String itemKey) {
  final c = _cache;
  if (c == null || c.isEmpty) return true;
  return c.contains(itemKey);
}
