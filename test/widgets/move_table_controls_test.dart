import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/views/widgets/move_table_controls.dart';

/// The sort/filter controls the Pokédex learnset table and the Move Dex
/// share (they used to carry a copy each).
void main() {
  const a = Move(name: 'Aura Sphere', nameKo: '파동탄', nameJa: 'はどうだん',
      type: PokemonType.fighting, category: MoveCategory.special, power: 80, accuracy: 0, pp: 20);
  const b = Move(name: 'Body Slam', nameKo: '누르기', nameJa: 'のしかかり',
      type: PokemonType.normal, category: MoveCategory.physical, power: 85, accuracy: 100, pp: 15);
  const c = Move(name: 'Crunch', nameKo: '깨물어부수기', nameJa: 'かみくだく',
      type: PokemonType.dark, category: MoveCategory.physical, power: 80, accuracy: 100, pp: 15);

  group('compareMoves', () {
    test('sorts by the key, ties broken by name, direction honoured', () {
      final desc = [a, b, c]..sort((x, y) => compareMoves(x, y, MoveSortKey.power, asc: false));
      expect(desc.first.name, 'Body Slam'); // 85 leads the two 80s
      final asc = [a, b, c]..sort((x, y) => compareMoves(x, y, MoveSortKey.power, asc: true));
      expect(asc.last.name, 'Body Slam');
      // Equal power → ordered by localized name (the whole comparison
      // is then reversed for descending, as the screens always did).
      expect(desc.sublist(1).map((m) => m.name), asc.sublist(0, 2).reversed.map((m) => m.name));
      final byName = [c, b, a]..sort((x, y) => compareMoves(x, y, MoveSortKey.name, asc: true));
      expect(byName.map((m) => m.localizedName).toList(),
          [a, b, c].map((m) => m.localizedName).toList()..sort());
    });
    test('defaults: text ascends, numbers descend', () {
      expect(moveSortDefaultAsc(MoveSortKey.name), isTrue);
      expect(moveSortDefaultAsc(MoveSortKey.power), isFalse);
      expect(moveSortDefaultAsc(MoveSortKey.accuracy), isFalse);
    });
  });

  group('MoveSortHeader', () {
    testWidgets('marks the active column with an arrow and reports taps', (tester) async {
      MoveSortKey? tapped;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: MoveSortHeader(
          sortKey: MoveSortKey.power, asc: false, onTap: (k) => tapped = k))));
      expect(find.textContaining('↓'), findsOneWidget);
      await tester.tap(find.textContaining('↓'));
      expect(tapped, MoveSortKey.power);
    });
    testWidgets('hides the arrow when asked (search overrides sort)', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: MoveSortHeader(
          sortKey: MoveSortKey.power, asc: false, showArrow: false, onTap: (_) {}))));
      expect(find.textContaining('↓'), findsNothing);
    });
  });

  group('CategoryFilterChip', () {
    testWidgets('offers only the available categories and emits picks', (tester) async {
      MoveCategory? picked = MoveCategory.status;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CategoryFilterChip(
          value: null,
          available: const {MoveCategory.physical},
          onChanged: (v) => picked = v))));
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.text(CategoryFilterChip.label(MoveCategory.special)), findsNothing);
      await tester.tap(find.text(CategoryFilterChip.label(MoveCategory.physical)).last);
      await tester.pumpAndSettle();
      expect(picked, MoveCategory.physical);
    });
  });
}
