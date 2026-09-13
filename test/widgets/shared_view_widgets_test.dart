import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/nature_profile.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/i18n/app_strings.dart';
import 'package:damage_calc/controllers/champions_filter_controller.dart';
import 'package:damage_calc/views/widgets/champions_scope_listener.dart';
import 'package:damage_calc/views/widgets/nature_pick_menu.dart';
import 'package:damage_calc/views/widgets/type_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The small view pieces that used to be copy-pasted per screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NaturePickMenu', () {
    testWidgets('picking a stat emits the updated profile; "none" clears it', (tester) async {
      NatureProfile? got;
      Widget host(NatureProfile n) => MaterialApp(
          home: Scaffold(body: NaturePickMenu(nature: n, isUp: true, onNatureChanged: (v) => got = v)));
      await tester.pumpWidget(host(NatureProfile.neutral));
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text(natureStatLabel(NatureStat.spa)).last);
      await tester.pumpAndSettle();
      expect(got?.up, NatureStat.spa);

      await tester.pumpWidget(host(got!));
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.t('nature.none')).last);
      await tester.pumpAndSettle();
      expect(got?.up, isNull);
    });
  });

  group('TypeChip', () {
    testWidgets('renders the localized type name', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TypeChip(PokemonType.fire))));
      expect(find.text('불꽃'), findsOneWidget);
    });
  });

  group('ChampionsScopeListener', () {
    testWidgets('host rebuilds when the scope flips', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await ChampionsFilterController.instance.load();
      await tester.pumpWidget(const MaterialApp(home: _Host()));
      expect(find.text('builds: 1'), findsOneWidget);
      await ChampionsFilterController.instance.set(false);
      await tester.pump();
      expect(find.text('builds: 2'), findsOneWidget);
      await ChampionsFilterController.instance.set(true);
    });
  });
}

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with ChampionsScopeListener {
  int builds = 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    return Scaffold(body: Text('builds: $builds'));
  }
}
