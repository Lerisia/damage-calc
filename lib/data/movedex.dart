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

/// Loads all move data from assets/moves/gen*.json
Future<Map<String, Move>> loadMovedex() async {
  final Map<String, Move> movedex = {};

  for (final file in _genFiles) {
    final jsonString = await rootBundle.loadString(file);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    for (final entry in jsonList) {
      final move = Move.fromJson(entry as Map<String, dynamic>);
      movedex[move.name] = move;
    }
  }

  return movedex;
}
