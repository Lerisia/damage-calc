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
    test('Huge Power / Pure Power doubles attack', () {
      final hp = getAbilityEffect('Huge Power', move: physicalNormal);
      final pp = getAbilityEffect('Pure Power', move: physicalNormal);
      expect(hp.statModifiers.attack, equals(2.0));
      expect(pp.statModifiers.attack, equals(2.0));
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
      expect(getAbilityEffect('Tough Claws', move: physicalNormal).powerModifier, equals(1.3));
      expect(getAbilityEffect('Tough Claws', move: physicalGround).powerModifier, equals(1.0));
    });

    test('Iron Fist boosts punch moves by 1.2x', () {
      expect(getAbilityEffect('Iron Fist', move: punchMove).powerModifier, equals(1.2));
      expect(getAbilityEffect('Iron Fist', move: physicalNormal).powerModifier, equals(1.0));
    });

    test('Strong Jaw boosts bite moves by 1.5x', () {
      expect(getAbilityEffect('Strong Jaw', move: biteMove).powerModifier, equals(1.5));
    });

    test('Mega Launcher boosts pulse moves by 1.5x', () {
      expect(getAbilityEffect('Mega Launcher', move: pulseMove).powerModifier, equals(1.5));
    });

    test('Sharpness boosts slice moves by 1.5x', () {
      expect(getAbilityEffect('Sharpness', move: sliceMove).powerModifier, equals(1.5));
    });

    test('Reckless boosts recoil moves by 1.2x', () {
      expect(getAbilityEffect('Reckless', move: recoilMove).powerModifier, equals(1.2));
    });

    test('Punk Rock boosts sound moves by 1.3x', () {
      expect(getAbilityEffect('Punk Rock', move: soundMove).powerModifier, equals(1.3));
    });

    test('Technician boosts moves with power <= 60', () {
      expect(getAbilityEffect('Technician', move: lowPowerMove).powerModifier, equals(1.5));
      expect(getAbilityEffect('Technician', move: specialFire).powerModifier, equals(1.0));
    });

    test('Sheer Force boosts moves with secondary effects', () {
      expect(getAbilityEffect('Sheer Force', move: secondaryMove).powerModifier, equals(1.3));
      expect(getAbilityEffect('Sheer Force', move: physicalGround).powerModifier, equals(1.0));
    });
  });

  group('STAB and type-based', () {
    test('Adaptability sets STAB to 2.0x', () {
      expect(getAbilityEffect('Adaptability', move: physicalNormal).stabOverride, equals(2.0));
    });

    test('Steelworker boosts steel moves by 1.5x', () {
      expect(getAbilityEffect('Steelworker', move: steelMove).powerModifier, equals(1.5));
      expect(getAbilityEffect('Steelworker', move: specialFire).powerModifier, equals(1.0));
    });

    test('Transistor boosts electric moves by 1.3x', () {
      expect(getAbilityEffect('Transistor', move: electricMove).powerModifier, equals(1.3));
    });

    test("Dragon's Maw boosts dragon moves by 1.5x", () {
      expect(getAbilityEffect("Dragon's Maw", move: dragonMove).powerModifier, equals(1.5));
    });

    test('Rocky Payload boosts rock moves by 1.5x', () {
      expect(getAbilityEffect('Rocky Payload', move: rockMove).powerModifier, equals(1.5));
    });

    test('Water Bubble boosts water moves by 2.0x', () {
      expect(getAbilityEffect('Water Bubble', move: waterMove).powerModifier, equals(2.0));
    });
  });

  group('Weather/Terrain conditional abilities', () {
    test('Solar Power boosts spAttack in sun/harsh sun', () {
      expect(getAbilityEffect('Solar Power', move: specialFire, weather: Weather.sun).statModifiers.spAttack, equals(1.5));
      expect(getAbilityEffect('Solar Power', move: specialFire, weather: Weather.harshSun).statModifiers.spAttack, equals(1.5));
      expect(getAbilityEffect('Solar Power', move: specialFire, weather: Weather.none).statModifiers.spAttack, equals(1.0));
    });

    test('Sand Force boosts ground/rock/steel in sandstorm', () {
      expect(getAbilityEffect('Sand Force', move: physicalGround, weather: Weather.sandstorm).powerModifier, equals(1.3));
      expect(getAbilityEffect('Sand Force', move: steelMove, weather: Weather.sandstorm).powerModifier, equals(1.3));
      expect(getAbilityEffect('Sand Force', move: specialFire, weather: Weather.sandstorm).powerModifier, equals(1.0));
      expect(getAbilityEffect('Sand Force', move: physicalGround, weather: Weather.sun).powerModifier, equals(1.0));
    });

    test('Orichalcum Pulse boosts attack in sun/harsh sun', () {
      expect(getAbilityEffect('Orichalcum Pulse', move: physicalNormal, weather: Weather.sun).statModifiers.attack, equals(1.3));
      expect(getAbilityEffect('Orichalcum Pulse', move: physicalNormal, weather: Weather.none).statModifiers.attack, equals(1.0));
    });

    test('Hadron Engine boosts spAttack in electric terrain', () {
      expect(getAbilityEffect('Hadron Engine', move: electricMove, terrain: Terrain.electric).statModifiers.spAttack, equals(1.3));
      expect(getAbilityEffect('Hadron Engine', move: electricMove, terrain: Terrain.none).statModifiers.spAttack, equals(1.0));
    });

    test('Flower Gift boosts attack and spDefense in sun', () {
      final effect = getAbilityEffect('Flower Gift', move: physicalNormal, weather: Weather.sun);
      expect(effect.statModifiers.attack, equals(1.5));
      expect(effect.statModifiers.spDefense, equals(1.5));
      final noSun = getAbilityEffect('Flower Gift', move: physicalNormal, weather: Weather.rain);
      expect(noSun.statModifiers.attack, equals(1.0));
    });
  });

  group('HP conditional abilities', () {
    test('Blaze/Overgrow/Torrent/Swarm boost at HP <= 33%', () {
      expect(getAbilityEffect('Blaze', move: specialFire, hpPercent: 33).powerModifier, equals(1.5));
      expect(getAbilityEffect('Blaze', move: specialFire, hpPercent: 34).powerModifier, equals(1.0));
      expect(getAbilityEffect('Blaze', move: waterMove, hpPercent: 10).powerModifier, equals(1.0));
      expect(getAbilityEffect('Overgrow', move: grassMove, hpPercent: 20).powerModifier, equals(1.5));
      expect(getAbilityEffect('Torrent', move: waterMove, hpPercent: 10).powerModifier, equals(1.5));
      expect(getAbilityEffect('Swarm', move: bugMove, hpPercent: 5).powerModifier, equals(1.5));
    });
  });

  group('Protosynthesis / Quark Drive', () {
    const highAtkStats = Stats(hp: 100, attack: 150, defense: 80, spAttack: 100, spDefense: 80, speed: 120);
    const highSpeStats = Stats(hp: 100, attack: 80, defense: 80, spAttack: 80, spDefense: 80, speed: 150);

    test('Protosynthesis boosts highest stat in sun', () {
      final effect = getAbilityEffect('Protosynthesis', move: physicalNormal, weather: Weather.sun, actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Protosynthesis boosts speed by 1.5x if highest', () {
      final effect = getAbilityEffect('Protosynthesis', move: physicalNormal, weather: Weather.sun, actualStats: highSpeStats);
      expect(effect.statModifiers.speed, equals(1.5));
    });

    test('Protosynthesis activates with booster-energy without sun', () {
      final effect = getAbilityEffect('Protosynthesis', move: physicalNormal, weather: Weather.none, heldItem: 'booster-energy', actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Protosynthesis inactive without sun or booster-energy', () {
      final effect = getAbilityEffect('Protosynthesis', move: physicalNormal, weather: Weather.none, actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.0));
    });

    test('Quark Drive boosts highest stat in electric terrain', () {
      final effect = getAbilityEffect('Quark Drive', move: electricMove, terrain: Terrain.electric, actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });

    test('Quark Drive activates with booster-energy without terrain', () {
      final effect = getAbilityEffect('Quark Drive', move: electricMove, terrain: Terrain.none, heldItem: 'booster-energy', actualStats: highAtkStats);
      expect(effect.statModifiers.attack, equals(1.3));
    });
  });

  group('Critical and status abilities', () {
    test('Sniper sets critical multiplier to 2.25x', () {
      expect(getAbilityEffect('Sniper', move: physicalNormal).criticalOverride, equals(2.25));
    });

    test('Guts boosts attack when statused', () {
      expect(getAbilityEffect('Guts', move: physicalNormal, status: StatusCondition.burn).statModifiers.attack, equals(1.5));
      expect(getAbilityEffect('Guts', move: physicalNormal, status: StatusCondition.none).statModifiers.attack, equals(1.0));
    });

    test('Toxic Boost boosts attack when poisoned only', () {
      expect(getAbilityEffect('Toxic Boost', move: physicalNormal, status: StatusCondition.poison).statModifiers.attack, equals(1.5));
      expect(getAbilityEffect('Toxic Boost', move: physicalNormal, status: StatusCondition.burn).statModifiers.attack, equals(1.0));
    });

    test('Flare Boost boosts spAttack when burned only', () {
      expect(getAbilityEffect('Flare Boost', move: specialFire, status: StatusCondition.burn).statModifiers.spAttack, equals(1.5));
      expect(getAbilityEffect('Flare Boost', move: specialFire, status: StatusCondition.poison).statModifiers.spAttack, equals(1.0));
    });
  });

  group('Defensive ability effects', () {
    test('Fur Coat doubles defense', () {
      final effect = getDefensiveAbilityEffect('Fur Coat');
      expect(effect.defModifier, equals(2.0));
      expect(effect.spdModifier, equals(1.0));
    });

    test('Ice Scales halves special damage via damage multiplier', () {
      final effect = getDefensiveAbilityEffect('Ice Scales');
      expect(effect.spdModifier, equals(1.0));
      final mult = getDefensiveAbilityDamageMultiplier(
          'Ice Scales', move: specialFire);
      expect(mult, equals(0.5));
    });

    test('Fluffy halves contact damage via damage multiplier', () {
      final effect = getDefensiveAbilityEffect('Fluffy');
      expect(effect.defModifier, equals(1.0));
      final mult = getDefensiveAbilityDamageMultiplier(
          'Fluffy', move: physicalNormal);
      expect(mult, equals(0.5));
    });

    test('Marvel Scale boosts defense when statused', () {
      expect(getDefensiveAbilityEffect('Marvel Scale', status: StatusCondition.burn).defModifier, equals(1.5));
      expect(getDefensiveAbilityEffect('Marvel Scale', status: StatusCondition.none).defModifier, equals(1.0));
    });
  });

  group('Analytic', () {
    test('boosts power by 1.3x when slower', () {
      final effect = getAbilityEffect('Analytic', move: physicalNormal,
          actualStats: const Stats(hp: 100, attack: 100, defense: 100, spAttack: 100, spDefense: 100, speed: 80),
          opponentSpeed: 100);
      expect(effect.powerModifier, equals(1.3));
    });

    test('no effect when faster or same speed', () {
      final faster = getAbilityEffect('Analytic', move: physicalNormal,
          actualStats: const Stats(hp: 100, attack: 100, defense: 100, spAttack: 100, spDefense: 100, speed: 120),
          opponentSpeed: 100);
      expect(faster.powerModifier, equals(1.0));
      final same = getAbilityEffect('Analytic', move: physicalNormal,
          actualStats: const Stats(hp: 100, attack: 100, defense: 100, spAttack: 100, spDefense: 100, speed: 100),
          opponentSpeed: 100);
      expect(same.powerModifier, equals(1.0));
    });
  });

  group('Rivalry', () {
    test('same gender boosts by 1.25x', () {
      expect(getAbilityEffect('Rivalry', move: physicalNormal, myGender: Gender.male, opponentGender: Gender.male).powerModifier, equals(1.25));
    });

    test('different gender reduces to 0.75x', () {
      expect(getAbilityEffect('Rivalry', move: physicalNormal, myGender: Gender.male, opponentGender: Gender.female).powerModifier, equals(0.75));
    });

    test('no effect when either is genderless or unset', () {
      expect(getAbilityEffect('Rivalry', move: physicalNormal, myGender: Gender.genderless, opponentGender: Gender.male).powerModifier, equals(1.0));
      expect(getAbilityEffect('Rivalry', move: physicalNormal, myGender: Gender.male, opponentGender: Gender.unset).powerModifier, equals(1.0));
    });
  });

  group('Speed ability modifiers', () {
    test('Swift Swim doubles speed in rain/heavy rain', () {
      expect(getSpeedAbilityModifier('Swift Swim', weather: Weather.rain), equals(2.0));
      expect(getSpeedAbilityModifier('Swift Swim', weather: Weather.heavyRain), equals(2.0));
      expect(getSpeedAbilityModifier('Swift Swim', weather: Weather.sun), equals(1.0));
    });

    test('Chlorophyll doubles speed in sun/harsh sun', () {
      expect(getSpeedAbilityModifier('Chlorophyll', weather: Weather.sun), equals(2.0));
      expect(getSpeedAbilityModifier('Chlorophyll', weather: Weather.harshSun), equals(2.0));
      expect(getSpeedAbilityModifier('Chlorophyll', weather: Weather.rain), equals(1.0));
    });

    test('Sand Rush doubles speed in sandstorm', () {
      expect(getSpeedAbilityModifier('Sand Rush', weather: Weather.sandstorm), equals(2.0));
      expect(getSpeedAbilityModifier('Sand Rush', weather: Weather.sun), equals(1.0));
    });

    test('Slush Rush doubles speed in snow', () {
      expect(getSpeedAbilityModifier('Slush Rush', weather: Weather.snow), equals(2.0));
    });

    test('Surge Surfer doubles speed in electric terrain', () {
      expect(getSpeedAbilityModifier('Surge Surfer', terrain: Terrain.electric), equals(2.0));
      expect(getSpeedAbilityModifier('Surge Surfer', terrain: Terrain.grassy), equals(1.0));
    });

    test('Quick Feet 1.5x when statused', () {
      expect(getSpeedAbilityModifier('Quick Feet', status: StatusCondition.burn), equals(1.5));
      expect(getSpeedAbilityModifier('Quick Feet'), equals(1.0));
    });
  });

  group('Type immunity abilities', () {
    test('Volt Absorb immune to electric', () {
      expect(isAbilityTypeImmune('Volt Absorb', PokemonType.electric), isTrue);
    });
    test('Volt Absorb not immune to water', () {
      expect(isAbilityTypeImmune('Volt Absorb', PokemonType.water), isFalse);
    });
    test('Water Absorb immune to water', () {
      expect(isAbilityTypeImmune('Water Absorb', PokemonType.water), isTrue);
    });
    test('Dry Skin immune to water', () {
      expect(isAbilityTypeImmune('Dry Skin', PokemonType.water), isTrue);
    });
    test('Flash Fire immune to fire', () {
      expect(isAbilityTypeImmune('Flash Fire', PokemonType.fire), isTrue);
    });
    test('Sap Sipper immune to grass', () {
      expect(isAbilityTypeImmune('Sap Sipper', PokemonType.grass), isTrue);
    });
    test('Lightning Rod immune to electric', () {
      expect(isAbilityTypeImmune('Lightning Rod', PokemonType.electric), isTrue);
    });
    test('Storm Drain immune to water', () {
      expect(isAbilityTypeImmune('Storm Drain', PokemonType.water), isTrue);
    });
    test('Motor Drive immune to electric', () {
      expect(isAbilityTypeImmune('Motor Drive', PokemonType.electric), isTrue);
    });
    test('Earth Eater immune to ground', () {
      expect(isAbilityTypeImmune('Earth Eater', PokemonType.ground), isTrue);
    });
    test('Well-Baked Body immune to fire', () {
      expect(isAbilityTypeImmune('Well-Baked Body', PokemonType.fire), isTrue);
    });
    test('unrelated ability not immune', () {
      expect(isAbilityTypeImmune('Intimidate', PokemonType.fire), isFalse);
    });
  });

  group('Parental Bond', () {
    test('boosts single-target move by 1.25x', () {
      final effect = getAbilityEffect('Parental Bond', move: physicalNormal);
      expect(effect.powerModifier, equals(1.25));
    });

    test('boosts special move by 1.25x', () {
      final effect = getAbilityEffect('Parental Bond', move: specialFire);
      expect(effect.powerModifier, equals(1.25));
    });

    test('does not boost multi-hit move (Bullet Seed)', () {
      const bulletSeed = Move(
        name: 'Bullet Seed', nameKo: '불릿시드', nameJa: 'タネマシンガン',
        type: PokemonType.grass, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30,
      );
      final effect = getAbilityEffect('Parental Bond', move: bulletSeed);
      expect(effect.powerModifier, equals(1.0));
    });

    test('does not boost multi-hit move (Icicle Spear)', () {
      const icicleSpear = Move(
        name: 'Icicle Spear', nameKo: '고드름침', nameJa: 'つららばり',
        type: PokemonType.ice, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30,
      );
      final effect = getAbilityEffect('Parental Bond', move: icicleSpear);
      expect(effect.powerModifier, equals(1.0));
    });

    test('does not boost Surging Strikes', () {
      const surgingStrikes = Move(
        name: 'Surging Strikes', nameKo: '수류연타', nameJa: 'すいりゅうれんだ',
        type: PokemonType.water, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 5,
      );
      final effect = getAbilityEffect('Parental Bond', move: surgingStrikes);
      expect(effect.powerModifier, equals(1.0));
    });
  });
}
