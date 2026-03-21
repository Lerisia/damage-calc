import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/gender.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/ability_effects.dart';

void main() {
  // Common test moves
  const physicalNormal = Move(
    name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
    type: PokemonType.normal, category: MoveCategory.physical,
    power: 40, accuracy: 100, pp: 35, tags: [MoveTags.contact],
  );

  const specialFire = Move(
    name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
    type: PokemonType.fire, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 15,
  );

  const physicalGround = Move(
    name: 'Earthquake', nameKo: '지진', nameJa: 'じしん',
    type: PokemonType.ground, category: MoveCategory.physical,
    power: 100, accuracy: 100, pp: 10,
  );

  const punchMove = Move(
    name: 'Mach Punch', nameKo: '마하펀치', nameJa: 'マッハパンチ',
    type: PokemonType.fighting, category: MoveCategory.physical,
    power: 40, accuracy: 100, pp: 30, tags: [MoveTags.punch, MoveTags.contact],
  );

  const biteMove = Move(
    name: 'Crunch', nameKo: '깨물어부수기', nameJa: 'かみくだく',
    type: PokemonType.dark, category: MoveCategory.physical,
    power: 80, accuracy: 100, pp: 15, tags: [MoveTags.bite, MoveTags.contact],
  );

  const pulseMove = Move(
    name: 'Dark Pulse', nameKo: '악의파동', nameJa: 'あくのはどう',
    type: PokemonType.dark, category: MoveCategory.special,
    power: 80, accuracy: 100, pp: 15, tags: [MoveTags.pulse],
  );

  const sliceMove = Move(
    name: 'Leaf Blade', nameKo: '리프블레이드', nameJa: 'リーフブレード',
    type: PokemonType.grass, category: MoveCategory.physical,
    power: 90, accuracy: 100, pp: 15, tags: [MoveTags.slice, MoveTags.contact],
  );

  const recoilMove = Move(
    name: 'Flare Blitz', nameKo: '플레어드라이브', nameJa: 'フレアドライブ',
    type: PokemonType.fire, category: MoveCategory.physical,
    power: 120, accuracy: 100, pp: 15, tags: [MoveTags.recoil, MoveTags.contact],
  );

  const soundMove = Move(
    name: 'Bug Buzz', nameKo: '벌레의야단법석', nameJa: 'むしのさざめき',
    type: PokemonType.bug, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10, tags: [MoveTags.sound],
  );

  const lowPowerMove = Move(
    name: 'Bullet Seed', nameKo: '씨기관총', nameJa: 'タネマシンガン',
    type: PokemonType.grass, category: MoveCategory.physical,
    power: 25, accuracy: 100, pp: 30,
  );

  const secondaryMove = Move(
    name: 'Ice Beam', nameKo: '냉동빔', nameJa: 'れいとうビーム',
    type: PokemonType.ice, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10, tags: [MoveTags.hasSecondary],
  );

  const waterMove = Move(
    name: 'Surf', nameKo: '파도타기', nameJa: 'なみのり',
    type: PokemonType.water, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 15,
  );

  const steelMove = Move(
    name: 'Flash Cannon', nameKo: '러스터캐논', nameJa: 'ラスターカノン',
    type: PokemonType.steel, category: MoveCategory.special,
    power: 80, accuracy: 100, pp: 10,
  );

  const electricMove = Move(
    name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
    type: PokemonType.electric, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 15,
  );

  const dragonMove = Move(
    name: 'Dragon Pulse', nameKo: '용의파동', nameJa: 'りゅうのはどう',
    type: PokemonType.dragon, category: MoveCategory.special,
    power: 85, accuracy: 100, pp: 10, tags: [MoveTags.pulse],
  );

  const rockMove = Move(
    name: 'Stone Edge', nameKo: '스톤에지', nameJa: 'ストーンエッジ',
    type: PokemonType.rock, category: MoveCategory.physical,
    power: 100, accuracy: 80, pp: 5,
  );

  const grassMove = Move(
    name: 'Energy Ball', nameKo: '에너지볼', nameJa: 'エナジーボール',
    type: PokemonType.grass, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10,
  );

  const bugMove = Move(
    name: 'X-Scissor', nameKo: '시저크로스', nameJa: 'シザークロス',
    type: PokemonType.bug, category: MoveCategory.physical,
    power: 80, accuracy: 100, pp: 15, tags: [MoveTags.slice, MoveTags.contact],
  );

  group('Stat modifier abilities', () {
    test('Huge Power doubles attack', () {
      final effect = getAbilityEffect('Huge Power', move: physicalNormal);
      expect(effect.statModifiers.attack, equals(2.0));
      expect(effect.statModifiers.spAttack, equals(1.0));
    });

    test('Pure Power doubles attack', () {
      final effect = getAbilityEffect('Pure Power', move: physicalNormal);
      expect(effect.statModifiers.attack, equals(2.0));
    });

    test('Huge Power does not affect special moves stat', () {
      final effect = getAbilityEffect('Huge Power', move: specialFire);
      expect(effect.statModifiers.attack, equals(2.0));
      // attack is still 2.0 but calculator uses spAttack for special moves
    });

    test('Gorilla Tactics boosts attack by 1.5x', () {
      final effect = getAbilityEffect('Gorilla Tactics', move: physicalNormal);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Hustle boosts attack by 1.5x', () {
      final effect = getAbilityEffect('Hustle', move: physicalNormal);
      expect(effect.statModifiers.attack, equals(1.5));
    });
  });

  group('Tag-based power abilities', () {
    test('Tough Claws boosts contact moves by 1.3x', () {
      final effect = getAbilityEffect('Tough Claws', move: physicalNormal);
      expect(effect.powerModifier, equals(1.3));
    });

    test('Tough Claws does not boost non-contact moves', () {
      final effect = getAbilityEffect('Tough Claws', move: physicalGround);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Iron Fist boosts punch moves by 1.2x', () {
      final effect = getAbilityEffect('Iron Fist', move: punchMove);
      expect(effect.powerModifier, equals(1.2));
    });

    test('Iron Fist does not boost non-punch moves', () {
      final effect = getAbilityEffect('Iron Fist', move: physicalNormal);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Strong Jaw boosts bite moves by 1.5x', () {
      final effect = getAbilityEffect('Strong Jaw', move: biteMove);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Mega Launcher boosts pulse moves by 1.5x', () {
      final effect = getAbilityEffect('Mega Launcher', move: pulseMove);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Sharpness boosts slice moves by 1.5x', () {
      final effect = getAbilityEffect('Sharpness', move: sliceMove);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Reckless boosts recoil moves by 1.2x', () {
      final effect = getAbilityEffect('Reckless', move: recoilMove);
      expect(effect.powerModifier, equals(1.2));
    });

    test('Punk Rock boosts sound moves by 1.3x', () {
      final effect = getAbilityEffect('Punk Rock', move: soundMove);
      expect(effect.powerModifier, equals(1.3));
    });

    test('Technician boosts moves with power <= 60', () {
      final effect = getAbilityEffect('Technician', move: lowPowerMove);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Technician does not boost moves with power > 60', () {
      final effect = getAbilityEffect('Technician', move: specialFire);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Sheer Force boosts moves with secondary effects', () {
      final effect = getAbilityEffect('Sheer Force', move: secondaryMove);
      expect(effect.powerModifier, equals(1.3));
    });

    test('Sheer Force does not boost moves without secondary effects', () {
      final effect = getAbilityEffect('Sheer Force', move: physicalGround);
      expect(effect.powerModifier, equals(1.0));
    });
  });

  group('STAB override', () {
    test('Adaptability sets STAB to 2.0x', () {
      final effect = getAbilityEffect('Adaptability', move: physicalNormal);
      expect(effect.stabOverride, equals(2.0));
    });
  });

  group('Type-based power abilities', () {
    test('Steelworker boosts steel moves by 1.5x', () {
      final effect = getAbilityEffect('Steelworker', move: steelMove);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Steelworker does not boost non-steel moves', () {
      final effect = getAbilityEffect('Steelworker', move: specialFire);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Transistor boosts electric moves by 1.3x', () {
      final effect = getAbilityEffect('Transistor', move: electricMove);
      expect(effect.powerModifier, equals(1.3));
    });

    test("Dragon\u2019s Maw boosts dragon moves by 1.5x", () {
      final effect = getAbilityEffect("Dragon\u2019s Maw", move: dragonMove);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Rocky Payload boosts rock moves by 1.5x', () {
      final effect = getAbilityEffect('Rocky Payload', move: rockMove);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Water Bubble boosts water moves by 2.0x', () {
      final effect = getAbilityEffect('Water Bubble', move: waterMove);
      expect(effect.powerModifier, equals(2.0));
    });
  });

  group('Weather/Terrain conditional abilities', () {
    test('Solar Power boosts spAttack in sun', () {
      final effect = getAbilityEffect('Solar Power',
          move: specialFire, weather: Weather.sun);
      expect(effect.statModifiers.spAttack, equals(1.5));
    });

    test('Solar Power no effect without sun', () {
      final effect = getAbilityEffect('Solar Power',
          move: specialFire, weather: Weather.none);
      expect(effect.statModifiers.spAttack, equals(1.0));
    });

    test('Sand Force boosts ground/rock/steel in sandstorm', () {
      final effect = getAbilityEffect('Sand Force',
          move: physicalGround, weather: Weather.sandstorm);
      expect(effect.powerModifier, equals(1.3));
    });

    test('Sand Force boosts rock in sandstorm', () {
      final effect = getAbilityEffect('Sand Force',
          move: rockMove, weather: Weather.sandstorm);
      expect(effect.powerModifier, equals(1.3));
    });

    test('Sand Force does not boost fire in sandstorm', () {
      final effect = getAbilityEffect('Sand Force',
          move: specialFire, weather: Weather.sandstorm);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Orichalcum Pulse boosts attack in sun', () {
      final effect = getAbilityEffect('Orichalcum Pulse',
          move: physicalNormal, weather: Weather.sun);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Hadron Engine boosts spAttack in electric terrain', () {
      final effect = getAbilityEffect('Hadron Engine',
          move: electricMove, terrain: Terrain.electric);
      expect(effect.statModifiers.spAttack, equals(1.3));
    });

    test('Flower Gift boosts attack and spDefense in sun', () {
      final effect = getAbilityEffect('Flower Gift',
          move: physicalNormal, weather: Weather.sun);
      expect(effect.statModifiers.attack, equals(1.5));
      expect(effect.statModifiers.spDefense, equals(1.5));
    });
  });

  group('HP conditional abilities', () {
    test('Blaze boosts fire moves at HP <= 33%', () {
      final effect = getAbilityEffect('Blaze',
          move: specialFire, hpPercent: 33);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Blaze no effect at HP > 33%', () {
      final effect = getAbilityEffect('Blaze',
          move: specialFire, hpPercent: 34);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Blaze no effect on non-fire moves', () {
      final effect = getAbilityEffect('Blaze',
          move: waterMove, hpPercent: 10);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Overgrow boosts grass moves at low HP', () {
      final effect = getAbilityEffect('Overgrow',
          move: grassMove, hpPercent: 20);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Torrent boosts water moves at low HP', () {
      final effect = getAbilityEffect('Torrent',
          move: waterMove, hpPercent: 10);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Swarm boosts bug moves at low HP', () {
      final effect = getAbilityEffect('Swarm',
          move: bugMove, hpPercent: 5);
      expect(effect.powerModifier, equals(1.5));
    });
  });

  group('Protosynthesis / Quark Drive', () {
    const highAtkStats = Stats(
      hp: 100, attack: 150, defense: 80,
      spAttack: 100, spDefense: 80, speed: 120,
    );

    const highSpeStats = Stats(
      hp: 100, attack: 80, defense: 80,
      spAttack: 80, spDefense: 80, speed: 150,
    );

    test('Protosynthesis boosts highest stat (attack) in sun', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.sun,
          actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
      expect(effect.statModifiers.speed, equals(1.0));
    });

    test('Protosynthesis boosts speed by 1.5x if highest', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.sun,
          actualStats: highSpeStats);
      expect(effect.statModifiers.speed, equals(1.5));
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Protosynthesis no effect without sun', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.none,
          actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Quark Drive boosts highest stat in electric terrain', () {
      final effect = getAbilityEffect('Quark Drive',
          move: electricMove, terrain: Terrain.electric,
          actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Quark Drive no effect without electric terrain', () {
      final effect = getAbilityEffect('Quark Drive',
          move: electricMove, terrain: Terrain.none,
          actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.0));
    });
  });

  group('Critical override', () {
    test('Sniper sets critical multiplier to 2.25x', () {
      final effect = getAbilityEffect('Sniper', move: physicalNormal);
      expect(effect.criticalOverride, equals(2.25));
    });
  });

  group('Status conditional abilities', () {
    test('Guts boosts attack when burned', () {
      final effect = getAbilityEffect('Guts',
          move: physicalNormal, status: StatusCondition.burn);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Guts boosts attack when paralyzed', () {
      final effect = getAbilityEffect('Guts',
          move: physicalNormal, status: StatusCondition.paralysis);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Guts no effect when healthy', () {
      final effect = getAbilityEffect('Guts',
          move: physicalNormal, status: StatusCondition.none);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Toxic Boost boosts attack when poisoned', () {
      final effect = getAbilityEffect('Toxic Boost',
          move: physicalNormal, status: StatusCondition.poison);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Toxic Boost boosts attack when badly poisoned', () {
      final effect = getAbilityEffect('Toxic Boost',
          move: physicalNormal, status: StatusCondition.badlyPoisoned);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Toxic Boost no effect when burned', () {
      final effect = getAbilityEffect('Toxic Boost',
          move: physicalNormal, status: StatusCondition.burn);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Flare Boost boosts spAttack when burned', () {
      final effect = getAbilityEffect('Flare Boost',
          move: specialFire, status: StatusCondition.burn);
      expect(effect.statModifiers.spAttack, equals(1.5));
    });

    test('Flare Boost no effect when poisoned', () {
      final effect = getAbilityEffect('Flare Boost',
          move: specialFire, status: StatusCondition.poison);
      expect(effect.statModifiers.spAttack, equals(1.0));
    });
  });

  group('Weather/Terrain with harsh conditions', () {
    test('Solar Power boosts spAttack in harsh sun', () {
      final effect = getAbilityEffect('Solar Power',
          move: specialFire, weather: Weather.harshSun);
      expect(effect.statModifiers.spAttack, equals(1.5));
    });

    test('Orichalcum Pulse boosts attack in harsh sun', () {
      final effect = getAbilityEffect('Orichalcum Pulse',
          move: physicalNormal, weather: Weather.harshSun);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Orichalcum Pulse no effect without sun', () {
      final effect = getAbilityEffect('Orichalcum Pulse',
          move: physicalNormal, weather: Weather.none);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Hadron Engine no effect without electric terrain', () {
      final effect = getAbilityEffect('Hadron Engine',
          move: electricMove, terrain: Terrain.none);
      expect(effect.statModifiers.spAttack, equals(1.0));
    });

    test('Flower Gift boosts in harsh sun', () {
      final effect = getAbilityEffect('Flower Gift',
          move: physicalNormal, weather: Weather.harshSun);
      expect(effect.statModifiers.attack, equals(1.5));
      expect(effect.statModifiers.spDefense, equals(1.5));
    });

    test('Flower Gift no effect without sun', () {
      final effect = getAbilityEffect('Flower Gift',
          move: physicalNormal, weather: Weather.rain);
      expect(effect.statModifiers.attack, equals(1.0));
      expect(effect.statModifiers.spDefense, equals(1.0));
    });

    test('Sand Force boosts steel in sandstorm', () {
      final effect = getAbilityEffect('Sand Force',
          move: steelMove, weather: Weather.sandstorm);
      expect(effect.powerModifier, equals(1.3));
    });

    test('Sand Force no effect in non-sandstorm', () {
      final effect = getAbilityEffect('Sand Force',
          move: physicalGround, weather: Weather.sun);
      expect(effect.powerModifier, equals(1.0));
    });
  });

  group('Protosynthesis / Quark Drive with booster-energy', () {
    const highAtkStats = Stats(
      hp: 100, attack: 150, defense: 80,
      spAttack: 100, spDefense: 80, speed: 120,
    );

    const highSpAStats = Stats(
      hp: 100, attack: 80, defense: 80,
      spAttack: 150, spDefense: 80, speed: 120,
    );

    const highDefStats = Stats(
      hp: 100, attack: 80, defense: 150,
      spAttack: 80, spDefense: 80, speed: 120,
    );

    const highSpDStats = Stats(
      hp: 100, attack: 80, defense: 80,
      spAttack: 80, spDefense: 150, speed: 120,
    );

    const highSpeStats = Stats(
      hp: 100, attack: 80, defense: 80,
      spAttack: 80, spDefense: 80, speed: 150,
    );

    test('Protosynthesis activates with booster-energy (no sun)', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.none,
          heldItem: 'booster-energy', actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Protosynthesis inactive without sun or booster-energy', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.none,
          actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Protosynthesis inactive without actualStats', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.sun);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Protosynthesis in harsh sun', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.harshSun,
          actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Quark Drive activates with booster-energy (no terrain)', () {
      final effect = getAbilityEffect('Quark Drive',
          move: electricMove, terrain: Terrain.none,
          heldItem: 'booster-energy', actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Quark Drive inactive without terrain or booster-energy', () {
      final effect = getAbilityEffect('Quark Drive',
          move: electricMove, terrain: Terrain.none,
          actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('boostHighestStat picks spAttack when highest', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: specialFire, weather: Weather.sun,
          actualStats: highSpAStats);
      expect(effect.statModifiers.spAttack, equals(1.3));
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('boostHighestStat picks defense when highest', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.sun,
          actualStats: highDefStats);
      expect(effect.statModifiers.defense, equals(1.3));
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('boostHighestStat picks spDefense when highest', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.sun,
          actualStats: highSpDStats);
      expect(effect.statModifiers.spDefense, equals(1.3));
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('boostHighestStat picks speed (1.5x) when highest', () {
      final effect = getAbilityEffect('Protosynthesis',
          move: physicalNormal, weather: Weather.sun,
          actualStats: highSpeStats);
      expect(effect.statModifiers.speed, equals(1.5));
      expect(effect.statModifiers.attack, equals(1.0));
    });
  });

  group('Tag-based edge cases', () {
    test('Technician boosts exactly 60 power move', () {
      const quickAttack = Move(
        name: 'Quick Attack', nameKo: '전광석화', nameJa: 'でんこうせっか',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 60, accuracy: 100, pp: 30,
      );
      final effect = getAbilityEffect('Technician', move: quickAttack);
      expect(effect.powerModifier, equals(1.5));
    });

    test('Technician does not boost 61 power move', () {
      const move61 = Move(
        name: 'Move61', nameKo: '기술61', nameJa: 'わざ61',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 61, accuracy: 100, pp: 30,
      );
      final effect = getAbilityEffect('Technician', move: move61);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Strong Jaw does not boost non-bite', () {
      final effect = getAbilityEffect('Strong Jaw', move: physicalNormal);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Mega Launcher does not boost non-pulse', () {
      final effect = getAbilityEffect('Mega Launcher', move: physicalNormal);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Sharpness does not boost non-slice', () {
      final effect = getAbilityEffect('Sharpness', move: physicalNormal);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Reckless does not boost non-recoil', () {
      final effect = getAbilityEffect('Reckless', move: physicalNormal);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Punk Rock does not boost non-sound', () {
      final effect = getAbilityEffect('Punk Rock', move: physicalNormal);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Water Bubble does not boost non-water', () {
      final effect = getAbilityEffect('Water Bubble', move: physicalNormal);
      expect(effect.powerModifier, equals(1.0));
    });
  });

  group('Type-based edge cases', () {
    test('Transistor does not boost non-electric', () {
      final effect = getAbilityEffect('Transistor', move: specialFire);
      expect(effect.powerModifier, equals(1.0));
    });

    test("Dragon\u2019s Maw does not boost non-dragon", () {
      final effect = getAbilityEffect("Dragon\u2019s Maw", move: specialFire);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Rocky Payload does not boost non-rock', () {
      final effect = getAbilityEffect('Rocky Payload', move: specialFire);
      expect(effect.powerModifier, equals(1.0));
    });
  });

  group('HP conditional edge cases', () {
    test('Overgrow no effect at HP 34%', () {
      final effect = getAbilityEffect('Overgrow',
          move: grassMove, hpPercent: 34);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Overgrow no effect on non-grass moves at low HP', () {
      final effect = getAbilityEffect('Overgrow',
          move: specialFire, hpPercent: 10);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Torrent no effect at HP 34%', () {
      final effect = getAbilityEffect('Torrent',
          move: waterMove, hpPercent: 34);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Swarm no effect on non-bug moves at low HP', () {
      final effect = getAbilityEffect('Swarm',
          move: specialFire, hpPercent: 5);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Blaze exactly at HP 33% triggers', () {
      final effect = getAbilityEffect('Blaze',
          move: specialFire, hpPercent: 33);
      expect(effect.powerModifier, equals(1.5));
    });
  });

  group('Status conditional edge cases', () {
    test('Guts boosts with poison', () {
      final effect = getAbilityEffect('Guts',
          move: physicalNormal, status: StatusCondition.poison);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Guts boosts with badly poisoned', () {
      final effect = getAbilityEffect('Guts',
          move: physicalNormal, status: StatusCondition.badlyPoisoned);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Guts boosts with sleep', () {
      final effect = getAbilityEffect('Guts',
          move: physicalNormal, status: StatusCondition.sleep);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Guts boosts with freeze', () {
      final effect = getAbilityEffect('Guts',
          move: physicalNormal, status: StatusCondition.freeze);
      expect(effect.statModifiers.attack, equals(1.5));
    });

    test('Toxic Boost no effect when healthy', () {
      final effect = getAbilityEffect('Toxic Boost',
          move: physicalNormal, status: StatusCondition.none);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Flare Boost no effect when healthy', () {
      final effect = getAbilityEffect('Flare Boost',
          move: specialFire, status: StatusCondition.none);
      expect(effect.statModifiers.spAttack, equals(1.0));
    });
  });

  group('Defensive ability effects', () {
    test('Fur Coat doubles defense', () {
      final effect = getDefensiveAbilityEffect('Fur Coat');
      expect(effect.defModifier, equals(2.0));
      expect(effect.spdModifier, equals(1.0));
    });

    test('Ice Scales doubles special defense', () {
      final effect = getDefensiveAbilityEffect('Ice Scales');
      expect(effect.defModifier, equals(1.0));
      expect(effect.spdModifier, equals(2.0));
    });

    test('Fluffy doubles defense', () {
      final effect = getDefensiveAbilityEffect('Fluffy');
      expect(effect.defModifier, equals(2.0));
      expect(effect.spdModifier, equals(1.0));
    });

    test('Marvel Scale boosts defense when statused', () {
      final effect = getDefensiveAbilityEffect('Marvel Scale',
          status: StatusCondition.burn);
      expect(effect.defModifier, equals(1.5));
    });

    test('Marvel Scale boosts defense when paralyzed', () {
      final effect = getDefensiveAbilityEffect('Marvel Scale',
          status: StatusCondition.paralysis);
      expect(effect.defModifier, equals(1.5));
    });

    test('Marvel Scale no effect when healthy', () {
      final effect = getDefensiveAbilityEffect('Marvel Scale',
          status: StatusCondition.none);
      expect(effect.defModifier, equals(1.0));
    });

    test('unknown defensive ability returns default', () {
      final effect = getDefensiveAbilityEffect('Pickup');
      expect(effect.defModifier, equals(1.0));
      expect(effect.spdModifier, equals(1.0));
    });
  });

  group('Speed conditional', () {
    test('Analytic boosts power by 1.3x when slower', () {
      final effect = getAbilityEffect('Analytic', move: physicalNormal,
          actualStats: const Stats(hp: 100, attack: 100, defense: 100,
              spAttack: 100, spDefense: 100, speed: 80),
          opponentSpeed: 100);
      expect(effect.powerModifier, equals(1.3));
    });

    test('Analytic no effect when faster', () {
      final effect = getAbilityEffect('Analytic', move: physicalNormal,
          actualStats: const Stats(hp: 100, attack: 100, defense: 100,
              spAttack: 100, spDefense: 100, speed: 120),
          opponentSpeed: 100);
      expect(effect.powerModifier, equals(1.0));
    });

    test('Analytic no effect at same speed', () {
      final effect = getAbilityEffect('Analytic', move: physicalNormal,
          actualStats: const Stats(hp: 100, attack: 100, defense: 100,
              spAttack: 100, spDefense: 100, speed: 100),
          opponentSpeed: 100);
      expect(effect.powerModifier, equals(1.0));
    });
  });

  group('Rivalry', () {
    test('same gender boosts power by 1.25x', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.male, opponentGender: Gender.male);
      expect(effect.powerModifier, equals(1.25));
    });

    test('same gender female-female boosts by 1.25x', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.female, opponentGender: Gender.female);
      expect(effect.powerModifier, equals(1.25));
    });

    test('different gender reduces power to 0.75x', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.male, opponentGender: Gender.female);
      expect(effect.powerModifier, equals(0.75));
    });

    test('different gender female-male reduces to 0.75x', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.female, opponentGender: Gender.male);
      expect(effect.powerModifier, equals(0.75));
    });

    test('no effect when attacker is genderless', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.genderless, opponentGender: Gender.male);
      expect(effect.powerModifier, equals(1.0));
    });

    test('no effect when defender is genderless', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.male, opponentGender: Gender.genderless);
      expect(effect.powerModifier, equals(1.0));
    });

    test('no effect when both are genderless', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.genderless, opponentGender: Gender.genderless);
      expect(effect.powerModifier, equals(1.0));
    });

    test('no effect when attacker gender is unset', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.unset, opponentGender: Gender.male);
      expect(effect.powerModifier, equals(1.0));
    });

    test('no effect when defender gender is unset', () {
      final effect = getAbilityEffect('Rivalry', move: physicalNormal,
        myGender: Gender.female, opponentGender: Gender.unset);
      expect(effect.powerModifier, equals(1.0));
    });

    test('works with special moves too', () {
      final effect = getAbilityEffect('Rivalry', move: specialFire,
        myGender: Gender.male, opponentGender: Gender.male);
      expect(effect.powerModifier, equals(1.25));
    });
  });

  group('Unknown abilities', () {
    test('unknown ability returns default', () {
      final effect = getAbilityEffect('Pickup', move: physicalNormal);
      expect(effect.statModifiers.attack, equals(1.0));
      expect(effect.powerModifier, equals(1.0));
      expect(effect.stabOverride, isNull);
      expect(effect.criticalOverride, isNull);
    });
  });
}
