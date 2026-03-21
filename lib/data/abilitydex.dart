import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/ability.dart';

Map<String, Ability>? _cache;

/// Loads ability data from assets/abilities.json (cached after first load).
Future<Map<String, Ability>> loadAbilitydex() async {
  if (_cache != null) return _cache!;

  final jsonString = await rootBundle.loadString('assets/abilities.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

  _cache = {
    for (final entry in jsonList)
      (entry['name'] as String):
          Ability.fromJson(entry as Map<String, dynamic>),
  };
  return _cache!;
}
