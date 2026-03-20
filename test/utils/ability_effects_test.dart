import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
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
    power: 40, accuracy: 100, pp: 35, tags: ['contact'],
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
    power: 40, accuracy: 100, pp: 30, tags: ['punch', 'contact'],
  );

  const biteMove = Move(
    name: 'Crunch', nameKo: '깨물어부수기', nameJa: 'かみくだく',
    type: PokemonType.dark, category: MoveCategory.physical,
    power: 80, accuracy: 100, pp: 15, tags: ['bite', 'contact'],
  );

  const pulseMove = Move(
    name: 'Dark Pulse', nameKo: '악의파동', nameJa: 'あくのはどう',
    type: PokemonType.dark, category: MoveCategory.special,
    power: 80, accuracy: 100, pp: 15, tags: ['pulse'],
  );

  const sliceMove = Move(
    name: 'Leaf Blade', nameKo: '리프블레이드', nameJa: 'リーフブレード',
    type: PokemonType.grass, category: MoveCategory.physical,
    power: 90, accuracy: 100, pp: 15, tags: ['slice', 'contact'],
  );

  const recoilMove = Move(
    name: 'Flare Blitz', nameKo: '플레어드라이브', nameJa: 'フレアドライブ',
    type: PokemonType.fire, category: MoveCategory.physical,
    power: 120, accuracy: 100, pp: 15, tags: ['recoil', 'contact'],
  );

  const soundMove = Move(
    name: 'Bug Buzz', nameKo: '벌레의야단법석', nameJa: 'むしのさざめき',
    type: PokemonType.bug, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10, tags: ['sound'],
  );

  const lowPowerMove = Move(
    name: 'Bullet Seed', nameKo: '씨기관총', nameJa: 'タネマシンガン',
    type: PokemonType.grass, category: MoveCategory.physical,
    power: 25, accuracy: 100, pp: 30,
  );

  const secondaryMove = Move(
    name: 'Ice Beam', nameKo: '냉동빔', nameJa: 'れいとうビーム',
    type: PokemonType.ice, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 10, tags: ['custom:has_secondary'],
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
    power: 85, accuracy: 100, pp: 10, tags: ['pulse'],
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
    power: 80, accuracy: 100, pp: 15, tags: ['slice', 'contact'],
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

    test("Dragon's Maw boosts dragon moves by 1.5x", () {
      final effect = getAbilityEffect("Dragon's Maw", move: dragonMove);
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
