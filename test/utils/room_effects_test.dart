import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/utils/room_effects.dart';

void main() {
  group('compareSpeed', () {
    test('faster speed wins normally', () {
      final result = compareSpeed(
        mySpeed: 120, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
      );
      expect(result, greaterThan(0));
    });

    test('slower speed loses normally', () {
      final result = compareSpeed(
        mySpeed: 80, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
      );
      expect(result, lessThan(0));
    });

    test('same speed is tied', () {
      final result = compareSpeed(
        mySpeed: 100, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
      );
      expect(result, equals(0));
    });

    test('Trick Room reverses: slower wins', () {
      final result = compareSpeed(
        mySpeed: 80, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
        room: Room.trickRoom,
      );
      expect(result, greaterThan(0));
    });

    test('Trick Room reverses: faster loses', () {
      final result = compareSpeed(
        mySpeed: 120, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
        room: Room.trickRoom,
      );
      expect(result, lessThan(0));
    });

    test('Trick Room: same speed still tied', () {
      final result = compareSpeed(
        mySpeed: 100, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
        room: Room.trickRoom,
      );
      expect(result, equals(0));
    });

    test('alwaysLast loses regardless of speed', () {
      final result = compareSpeed(
        mySpeed: 200, opponentSpeed: 50,
        myAlwaysLast: true, opponentAlwaysLast: false,
      );
      expect(result, lessThan(0));
    });

    test('alwaysLast loses even in Trick Room', () {
      final result = compareSpeed(
        mySpeed: 200, opponentSpeed: 50,
        myAlwaysLast: true, opponentAlwaysLast: false,
        room: Room.trickRoom,
      );
      expect(result, lessThan(0));
    });

    test('opponent alwaysLast means I win', () {
      final result = compareSpeed(
        mySpeed: 50, opponentSpeed: 200,
        myAlwaysLast: false, opponentAlwaysLast: true,
      );
      expect(result, greaterThan(0));
    });

    test('opponent alwaysLast wins even in Trick Room', () {
      final result = compareSpeed(
        mySpeed: 50, opponentSpeed: 200,
        myAlwaysLast: false, opponentAlwaysLast: true,
        room: Room.trickRoom,
      );
      expect(result, greaterThan(0));
    });

    test('both alwaysLast: falls back to normal speed comparison', () {
      final result = compareSpeed(
        mySpeed: 120, opponentSpeed: 100,
        myAlwaysLast: true, opponentAlwaysLast: true,
      );
      expect(result, greaterThan(0));
    });

    test('both alwaysLast in Trick Room: reversed comparison', () {
      final result = compareSpeed(
        mySpeed: 120, opponentSpeed: 100,
        myAlwaysLast: true, opponentAlwaysLast: true,
        room: Room.trickRoom,
      );
      expect(result, lessThan(0));
    });
  });

  group('getSpeedResult', () {
    test('faster returns SpeedResult.faster', () {
      expect(getSpeedResult(
        mySpeed: 120, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
      ), equals(SpeedResult.faster));
    });

    test('slower returns SpeedResult.slower', () {
      expect(getSpeedResult(
        mySpeed: 80, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
      ), equals(SpeedResult.slower));
    });

    test('tied returns SpeedResult.tied', () {
      expect(getSpeedResult(
        mySpeed: 100, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
      ), equals(SpeedResult.tied));
    });

    test('Trick Room: slower becomes faster', () {
      expect(getSpeedResult(
        mySpeed: 80, opponentSpeed: 100,
        myAlwaysLast: false, opponentAlwaysLast: false,
        room: Room.trickRoom,
      ), equals(SpeedResult.faster));
    });

    test('alwaysLast returns SpeedResult.alwaysLast', () {
      expect(getSpeedResult(
        mySpeed: 200, opponentSpeed: 50,
        myAlwaysLast: true, opponentAlwaysLast: false,
      ), equals(SpeedResult.alwaysLast));
    });

    test('alwaysLast unaffected by Trick Room', () {
      expect(getSpeedResult(
        mySpeed: 200, opponentSpeed: 50,
        myAlwaysLast: true, opponentAlwaysLast: false,
        room: Room.trickRoom,
      ), equals(SpeedResult.alwaysLast));
    });

    test('opponent alwaysLast returns SpeedResult.alwaysFirst', () {
      expect(getSpeedResult(
        mySpeed: 50, opponentSpeed: 200,
        myAlwaysLast: false, opponentAlwaysLast: true,
      ), equals(SpeedResult.alwaysFirst));
    });

    test('both alwaysLast: normal comparison applies', () {
      expect(getSpeedResult(
        mySpeed: 120, opponentSpeed: 100,
        myAlwaysLast: true, opponentAlwaysLast: true,
      ), equals(SpeedResult.faster));
    });
  });
}
