import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/move.dart';

const _typeFiles = [
  'assets/moves/normal.json',
  'assets/moves/fire.json',
  'assets/moves/water.json',
  'assets/moves/electric.json',
  'assets/moves/grass.json',
  'assets/moves/ice.json',
  'assets/moves/fighting.json',
  'assets/moves/poison.json',
  'assets/moves/ground.json',
  'assets/moves/flying.json',
  'assets/moves/psychic.json',
  'assets/moves/bug.json',
  'assets/moves/rock.json',
  'assets/moves/ghost.json',
  'assets/moves/dragon.json',
  'assets/moves/dark.json',
  'assets/moves/steel.json',
  'assets/moves/fairy.json',
];

/// Loads all move data from assets/moves/<type>.json
Future<Map<String, Move>> loadMovedex() async {
  final Map<String, Move> movedex = {};

  for (final file in _typeFiles) {
    final jsonString = await rootBundle.loadString(file);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    for (final entry in jsonList) {
      final move = Move.fromJson(entry as Map<String, dynamic>);
      movedex[move.name] = move;
    }
  }

  return movedex;
}
