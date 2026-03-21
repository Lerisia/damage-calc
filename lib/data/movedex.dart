import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/move.dart';

const _genFiles = [
  'assets/moves/gen1.json',
  'assets/moves/gen2.json',
  'assets/moves/gen3.json',
  'assets/moves/gen4.json',
  'assets/moves/gen5.json',
  'assets/moves/gen6.json',
  'assets/moves/gen7.json',
  'assets/moves/gen8.json',
  'assets/moves/gen9.json',
];

List<Move>? _cache;

/// Loads all moves as a list from assets/moves/gen*.json (cached after first load).
///
/// Returns a copy so callers can safely sort/filter without mutating the cache.
Future<List<Move>> loadAllMoves() async {
  if (_cache != null) return List.of(_cache!);

  final List<Move> moves = [];

  for (final file in _genFiles) {
    final jsonString = await rootBundle.loadString(file);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    for (final entry in jsonList) {
      moves.add(Move.fromJson(entry as Map<String, dynamic>));
    }
  }

  _cache = moves;
  return List.of(moves);
}

/// Loads all move data as a map (keyed by English name)
Future<Map<String, Move>> loadMovedex() async {
  final moves = await loadAllMoves();
  return {for (final m in moves) m.name: m};
}
