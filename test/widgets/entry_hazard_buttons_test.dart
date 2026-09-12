import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/entry_hazards.dart';
import 'package:damage_calc/views/widgets/entry_hazard_buttons.dart';

/// The shared 스록 / 압정 mini-buttons: Stealth Rock is a single shot,
/// Spikes counts up to three layers and reports each tap.
void main() {
  Widget host({required bool sr, required int layers, required ValueChanged<EntryHazard> onTap}) =>
      MaterialApp(home: Scaffold(body: EntryHazardButtons(
          stealthRockApplied: sr, spikesLayers: layers, onTap: onTap)));

  testWidgets('taps report their hazard', (tester) async {
    final taps = <EntryHazard>[];
    await tester.pumpWidget(host(sr: false, layers: 0, onTap: taps.add));
    await tester.tap(find.text('스록'));
    await tester.tap(find.text('압정'));
    expect(taps, [EntryHazard.stealthRock, EntryHazard.spikes]);
  });

  testWidgets('Stealth Rock disables once applied', (tester) async {
    final taps = <EntryHazard>[];
    await tester.pumpWidget(host(sr: true, layers: 0, onTap: taps.add));
    await tester.tap(find.text('스록'), warnIfMissed: false);
    expect(taps, isEmpty);
  });

  testWidgets('Spikes shows the layer count and stops at three', (tester) async {
    final taps = <EntryHazard>[];
    await tester.pumpWidget(host(sr: false, layers: 2, onTap: taps.add));
    expect(find.text('압정 2'), findsOneWidget);
    await tester.pumpWidget(host(sr: false, layers: 3, onTap: taps.add));
    await tester.tap(find.text('압정 3'), warnIfMissed: false);
    expect(taps, isEmpty);
  });
}
