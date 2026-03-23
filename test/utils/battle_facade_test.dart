import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/utils/battle_facade.dart';

void main() {
  // ----------------------------------------------------------------
  // resolveEffectiveItem
  // ----------------------------------------------------------------
  group('resolveEffectiveItem', () {
    test('returns item normally', () {
      expect(resolveEffectiveItem(item: 'leftovers'), 'leftovers');
    });

    test('Klutz nullifies item', () {
      expect(
        resolveEffectiveItem(item: 'leftovers', ability: 'Klutz'),
        isNull,
      );
    });

    test('Dynamax nullifies choice items', () {
      expect(
        resolveEffectiveItem(item: 'choice-band', isDynamaxed: true),
        isNull,
      );
    });

    test('Dynamax keeps non-choice items', () {
      expect(
        resolveEffectiveItem(item: 'leftovers', isDynamaxed: true),
        'leftovers',
      );
    });

    test('null item returns null', () {
      expect(resolveEffectiveItem(item: null), isNull);
    });
  });

  // ----------------------------------------------------------------
  // resolveEffectiveAbility
  // ----------------------------------------------------------------
  group('resolveEffectiveAbility', () {
    test('returns ability normally', () {
      expect(resolveEffectiveAbility(ability: 'Intimidate'), 'Intimidate');
    });

    test('Dynamax nullifies Gorilla Tactics', () {
      expect(
        resolveEffectiveAbility(ability: 'Gorilla Tactics', isDynamaxed: true),
        isNull,
      );
    });

    test('Dynamax nullifies Sheer Force', () {
      expect(
        resolveEffectiveAbility(ability: 'Sheer Force', isDynamaxed: true),
        isNull,
      );
    });

    test('Dynamax keeps other abilities', () {
      expect(
        resolveEffectiveAbility(ability: 'Intimidate', isDynamaxed: true),
        'Intimidate',
      );
    });
  });

  // ----------------------------------------------------------------
  // effectiveWeight
  // ----------------------------------------------------------------
  group('effectiveWeight', () {
    test('base weight', () {
      final state = BattlePokemonState(); // weight 6.9
      expect(BattleFacade.effectiveWeight(state), 6.9);
    });

    test('Heavy Metal doubles weight', () {
      final state = BattlePokemonState(selectedAbility: 'Heavy Metal');
      expect(BattleFacade.effectiveWeight(state), 13.8);
    });

    test('Light Metal halves weight', () {
      final state = BattlePokemonState(selectedAbility: 'Light Metal');
      expect(BattleFacade.effectiveWeight(state), closeTo(3.45, 0.01));
    });

    test('Float Stone halves weight', () {
      final state = BattlePokemonState(selectedItem: 'float-stone');
      expect(BattleFacade.effectiveWeight(state), closeTo(3.45, 0.01));
    });
  });

  // ----------------------------------------------------------------
  // calcSpeed
  // ----------------------------------------------------------------
  group('calcSpeed', () {
    test('returns positive value for default Bulbasaur', () {
      final state = BattlePokemonState();
      final speed = BattleFacade.calcSpeed(
        state: state,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(speed, greaterThan(0));
    });

    test('paralysis reduces speed', () {
      final normal = BattlePokemonState();
      final paralyzed = BattlePokemonState(status: StatusCondition.paralysis);

      final speedNormal = BattleFacade.calcSpeed(
        state: normal,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      final speedPara = BattleFacade.calcSpeed(
        state: paralyzed,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(speedPara, lessThan(speedNormal));
    });

    test('tailwind boosts speed', () {
      final normal = BattlePokemonState();
      final tailwinded = BattlePokemonState(tailwind: true);

      final speedNormal = BattleFacade.calcSpeed(
        state: normal,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      final speedTailwind = BattleFacade.calcSpeed(
        state: tailwinded,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(speedTailwind, greaterThan(speedNormal));
    });
  });

  // ----------------------------------------------------------------
  // getMoveSlotInfo
  // ----------------------------------------------------------------
  group('getMoveSlotInfo', () {
    test('no move returns empty', () {
      final state = BattlePokemonState(); // moves all null
      final info = BattleFacade.getMoveSlotInfo(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(info.displayName, isNull);
    });

    test('with move returns info', () {
      final state = BattlePokemonState();
      state.moves[0] = const Move(
        name: 'Tackle',
        nameKo: '몸통박치기',
        nameJa: 'たいあたり',
        type: PokemonType.normal,
        category: MoveCategory.physical,
        power: 40,
        accuracy: 100,
        pp: 35,
      );
      final info = BattleFacade.getMoveSlotInfo(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(info.displayName, isNotNull);
      expect(info.effectiveType, isNotNull);
      expect(info.effectivePower, greaterThan(0));
    });

    test('fixed damage move detected', () {
      final state = BattlePokemonState();
      const nightShade = Move(
        name: 'Night Shade',
        nameKo: '나이트헤드',
        nameJa: 'ナイトヘッド',
        type: PokemonType.ghost,
        category: MoveCategory.special,
        power: 0,
        accuracy: 100,
        pp: 15,
        tags: [MoveTags.fixedLevel],
      );
      state.moves[0] = nightShade;
      final info = BattleFacade.getMoveSlotInfo(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(info.isFixedDamage, isTrue);
    });
  });

  // ----------------------------------------------------------------
  // calcOffensivePower
  // ----------------------------------------------------------------
  group('calcOffensivePower', () {
    test('returns null for empty slot', () {
      final state = BattlePokemonState(); // no moves
      final result = BattleFacade.calcOffensivePower(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(result, isNull);
    });

    test('returns positive for attacking move', () {
      final state = BattlePokemonState();
      state.moves[0] = const Move(
        name: 'Tackle',
        nameKo: '몸통박치기',
        nameJa: 'たいあたり',
        type: PokemonType.normal,
        category: MoveCategory.physical,
        power: 40,
        accuracy: 100,
        pp: 35,
      );
      final result = BattleFacade.calcOffensivePower(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(result, isNotNull);
      expect(result!, greaterThan(0));
    });

    test('STAB is higher than non-STAB', () {
      // Bulbasaur is grass/poison — poison move gets STAB
      final stateStab = BattlePokemonState();
      stateStab.moves[0] = const Move(
        name: 'Sludge Bomb',
        nameKo: '오물폭탄',
        nameJa: 'ヘドロばくだん',
        type: PokemonType.poison,
        category: MoveCategory.special,
        power: 90,
        accuracy: 100,
        pp: 10,
      );

      final stateNoStab = BattlePokemonState();
      stateNoStab.moves[0] = const Move(
        name: 'Flamethrower',
        nameKo: '화염방사',
        nameJa: 'かえんほうしゃ',
        type: PokemonType.fire,
        category: MoveCategory.special,
        power: 90,
        accuracy: 100,
        pp: 15,
      );

      final stabPower = BattleFacade.calcOffensivePower(
        state: stateStab,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      )!;

      final noStabPower = BattleFacade.calcOffensivePower(
        state: stateNoStab,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      )!;

      expect(stabPower, greaterThan(noStabPower));
    });
  });

  // ----------------------------------------------------------------
  // calcBulk
  // ----------------------------------------------------------------
  group('calcBulk', () {
    test('returns positive physical and special bulk', () {
      final state = BattlePokemonState();
      final bulk = BattleFacade.calcBulk(
        state: state,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(bulk.physical, greaterThan(0));
      expect(bulk.special, greaterThan(0));
    });
  });
}
