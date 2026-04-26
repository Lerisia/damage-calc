import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/stacking_moves.dart';

/// Test fixtures matching the in-game moves we currently treat as
/// "stacking-power" (single-hit attacks whose raw power scales by a
/// runtime counter — fainted allies for Last Respects, hits taken for
/// Rage Fist). Power=50 for both, matching the assets/moves data.
const _lastRespects = Move(
  name: 'Last Respects',
  nameKo: '성묘',
  nameJa: 'おはかまいり',
  type: PokemonType.ghost,
  category: MoveCategory.physical,
  power: 50,
  accuracy: 100,
  pp: 10,
);

const _rageFist = Move(
  name: 'Rage Fist',
  nameKo: '분노의주먹',
  nameJa: 'ふんどのこぶし',
  type: PokemonType.ghost,
  category: MoveCategory.physical,
  power: 50,
  accuracy: 100,
  pp: 10,
);

const _earthquake = Move(
  name: 'Earthquake',
  nameKo: '지진',
  nameJa: 'じしん',
  type: PokemonType.ground,
  category: MoveCategory.physical,
  power: 100,
  accuracy: 100,
  pp: 10,
);

void main() {
  group('isStackingPower / stackingMax', () {
    test('Last Respects stacks up to ×5 (4 fainted allies + base)', () {
      expect(isStackingPower(_lastRespects), isTrue);
      expect(stackingMax(_lastRespects), equals(5));
    });

    test('Rage Fist stacks up to ×7 (6 hits taken + base)', () {
      expect(isStackingPower(_rageFist), isTrue);
      expect(stackingMax(_rageFist), equals(7));
    });

    test('non-stacking move returns null max and false', () {
      expect(isStackingPower(_earthquake), isFalse);
      expect(stackingMax(_earthquake), isNull);
    });
  });

  group('stackingPower', () {
    test('Last Respects scales linearly: 50, 100, 150, 200, 250', () {
      expect(stackingPower(_lastRespects, 1), equals(50));
      expect(stackingPower(_lastRespects, 2), equals(100));
      expect(stackingPower(_lastRespects, 3), equals(150));
      expect(stackingPower(_lastRespects, 4), equals(200));
      expect(stackingPower(_lastRespects, 5), equals(250));
    });

    test('Rage Fist scales linearly: 50, 100, ..., 350', () {
      expect(stackingPower(_rageFist, 1), equals(50));
      expect(stackingPower(_rageFist, 4), equals(200));
      expect(stackingPower(_rageFist, 7), equals(350));
    });

    test('non-stacking move ignores tier and returns base power', () {
      expect(stackingPower(_earthquake, 3), equals(100));
      expect(stackingPower(_earthquake, 5), equals(100));
    });
  });

  group('stackingDefaultTier', () {
    test('Last Respects defaults to ×3 (two fainted allies)', () {
      // The dex/attacker/simple panels seed this on species pick so
      // the displayed power matches a realistic mid-game scenario
      // rather than the lone-survivor ×1 baseline.
      expect(stackingDefaultTier(_lastRespects), equals(3));
    });

    test('Rage Fist defaults to ×1 (no hits taken yet)', () {
      expect(stackingDefaultTier(_rageFist), equals(1));
    });

    test('non-stacking move defaults to ×1', () {
      expect(stackingDefaultTier(_earthquake), equals(1));
    });
  });

  group('currentStackingTier', () {
    test('non-stacking move always returns 1', () {
      expect(currentStackingTier(_earthquake, 250), equals(1));
      expect(currentStackingTier(_earthquake, null), equals(1));
    });

    test('null override falls back to stackingDefaultTier', () {
      expect(currentStackingTier(_lastRespects, null), equals(3));
      expect(currentStackingTier(_rageFist, null), equals(1));
    });

    test('clean multiples decode back to the original tier', () {
      // 50 * 4 = 200 → tier 4
      expect(currentStackingTier(_lastRespects, 200), equals(4));
      expect(currentStackingTier(_rageFist, 350), equals(7));
    });

    test('off-multiple values round to the nearest legal tier', () {
      // User typed an arbitrary power → snap to nearest tier so the
      // chip stays in sync with the numeric input.
      expect(currentStackingTier(_lastRespects, 175), equals(4));
      expect(currentStackingTier(_lastRespects, 120), equals(2));
    });

    test('values above the cap clamp to stackingMax', () {
      expect(currentStackingTier(_lastRespects, 999), equals(5));
      expect(currentStackingTier(_rageFist, 999), equals(7));
    });

    test('values below 1 clamp up to 1', () {
      expect(currentStackingTier(_lastRespects, 0), equals(1));
      expect(currentStackingTier(_lastRespects, -50), equals(1));
    });
  });
}
