import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A type is drawn by [TypeChip] and nothing else.
///
/// Design review (2026-10-02): the same information must look the same
/// everywhere. Before that the type's colour was read in twenty places
/// to hand-build chips, coloured text and dots, each a little
/// different. This guard fails when a new file reads a type colour
/// directly; the allowlist below is every legitimate non-chip use.
void main() {
  // file → why it may read a type colour itself.
  const allowed = <String, String>{
    'lib/views/widgets/type_chip.dart': 'the chip',
    'lib/views/widgets/type_picker_dialog.dart':
        'order badge on a picked option, in the option\'s colour',
    'lib/views/widgets/type_chart_sheet.dart':
        'axis cells of the 18×18 chart — table cells, not chips',
    'lib/views/widgets/damage_result_panel.dart':
        'damage card background tint',
    'lib/views/damage_calculator_screen.dart': 'damage card background tint',
    'lib/views/move_dex_screen.dart':
        'learner chips are Pokémon chips tinted by their types',
    'lib/views/team_coverage/coverage_matrix.dart':
        'column header tint behind a team member',
    'lib/views/team_coverage/slot_summary_card.dart':
        'move pill: a move name on its type colour',
    'lib/views/widgets/trainer_card_dialog.dart': 'card theme colours',
    'lib/views/simple_mode_screen.dart': 'Terastal icon colour',
  };

  test('no file outside the allowlist reads a type colour directly', () {
    final offenders = <String>[];
    final seen = <String>{};
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = f.path.replaceAll('\\', '/');
      if (path.startsWith('lib/i18n/')) continue; // the colour table
      final src = f.readAsStringSync();
      if (!src.contains('getTypeColor(') && !src.contains('KoStrings.typeColor')) {
        continue;
      }
      seen.add(path);
      if (!allowed.containsKey(path)) offenders.add(path);
    }
    expect(offenders, isEmpty,
        reason: 'show a type with TypeChip (lib/views/widgets/type_chip.dart) '
            'instead of building a coloured box or coloured text');
    // Keep the allowlist honest: an entry that no longer applies goes.
    expect(allowed.keys.where((p) => !seen.contains(p)), isEmpty,
        reason: 'stale allowlist entries');
  });

  test('a type name is not printed as bare text next to the calculator\'s chips',
      () {
    // The three screens the review called out showed the type as a
    // chip in one place and as text in another.
    for (final path in [
      'lib/views/widgets/pokemon_panel.dart',
      'lib/views/widgets/move_selector.dart',
      'lib/views/widgets/damage_result_panel.dart',
    ]) {
      expect(File(path).readAsStringSync().contains('getTypeName('), isFalse,
          reason: '$path should render types through TypeChip');
    }
  });
}
