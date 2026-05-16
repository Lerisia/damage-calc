import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/utils/champions_mode.dart';

void main() {
  group('ChampionsUsageEntry.defaultSp', () {
    test('parses the abbreviated SP keys into a Stats spread', () {
      final entry = ChampionsUsageEntry.fromJson({
        'defaultSp': {
          'hp': 2,
          'atk': 32,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 32,
        },
      });
      final sp = entry.defaultSp;
      expect(sp, isNotNull);
      expect(sp!.hp, equals(2));
      expect(sp.attack, equals(32));
      expect(sp.defense, equals(0));
      expect(sp.spAttack, equals(0));
      expect(sp.spDefense, equals(0));
      expect(sp.speed, equals(32));
    });

    test('is null when the entry has no defaultSp', () {
      final entry = ChampionsUsageEntry.fromJson({
        'abilities': [
          {'name': 'Rough Skin'},
        ],
      });
      expect(entry.defaultSp, isNull);
    });

    test('missing stat keys default to 0', () {
      final entry = ChampionsUsageEntry.fromJson({
        'defaultSp': {'atk': 32},
      });
      expect(entry.defaultSp!.attack, equals(32));
      expect(entry.defaultSp!.hp, equals(0));
      expect(entry.defaultSp!.speed, equals(0));
    });

    test('defaultSp converts to a legal EV spread via ChampionsMode', () {
      // 32 SP → 252 EV, 2 SP → 12 EV (8·2 − 4). A real in-game spread
      // must stay inside both the 66 SP cap and per-stat 32 SP cap.
      final entry = ChampionsUsageEntry.fromJson({
        'defaultSp': {
          'hp': 2,
          'atk': 32,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 32,
        },
      });
      final sp = entry.defaultSp!;
      expect(ChampionsMode.isValid(sp), isTrue);
      final ev = ChampionsMode.spToEvStats(sp);
      expect(ev.attack, equals(252));
      expect(ev.speed, equals(252));
      expect(ev.hp, equals(12));
      expect(ev.defense, equals(0));
    });
  });
}
