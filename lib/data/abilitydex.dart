import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/ability.dart';

/// Loads ability data from assets/abilities.json
Future<Map<String, Ability>> loadAbilitydex() async {
  final jsonString = await rootBundle.loadString('assets/abilities.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

  return {
    for (final entry in jsonList)
      (entry['name'] as String):
          Ability.fromJson(entry as Map<String, dynamic>),
  };
}
