import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move_tags.dart';

/// Keeps MoveTags and assets/moves/*.json honest about which tags are
/// data flags, data-only flags, and runtime markers.
void main() {
  final constants = {
    for (final m in RegExp(r"static const String \w+ = '([^']+)';")
        .allMatches(File('lib/models/move_tags.dart').readAsStringSync()))
      m.group(1)!,
  };
  final dataTags = <String>{};
  for (final f in Directory('assets/moves').listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    for (final m in (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>()) {
      dataTags.addAll(((m['tags'] as List?) ?? const []).cast<String>());
    }
  }

  test('every tag in the move data has a MoveTags constant', () {
    expect(dataTags.difference(constants), isEmpty);
  });

  test('runtime markers never appear in the move data', () {
    expect(MoveTags.runtimeMarkers.intersection(dataTags), isEmpty);
  });

  test('data-only flags really are in the data', () {
    expect(MoveTags.dataOnly.difference(dataTags), isEmpty);
  });

  test('every other constant is used by some move (or is a documented marker)', () {
    final unused = constants
        .difference(dataTags)
        .difference(MoveTags.runtimeMarkers);
    // `custom:spread` is in the data too, so it never lands here.
    expect(unused, isEmpty, reason: 'constants nothing carries: $unused');
  });
}
