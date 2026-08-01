import 'dart:convert';
import 'package:flutter/services.dart';

/// Champions-legal move allowlist.
///
/// Champions ships a restricted move roster (a subset of the national-
/// dex movepool). When the global "Champions only" filter is on, moves
/// absent from this set are hidden from the Move Dex, the move selector,
/// and any other move list — a legal-in-mainline move that Champions cut
/// shouldn't be pickable while the user is scoped to Champions.
///
/// Sourced from `assets/champions_moves.json`, built by
/// `tools/fetch_champions_moves.py` off yakkun's Champions move list
/// (the only source that enumerates the legal set — pkmnchamps' API is
/// items-only and usage data misses legal-but-unused moves). Refreshed
/// on the same cron as the usage data.

Set<String>? _cache;
Future<Set<String>>? _loading;

/// Loads and caches the Champions-legal move-name set (English keys,
/// matching `Move.name`). Re-returns the cache on later calls.
Future<Set<String>> loadChampionsMoves() {
  if (_cache != null) return Future.value(_cache!);
  return _loading ??= _doLoad();
}

Future<Set<String>> _doLoad() async {
  try {
    final jsonString =
        await rootBundle.loadString('assets/champions_moves.json');
    final raw = json.decode(jsonString) as Map<String, dynamic>;
    final moves = (raw['moves'] as List?)?.cast<String>() ?? const [];
    _cache = moves.toSet();
  } catch (_) {
    // Missing / malformed asset → empty set. Callers treat an empty
    // allowlist as "don't filter" (see [isChampionsMove]) so a bad
    // asset degrades to showing everything rather than hiding all
    // moves and stranding the user with empty pickers.
    _cache = <String>{};
  }
  return _cache!;
}

/// Fire-and-forget warmup — call from app startup so the first Move
/// Dex / selector render has the set in hand.
void preloadChampionsMoves() {
  loadChampionsMoves();
}

/// Whether [moveName] is legal in Champions. Returns `true` when the
/// cache hasn't loaded yet OR the allowlist is empty, so callers never
/// hide moves on the strength of missing data — the filter only ever
/// removes a move we can positively confirm is NOT in Champions.
bool isChampionsMove(String moveName) {
  final c = _cache;
  if (c == null || c.isEmpty) return true;
  return c.contains(moveName);
}
