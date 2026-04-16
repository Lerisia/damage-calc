import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/dynamax.dart';
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/utils/damage_calculator.dart';

void main() {
  // Reusable moves
  const tackle = Move(
    name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
    type: PokemonType.normal, category: MoveCategory.physical,
    power: 40, accuracy: 100, pp: 35, tags: [MoveTags.contact],
  );

  const ember = Move(
    name: 'Ember', nameKo: '불꽃세례', nameJa: 'ひのこ',
    type: PokemonType.fire, category: MoveCategory.special,
    power: 40, accuracy: 100, pp: 25,
  );

  const sludgeBomb = Move(
    name: 'Sludge Bomb', nameKo: '오물폭탄', nameJa: 'ヘドロばくだん',
    type: PokemonType.poison, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10,
  );

  // Helper
  DamageResult calc({
    Move move = tackle,
    PokemonType atkType1 = PokemonType.grass,
    PokemonType? atkType2 = PokemonType.poison,
    String? atkAbility = 'Overgrow',
    String? atkItem,
    StatusCondition atkStatus = StatusCondition.none,
    bool critical = false,
    bool charge = false,
    Rank atkRank = const Rank(),
    int atkHpPercent = 100,
    PokemonType defType1 = PokemonType.grass,
    PokemonType? defType2 = PokemonType.poison,
    String? defAbility = 'Overgrow',
    String? defItem,
    StatusCondition defStatus = StatusCondition.none,
    int defHpPercent = 100,
    bool reflect = false,
    bool lightScreen = false,
    DynamaxState defDynamax = DynamaxState.none,
    Weather weather = Weather.none,
    Terrain terrain = Terrain.none,
    RoomConditions room = const RoomConditions(),
    TerastalState atkTerastal = const TerastalState(),
  }) {
    final atk = BattlePokemonState(
      type1: atkType1, type2: atkType2,
      selectedAbility: atkAbility, selectedItem: atkItem,
      status: atkStatus, charge: charge, rank: atkRank,
      hpPercent: atkHpPercent,
      moves: [move, null, null, null],
      criticals: [critical, false, false, false],
      terastal: atkTerastal,
    );
    final def = BattlePokemonState(
      type1: defType1, type2: defType2,
      selectedAbility: defAbility, selectedItem: defItem,
      status: defStatus, hpPercent: defHpPercent,
      reflect: reflect, lightScreen: lightScreen,
      dynamax: defDynamax,
    );
    return DamageCalculator.calculate(
      attacker: atk, defender: def, moveIndex: 0,
      weather: weather, terrain: terrain, room: room,
    );
  }

  group('Basic damage', () {
    test('physical move deals positive damage', () {
      final result = calc();
      expect(result.maxDamage, greaterThan(0));
    });

    test('special move deals positive damage', () {
      final result = calc(move: ember);
      expect(result.maxDamage, greaterThan(0));
    });

    test('status move returns empty', () {
      const statusMove = Move(
        name: 'Growl', nameKo: '울음소리', nameJa: 'なきごえ',
        type: PokemonType.normal, category: MoveCategory.status,
        power: 0, accuracy: 100, pp: 40,
      );
      final result = calc(move: statusMove);
      expect(result.isEmpty, isTrue);
    });

    test('no move returns empty', () {
      final atk = BattlePokemonState();
      final def = BattlePokemonState();
      final result = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(result.isEmpty, isTrue);
    });
  });

  group('Type effectiveness', () {
    test('super effective (fire vs grass)', () {
      final result = calc(
        move: ember,
        defType1: PokemonType.grass, defType2: null,
      );
      expect(result.effectiveness, equals(2.0));
    });

    test('not very effective (fire vs water)', () {
      final result = calc(
        move: ember,
        defType1: PokemonType.water, defType2: null,
      );
      expect(result.effectiveness, equals(0.5));
    });

    test('immune (normal vs ghost)', () {
      final result = calc(
        move: tackle,
        defType1: PokemonType.ghost, defType2: null,
      );
      expect(result.effectiveness, equals(0.0));
      expect(result.maxDamage, equals(0));
    });

    test('neutral effectiveness', () {
      final result = calc(
        move: tackle,
        defType1: PokemonType.normal, defType2: null,
      );
      expect(result.effectiveness, equals(1.0));
    });
  });

  group('STAB', () {
    test('STAB move deals more damage than non-STAB', () {
      // sludgeBomb is poison type, attacker is grass/poison -> STAB
      final stab = calc(
        move: sludgeBomb,
        defType1: PokemonType.fire, defType2: null,
      );
      // ember is fire type, attacker is grass/poison -> no STAB
      final noStab = calc(
        move: ember,
        defType1: PokemonType.fire, defType2: null,
      );
      // sludgeBomb has higher base power (90 vs 40) AND STAB,
      // so it should deal more damage
      expect(stab.maxDamage, greaterThan(noStab.maxDamage));
    });
  });

  group('Critical hit', () {
    test('critical increases damage', () {
      final noCrit = calc(critical: false);
      final crit = calc(critical: true);
      expect(crit.maxDamage, greaterThan(noCrit.maxDamage));
    });
  });

  group('Weather', () {
    test('sun boosts fire moves', () {
      final noWeather = calc(
        move: ember,
        defType1: PokemonType.normal, defType2: null,
      );
      final sun = calc(
        move: ember,
        defType1: PokemonType.normal, defType2: null,
        weather: Weather.sun,
      );
      expect(sun.maxDamage, greaterThan(noWeather.maxDamage));
    });

    test('rain boosts water moves', () {
      const waterGun = Move(
        name: 'Water Gun', nameKo: '물대포', nameJa: 'みずでっぽう',
        type: PokemonType.water, category: MoveCategory.special,
        power: 40, accuracy: 100, pp: 25,
      );
      final noWeather = calc(
        move: waterGun,
        defType1: PokemonType.normal, defType2: null,
      );
      final rain = calc(
        move: waterGun,
        defType1: PokemonType.normal, defType2: null,
        weather: Weather.rain,
      );
      expect(rain.maxDamage, greaterThan(noWeather.maxDamage));
    });

    test('sun weakens water moves', () {
      const waterGun = Move(
        name: 'Water Gun', nameKo: '물대포', nameJa: 'みずでっぽう',
        type: PokemonType.water, category: MoveCategory.special,
        power: 40, accuracy: 100, pp: 25,
      );
      final noWeather = calc(
        move: waterGun,
        defType1: PokemonType.normal, defType2: null,
      );
      final sun = calc(
        move: waterGun,
        defType1: PokemonType.normal, defType2: null,
        weather: Weather.sun,
      );
      expect(sun.maxDamage, lessThan(noWeather.maxDamage));
    });
  });

  group('Burn', () {
    test('burn reduces physical damage', () {
      final normal = calc(
        move: tackle,
        defType1: PokemonType.normal, defType2: null,
      );
      final burned = calc(
        move: tackle,
        defType1: PokemonType.normal, defType2: null,
        atkStatus: StatusCondition.burn,
      );
      expect(burned.maxDamage, lessThan(normal.maxDamage));
    });

    test('burn does not affect special damage', () {
      final normal = calc(
        move: ember,
        defType1: PokemonType.normal, defType2: null,
      );
      final burned = calc(
        move: ember,
        defType1: PokemonType.normal, defType2: null,
        atkStatus: StatusCondition.burn,
      );
      expect(burned.maxDamage, equals(normal.maxDamage));
    });
  });

  group('Screens', () {
    test('Reflect reduces physical damage', () {
      final noScreen = calc(
        move: tackle,
        defType1: PokemonType.normal, defType2: null,
      );
      final withReflect = calc(
        move: tackle,
        defType1: PokemonType.normal, defType2: null,
        reflect: true,
      );
      expect(withReflect.maxDamage, lessThan(noScreen.maxDamage));
    });

    test('Light Screen reduces special damage', () {
      final noScreen = calc(
        move: ember,
        defType1: PokemonType.normal, defType2: null,
      );
      final withScreen = calc(
        move: ember,
        defType1: PokemonType.normal, defType2: null,
        lightScreen: true,
      );
      expect(withScreen.maxDamage, lessThan(noScreen.maxDamage));
    });

    test('critical bypasses Reflect', () {
      final critNoReflect = calc(
        move: tackle,
        defType1: PokemonType.normal, defType2: null,
        critical: true, reflect: false,
      );
      final critReflect = calc(
        move: tackle,
        defType1: PokemonType.normal, defType2: null,
        critical: true, reflect: true,
      );
      expect(critReflect.maxDamage, equals(critNoReflect.maxDamage));
    });
  });

  group('OHKO moves', () {
    const fissure = Move(
      name: 'Fissure', nameKo: '지각변동', nameJa: 'じわれ',
      type: PokemonType.ground, category: MoveCategory.physical,
      power: 0, accuracy: 30, pp: 5, tags: [MoveTags.ohko],
    );

    test('deals damage equal to defender HP', () {
      final result = calc(
        move: fissure,
        defType1: PokemonType.normal, defType2: null,
      );
      expect(result.baseDamage, equals(result.defenderHp));
    });

    test('Sturdy blocks OHKO', () {
      final result = calc(
        move: fissure,
        defType1: PokemonType.normal, defType2: null,
        defAbility: 'Sturdy',
      );
      expect(result.maxDamage, equals(0));
    });

    test('type immunity blocks OHKO', () {
      final result = calc(
        move: fissure,
        defType1: PokemonType.flying, defType2: null,
      );
      expect(result.maxDamage, equals(0));
    });
  });

  group('Fixed damage', () {
    test('Night Shade deals level-based damage', () {
      const nightShade = Move(
        name: 'Night Shade', nameKo: '나이트헤드', nameJa: 'ナイトヘッド',
        type: PokemonType.ghost, category: MoveCategory.special,
        power: 0, accuracy: 100, pp: 15, tags: [MoveTags.fixedLevel],
      );
      final result = calc(
        move: nightShade,
        defType1: PokemonType.fire, defType2: null,
      );
      // Default level is 50
      expect(result.baseDamage, equals(50));
    });

    test('Super Fang deals half defender HP', () {
      const superFang = Move(
        name: 'Super Fang', nameKo: '분노의앞니', nameJa: 'いかりのまえば',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 0, accuracy: 90, pp: 10, tags: [MoveTags.fixedHalfHp],
      );
      final result = calc(
        move: superFang,
        defType1: PokemonType.fire, defType2: null,
      );
      expect(result.baseDamage, equals(result.defenderHp ~/ 2));
    });
  });

  group('Knock Off', () {
    const knockOff = Move(
      name: 'Knock Off', nameKo: '탁쳐서떨어뜨리기', nameJa: 'はたきおとす',
      type: PokemonType.dark, category: MoveCategory.physical,
      power: 65, accuracy: 100, pp: 20,
      tags: [MoveTags.knockOff, MoveTags.contact],
    );

    test('1.5x boost when defender has removable item', () {
      final noItem = calc(
        move: knockOff,
        defType1: PokemonType.normal, defType2: null,
      );
      final withItem = calc(
        move: knockOff,
        defType1: PokemonType.normal, defType2: null,
        defItem: 'Leftovers',
      );
      expect(withItem.maxDamage, greaterThan(noItem.maxDamage));
    });
  });

  group('Hex', () {
    const hex = Move(
      name: 'Hex', nameKo: '불운', nameJa: 'たたりめ',
      type: PokemonType.ghost, category: MoveCategory.special,
      power: 65, accuracy: 100, pp: 10, tags: [MoveTags.doubleOnStatus],
    );

    test('doubles power on statused target', () {
      final noStatus = calc(
        move: hex,
        defType1: PokemonType.fire, defType2: null,
      );
      final withStatus = calc(
        move: hex,
        defType1: PokemonType.fire, defType2: null,
        defStatus: StatusCondition.burn,
      );
      expect(withStatus.maxDamage, greaterThan(noStatus.maxDamage));
    });
  });

  group('Wonder Guard', () {
    test('blocks non-super-effective moves', () {
      final result = calc(
        move: tackle,
        defAbility: 'Wonder Guard',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(result.maxDamage, equals(0));
    });

    test('allows super effective moves', () {
      const rockSmash = Move(
        name: 'Rock Smash', nameKo: '바위깨기', nameJa: 'いわくだき',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 40, accuracy: 100, pp: 15, tags: [MoveTags.contact],
      );
      final result = calc(
        move: rockSmash,
        defAbility: 'Wonder Guard',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(result.maxDamage, greaterThan(0));
    });
  });

  group('Neutralizing Gas', () {
    const thunderbolt = Move(
      name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    test('suppresses defensive abilities', () {
      final result = calc(
        move: thunderbolt,
        atkAbility: 'Neutralizing Gas',
        defAbility: 'Volt Absorb',
        defType1: PokemonType.water, defType2: null,
      );
      expect(result.maxDamage, greaterThan(0));
    });
  });

  group('Scrappy', () {
    test('Normal hits Ghost', () {
      final result = calc(
        move: tackle,
        atkAbility: 'Scrappy',
        defType1: PokemonType.ghost, defType2: null,
      );
      expect(result.maxDamage, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------
  // Additional coverage: DamageResult getters
  // ---------------------------------------------------------------

  group('DamageResult getters', () {
    test('minPercent and maxPercent', () {
      final r = calc(defType1: PokemonType.normal, defType2: null);
      expect(r.minPercent, greaterThan(0));
      expect(r.maxPercent, greaterThanOrEqualTo(r.minPercent));
    });

    test('koInfo returns valid data for single-hit', () {
      final r = calc(defType1: PokemonType.normal, defType2: null);
      final info = r.koInfo;
      expect(info.hits, greaterThan(0));
      expect(info.totalCount, greaterThan(0));
    });

    test('koLabel returns non-empty for damaging move', () {
      final r = calc(defType1: PokemonType.normal, defType2: null);
      expect(r.koLabel, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------
  // Weather/Terrain negation
  // ---------------------------------------------------------------

  group('Weather/Terrain negation', () {
    test('Cloud Nine negates weather boost', () {
      final sunBoosted = calc(
        move: ember, weather: Weather.sun,
        defType1: PokemonType.normal, defType2: null,
      );
      final cloudNine = calc(
        move: ember, weather: Weather.sun,
        atkAbility: 'Cloud Nine',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(cloudNine.maxDamage, lessThan(sunBoosted.maxDamage));
    });

    test('Air Lock negates weather boost', () {
      final sunBoosted = calc(
        move: ember, weather: Weather.sun,
        defType1: PokemonType.normal, defType2: null,
      );
      final airLock = calc(
        move: ember, weather: Weather.sun,
        atkAbility: 'Air Lock',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(airLock.maxDamage, lessThan(sunBoosted.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Gravity
  // ---------------------------------------------------------------

  group('Gravity', () {
    test('disables gravity-blocked moves', () {
      const flyMove = Move(
        name: 'Fly', nameKo: '공중날기', nameJa: 'そらをとぶ',
        type: PokemonType.flying, category: MoveCategory.physical,
        power: 90, accuracy: 95, pp: 15,
        tags: [MoveTags.contact, MoveTags.disabledByGravity],
      );
      final r = calc(
        move: flyMove,
        defType1: PokemonType.normal, defType2: null,
        room: const RoomConditions(gravity: true),
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Dream Eater
  // ---------------------------------------------------------------

  group('Dream Eater', () {
    const dreamEater = Move(
      name: 'Dream Eater', nameKo: '꿈먹기', nameJa: 'ゆめくい',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 100, accuracy: 100, pp: 15,
      tags: [MoveTags.requiresDefSleep],
    );

    test('fails when target is not asleep', () {
      final r = calc(
        move: dreamEater,
        defType1: PokemonType.fire, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });

    test('works when target is asleep', () {
      final r = calc(
        move: dreamEater,
        defType1: PokemonType.fire, defType2: null,
        defStatus: StatusCondition.sleep,
      );
      expect(r.maxDamage, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------
  // Charge (Electric 2x)
  // ---------------------------------------------------------------

  group('Charge', () {
    const thunderbolt = Move(
      name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    test('doubles electric move damage', () {
      final normal = calc(
        move: thunderbolt,
        defType1: PokemonType.water, defType2: null,
      );
      final charged = calc(
        move: thunderbolt, charge: true,
        defType1: PokemonType.water, defType2: null,
      );
      expect(charged.maxDamage, greaterThan(normal.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Wonder Room
  // ---------------------------------------------------------------

  group('Wonder Room', () {
    test('swaps Def and SpDef', () {
      // Use a Pokemon with uneven Def/SpDef
      final physical = calc(
        defType1: PokemonType.normal, defType2: null,
        room: const RoomConditions(wonderRoom: true),
      );
      final physicalNormal = calc(
        defType1: PokemonType.normal, defType2: null,
      );
      // With default Bulbasaur (Def 49, SpDef 65), Wonder Room swaps them
      // Physical move hits Def, which becomes 65 (was SpDef) -> less damage
      expect(physical.maxDamage, lessThan(physicalNormal.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Mold Breaker
  // ---------------------------------------------------------------

  group('Mold Breaker', () {
    test('ignores defensive abilities', () {
      final withMoldBreaker = calc(
        move: tackle, atkAbility: 'Mold Breaker',
        defAbility: 'Fur Coat',
        defType1: PokemonType.normal, defType2: null,
      );
      final withoutMoldBreaker = calc(
        move: tackle, atkAbility: null,
        defAbility: 'Fur Coat',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(withMoldBreaker.maxDamage, greaterThan(withoutMoldBreaker.maxDamage));
      expect(withMoldBreaker.modifierNotes.any((n) => n.contains('moldbreaker')), isTrue);
    });
  });

  // ---------------------------------------------------------------
  // Shell Armor negates critical
  // ---------------------------------------------------------------

  group('Shell Armor', () {
    test('negates critical hit', () {
      final crit = calc(
        critical: true,
        defAbility: 'Shell Armor',
        defType1: PokemonType.normal, defType2: null,
      );
      final noCrit = calc(
        critical: false,
        defAbility: 'Shell Armor',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(crit.maxDamage, equals(noCrit.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Type immunity ability (Bulletproof, Soundproof)
  // ---------------------------------------------------------------

  group('Move-based immunity abilities', () {
    test('Bulletproof blocks ball/bomb moves', () {
      const shadowBall = Move(
        name: 'Shadow Ball', nameKo: '섀도볼', nameJa: 'シャドーボール',
        type: PokemonType.ghost, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15, tags: [MoveTags.ball],
      );
      final r2 = calc(
        move: shadowBall,
        defAbility: 'Bulletproof',
        defType1: PokemonType.fire, defType2: null,
      );
      expect(r2.maxDamage, equals(0));
    });

    test('Soundproof blocks sound moves', () {
      const bugBuzz = Move(
        name: 'Bug Buzz', nameKo: '벌레의야단법석', nameJa: 'むしのさざめき',
        type: PokemonType.bug, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10, tags: [MoveTags.sound],
      );
      final r = calc(
        move: bugBuzz,
        defAbility: 'Soundproof',
        defType1: PokemonType.fire, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Priority blockers
  // ---------------------------------------------------------------

  group('Priority blocking', () {
    const quickAttack = Move(
      name: 'Quick Attack', nameKo: '전광석화', nameJa: 'でんこうせっか',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 30,
      tags: [MoveTags.contact], priority: 1,
    );

    test('Queenly Majesty blocks priority', () {
      final r = calc(
        move: quickAttack,
        defAbility: 'Queenly Majesty',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });

    test('Psychic Terrain blocks priority on grounded target', () {
      final r = calc(
        move: quickAttack,
        terrain: Terrain.psychic,
        defType1: PokemonType.normal, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Terastal
  // ---------------------------------------------------------------

  group('Terastal STAB', () {
    test('Tera STAB + original STAB gives 2.0x', () {
      // Attacker is grass/poison, Tera poison -> poison move = Tera STAB + original STAB
      final teraStab = calc(
        move: sludgeBomb,
        atkTerastal: TerastalState(active: true, teraType: PokemonType.poison),
        defType1: PokemonType.fire, defType2: null,
      );
      final normalStab = calc(
        move: sludgeBomb,
        defType1: PokemonType.fire, defType2: null,
      );
      // 2.0x vs 1.5x STAB
      expect(teraStab.maxDamage, greaterThan(normalStab.maxDamage));
    });

    test('Stellar type: original STAB gets 2.0x', () {
      final stellar = calc(
        move: sludgeBomb,
        atkTerastal: TerastalState(active: true, teraType: PokemonType.stellar),
        defType1: PokemonType.fire, defType2: null,
      );
      final normal = calc(
        move: sludgeBomb,
        defType1: PokemonType.fire, defType2: null,
      );
      expect(stellar.maxDamage, greaterThan(normal.maxDamage));
    });

    test('Stellar type: non-STAB gets 1.2x', () {
      final stellar = calc(
        move: ember,
        atkTerastal: TerastalState(active: true, teraType: PokemonType.stellar),
        defType1: PokemonType.normal, defType2: null,
      );
      final normal = calc(
        move: ember,
        defType1: PokemonType.normal, defType2: null,
      );
      expect(stellar.maxDamage, greaterThan(normal.maxDamage));
    });

    test('Tera minimum power: weak Tera STAB move boosted to 60', () {
      // A low-power move with Tera STAB should get boosted to 60 power
      const weakMove = Move(
        name: 'Acid', nameKo: '녹이기', nameJa: 'ようかいえき',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 40, accuracy: 100, pp: 30,
      );
      final teraResult = calc(
        move: weakMove,
        atkTerastal: TerastalState(active: true, teraType: PokemonType.poison),
        defType1: PokemonType.fire, defType2: null,
      );
      final normalResult = calc(
        move: weakMove,
        defType1: PokemonType.fire, defType2: null,
      );
      // Tera min power (60) + 2.0x STAB vs normal (40) + 1.5x STAB
      expect(teraResult.maxDamage, greaterThan(normalResult.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Harsh Sun / Heavy Rain (weather blocks)
  // ---------------------------------------------------------------

  group('Extreme weather blocks', () {
    test('Harsh Sun blocks water moves', () {
      const waterGun = Move(
        name: 'Water Gun', nameKo: '물대포', nameJa: 'みずでっぽう',
        type: PokemonType.water, category: MoveCategory.special,
        power: 40, accuracy: 100, pp: 25,
      );
      final r = calc(
        move: waterGun, weather: Weather.harshSun,
        defType1: PokemonType.normal, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });

    test('Heavy Rain blocks fire moves', () {
      final r = calc(
        move: ember, weather: Weather.heavyRain,
        defType1: PokemonType.normal, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Strong Winds
  // ---------------------------------------------------------------

  group('Strong Winds', () {
    test('removes Flying weakness', () {
      const iceBeam = Move(
        name: 'Ice Beam', nameKo: '냉동빔', nameJa: 'れいとうビーム',
        type: PokemonType.ice, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
      );
      final normal = calc(
        move: iceBeam,
        defType1: PokemonType.flying, defType2: null,
      );
      final winds = calc(
        move: iceBeam, weather: Weather.strongWinds,
        defType1: PokemonType.flying, defType2: null,
      );
      expect(winds.maxDamage, lessThan(normal.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Tera Shell
  // ---------------------------------------------------------------

  group('Tera Shell', () {
    test('reduces super effective to 0.5x at full HP', () {
      final normal = calc(
        move: ember,
        defAbility: 'Overgrow',
        defType1: PokemonType.grass, defType2: null,
      );
      final teraShell = calc(
        move: ember,
        defAbility: 'Tera Shell',
        defType1: PokemonType.grass, defType2: null,
      );
      expect(teraShell.maxDamage, lessThan(normal.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Move-specific power modifiers
  // ---------------------------------------------------------------

  group('Move-specific power modifiers', () {
    test('Brine doubles on half HP target', () {
      const brine = Move(
        name: 'Brine', nameKo: '소금물', nameJa: 'しおみず',
        type: PokemonType.water, category: MoveCategory.special,
        power: 65, accuracy: 100, pp: 10, tags: [MoveTags.doubleOnHalfHp],
      );
      final full = calc(
        move: brine,
        defType1: PokemonType.fire, defType2: null,
        defHpPercent: 100,
      );
      final half = calc(
        move: brine,
        defType1: PokemonType.fire, defType2: null,
        defHpPercent: 50,
      );
      expect(half.maxDamage, greaterThan(full.maxDamage));
    });

    test('Venoshock doubles on poisoned target', () {
      const venoshock = Move(
        name: 'Venoshock', nameKo: '베놈쇼크', nameJa: 'ベノムショック',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 65, accuracy: 100, pp: 10, tags: [MoveTags.doubleOnPoison],
      );
      final normal = calc(
        move: venoshock,
        defType1: PokemonType.fire, defType2: null,
      );
      final poisoned = calc(
        move: venoshock,
        defType1: PokemonType.fire, defType2: null,
        defStatus: StatusCondition.poison,
      );
      expect(poisoned.maxDamage, greaterThan(normal.maxDamage));
    });

    test('Wake-Up Slap doubles on sleeping target', () {
      const wakeUpSlap = Move(
        name: 'Wake-Up Slap', nameKo: '눈깨움뺨치기', nameJa: 'めざましビンタ',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 70, accuracy: 100, pp: 10,
        tags: [MoveTags.doubleOnSleep, MoveTags.contact],
      );
      final awake = calc(
        move: wakeUpSlap,
        defType1: PokemonType.normal, defType2: null,
      );
      final asleep = calc(
        move: wakeUpSlap,
        defType1: PokemonType.normal, defType2: null,
        defStatus: StatusCondition.sleep,
      );
      expect(asleep.maxDamage, greaterThan(awake.maxDamage));
    });

    test('Smelling Salts doubles on paralyzed target', () {
      const smellingSalts = Move(
        name: 'Smelling Salts', nameKo: '기합의멱살잡기', nameJa: 'きつけ',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 70, accuracy: 100, pp: 10,
        tags: [MoveTags.doubleOnParalysis, MoveTags.contact],
      );
      final normal = calc(
        move: smellingSalts,
        defType1: PokemonType.fire, defType2: null,
      );
      final paralyzed = calc(
        move: smellingSalts,
        defType1: PokemonType.fire, defType2: null,
        defStatus: StatusCondition.paralysis,
      );
      expect(paralyzed.maxDamage, greaterThan(normal.maxDamage));
    });

    test('Dynamax Cannon doubles vs Dynamaxed target', () {
      const dynamaxCannon = Move(
        name: 'Dynamax Cannon', nameKo: '다이맥스포', nameJa: 'ダイマックスほう',
        type: PokemonType.dragon, category: MoveCategory.special,
        power: 100, accuracy: 100, pp: 5, tags: [MoveTags.doubleDynamax],
      );
      final normal = calc(
        move: dynamaxCannon,
        defType1: PokemonType.normal, defType2: null,
      );
      final vsDmax = calc(
        move: dynamaxCannon,
        defType1: PokemonType.normal, defType2: null,
        defDynamax: DynamaxState.dynamax,
      );
      expect(vsDmax.maxDamage, greaterThan(normal.maxDamage));
    });

    test('Collision Course boosts on super effective', () {
      const collisionCourse = Move(
        name: 'Collision Course', nameKo: '클래시임팩트', nameJa: 'アクセルブレイク',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 100, accuracy: 100, pp: 5,
        tags: [MoveTags.superEffectiveBoost, MoveTags.contact],
      );
      // Fighting vs Normal = SE
      final se = calc(
        move: collisionCourse,
        defType1: PokemonType.normal, defType2: null,
      );
      // Compare with a similar move without the boost tag
      const closeCombat = Move(
        name: 'Close Combat', nameKo: '인파이트', nameJa: 'インファイト',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 100, accuracy: 100, pp: 5, tags: [MoveTags.contact],
      );
      final noBoost = calc(
        move: closeCombat,
        defType1: PokemonType.normal, defType2: null,
      );
      expect(se.maxDamage, greaterThan(noBoost.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Corrosion (Poison hits Steel)
  // ---------------------------------------------------------------

  group('Corrosion', () {
    test('Poison hits Steel', () {
      final r = calc(
        move: sludgeBomb,
        atkAbility: 'Corrosion',
        defType1: PokemonType.steel, defType2: null,
      );
      expect(r.maxDamage, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------
  // Thousand Arrows (Ground hits Flying)
  // ---------------------------------------------------------------

  group('Thousand Arrows', () {
    test('Ground hits Flying', () {
      const thousandArrows = Move(
        name: 'Thousand Arrows', nameKo: '사우전드애로우', nameJa: 'サウザンドアロー',
        type: PokemonType.ground, category: MoveCategory.physical,
        power: 90, accuracy: 100, pp: 10, tags: [MoveTags.thousandArrows],
      );
      final r = calc(
        move: thousandArrows,
        defType1: PokemonType.flying, defType2: null,
      );
      expect(r.maxDamage, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------
  // Expert Belt
  // ---------------------------------------------------------------

  group('Expert Belt', () {
    test('boosts super effective by 1.2x', () {
      final normal = calc(
        move: ember,
        defType1: PokemonType.grass, defType2: null,
      );
      final belt = calc(
        move: ember, atkItem: 'expert-belt',
        defType1: PokemonType.grass, defType2: null,
      );
      expect(belt.maxDamage, greaterThan(normal.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Infiltrator bypasses screens
  // ---------------------------------------------------------------

  group('Infiltrator', () {
    test('bypasses Reflect', () {
      final infiltrator = calc(
        move: tackle, atkAbility: 'Infiltrator',
        defType1: PokemonType.normal, defType2: null,
        reflect: true,
      );
      final noScreen = calc(
        move: tackle, atkAbility: 'Infiltrator',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(infiltrator.maxDamage, equals(noScreen.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Resist berry
  // ---------------------------------------------------------------

  group('Resist berry', () {
    test('reduces super effective damage', () {
      final noBerry = calc(
        move: ember,
        defType1: PokemonType.grass, defType2: null,
      );
      final withBerry = calc(
        move: ember,
        defType1: PokemonType.grass, defType2: null,
        defItem: 'occa-berry',
      );
      expect(withBerry.maxDamage, lessThan(noBerry.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Weight-based vs Dynamax immunity
  // ---------------------------------------------------------------

  group('Weight-based vs Dynamax', () {
    test('weight-based moves fail against Dynamaxed targets', () {
      const lowKick = Move(
        name: 'Low Kick', nameKo: '로킥', nameJa: 'けたぐり',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 20,
        tags: [MoveTags.weightTarget, MoveTags.contact, MoveTags.weightBased],
      );
      final r = calc(
        move: lowKick,
        defType1: PokemonType.normal, defType2: null,
        defDynamax: DynamaxState.dynamax,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Multi-hit moves
  // ---------------------------------------------------------------

  group('Multi-hit moves', () {
    test('multi-hit produces perHitAllRolls', () {
      const iciclespear = Move(
        name: 'Icicle Spear', nameKo: '고드름침', nameJa: 'つららばり',
        type: PokemonType.ice, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30,
        minHits: 2, maxHits: 5,
      );
      final atk = BattlePokemonState(
        moves: [iciclespear, null, null, null],
      );
      final def = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
      );
      final r = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(r.perHitAllRolls, isNotNull);
      expect(r.perHitAllRolls!.length, equals(5));
      expect(r.maxDamage, greaterThan(0));
      // koInfo and koLabel should work for multi-hit
      final info = r.koInfo;
      expect(info.hits, greaterThan(0));
      expect(r.koLabel, isNotEmpty);
    });

    test('Kee Berry: physical multi-hit gets Defense ↑ from hit 2', () {
      const bulletSeed = Move(
        name: 'Bullet Seed', nameKo: '씨기관총', nameJa: 'タネマシンガン',
        type: PokemonType.grass, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30,
        minHits: 2, maxHits: 5,
      );
      final atk = BattlePokemonState(
        moves: [bulletSeed, null, null, null],
      );
      final defWithBerry = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedItem: 'kee-berry',
      );
      final defNoBerry = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
      );
      final rWith = DamageCalculator.calculate(
        attacker: atk, defender: defWithBerry, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      final rNo = DamageCalculator.calculate(
        attacker: atk, defender: defNoBerry, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      // First hit: same damage (berry not yet activated)
      expect(rWith.perHitAllRolls![0], equals(rNo.perHitAllRolls![0]));
      // Subsequent hits: less damage due to Defense boost
      expect(rWith.perHitAllRolls![1].first, lessThan(rNo.perHitAllRolls![1].first));
      // Total max damage with berry should be less
      expect(rWith.maxDamage, lessThan(rNo.maxDamage));
    });

    test('Kee Berry: special move does NOT trigger Kee Berry', () {
      const waterShuriken = Move(
        name: 'Water Shuriken', nameKo: '물수리검', nameJa: 'みずしゅりけん',
        type: PokemonType.water, category: MoveCategory.special,
        power: 15, accuracy: 100, pp: 20,
        minHits: 2, maxHits: 5,
      );
      final atk = BattlePokemonState(
        moves: [waterShuriken, null, null, null],
      );
      final defWithKee = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedItem: 'kee-berry',
      );
      final defNoBerry = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
      );
      final rWith = DamageCalculator.calculate(
        attacker: atk, defender: defWithKee, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      final rNo = DamageCalculator.calculate(
        attacker: atk, defender: defNoBerry, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      expect(rWith.maxDamage, equals(rNo.maxDamage));
    });

    test('Maranga Berry: special multi-hit gets Sp.Def ↑ from hit 2', () {
      const waterShuriken = Move(
        name: 'Water Shuriken', nameKo: '물수리검', nameJa: 'みずしゅりけん',
        type: PokemonType.water, category: MoveCategory.special,
        power: 15, accuracy: 100, pp: 20,
        minHits: 2, maxHits: 5,
      );
      final atk = BattlePokemonState(
        moves: [waterShuriken, null, null, null],
      );
      final defWithMaranga = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedItem: 'maranga-berry',
      );
      final defNoBerry = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
      );
      final rWith = DamageCalculator.calculate(
        attacker: atk, defender: defWithMaranga, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      final rNo = DamageCalculator.calculate(
        attacker: atk, defender: defNoBerry, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      expect(rWith.perHitAllRolls![0], equals(rNo.perHitAllRolls![0]));
      expect(rWith.perHitAllRolls![1].first, lessThan(rNo.perHitAllRolls![1].first));
      expect(rWith.maxDamage, lessThan(rNo.maxDamage));
    });

    test('Kee Berry: escalating move (Triple Axel) also boosted', () {
      const tripleAxel = Move(
        name: 'Triple Axel', nameKo: '트리플악셀', nameJa: 'トリプルアクセル',
        type: PokemonType.ice, category: MoveCategory.physical,
        power: 20, accuracy: 90, pp: 10,
        minHits: 1, maxHits: 3,
        tags: [MoveTags.escalatingHits],
      );
      final atk = BattlePokemonState(
        moves: [tripleAxel, null, null, null],
      );
      final defWithBerry = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedItem: 'kee-berry',
      );
      final defNoBerry = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
      );
      final rWith = DamageCalculator.calculate(
        attacker: atk, defender: defWithBerry, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      final rNo = DamageCalculator.calculate(
        attacker: atk, defender: defNoBerry, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      // 1st hit unchanged, 2nd and 3rd reduced
      expect(rWith.perHitAllRolls![0], equals(rNo.perHitAllRolls![0]));
      expect(rWith.maxDamage, lessThan(rNo.maxDamage));
    });

    test('Stamina: any multi-hit move reduces damage after hit 1', () {
      const bulletSeed = Move(
        name: 'Bullet Seed', nameKo: '씨기관총', nameJa: 'タネマシンガン',
        type: PokemonType.grass, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30,
        minHits: 2, maxHits: 5,
      );
      final atk = BattlePokemonState(
        moves: [bulletSeed, null, null, null],
      );
      final defStamina = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedAbility: 'Stamina',
      );
      final defNoAbility = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedAbility: 'Overgrow',
      );
      final rWith = DamageCalculator.calculate(
        attacker: atk, defender: defStamina, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      final rNo = DamageCalculator.calculate(
        attacker: atk, defender: defNoAbility, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      expect(rWith.perHitAllRolls![0], equals(rNo.perHitAllRolls![0]));
      expect(rWith.perHitAllRolls![1].first, lessThan(rNo.perHitAllRolls![1].first));
    });


    test('Water Compaction: water multi-hit reduces damage more (+2 Def)', () {
      const waterShuriken = Move(
        name: 'Water Shuriken', nameKo: '물수리검', nameJa: 'みずしゅりけん',
        type: PokemonType.water, category: MoveCategory.special,
        power: 15, accuracy: 100, pp: 20,
        minHits: 2, maxHits: 5,
      );
      // Water Shuriken is special, so +Def doesn't help.
      // Use a physical water multi-hit like Surging Strikes instead.
      const surgingStrikes = Move(
        name: 'Surging Strikes', nameKo: '물의파동연격', nameJa: 'すいりゅうれんだ',
        type: PokemonType.water, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 5,
        minHits: 3, maxHits: 3,
      );
      final atk = BattlePokemonState(
        moves: [surgingStrikes, null, null, null],
      );
      final defWC = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedAbility: 'Water Compaction',
      );
      final defNo = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedAbility: 'Overgrow',
      );
      final rWith = DamageCalculator.calculate(
        attacker: atk, defender: defWC, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      final rNo = DamageCalculator.calculate(
        attacker: atk, defender: defNo, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      expect(rWith.maxDamage, lessThan(rNo.maxDamage));
      // Silence unused warning
      expect(waterShuriken.name, isNotEmpty);
    });

    test('Weak Armor: physical multi-hit deals MORE damage after hit 1', () {
      const bulletSeed = Move(
        name: 'Bullet Seed', nameKo: '씨기관총', nameJa: 'タネマシンガン',
        type: PokemonType.grass, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30,
        minHits: 2, maxHits: 5,
      );
      final atk = BattlePokemonState(
        moves: [bulletSeed, null, null, null],
      );
      final defWA = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedAbility: 'Weak Armor',
      );
      final defNo = BattlePokemonState(
        type1: PokemonType.normal, type2: null,
        selectedAbility: 'Overgrow',
      );
      final rWith = DamageCalculator.calculate(
        attacker: atk, defender: defWA, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      final rNo = DamageCalculator.calculate(
        attacker: atk, defender: defNo, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none, room: const RoomConditions(),
      );
      expect(rWith.perHitAllRolls![0], equals(rNo.perHitAllRolls![0]));
      expect(rWith.perHitAllRolls![1].first, greaterThan(rNo.perHitAllRolls![1].first));
    });
  });

  // ---------------------------------------------------------------
  // Parental Bond (Mega Kangaskhan)
  // ---------------------------------------------------------------
  group('Parental Bond', () {
    test('normal move becomes 2-hit with 2nd hit at 0.25x power', () {
      final rNo = calc(move: tackle);
      final rPB = calc(move: tackle, atkAbility: 'Parental Bond');

      // 2-hit multi-hit result
      expect(rPB.perHitAllRolls, isNotNull);
      expect(rPB.perHitAllRolls!.length, equals(2));

      // Hit 1 matches no-ability damage
      expect(rPB.perHitAllRolls![0], equals(rNo.allRolls));

      // Hit 2 < Hit 1 (0.25x power)
      final hit1Max = rPB.perHitAllRolls![0].reduce((a, b) => a > b ? a : b);
      final hit2Max = rPB.perHitAllRolls![1].reduce((a, b) => a > b ? a : b);
      expect(hit2Max, lessThan(hit1Max));
    });

    test('Seismic Toss hits twice at full damage', () {
      const seismicToss = Move(
        name: 'Seismic Toss', nameKo: '지구던지기', nameJa: 'ちきゅうなげ',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 20,
        tags: [MoveTags.fixedLevel],
      );
      final rNo = calc(move: seismicToss, defType1: PokemonType.normal, defType2: null);
      final rPB = calc(move: seismicToss, atkAbility: 'Parental Bond',
          defType1: PokemonType.normal, defType2: null);

      expect(rPB.maxDamage, equals(rNo.maxDamage * 2));
      expect(rPB.perHitAllRolls, isNotNull);
      expect(rPB.perHitAllRolls!.length, equals(2));
      expect(rPB.perHitAllRolls![0].first, equals(rNo.maxDamage));
      expect(rPB.perHitAllRolls![1].first, equals(rNo.maxDamage));
    });

    test('Bullet Seed unaffected by Parental Bond (already multi-hit)', () {
      const bulletSeed = Move(
        name: 'Bullet Seed', nameKo: '씨기관총', nameJa: 'タネマシンガン',
        type: PokemonType.grass, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30, minHits: 2, maxHits: 5,
      );
      final rNo = calc(move: bulletSeed);
      final rPB = calc(move: bulletSeed, atkAbility: 'Parental Bond');
      expect(rPB.maxDamage, equals(rNo.maxDamage));
      // Still 5-hit, not 2
      expect(rPB.perHitAllRolls!.length, equals(5));
    });

    test('Solar Beam (charge move) excluded: no double hit', () {
      const solarBeam = Move(
        name: 'Solar Beam', nameKo: '솔라빔', nameJa: 'ソーラービーム',
        type: PokemonType.grass, category: MoveCategory.special,
        power: 120, accuracy: 100, pp: 10,
      );
      final rPB = calc(move: solarBeam, atkAbility: 'Parental Bond');
      // Single-hit; no perHitAllRolls
      expect(rPB.perHitAllRolls, isNull);
    });

    test('Explosion (self-destruct) excluded: no double hit', () {
      const explosion = Move(
        name: 'Explosion', nameKo: '대폭발', nameJa: 'だいばくはつ',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 250, accuracy: 100, pp: 5,
      );
      final rPB = calc(move: explosion, atkAbility: 'Parental Bond',
          defType1: PokemonType.fire, defType2: null);
      expect(rPB.perHitAllRolls, isNull);
    });

    test('Super Fang + PB: hit 2 recalculates from remaining HP', () {
      const superFang = Move(
        name: 'Super Fang', nameKo: '엄청난이빨', nameJa: 'いかりのまえば',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 0, accuracy: 90, pp: 10,
        tags: [MoveTags.fixedHalfHp],
      );
      final r = calc(move: superFang, atkAbility: 'Parental Bond',
          defType1: PokemonType.fairy, defType2: null);
      expect(r.perHitAllRolls, isNotNull);
      expect(r.perHitAllRolls!.length, equals(2));
      final hit1 = r.perHitAllRolls![0].first;
      final hit2 = r.perHitAllRolls![1].first;
      // Hit 2 must be smaller than Hit 1 (half of remaining, not half of full)
      expect(hit2, lessThan(hit1));
      // Total ≈ 75% of max HP (not 100%)
      expect(r.maxDamage, lessThan(r.defenderHp));
    });

    test('Sonic Boom + PB: 20 + 20 = 40', () {
      const sonicBoom = Move(
        name: 'Sonic Boom', nameKo: '음파', nameJa: 'ソニックブーム',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 0, accuracy: 90, pp: 20,
        tags: [MoveTags.fixed20],
      );
      final r = calc(move: sonicBoom, atkAbility: 'Parental Bond',
          defType1: PokemonType.fairy, defType2: null);
      expect(r.maxDamage, equals(40));
    });

    test('Dragon Rage + PB: 40 + 40 = 80', () {
      const dragonRage = Move(
        name: 'Dragon Rage', nameKo: '용의분노', nameJa: 'りゅうのいかり',
        type: PokemonType.dragon, category: MoveCategory.special,
        power: 0, accuracy: 100, pp: 10,
        tags: [MoveTags.fixed40],
      );
      final r = calc(move: dragonRage, atkAbility: 'Parental Bond',
          defType1: PokemonType.fairy, defType2: null);
      expect(r.maxDamage, equals(80));
    });

    test('Hard Press + PB KO on hit 1: hit 2 = 0', () {
      const hardPress = Move(
        name: 'Hard Press', nameKo: '하드프레스', nameJa: 'ハードプレス',
        type: PokemonType.steel, category: MoveCategory.physical,
        power: 100, accuracy: 100, pp: 5,
        tags: [MoveTags.powerByTargetHp100],
      );
      // Set defender at 1% HP so hit 1 certainly KOs.
      final rPB = calc(move: hardPress, atkAbility: 'Parental Bond',
          defType1: PokemonType.fairy, defType2: null,
          defHpPercent: 1);
      expect(rPB.perHitAllRolls, isNotNull);
      // Every hit 2 roll should be 0 (hit 2 doesn't execute after KO)
      for (final v in rPB.perHitAllRolls![1]) {
        expect(v, equals(0));
      }
    });

    test('Seismic Toss + PB KO on hit 1: hit 2 = 0', () {
      const seismicToss = Move(
        name: 'Seismic Toss', nameKo: '지구던지기', nameJa: 'ちきゅうなげ',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 20,
        tags: [MoveTags.fixedLevel],
      );
      // Target at 1% HP, much less than attacker level damage.
      final rPB = calc(move: seismicToss, atkAbility: 'Parental Bond',
          defType1: PokemonType.normal, defType2: null,
          defHpPercent: 1);
      expect(rPB.perHitAllRolls, isNotNull);
      expect(rPB.perHitAllRolls![1].first, equals(0));
    });

    test('Hard Press + PB: hit 2 recalculates power from remaining HP', () {
      const hardPress = Move(
        name: 'Hard Press', nameKo: '하드프레스', nameJa: 'ハードプレス',
        type: PokemonType.steel, category: MoveCategory.physical,
        power: 100, accuracy: 100, pp: 5,
        tags: [MoveTags.powerByTargetHp100],
      );
      final rPB = calc(move: hardPress, atkAbility: 'Parental Bond',
          defType1: PokemonType.fairy, defType2: null);

      expect(rPB.perHitAllRolls, isNotNull);
      expect(rPB.perHitAllRolls!.length, equals(2));

      // Hit 2 at roll 100% should be smaller than naive 0.25x (because remaining
      // HP < 100% means less than max 100 power).
      final hit1Max = rPB.perHitAllRolls![0].reduce((a, b) => a > b ? a : b);
      expect(hit1Max, greaterThan(0));

      // Hit 2's power varies by hit 1's damage, so hit 2 should be lower than
      // if we used naive constant 0.25x of max power. Rough sanity check: hit 2
      // damage < hit 1 damage.
      final hit2Max = rPB.perHitAllRolls![1].reduce((a, b) => a > b ? a : b);
      expect(hit2Max, lessThan(hit1Max));
    });

    test('Hyper Beam (recharge) still double-hits', () {
      const hyperBeam = Move(
        name: 'Hyper Beam', nameKo: '파괴광선', nameJa: 'はかいこうせん',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 150, accuracy: 90, pp: 5,
      );
      final rPB = calc(move: hyperBeam, atkAbility: 'Parental Bond',
          defType1: PokemonType.fire, defType2: null);
      expect(rPB.perHitAllRolls, isNotNull);
      expect(rPB.perHitAllRolls!.length, equals(2));
    });
  });

  // ---------------------------------------------------------------
  // Disguise vs fixed-damage / OHKO moves
  // ---------------------------------------------------------------
  group('Disguise vs fixed-damage', () {
    // Mimikyu's typical HP total (~130-140 depending on EV/IV/nature).
    // With the default calc() setup, Disguise damage = maxHp / 8.

    test('Seismic Toss vs Disguise: 1/8 max HP, not attacker level', () {
      const seismicToss = Move(
        name: 'Seismic Toss', nameKo: '지구던지기', nameJa: 'ちきゅうなげ',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 20,
        tags: [MoveTags.fixedLevel],
      );
      final rPlain = calc(move: seismicToss, defAbility: 'Overgrow',
          defType1: PokemonType.normal, defType2: null);
      final rDisguise = calc(move: seismicToss, defAbility: 'Disguise Disguised',
          defType1: PokemonType.ghost, defType2: PokemonType.fairy);
      expect(rDisguise.maxDamage, equals((rDisguise.defenderHp / 8).floor()));
      expect(rDisguise.maxDamage, isNot(equals(rPlain.maxDamage)));
    });

    test('Super Fang vs Disguise: 1/8 max HP, not 50% current HP', () {
      const superFang = Move(
        name: 'Super Fang', nameKo: '엄청난이빨', nameJa: 'いかりのまえば',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 0, accuracy: 90, pp: 10,
        tags: [MoveTags.fixedHalfHp],
      );
      // Normal vs Ghost/Fairy = 0, skip to a non-immune typing
      final r = calc(move: superFang, defAbility: 'Disguise Disguised',
          defType1: PokemonType.fairy, defType2: null);
      expect(r.maxDamage, equals((r.defenderHp / 8).floor()));
    });

    test('Nature\'s Madness vs Disguise: 1/8 max HP', () {
      const naturesMadness = Move(
        name: "Nature's Madness", nameKo: '자연의분노', nameJa: 'しぜんのいかり',
        type: PokemonType.fairy, category: MoveCategory.special,
        power: 0, accuracy: 90, pp: 10,
        tags: [MoveTags.fixedHalfHp],
      );
      final r = calc(move: naturesMadness, defAbility: 'Disguise Disguised',
          defType1: PokemonType.ghost, defType2: PokemonType.fairy);
      expect(r.maxDamage, equals((r.defenderHp / 8).floor()));
    });

    test('OHKO (Fissure) vs Disguise: 1/8 max HP, not full HP', () {
      const fissure = Move(
        name: 'Fissure', nameKo: '지각변동', nameJa: 'じわれ',
        type: PokemonType.ground, category: MoveCategory.physical,
        power: 0, accuracy: 30, pp: 5, tags: [MoveTags.ohko],
      );
      final r = calc(move: fissure, defAbility: 'Disguise Disguised',
          defType1: PokemonType.fairy, defType2: null);
      expect(r.maxDamage, equals((r.defenderHp / 8).floor()));
    });

    test('Mold Breaker bypasses Disguise for Seismic Toss', () {
      const seismicToss = Move(
        name: 'Seismic Toss', nameKo: '지구던지기', nameJa: 'ちきゅうなげ',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 20,
        tags: [MoveTags.fixedLevel],
      );
      final rMold = calc(move: seismicToss, atkAbility: 'Mold Breaker',
          defAbility: 'Disguise Disguised',
          defType1: PokemonType.ghost, defType2: PokemonType.fairy);
      // Seismic Toss deals level damage (50 at default level)
      expect(rMold.maxDamage, equals(50));
    });

    test('Parental Bond + Seismic Toss vs Disguise: hit 1 busts disguise, hit 2 full', () {
      const seismicToss = Move(
        name: 'Seismic Toss', nameKo: '지구던지기', nameJa: 'ちきゅうなげ',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 20,
        tags: [MoveTags.fixedLevel],
      );
      final r = calc(move: seismicToss, atkAbility: 'Parental Bond',
          defAbility: 'Disguise Disguised',
          defType1: PokemonType.ghost, defType2: PokemonType.fairy);
      expect(r.perHitAllRolls, isNotNull);
      expect(r.perHitAllRolls!.length, equals(2));
      final hit1 = r.perHitAllRolls![0].first;
      final hit2 = r.perHitAllRolls![1].first;
      expect(hit1, equals((r.defenderHp / 8).floor())); // disguise break
      expect(hit2, equals(50)); // attacker level
    });
  });

  // ---------------------------------------------------------------
  // OHKO vs Dynamax
  // ---------------------------------------------------------------

  group('OHKO vs Dynamax', () {
    test('OHKO fails against Dynamaxed target', () {
      const fissure = Move(
        name: 'Fissure', nameKo: '지각변동', nameJa: 'じわれ',
        type: PokemonType.ground, category: MoveCategory.physical,
        power: 0, accuracy: 30, pp: 5, tags: [MoveTags.ohko],
      );
      final r = calc(
        move: fissure,
        defType1: PokemonType.normal, defType2: null,
        defDynamax: DynamaxState.dynamax,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Sheer Cold vs Ice type
  // ---------------------------------------------------------------

  group('Sheer Cold', () {
    test('Ice type is immune to Sheer Cold', () {
      const sheerCold = Move(
        name: 'Sheer Cold', nameKo: '절대영도', nameJa: 'ぜったいれいど',
        type: PokemonType.ice, category: MoveCategory.special,
        power: 0, accuracy: 30, pp: 5, tags: [MoveTags.ohko, MoveTags.ohkoIceImmune],
      );
      final r = calc(
        move: sheerCold,
        defType1: PokemonType.ice, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Fixed damage: ability type immunity
  // ---------------------------------------------------------------

  group('Fixed damage ability immunity', () {
    test('Volt Absorb blocks fixed Electric damage', () {
      const fixed20Electric = Move(
        name: 'Electro Shock', nameKo: 'test', nameJa: 'test',
        type: PokemonType.electric, category: MoveCategory.special,
        power: 0, accuracy: 100, pp: 10, tags: [MoveTags.fixed20],
      );
      final r = calc(
        move: fixed20Electric,
        defAbility: 'Volt Absorb',
        defType1: PokemonType.water, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Aura abilities
  // ---------------------------------------------------------------

  group('Aura abilities', () {
    test('Fairy Aura boosts fairy moves', () {
      const moonblast = Move(
        name: 'Moonblast', nameKo: '문포스', nameJa: 'ムーンフォース',
        type: PokemonType.fairy, category: MoveCategory.special,
        power: 95, accuracy: 100, pp: 15,
      );
      final normal = calc(
        move: moonblast,
        defType1: PokemonType.fire, defType2: null,
      );
      final aura = calc(
        move: moonblast, atkAbility: 'Fairy Aura',
        defType1: PokemonType.fire, defType2: null,
      );
      expect(aura.maxDamage, greaterThan(normal.maxDamage));
    });
  });

  // ---------------------------------------------------------------
  // Unaware notes
  // ---------------------------------------------------------------

  group('Unaware', () {
    test('defender Unaware noted', () {
      final r = calc(
        defAbility: 'Unaware',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(r.modifierNotes.any((n) => n.contains('unaware:defender')), isTrue);
    });

    test('attacker Unaware noted', () {
      final r = calc(
        atkAbility: 'Unaware',
        defType1: PokemonType.normal, defType2: null,
      );
      expect(r.modifierNotes.any((n) => n.contains('unaware:attacker')), isTrue);
    });
  });

  // ---------------------------------------------------------------
  // Psyshock targets physical defense
  // ---------------------------------------------------------------

  group('Psyshock', () {
    test('targets physical defense', () {
      const psyshock = Move(
        name: 'Psyshock', nameKo: '사이코쇼크', nameJa: 'サイコショック',
        type: PokemonType.psychic, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 10, tags: [MoveTags.targetPhysDef],
      );
      final r = calc(
        move: psyshock,
        defType1: PokemonType.fire, defType2: null,
      );
      expect(r.targetPhysDef, isTrue);
      expect(r.isPhysical, isFalse); // still special category
    });
  });

  // ---------------------------------------------------------------
  // Requires defender item
  // ---------------------------------------------------------------

  group('Requires defender item', () {
    test('fails when defender has no item', () {
      const poltergeist = Move(
        name: 'Poltergeist', nameKo: '폴터가이스트', nameJa: 'ポルターガイスト',
        type: PokemonType.ghost, category: MoveCategory.physical,
        power: 110, accuracy: 90, pp: 5, tags: [MoveTags.requiresDefItem],
      );
      final r = calc(
        move: poltergeist,
        defType1: PokemonType.fire, defType2: null,
      );
      expect(r.maxDamage, equals(0));
    });
  });

  // ---------------------------------------------------------------
  // Defender Terastal type override
  // ---------------------------------------------------------------

  group('Defender Terastal', () {
    test('overrides defender type for effectiveness', () {
      // Defender is grass but Tera fire -> fire vs fire = NVE
      final def = BattlePokemonState(
        type1: PokemonType.grass, type2: null,
        terastal: TerastalState(active: true, teraType: PokemonType.fire),
      );
      final atk = BattlePokemonState(
        moves: [ember, null, null, null],
      );
      final r = DamageCalculator.calculate(
        attacker: atk, defender: def, moveIndex: 0,
        weather: Weather.none, terrain: Terrain.none,
        room: const RoomConditions(),
      );
      expect(r.effectiveness, equals(0.5)); // fire vs fire
    });
  });

  group('Struggle (typeless)', () {
    const struggle = Move(
      name: 'Struggle', nameKo: '발버둥', nameJa: 'わるあがき',
      type: PokemonType.typeless, category: MoveCategory.physical,
      power: 50, accuracy: 0, pp: 1,
    );

    test('deals positive damage', () {
      final result = calc(move: struggle);
      expect(result.maxDamage, greaterThan(0));
    });

    test('hits Ghost type (bypasses Normal immunity)', () {
      final result = calc(
        move: struggle,
        defType1: PokemonType.ghost, defType2: null,
      );
      expect(result.maxDamage, greaterThan(0));
      expect(result.effectiveness, equals(1.0));
    });

    test('neutral effectiveness against all types', () {
      final result = calc(
        move: struggle,
        defType1: PokemonType.rock, defType2: PokemonType.steel,
      );
      expect(result.effectiveness, equals(1.0));
    });

    test('no STAB even with matching type', () {
      final withStab = calc(
        move: const Move(
          name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
          type: PokemonType.normal, category: MoveCategory.physical,
          power: 50, accuracy: 100, pp: 35,
        ),
        atkType1: PokemonType.normal, atkType2: null,
        defType1: PokemonType.normal, defType2: null,
        atkAbility: null, defAbility: null,
      );
      final withoutStab = calc(
        move: struggle,
        atkType1: PokemonType.normal, atkType2: null,
        defType1: PokemonType.normal, defType2: null,
        atkAbility: null, defAbility: null,
      );
      expect(withoutStab.maxDamage, lessThan(withStab.maxDamage));
    });
  });
}
