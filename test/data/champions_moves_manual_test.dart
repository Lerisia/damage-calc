import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Champions move allowlist is rebuilt daily from yakkun, which lags
/// the game when a species joins mid-season. fetch_champions_moves.py
/// unions MANUAL_ADDITIONS into its output; this pins that the asset
/// actually carries them, so a refresh that drops the union fails here
/// instead of silently hiding Pyro Ball from Cinderace.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signature moves of M-C entrants stay legal', () async {
    final raw = json.decode(
        await rootBundle.loadString('assets/champions_moves.json'));
    final legal = (raw['moves'] as List).cast<String>().toSet();
    for (final m in const [
      'Pyro Ball', 'Court Change', 'Drum Beating', 'Glaive Rush',
      'Meteor Assault', 'Octolock', 'Snipe Shot', 'Overdrive',
      'Zing Zap', 'Octazooka', 'Double Shock', 'Revival Blessing',
    ]) {
      expect(legal, contains(m));
    }
  });
}
