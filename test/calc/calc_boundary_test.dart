import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// lib/calc is the game-rules core: pure Dart, no Flutter. It is the
/// boundary a future `champ_calc` package would be cut along. The
/// handful of outward references that exist today are listed so any
/// new one has to be added here on purpose.
void main() {
  final files = Directory('lib/calc')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no calc module imports Flutter', () {
    for (final f in files) {
      final flutter = RegExp(r"^import 'package:flutter", multiLine: true)
          .allMatches(f.readAsStringSync());
      expect(flutter, isEmpty, reason: f.path);
    }
  });

  test('outward references (data loaders, i18n, controllers) stay on the known list', () {
    const known = {
      'damage_calculator.dart': {'../data/pokedex.dart'},
      'move_transform.dart': {'../data/fling_powers.dart'},
      'speed_tier.dart': {'../i18n/app_strings.dart'},
      'speed_tier_variants.dart': {
        '../data/abilitydex.dart', '../data/champions_usage.dart',
        '../data/pokedex.dart', '../i18n/app_strings.dart',
        '../controllers/champions_format_controller.dart',
      },
    };
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      final outward = RegExp(r"^import '(\.\./(?!models/)[^']+)'", multiLine: true)
          .allMatches(f.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(outward, known[name] ?? <String>{},
          reason: '$name reaches outside lib/calc (and lib/models) in a new way');
    }
  });
}
