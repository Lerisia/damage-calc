import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/item.dart';

/// Loads item data from assets/items.json
Future<Map<String, Item>> loadItemdex() async {
  final jsonString = await rootBundle.loadString('assets/items.json');
  final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

  return {
    for (final entry in jsonList)
      (entry['name'] as String):
          Item.fromJson(entry as Map<String, dynamic>),
  };
}
