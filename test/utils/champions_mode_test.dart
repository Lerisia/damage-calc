import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/nature.dart';
import 'package:damage_calc/utils/champions_mode.dart';
import 'package:damage_calc/utils/stat_calculator.dart';

void main() {
  group('SP → EV conversion', () {
    test('0 SP → 0 EV', () {
      expect(ChampionsMode.spToEv(0), equals(0));
    });

    test('1 SP → 4 EV', () {
      expect(ChampionsMode.spToEv(1), equals(4));
    });

    test('2 SP → 12 EV', () {
      expect(ChampionsMode.spToEv(2), equals(12));
    });

    test('32 SP → 252 EV', () {
      expect(ChampionsMode.spToEv(32), equals(252));
    });
  });

  group('EV → SP conversion', () {
    test('0 EV → 0 SP', () {
      expect(ChampionsMode.evToSp(0), equals(0));
    });

    test('4 EV → 1 SP', () {
      expect(ChampionsMode.evToSp(4), equals(1));
    });

    test('8 EV → 1 SP (same stat as 4 EV at Lv50)', () {
      expect(ChampionsMode.evToSp(8), equals(1));
    });

    test('12 EV → 2 SP', () {
      expect(ChampionsMode.evToSp(12), equals(2));
    });

    test('252 EV → 32 SP', () {
      expect(ChampionsMode.evToSp(252), equals(32));
    });

    test('sub-4 EV rounds to 1 SP if any investment', () {
      expect(ChampionsMode.evToSp(1), equals(1));
      expect(ChampionsMode.evToSp(3), equals(1));
    });
  });

  group('Round-trip SP → EV → SP', () {
    test('all SP values round-trip correctly', () {
      for (int sp = 0; sp <= 32; sp++) {
        final ev = ChampionsMode.spToEv(sp);
        final back = ChampionsMode.evToSp(ev);
        expect(back, equals(sp), reason: 'sp=$sp → ev=$ev → back=$back');
      }
    });

    test('full spread round-trips', () {
      const sp = Stats(hp: 4, attack: 32, defense: 0, spAttack: 16, spDefense: 6, speed: 8);
      final ev = ChampionsMode.spToEvStats(sp);
      final backToSp = ChampionsMode.evToSpStats(ev);
      expect(backToSp.hp, equals(sp.hp));
      expect(backToSp.attack, equals(sp.attack));
      expect(backToSp.defense, equals(sp.defense));
      expect(backToSp.spAttack, equals(sp.spAttack));
      expect(backToSp.spDefense, equals(sp.spDefense));
      expect(backToSp.speed, equals(sp.speed));
    });
  });

  group('Validation', () {
    test('valid spread passes', () {
      const sp = Stats(hp: 4, attack: 32, defense: 0, spAttack: 16, spDefense: 6, speed: 8);
      expect(ChampionsMode.isValid(sp), isTrue);
      expect(ChampionsMode.totalSp(sp), equals(66));
      expect(ChampionsMode.remaining(sp), equals(0));
    });

    test('exceeding total fails', () {
      const sp = Stats(hp: 32, attack: 32, defense: 3, spAttack: 0, spDefense: 0, speed: 0);
      expect(ChampionsMode.isValid(sp), isFalse);
    });

    test('exceeding per-stat cap fails', () {
      const sp = Stats(hp: 33, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);
      expect(ChampionsMode.isValid(sp), isFalse);
    });

    test('remaining calculates correctly', () {
      const sp = Stats(hp: 10, attack: 10, defense: 0, spAttack: 0, spDefense: 0, speed: 0);
      expect(ChampionsMode.remaining(sp), equals(46));
    });
  });

  group('EV-based total/remaining', () {
    test('252+252+4 EV = 65 SP used, 1 remaining', () {
      const ev = Stats(hp: 252, attack: 252, defense: 4, spAttack: 0, spDefense: 0, speed: 0);
      expect(ChampionsMode.totalSpFromEv(ev), equals(65));
      expect(ChampionsMode.remainingFromEv(ev), equals(1));
    });

    test('total is not simply EV sum / 8', () {
      const ev = Stats(hp: 252, attack: 252, defense: 4, spAttack: 0, spDefense: 0, speed: 0);
      final evTotal = ev.hp + ev.attack + ev.defense;
      // Naive: 508 / 8 = 63 (wrong)
      expect(evTotal ~/ 8, equals(63));
      // Correct: per-stat conversion
      expect(ChampionsMode.totalSpFromEv(ev), equals(65));
    });

    test('all zero EV = 0 SP', () {
      const ev = Stats(hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);
      expect(ChampionsMode.totalSpFromEv(ev), equals(0));
      expect(ChampionsMode.remainingFromEv(ev), equals(66));
    });
  });

  group('Stat equivalence', () {
    test('SP-converted EV gives same stat as original EV at Lv50', () {
      // 252 EV and spToEv(32)=252 EV should give same stat
      for (int base = 50; base <= 150; base++) {
        final baseStats = Stats(
          hp: base, attack: base, defense: base,
          spAttack: base, spDefense: base, speed: base,
        );
        // Traditional 252 EV
        final traditional = StatCalculator.calculate(
          baseStats: baseStats,
          iv: ChampionsMode.fixedIv,
          ev: const Stats(hp: 0, attack: 252, defense: 0, spAttack: 0, spDefense: 0, speed: 0),
          nature: Nature.hardy,
          level: ChampionsMode.level,
        );
        // Champions 32 SP = 252 EV
        final champions = StatCalculator.calculate(
          baseStats: baseStats,
          iv: ChampionsMode.fixedIv,
          ev: Stats(hp: 0, attack: ChampionsMode.spToEv(32), defense: 0, spAttack: 0, spDefense: 0, speed: 0),
          nature: Nature.hardy,
          level: ChampionsMode.level,
        );
        expect(champions.attack, equals(traditional.attack),
          reason: 'base=$base: 32 SP should equal 252 EV');
      }
    });

    test('each SP gives exactly +1 stat at Lv50', () {
      for (int base = 50; base <= 150; base++) {
        final baseStats = Stats(
          hp: base, attack: base, defense: base,
          spAttack: base, spDefense: base, speed: base,
        );
        final resultZero = StatCalculator.calculate(
          baseStats: baseStats,
          iv: ChampionsMode.fixedIv,
          ev: const Stats(hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0),
          nature: Nature.hardy,
          level: ChampionsMode.level,
        );
        for (int sp = 1; sp <= 3; sp++) {
          final result = StatCalculator.calculate(
            baseStats: baseStats,
            iv: ChampionsMode.fixedIv,
            ev: Stats(hp: 0, attack: ChampionsMode.spToEv(sp), defense: 0, spAttack: 0, spDefense: 0, speed: 0),
            nature: Nature.hardy,
            level: ChampionsMode.level,
          );
          expect(result.attack - resultZero.attack, equals(sp),
            reason: 'base=$base, sp=$sp');
        }
      }
    });
  });
}
