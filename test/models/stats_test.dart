import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/stats.dart';

void main() {
  group('Stats', () {
    test('fromJson parses all fields', () {
      final stats = Stats.fromJson({
        'hp': 100, 'attack': 130, 'defense': 80,
        'spAttack': 60, 'spDefense': 70, 'speed': 120,
      });
      expect(stats.hp, equals(100));
      expect(stats.attack, equals(130));
      expect(stats.defense, equals(80));
      expect(stats.spAttack, equals(60));
      expect(stats.spDefense, equals(70));
      expect(stats.speed, equals(120));
    });
  });
}
