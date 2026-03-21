import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/item.dart';

Map<String, Item>? _cache;

/// Loads item data from assets/items.json (cached after first load).
Future<Map<String, Item>> loadItemdex() async {
  if (_cache != null) return _cache!;

  final jsonString = await rootBundle.loadString('assets/items.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

  _cache = {
    for (final entry in jsonList)
      (entry['name'] as String):
          Item.fromJson(entry as Map<String, dynamic>),
  };
  return _cache!;
}
