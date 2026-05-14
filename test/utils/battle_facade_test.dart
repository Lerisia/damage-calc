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

    test('Shell Side Arm: category flips to physical vs low-Def defender', () {
      final state = BattlePokemonState();
      state.moves[0] = const Move(
        name: 'Shell Side Arm', nameKo: '셸암즈', nameJa: 'シェルアームズ',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
        tags: [MoveTags.shellSideArm],
      );
      // Defender: Def 50, SpD 200 → physical side wins
      final info = BattleFacade.getMoveSlotInfo(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
        opponentDefense: 50,
        opponentSpDefense: 200,
      );
      expect(info.effectiveCategory, equals(MoveCategory.physical));
    });

    test('Shell Side Arm: category stays special vs low-SpD defender', () {
      final state = BattlePokemonState();
      state.moves[0] = const Move(
        name: 'Shell Side Arm', nameKo: '셸암즈', nameJa: 'シェルアームズ',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
        tags: [MoveTags.shellSideArm],
      );
      // Defender: Def 200, SpD 50 → special side wins
      final info = BattleFacade.getMoveSlotInfo(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
        opponentDefense: 200,
        opponentSpDefense: 50,
      );
      expect(info.effectiveCategory, equals(MoveCategory.special));
    });

    test('Shell Side Arm: no defender stats → stays at base special', () {
      final state = BattlePokemonState();
      state.moves[0] = const Move(
        name: 'Shell Side Arm', nameKo: '셸암즈', nameJa: 'シェルアームズ',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
        tags: [MoveTags.shellSideArm],
      );
      final info = BattleFacade.getMoveSlotInfo(
        state: state,
        moveIndex: 0,
        weather: Weather.none,
        terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(info.effectiveCategory, equals(MoveCategory.special));
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

    // Move-conditional bpMods (Knock Off ×1.5, Solar Beam/Blade ×0.5,
    // Grav Apple / Misty Explosion / Expanding Force ×1.5) aren't
    // baked into the printed BP — getMoveSlotInfo folds them into
    // effectivePower with the same 4096-fp rounding as the damage
    // calculator.
    group('move-conditional bpMods in effectivePower', () {
      const solarBeam = Move(
        name: 'Solar Beam', nameKo: '솔라빔', nameJa: 'ソーラービーム',
        type: PokemonType.grass, category: MoveCategory.special,
        power: 120, accuracy: 100, pp: 10, tags: [MoveTags.solarHalve],
      );
      const solarBlade = Move(
        name: 'Solar Blade', nameKo: '솔라블레이드', nameJa: 'ソーラーブレード',
        type: PokemonType.grass, category: MoveCategory.physical,
        power: 125, accuracy: 100, pp: 10, tags: [MoveTags.solarHalve],
      );
      const knockOff = Move(
        name: 'Knock Off', nameKo: '잡아던지기', nameJa: 'はたきおとす',
        type: PokemonType.dark, category: MoveCategory.physical,
        power: 65, accuracy: 100, pp: 20, tags: [MoveTags.knockOff],
      );
      const gravApple = Move(
        name: 'Grav Apple', nameKo: 'G의힘', nameJa: 'Ｇのちから',
        type: PokemonType.grass, category: MoveCategory.physical,
        power: 90, accuracy: 100, pp: 10, tags: [MoveTags.gravityBoost],
      );

      MoveSlotInfo slot(Move m, {
        Weather weather = Weather.none,
        Terrain terrain = Terrain.none,
        RoomConditions room = const RoomConditions(),
        String? opponentItem,
      }) {
        final state = BattlePokemonState();
        state.moves[0] = m;
        return BattleFacade.getMoveSlotInfo(
          state: state, moveIndex: 0,
          weather: weather, terrain: terrain, room: room,
          opponentItem: opponentItem,
        );
      }

      test('Solar Beam halved in rain (120 → 60)', () {
        expect(slot(solarBeam, weather: Weather.rain).effectivePower, 60);
      });
      test('Solar Beam unchanged in sun (120)', () {
        expect(slot(solarBeam, weather: Weather.sun).effectivePower, 120);
      });
      test('Solar Blade in rain uses chainmod rounding (125 → 63)', () {
        expect(slot(solarBlade, weather: Weather.rain).effectivePower, 63);
      });
      test('Knock Off ×1.5 vs target with removable item (65 → 98)', () {
        expect(slot(knockOff, opponentItem: 'leftovers').effectivePower, 98);
      });
      test('Knock Off unchanged vs target with no item (65)', () {
        expect(slot(knockOff).effectivePower, 65);
      });
      test('Knock Off unchanged vs target with unremovable item (65)', () {
        // Mega stones are unremovable by Knock Off.
        expect(slot(knockOff, opponentItem: 'charizardite-x').effectivePower, 65);
      });
      test('Grav Apple ×1.5 under Gravity (90 → 135)', () {
        expect(
          slot(gravApple, room: const RoomConditions(gravity: true))
              .effectivePower,
          135,
        );
      });
      test('Grav Apple unchanged without Gravity (90)', () {
        expect(slot(gravApple).effectivePower, 90);
      });

      test('결정력 reflects Solar Beam halving (rain < sun)', () {
        final state = BattlePokemonState();
        state.moves[0] = solarBeam;
        final sun = BattleFacade.calcOffensivePower(
          state: state, moveIndex: 0,
          weather: Weather.sun, terrain: Terrain.none,
          room: const RoomConditions());
        final rain = BattleFacade.calcOffensivePower(
          state: state, moveIndex: 0,
          weather: Weather.rain, terrain: Terrain.none,
          room: const RoomConditions());
        expect(sun, isNotNull);
        expect(rain, isNotNull);
        expect(rain!, lessThan(sun!));
      });
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

    // Regression: items that affect attacker output via the
    // atkStatModifier bucket (Choice Band) or the damageModifier
    // bucket (Life Orb) must show up in 결정력. They were silently
    // dropped at 9ecc8a3 / 044847b respectively when item effects
    // were re-split to match Showdown's chains.
    group('item effects in 결정력', () {
      const tackle = Move(
        name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 40, accuracy: 100, pp: 35,
      );
      int? power(BattlePokemonState s) => BattleFacade.calcOffensivePower(
        state: s, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none,
        room: const RoomConditions(),
      );
      test('Choice Band raises 결정력', () {
        final noItem = BattlePokemonState();
        noItem.moves[0] = tackle;
        final withCb = BattlePokemonState();
        withCb.moves[0] = tackle;
        withCb.selectedItem = 'choice-band';
        expect(power(withCb)!, greaterThan(power(noItem)!));
      });
      test('Life Orb raises 결정력', () {
        final noItem = BattlePokemonState();
        noItem.moves[0] = tackle;
        final withLo = BattlePokemonState();
        withLo.moves[0] = tackle;
        withLo.selectedItem = 'life-orb';
        expect(power(withLo)!, greaterThan(power(noItem)!));
      });
      test('Choice Specs raises 결정력 on special move', () {
        const ember = Move(
          name: 'Ember', nameKo: '불꽃세례', nameJa: 'ひのこ',
          type: PokemonType.fire, category: MoveCategory.special,
          power: 40, accuracy: 100, pp: 25,
        );
        final noItem = BattlePokemonState()..moves[0] = ember;
        final withCs = BattlePokemonState()
          ..moves[0] = ember
          ..selectedItem = 'choice-specs';
        expect(power(withCs)!, greaterThan(power(noItem)!));
      });
    });

    // notesOut: the 결정력 breakdown popup reads this list. Verify
    // every multiplier the calc applies produces exactly one note.
    group('결정력 breakdown notes', () {
      const tackle = Move(
        name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 40, accuracy: 100, pp: 35,
      );

      test('Choice Band emits an item note', () {
        final s = BattlePokemonState()
          ..moves[0] = tackle
          ..selectedItem = 'choice-band';
        final notes = <String>[];
        BattleFacade.calcOffensivePower(
          state: s, moveIndex: 0,
          weather: Weather.none, terrain: Terrain.none,
          room: const RoomConditions(),
          notesOut: notes,
        );
        expect(notes.any((n) => n.startsWith('item:choice-band:')), isTrue);
      });

      test('Life Orb emits an item note', () {
        final s = BattlePokemonState()
          ..moves[0] = tackle
          ..selectedItem = 'life-orb';
        final notes = <String>[];
        BattleFacade.calcOffensivePower(
          state: s, moveIndex: 0,
          weather: Weather.none, terrain: Terrain.none,
          room: const RoomConditions(),
          notesOut: notes,
        );
        expect(notes.any((n) => n.startsWith('item:life-orb:')), isTrue);
      });

      test('crit toggle emits crit note', () {
        final s = BattlePokemonState()
          ..moves[0] = tackle
          ..criticals = [true, false, false, false];
        final notes = <String>[];
        BattleFacade.calcOffensivePower(
          state: s, moveIndex: 0,
          weather: Weather.none, terrain: Terrain.none,
          room: const RoomConditions(),
          notesOut: notes,
        );
        expect(notes.any((n) => n.startsWith('crit:')), isTrue);
      });

      test('STAB on matching type emits stab note', () {
        // Default Bulbasaur is Grass/Poison — Tackle (Normal) is not
        // STAB. Use a Grass move to trigger.
        const vineWhip = Move(
          name: 'Vine Whip', nameKo: '덩굴채찍', nameJa: 'つるのムチ',
          type: PokemonType.grass, category: MoveCategory.physical,
          power: 45, accuracy: 100, pp: 25,
        );
        final s = BattlePokemonState()..moves[0] = vineWhip;
        final notes = <String>[];
        BattleFacade.calcOffensivePower(
          state: s, moveIndex: 0,
          weather: Weather.none, terrain: Terrain.none,
          room: const RoomConditions(),
          notesOut: notes,
        );
        expect(notes.any((n) => n.startsWith('stab:')), isTrue);
      });

      test('getMoveSlotInfo populates offensivePowerNotes', () {
        final s = BattlePokemonState()
          ..moves[0] = tackle
          ..selectedItem = 'choice-band';
        final info = BattleFacade.getMoveSlotInfo(
          state: s, moveIndex: 0,
          weather: Weather.none, terrain: Terrain.none,
          room: const RoomConditions(),
        );
        expect(info.offensivePowerNotes,
            contains(predicate<String>((n) => n.startsWith('item:choice-band:'))));
      });
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
