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
Map<String, Move>? _byName;
Future<List<Move>>? _loading;

/// Loads all moves as a list from assets/moves/gen*.json (cached after first load).
/// Uses parallel loading for faster startup.
Future<List<Move>> loadAllMoves() {
  if (_cache != null) return Future.value(List.of(_cache!));
  return (_loading ??= _doLoad()).then((_) => List.of(_cache!));
}

Future<List<Move>> _doLoad() async {
  final futures = _genFiles.map((file) async {
    final jsonString = await rootBundle.loadString(file);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList.map((e) => Move.fromJson(e as Map<String, dynamic>)).toList();
  });

  final results = await Future.wait(futures);
  _cache = results.expand((list) => list).toList();
  _byName = {for (final m in _cache!) m.name: m};
  return _cache!;
}

/// Loads all move data as a map (keyed by English name)
Future<Map<String, Move>> loadMovedex() async {
  final moves = await loadAllMoves();
  return {for (final m in moves) m.name: m};
}

/// Sync lookup by English move name. Returns `null` before the
/// movedex cache is populated or for unknown names.
Move? findMoveByName(String name) => _byName?[name];
