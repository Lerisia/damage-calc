import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/dynamax.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/rank.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/status.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/utils/move_transform.dart';

void main() {
  const normalMove = Move(
    name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
    type: PokemonType.normal, category: MoveCategory.physical,
    power: 40, accuracy: 100, pp: 35,
  );

  const fireMove = Move(
    name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
    type: PokemonType.fire, category: MoveCategory.special,
    power: 90, accuracy: 100, pp: 15,
  );

  group('Weather Ball', () {
    const weatherBall = Move(
      name: 'Weather Ball', nameKo: '웨더볼', nameJa: 'ウェザーボール',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 50, accuracy: 100, pp: 10,
    );

    test('becomes Fire/100 in sun', () {
      final result = applyWeatherToMove(weatherBall, Weather.sun);
      expect(result.type, equals(PokemonType.fire));
      expect(result.power, equals(100));
    });

    test('becomes Water/100 in rain', () {
      final result = applyWeatherToMove(weatherBall, Weather.rain);
      expect(result.type, equals(PokemonType.water));
      expect(result.power, equals(100));
    });

    test('stays Normal/50 with no weather', () {
      final result = applyWeatherToMove(weatherBall, Weather.none);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(50));
    });
  });

  group('Terrain Pulse', () {
    const terrainPulse = Move(
      name: 'Terrain Pulse', nameKo: '대지의파동', nameJa: 'テレインパルス',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 50, accuracy: 100, pp: 10,
    );

    test('becomes Electric/100 on Electric Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.electric);
      expect(result.type, equals(PokemonType.electric));
      expect(result.power, equals(100));
    });

    test('becomes Fairy/100 on Misty Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.misty);
      expect(result.type, equals(PokemonType.fairy));
      expect(result.power, equals(100));
    });
  });

  group('Skin abilities', () {
    test('Aerilate converts Normal to Flying with 1.2x power', () {
      final result = transformMove(normalMove,
          const MoveContext(ability: 'Aerilate'));
      expect(result.move.type, equals(PokemonType.flying));
      expect(result.move.power, equals(48)); // 40 * 1.2
    });

    test('Pixilate converts Normal to Fairy with 1.2x power', () {
      final result = transformMove(normalMove,
          const MoveContext(ability: 'Pixilate'));
      expect(result.move.type, equals(PokemonType.fairy));
      expect(result.move.power, equals(48));
    });

    test('Refrigerate converts Normal to Ice with 1.2x power', () {
      final result = transformMove(normalMove,
          const MoveContext(ability: 'Refrigerate'));
      expect(result.move.type, equals(PokemonType.ice));
      expect(result.move.power, equals(48));
    });

    test('Galvanize converts Normal to Electric with 1.2x power', () {
      final result = transformMove(normalMove,
          const MoveContext(ability: 'Galvanize'));
      expect(result.move.type, equals(PokemonType.electric));
      expect(result.move.power, equals(48));
    });

    test('Aerilate does not affect non-Normal moves', () {
      final result = transformMove(fireMove,
          const MoveContext(ability: 'Aerilate'));
      expect(result.move.type, equals(PokemonType.fire));
      expect(result.move.power, equals(90));
    });

    test('Normalize converts non-Normal moves to Normal (power unchanged)', () {
      final result = transformMove(fireMove,
          const MoveContext(ability: 'Normalize'));
      expect(result.move.type, equals(PokemonType.normal));
      expect(result.move.power, equals(90)); // power unchanged, 1.2x in ability_effects
    });

    test('Normalize does not change power (1.2x is in ability_effects)', () {
      final result = transformMove(normalMove,
          const MoveContext(ability: 'Normalize'));
      expect(result.move.type, equals(PokemonType.normal));
      expect(result.move.power, equals(40)); // power unchanged here
    });

    test('Skin does not apply after Weather Ball type change', () {
      const weatherBall = Move(
        name: 'Weather Ball', nameKo: '웨더볼', nameJa: 'ウェザーボール',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 50, accuracy: 100, pp: 10,
      );
      final result = transformMove(weatherBall,
          const MoveContext(weather: Weather.sun, ability: 'Aerilate'));
      // Weather Ball becomes Fire first, then Aerilate doesn't apply
      expect(result.move.type, equals(PokemonType.fire));
      expect(result.move.power, equals(100));
    });
  });

  group('Acrobatics', () {
    const acrobatics = Move(
      name: 'Acrobatics', nameKo: '애크러뱃', nameJa: 'アクロバット',
      type: PokemonType.flying, category: MoveCategory.physical,
      power: 55, accuracy: 100, pp: 15, tags: [MoveTags.doubleNoItem],
    );

    test('doubles power without item', () {
      final result = transformMove(acrobatics,
          const MoveContext(hasItem: false));
      expect(result.move.power, equals(110));
    });

    test('normal power with item', () {
      final result = transformMove(acrobatics,
          const MoveContext(hasItem: true));
      expect(result.move.power, equals(55));
    });
  });

  group('HP-based power', () {
    const eruption = Move(
      name: 'Eruption', nameKo: '분화', nameJa: 'ふんか',
      type: PokemonType.fire, category: MoveCategory.special,
      power: 150, accuracy: 100, pp: 5, tags: [MoveTags.hpPowerHigh],
    );

    const flail = Move(
      name: 'Flail', nameKo: '바둥바둥', nameJa: 'じたばた',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 15, tags: [MoveTags.hpPowerLow],
    );

    test('Eruption at full HP = 150', () {
      final result = transformMove(eruption,
          const MoveContext(hpPercent: 100));
      expect(result.move.power, equals(150));
    });

    test('Eruption at 50% HP = 75', () {
      final result = transformMove(eruption,
          const MoveContext(hpPercent: 50));
      expect(result.move.power, equals(75));
    });

    test('Eruption at 1% HP = minimum 1', () {
      final result = transformMove(eruption,
          const MoveContext(hpPercent: 1));
      expect(result.move.power, equals(1));
    });

    test('Flail at full HP = 20', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 100));
      expect(result.move.power, equals(20));
    });

    test('Flail at 5% HP = 150', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 5));
      expect(result.move.power, equals(150));
    });

    test('Flail at 1% HP = 200', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 1));
      expect(result.move.power, equals(200));
    });
  });

  group('Terrain power boosts', () {
    const risingVoltage = Move(
      name: 'Rising Voltage', nameKo: '라이징볼트', nameJa: 'ライジングボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 70, accuracy: 100, pp: 20, tags: [MoveTags.terrainDoubleElectric],
    );

    test('Rising Voltage doubles in Electric Terrain', () {
      final result = transformMove(risingVoltage,
          const MoveContext(terrain: Terrain.electric));
      expect(result.move.power, equals(140));
    });

    test('Rising Voltage normal without terrain', () {
      final result = transformMove(risingVoltage,
          const MoveContext(terrain: Terrain.none));
      expect(result.move.power, equals(70));
    });
  });

  group('Rank-based power', () {
    const storedPower = Move(
      name: 'Stored Power', nameKo: '어시스트파워', nameJa: 'アシストパワー',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 20, accuracy: 100, pp: 10, tags: [MoveTags.rankPower],
    );

    test('base power at no boosts', () {
      final result = transformMove(storedPower,
          const MoveContext(rank: Rank()));
      expect(result.move.power, equals(20));
    });

    test('power with +2 attack +1 speed = 20 + 60', () {
      final result = transformMove(storedPower,
          const MoveContext(rank: Rank(attack: 2, speed: 1)));
      expect(result.move.power, equals(80));
    });

    test('negative ranks do not count', () {
      final result = transformMove(storedPower,
          const MoveContext(rank: Rank(attack: 2, defense: -1)));
      expect(result.move.power, equals(60)); // 20 + 2*20
    });
  });

  group('Facade (status power)', () {
    const facade = Move(
      name: 'Facade', nameKo: '객기', nameJa: 'からげんき',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 70, accuracy: 100, pp: 20, tags: [MoveTags.facade],
    );

    test('doubles power when burned', () {
      final result = transformMove(facade,
          const MoveContext(status: StatusCondition.burn));
      expect(result.move.power, equals(140));
    });

    test('doubles power when poisoned', () {
      final result = transformMove(facade,
          const MoveContext(status: StatusCondition.poison));
      expect(result.move.power, equals(140));
    });

    test('doubles power when paralyzed', () {
      final result = transformMove(facade,
          const MoveContext(status: StatusCondition.paralysis));
      expect(result.move.power, equals(140));
    });

    test('normal power when healthy', () {
      final result = transformMove(facade,
          const MoveContext(status: StatusCondition.none));
      expect(result.move.power, equals(70));
    });

    test('normal power when asleep', () {
      final result = transformMove(facade,
          const MoveContext(status: StatusCondition.sleep));
      expect(result.move.power, equals(70));
    });
  });

  group('Offensive stat selection', () {
    const bodyPress = Move(
      name: 'Body Press', nameKo: '바디프레스', nameJa: 'ボディプレス',
      type: PokemonType.fighting, category: MoveCategory.physical,
      power: 80, accuracy: 100, pp: 10, tags: [MoveTags.useDefense],
    );

    const photonGeyser = Move(
      name: 'Photon Geyser', nameKo: '포톤가이저', nameJa: 'フォトンガイザー',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 100, accuracy: 100, pp: 5, tags: [MoveTags.useHigherAtk],
    );

    test('Body Press uses defense stat', () {
      final result = transformMove(bodyPress, const MoveContext());
      expect(result.offensiveStat, equals(OffensiveStat.defense));
    });

    test('Photon Geyser uses higher attack stat', () {
      final result = transformMove(photonGeyser, const MoveContext());
      expect(result.offensiveStat, equals(OffensiveStat.higherAttack));
    });

    test('normal physical move uses attack', () {
      final result = transformMove(normalMove, const MoveContext());
      expect(result.offensiveStat, equals(OffensiveStat.attack));
    });

    test('normal special move uses spAttack', () {
      final result = transformMove(fireMove, const MoveContext());
      expect(result.offensiveStat, equals(OffensiveStat.spAttack));
    });
  });

  group('Weather Ball additional weathers', () {
    const weatherBall = Move(
      name: 'Weather Ball', nameKo: '웨더볼', nameJa: 'ウェザーボール',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 50, accuracy: 100, pp: 10,
    );

    test('becomes Rock/100 in sandstorm', () {
      final result = applyWeatherToMove(weatherBall, Weather.sandstorm);
      expect(result.type, equals(PokemonType.rock));
      expect(result.power, equals(100));
    });

    test('becomes Ice/100 in snow', () {
      final result = applyWeatherToMove(weatherBall, Weather.snow);
      expect(result.type, equals(PokemonType.ice));
      expect(result.power, equals(100));
    });

    test('becomes fire in harsh sun', () {
      final result = applyWeatherToMove(weatherBall, Weather.harshSun);
      expect(result.type, equals(PokemonType.fire));
      expect(result.power, equals(100));
    });

    test('becomes water in heavy rain', () {
      final result = applyWeatherToMove(weatherBall, Weather.heavyRain);
      expect(result.type, equals(PokemonType.water));
      expect(result.power, equals(100));
    });

    test('stays unchanged in strong winds', () {
      final result = applyWeatherToMove(weatherBall, Weather.strongWinds);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(50));
    });

    test('non-Weather Ball move is not affected by weather', () {
      final result = applyWeatherToMove(normalMove, Weather.sun);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(40));
    });
  });

  group('Terrain Pulse additional terrains', () {
    const terrainPulse = Move(
      name: 'Terrain Pulse', nameKo: '대지의파동', nameJa: 'テレインパルス',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 50, accuracy: 100, pp: 10,
    );

    test('becomes Grass/100 on Grassy Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.grassy);
      expect(result.type, equals(PokemonType.grass));
      expect(result.power, equals(100));
    });

    test('becomes Psychic/100 on Psychic Terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.psychic);
      expect(result.type, equals(PokemonType.psychic));
      expect(result.power, equals(100));
    });

    test('stays Normal/50 with no terrain', () {
      final result = applyTerrainToMove(terrainPulse, Terrain.none);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(50));
    });

    test('non-Terrain Pulse move is not affected by terrain', () {
      final result = applyTerrainToMove(normalMove, Terrain.electric);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(40));
    });
  });

  group('Terrain power boosts additional', () {
    const expandingForce = Move(
      name: 'Expanding Force', nameKo: '와이드포스', nameJa: 'ワイドフォース',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 80, accuracy: 100, pp: 10, tags: [MoveTags.terrainBoostPsychic],
    );

    const mistyExplosion = Move(
      name: 'Misty Explosion', nameKo: '미스트버스트', nameJa: 'ミストバースト',
      type: PokemonType.fairy, category: MoveCategory.special,
      power: 100, accuracy: 100, pp: 5, tags: [MoveTags.terrainBoostMisty],
    );

    test('Expanding Force gets 1.5x in Psychic Terrain', () {
      final result = transformMove(expandingForce,
          const MoveContext(terrain: Terrain.psychic));
      expect(result.move.power, equals(120)); // 80 * 1.5
    });

    test('Expanding Force normal without Psychic Terrain', () {
      final result = transformMove(expandingForce,
          const MoveContext(terrain: Terrain.none));
      expect(result.move.power, equals(80));
    });

    test('Misty Explosion gets 1.5x in Misty Terrain', () {
      final result = transformMove(mistyExplosion,
          const MoveContext(terrain: Terrain.misty));
      expect(result.move.power, equals(150)); // 100 * 1.5
    });

    test('Misty Explosion normal without Misty Terrain', () {
      final result = transformMove(mistyExplosion,
          const MoveContext(terrain: Terrain.none));
      expect(result.move.power, equals(100));
    });
  });

  group('Flail/Reversal power table boundaries', () {
    const flail = Move(
      name: 'Flail', nameKo: '바둥바둥', nameJa: 'じたばた',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 15, tags: [MoveTags.hpPowerLow],
    );

    test('Flail at 69% HP = 20', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 69));
      expect(result.move.power, equals(20));
    });

    test('Flail at 68% HP = 40', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 68));
      expect(result.move.power, equals(40));
    });

    test('Flail at 35% HP = 40', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 35));
      expect(result.move.power, equals(40));
    });

    test('Flail at 34% HP = 80', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 34));
      expect(result.move.power, equals(80));
    });

    test('Flail at 21% HP = 80', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 21));
      expect(result.move.power, equals(80));
    });

    test('Flail at 20% HP = 100', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 20));
      expect(result.move.power, equals(100));
    });

    test('Flail at 10% HP = 100', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 10));
      expect(result.move.power, equals(100));
    });

    test('Flail at 9% HP = 150', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 9));
      expect(result.move.power, equals(150));
    });

    test('Flail at 4% HP = 150', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 4));
      expect(result.move.power, equals(150));
    });

    test('Flail at 3% HP = 200', () {
      final result = transformMove(flail,
          const MoveContext(hpPercent: 3));
      expect(result.move.power, equals(200));
    });
  });

  group('HP-based power edge cases', () {
    const eruption = Move(
      name: 'Eruption', nameKo: '분화', nameJa: 'ふんか',
      type: PokemonType.fire, category: MoveCategory.special,
      power: 150, accuracy: 100, pp: 5, tags: [MoveTags.hpPowerHigh],
    );

    test('Eruption at 0% HP = minimum 1', () {
      final result = transformMove(eruption,
          const MoveContext(hpPercent: 0));
      // max(1, floor(150 * 0 / 100)) = max(1, 0) = 1
      expect(result.move.power, equals(1));
    });

    test('Eruption at 75% HP = 112', () {
      final result = transformMove(eruption,
          const MoveContext(hpPercent: 75));
      expect(result.move.power, equals(112)); // floor(150 * 75 / 100) = 112
    });
  });

  group('Facade additional statuses', () {
    const facade = Move(
      name: 'Facade', nameKo: '객기', nameJa: 'からげんき',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 70, accuracy: 100, pp: 20, tags: [MoveTags.facade],
    );

    test('doubles power when badly poisoned', () {
      final result = transformMove(facade,
          const MoveContext(status: StatusCondition.badlyPoisoned));
      expect(result.move.power, equals(140));
    });

    test('normal power when frozen', () {
      final result = transformMove(facade,
          const MoveContext(status: StatusCondition.freeze));
      expect(result.move.power, equals(70));
    });
  });

  group('Rank-based power edge cases', () {
    const storedPower = Move(
      name: 'Stored Power', nameKo: '어시스트파워', nameJa: 'アシストパワー',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 20, accuracy: 100, pp: 10, tags: [MoveTags.rankPower],
    );

    test('max boosts (+6 all) = 20 + 30*20 = 620', () {
      final result = transformMove(storedPower,
          const MoveContext(rank: Rank(
            attack: 6, defense: 6, spAttack: 6, spDefense: 6, speed: 6,
          )));
      expect(result.move.power, equals(620));
    });

    test('all negative ranks = 20 (no boost)', () {
      final result = transformMove(storedPower,
          const MoveContext(rank: Rank(
            attack: -6, defense: -6, spAttack: -6, spDefense: -6, speed: -6,
          )));
      expect(result.move.power, equals(20));
    });

    test('mixed positive and negative only counts positive', () {
      final result = transformMove(storedPower,
          const MoveContext(rank: Rank(
            attack: 3, defense: -2, spAttack: 1, spDefense: -3, speed: 0,
          )));
      // positive: 3 + 1 = 4, power = 20 + 4*20 = 100
      expect(result.move.power, equals(100));
    });
  });

  group('TransformedMove.resolveStat', () {
    const testStats = Stats(
      hp: 300, attack: 150, defense: 200,
      spAttack: 180, spDefense: 100, speed: 120,
    );

    test('attack returns attack stat', () {
      final tm = TransformedMove(normalMove, OffensiveStat.attack);
      expect(tm.resolveStat(testStats), equals(150));
    });

    test('spAttack returns spAttack stat', () {
      final tm = TransformedMove(fireMove, OffensiveStat.spAttack);
      expect(tm.resolveStat(testStats), equals(180));
    });

    test('defense returns defense stat', () {
      final tm = TransformedMove(normalMove, OffensiveStat.defense);
      expect(tm.resolveStat(testStats), equals(200));
    });

    test('higherAttack returns max of attack and spAttack', () {
      final tm = TransformedMove(normalMove, OffensiveStat.higherAttack);
      expect(tm.resolveStat(testStats), equals(180)); // max(150, 180)
    });

    test('higherAttack returns attack when attack > spAttack', () {
      const highAtkStats = Stats(
        hp: 300, attack: 200, defense: 100,
        spAttack: 150, spDefense: 100, speed: 120,
      );
      final tm = TransformedMove(normalMove, OffensiveStat.higherAttack);
      expect(tm.resolveStat(highAtkStats), equals(200));
    });
  });

  group('Skin does not apply to Terrain Pulse after type change', () {
    test('Terrain Pulse on Electric Terrain with Pixilate stays Electric', () {
      const terrainPulse = Move(
        name: 'Terrain Pulse', nameKo: '대지의파동', nameJa: 'テレインパルス',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 50, accuracy: 100, pp: 10,
      );
      final result = transformMove(terrainPulse,
          const MoveContext(terrain: Terrain.electric, ability: 'Pixilate'));
      expect(result.move.type, equals(PokemonType.electric));
      // 50 * 2 (terrain pulse) = 100 (1.3x terrain boost is NOT in transform)
      expect(result.move.power, equals(100));
    });
  });

  group('Speed-based power', () {
    const gyroBall = Move(
      name: 'Gyro Ball', nameKo: '자이로볼', nameJa: 'ジャイロボール',
      type: PokemonType.steel, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 5,
      tags: [MoveTags.contact, 'ball', MoveTags.gyroSpeed],
    );

    const electroBall = Move(
      name: 'Electro Ball', nameKo: '일렉트릭볼', nameJa: 'エレキボール',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 0, accuracy: 100, pp: 10,
      tags: ['ball', MoveTags.electroSpeed],
    );

    test('Gyro Ball: slow user vs fast target = high power', () {
      // 25 * 200 / 50 + 1 = 101
      final result = transformMove(gyroBall,
          const MoveContext(mySpeed: 50, opponentSpeed: 200));
      expect(result.move.power, equals(101));
    });

    test('Gyro Ball: caps at 150', () {
      // 25 * 300 / 10 + 1 = 751 -> capped to 150
      final result = transformMove(gyroBall,
          const MoveContext(mySpeed: 10, opponentSpeed: 300));
      expect(result.move.power, equals(150));
    });

    test('Gyro Ball: same speed = low power', () {
      // 25 * 100 / 100 + 1 = 26
      final result = transformMove(gyroBall,
          const MoveContext(mySpeed: 100, opponentSpeed: 100));
      expect(result.move.power, equals(26));
    });

    test('Gyro Ball: no speed data keeps original power', () {
      final result = transformMove(gyroBall, const MoveContext());
      expect(result.move.power, equals(0));
    });

    test('Electro Ball: 4x faster = 150 power', () {
      final result = transformMove(electroBall,
          const MoveContext(mySpeed: 400, opponentSpeed: 100));
      expect(result.move.power, equals(150));
    });

    test('Electro Ball: 3x faster = 120 power', () {
      final result = transformMove(electroBall,
          const MoveContext(mySpeed: 300, opponentSpeed: 100));
      expect(result.move.power, equals(120));
    });

    test('Electro Ball: 2x faster = 80 power', () {
      final result = transformMove(electroBall,
          const MoveContext(mySpeed: 200, opponentSpeed: 100));
      expect(result.move.power, equals(80));
    });

    test('Electro Ball: less than 2x faster = 60 power', () {
      final result = transformMove(electroBall,
          const MoveContext(mySpeed: 150, opponentSpeed: 100));
      expect(result.move.power, equals(60));
    });

    test('Electro Ball: same speed = 60 power', () {
      final result = transformMove(electroBall,
          const MoveContext(mySpeed: 100, opponentSpeed: 100));
      expect(result.move.power, equals(60));
    });
  });

  // ====== Dynamax Tests ======
  group('Dynamax transform', () {
    // Standard power conversion
    test('Tackle (40) -> Max Strike (90)', () {
      final result = transformMove(normalMove,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이어택'));
      expect(result.move.power, equals(90));
      expect(result.move.type, equals(PokemonType.normal));
    });

    test('Flamethrower (90) -> Max Flare (130)', () {
      final result = transformMove(fireMove,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이번'));
      expect(result.move.power, equals(130));
    });

    test('fire move 130 power -> Max Flare (150)', () {
      const overheat = Move(
        name: 'Overheat', nameKo: '오버히트', nameJa: 'オーバーヒート',
        type: PokemonType.fire, category: MoveCategory.special,
        power: 130, accuracy: 90, pp: 5,
      );
      final result = transformMove(overheat,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(150));
    });

    // Fighting/Poison reduced power
    test('Close Combat (120) -> Max Knuckle (95)', () {
      const closeCombat = Move(
        name: 'Close Combat', nameKo: '인파이트', nameJa: 'インファイト',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 120, accuracy: 100, pp: 5,
      );
      final result = transformMove(closeCombat,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이너클'));
      expect(result.move.power, equals(95));
    });

    test('Sludge Bomb (90) -> Max Ooze (90)', () {
      const sludgeBomb = Move(
        name: 'Sludge Bomb', nameKo: '오물폭탄', nameJa: 'ヘドロばくだん',
        type: PokemonType.poison, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
      );
      final result = transformMove(sludgeBomb,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이애시드'));
      expect(result.move.power, equals(90));
    });

    // Type-specific Max Move names
    test('Grass move -> 다이그래스', () {
      const grassMove = Move(
        name: 'Energy Ball', nameKo: '에너지볼', nameJa: 'エナジーボール',
        type: PokemonType.grass, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
      );
      final result = transformMove(grassMove,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이그래스'));
    });

    test('Ghost move -> 다이할로우', () {
      const shadowBall = Move(
        name: 'Shadow Ball', nameKo: '섀도볼', nameJa: 'シャドーボール',
        type: PokemonType.ghost, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15,
      );
      final result = transformMove(shadowBall,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이할로우'));
    });

    test('Dragon move -> 다이드라군', () {
      const dragonPulse = Move(
        name: 'Dragon Pulse', nameKo: '용의파동', nameJa: 'りゅうのはどう',
        type: PokemonType.dragon, category: MoveCategory.special,
        power: 85, accuracy: 100, pp: 10,
      );
      final result = transformMove(dragonPulse,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이드라군'));
    });

    test('Dark move -> 다이아크', () {
      const darkPulse = Move(
        name: 'Dark Pulse', nameKo: '악의파동', nameJa: 'あくのはどう',
        type: PokemonType.dark, category: MoveCategory.special,
        power: 80, accuracy: 100, pp: 15,
      );
      final result = transformMove(darkPulse,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이아크'));
    });

    // Special move handling
    test('OHKO move -> fixed max power 130', () {
      const fissure = Move(
        name: 'Fissure', nameKo: '땅가르기', nameJa: 'じわれ',
        type: PokemonType.ground, category: MoveCategory.physical,
        power: 0, accuracy: 30, pp: 5,
        tags: ['custom:ohko'],
      );
      final result = transformMove(fissure,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
      expect(result.move.nameKo, equals('다이어스'));
    });

    test('Multi-hit move (Icicle Spear 25) -> fixed max power 130', () {
      const icicleSpear = Move(
        name: 'Icicle Spear', nameKo: '고드름침', nameJa: 'つららばり',
        type: PokemonType.ice, category: MoveCategory.physical,
        power: 25, accuracy: 100, pp: 30,
        minHits: 2, maxHits: 5,
      );
      final result = transformMove(icicleSpear,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });

    test('Variable power move (Flail) -> fixed max power 130', () {
      const flail = Move(
        name: 'Flail', nameKo: '바둥바둥', nameJa: 'じたばた',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 15,
        tags: [MoveTags.hpPowerLow],
      );
      final result = transformMove(flail,
          const MoveContext(dynamax: DynamaxState.dynamax, hpPercent: 10));
      expect(result.move.power, equals(130));
    });

    // Status move -> Max Guard
    test('Status move -> Max Guard with 0 power', () {
      const swordsD = Move(
        name: 'Swords Dance', nameKo: '칼춤', nameJa: 'つるぎのまい',
        type: PokemonType.normal, category: MoveCategory.status,
        power: 0, accuracy: 100, pp: 20,
      );
      final result = transformMove(swordsD,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.nameKo, equals('다이월'));
      expect(result.move.power, equals(0));
    });

    // No transform when not dynamaxed
    test('No transform when dynamax is none', () {
      final result = transformMove(normalMove, const MoveContext());
      expect(result.move.nameKo, equals('몸통박치기'));
      expect(result.move.power, equals(40));
    });

    // G-Max moves
    test('Charizard fire move -> G-Max Wildfire (거다이옥염)', () {
      final result = transformMove(fireMove,
          const MoveContext(dynamax: DynamaxState.gigantamax, pokemonName: 'Charizard'));
      expect(result.move.nameKo, equals('거다이옥염'));
      expect(result.move.power, equals(130)); // 90 -> 130
    });

    test('Charizard non-fire move -> regular Max Move', () {
      final result = transformMove(normalMove,
          const MoveContext(dynamax: DynamaxState.gigantamax, pokemonName: 'Charizard'));
      expect(result.move.nameKo, equals('다이어택'));
    });

    test('Venusaur grass move -> G-Max Vine Lash at 160 power', () {
      const grassMove = Move(
        name: 'Energy Ball', nameKo: '에너지볼', nameJa: 'エナジーボール',
        type: PokemonType.grass, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 10,
      );
      final result = transformMove(grassMove,
          const MoveContext(dynamax: DynamaxState.gigantamax, pokemonName: 'Venusaur'));
      expect(result.move.nameKo, equals('거다이편달'));
      expect(result.move.power, equals(160));
    });

    test('Regular dynamax for Charizard (not gigantamax) -> normal Max Move', () {
      final result = transformMove(fireMove,
          const MoveContext(dynamax: DynamaxState.dynamax, pokemonName: 'Charizard'));
      expect(result.move.nameKo, equals('다이번'));
    });

    // Skin + Dynamax interaction
    test('Pixilate Normal move -> Fairy type -> Max Starfall', () {
      final result = transformMove(normalMove,
          const MoveContext(dynamax: DynamaxState.dynamax, ability: 'Pixilate'));
      expect(result.move.type, equals(PokemonType.fairy));
      expect(result.move.nameKo, equals('다이페어리'));
    });

    // Weather Ball + Dynamax
    test('Weather Ball in sun -> Fire -> Max Flare', () {
      const weatherBall = Move(
        name: 'Weather Ball', nameKo: '웨더볼', nameJa: 'ウェザーボール',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 50, accuracy: 100, pp: 10,
      );
      final result = transformMove(weatherBall,
          const MoveContext(dynamax: DynamaxState.dynamax, weather: Weather.sun));
      expect(result.move.type, equals(PokemonType.fire));
      expect(result.move.nameKo, equals('다이번'));
    });
  });

  group('Foul Play (useOpponentAtk)', () {
    const foulPlay = Move(
      name: 'Foul Play', nameKo: '이판사판', nameJa: 'イカサマ',
      type: PokemonType.dark, category: MoveCategory.physical,
      power: 95, accuracy: 100, pp: 15,
      tags: [MoveTags.useOpponentAtk],
    );

    test('uses opponentAttack stat', () {
      final result = transformMove(foulPlay, const MoveContext());
      expect(result.offensiveStat, equals(OffensiveStat.opponentAttack));
    });

    test('resolveStat returns opponentAttack when provided', () {
      const stats = Stats(
        hp: 300, attack: 100, defense: 100,
        spAttack: 100, spDefense: 100, speed: 100,
      );
      final tm = TransformedMove(foulPlay, OffensiveStat.opponentAttack);
      expect(tm.resolveStat(stats, opponentAttack: 200), equals(200));
    });

    test('resolveStat falls back to own attack when opponentAttack is null', () {
      const stats = Stats(
        hp: 300, attack: 150, defense: 100,
        spAttack: 100, spDefense: 100, speed: 100,
      );
      final tm = TransformedMove(foulPlay, OffensiveStat.opponentAttack);
      expect(tm.resolveStat(stats), equals(150));
    });
  });

  group('Tera Blast', () {
    const teraBlast = Move(
      name: 'Tera Blast', nameKo: '테라버스트', nameJa: 'テラバースト',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 80, accuracy: 100, pp: 10,
    );

    test('changes type to tera type when terastallized', () {
      final result = transformMove(teraBlast,
          const MoveContext(terastallized: true, teraType: PokemonType.fire));
      expect(result.move.type, equals(PokemonType.fire));
      expect(result.move.power, equals(80));
    });

    test('becomes physical when Attack > SpAttack', () {
      final result = transformMove(teraBlast,
          const MoveContext(
            terastallized: true, teraType: PokemonType.water,
            actualAttack: 200, actualSpAttack: 100,
          ));
      expect(result.move.type, equals(PokemonType.water));
      expect(result.move.category, equals(MoveCategory.physical));
    });

    test('stays special when SpAttack >= Attack', () {
      final result = transformMove(teraBlast,
          const MoveContext(
            terastallized: true, teraType: PokemonType.water,
            actualAttack: 100, actualSpAttack: 200,
          ));
      expect(result.move.category, equals(MoveCategory.special));
    });

    test('Stellar tera: power becomes 100, type stays Normal', () {
      final result = transformMove(teraBlast,
          const MoveContext(
            terastallized: true, teraType: PokemonType.stellar,
          ));
      expect(result.move.power, equals(100));
      // Stellar Tera Blast keeps Normal type
    });

    test('Stellar tera: becomes physical when Attack > SpAttack', () {
      final result = transformMove(teraBlast,
          const MoveContext(
            terastallized: true, teraType: PokemonType.stellar,
            actualAttack: 200, actualSpAttack: 100,
          ));
      expect(result.move.power, equals(100));
      expect(result.move.category, equals(MoveCategory.physical));
    });

    test('not terastallized: no change', () {
      final result = transformMove(teraBlast, const MoveContext());
      expect(result.move.type, equals(PokemonType.normal));
      expect(result.move.power, equals(80));
    });
  });

  group('Tera Starstorm', () {
    const teraStarstorm = Move(
      name: 'Tera Starstorm', nameKo: '테라클러스터', nameJa: 'テラクラスター',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 120, accuracy: 100, pp: 5,
    );

    test('becomes Stellar type for Terapagos', () {
      final result = transformMove(teraStarstorm,
          const MoveContext(pokemonName: 'Terapagos'));
      expect(result.move.type, equals(PokemonType.stellar));
    });

    test('becomes physical when Attack > SpAttack for Terapagos', () {
      final result = transformMove(teraStarstorm,
          const MoveContext(
            pokemonName: 'Terapagos-Stellar',
            actualAttack: 200, actualSpAttack: 100,
          ));
      expect(result.move.type, equals(PokemonType.stellar));
      expect(result.move.category, equals(MoveCategory.physical));
    });

    test('stays special for Terapagos when SpAttack >= Attack', () {
      final result = transformMove(teraStarstorm,
          const MoveContext(
            pokemonName: 'Terapagos',
            actualAttack: 100, actualSpAttack: 200,
          ));
      expect(result.move.category, equals(MoveCategory.special));
    });

    test('no change for non-Terapagos', () {
      final result = transformMove(teraStarstorm,
          const MoveContext(pokemonName: 'Arceus'));
      expect(result.move.type, equals(PokemonType.normal));
    });
  });

  group('Liquid Voice', () {
    const hyperVoice = Move(
      name: 'Hyper Voice', nameKo: '하이퍼보이스', nameJa: 'ハイパーボイス',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 10, tags: [MoveTags.sound],
    );

    test('sound move becomes Water type', () {
      final result = transformMove(hyperVoice,
          const MoveContext(ability: 'Liquid Voice'));
      expect(result.move.type, equals(PokemonType.water));
    });

    test('non-sound move not affected', () {
      final result = transformMove(fireMove,
          const MoveContext(ability: 'Liquid Voice'));
      expect(result.move.type, equals(PokemonType.fire));
    });
  });

  group('Ivy Cudgel', () {
    const ivyCudgel = Move(
      name: 'Ivy Cudgel', nameKo: '담쟁이곤봉', nameJa: 'ツタこんぼう',
      type: PokemonType.grass, category: MoveCategory.physical,
      power: 100, accuracy: 100, pp: 10,
    );

    test('Wellspring form -> Water type', () {
      final result = transformMove(ivyCudgel,
          const MoveContext(pokemonName: 'Ogerpon-Wellspring'));
      expect(result.move.type, equals(PokemonType.water));
    });

    test('Hearthflame form -> Fire type', () {
      final result = transformMove(ivyCudgel,
          const MoveContext(pokemonName: 'Ogerpon-Hearthflame'));
      expect(result.move.type, equals(PokemonType.fire));
    });

    test('Cornerstone form -> Rock type', () {
      final result = transformMove(ivyCudgel,
          const MoveContext(pokemonName: 'Ogerpon-Cornerstone'));
      expect(result.move.type, equals(PokemonType.rock));
    });

    test('base Ogerpon -> stays Grass', () {
      final result = transformMove(ivyCudgel,
          const MoveContext(pokemonName: 'Ogerpon'));
      expect(result.move.type, equals(PokemonType.grass));
    });
  });

  group('Judgment (Arceus plate)', () {
    const judgment = Move(
      name: 'Judgment', nameKo: '심판', nameJa: 'さばきのつぶて',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 100, accuracy: 100, pp: 10,
    );

    test('flame-plate -> Fire type', () {
      final result = transformMove(judgment,
          const MoveContext(heldItem: 'flame-plate'));
      expect(result.move.type, equals(PokemonType.fire));
    });

    test('no plate -> stays Normal', () {
      final result = transformMove(judgment, const MoveContext());
      expect(result.move.type, equals(PokemonType.normal));
    });

    test('unknown item -> stays Normal', () {
      final result = transformMove(judgment,
          const MoveContext(heldItem: 'choice-band'));
      expect(result.move.type, equals(PokemonType.normal));
    });
  });

  group('Multi-Attack (Silvally memory)', () {
    const multiAttack = Move(
      name: 'Multi-Attack', nameKo: '멀티어택', nameJa: 'マルチアタック',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 120, accuracy: 100, pp: 10,
    );

    test('fire-memory -> Fire type', () {
      final result = transformMove(multiAttack,
          const MoveContext(heldItem: 'fire-memory'));
      expect(result.move.type, equals(PokemonType.fire));
    });

    test('no memory -> stays Normal', () {
      final result = transformMove(multiAttack, const MoveContext());
      expect(result.move.type, equals(PokemonType.normal));
    });

    test('invalid memory -> stays Normal', () {
      final result = transformMove(multiAttack,
          const MoveContext(heldItem: 'choice-band'));
      expect(result.move.type, equals(PokemonType.normal));
    });
  });

  group('Revelation Dance', () {
    const revelationDance = Move(
      name: 'Revelation Dance', nameKo: '풀잎댄스', nameJa: 'めざめるダンス',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15,
    );

    test('matches user primary type', () {
      final result = transformMove(revelationDance,
          const MoveContext(userType1: PokemonType.fire));
      expect(result.move.type, equals(PokemonType.fire));
    });

    test('no user type -> stays Normal', () {
      final result = transformMove(revelationDance, const MoveContext());
      expect(result.move.type, equals(PokemonType.normal));
    });
  });

  group('Aura Wheel (Morpeko)', () {
    const auraWheel = Move(
      name: 'Aura Wheel', nameKo: '오라휠', nameJa: 'オーラぐるま',
      type: PokemonType.electric, category: MoveCategory.physical,
      power: 110, accuracy: 100, pp: 10,
    );

    test('Morpeko base -> Electric type', () {
      final result = transformMove(auraWheel,
          const MoveContext(pokemonName: 'Morpeko'));
      expect(result.move.type, equals(PokemonType.electric));
    });

    test('Morpeko-Hangry -> Dark type', () {
      final result = transformMove(auraWheel,
          const MoveContext(pokemonName: 'Morpeko-Hangry'));
      expect(result.move.type, equals(PokemonType.dark));
    });
  });

  group('Raging Bull (Paldean Tauros)', () {
    const ragingBull = Move(
      name: 'Raging Bull', nameKo: '레이징불', nameJa: 'レイジングブル',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 90, accuracy: 100, pp: 10,
    );

    test('Paldea Combat -> Fighting type', () {
      final result = transformMove(ragingBull,
          const MoveContext(pokemonName: 'Tauros-Paldea-Combat'));
      expect(result.move.type, equals(PokemonType.fighting));
    });

    test('Paldea Blaze -> Fire type', () {
      final result = transformMove(ragingBull,
          const MoveContext(pokemonName: 'Tauros-Paldea-Blaze'));
      expect(result.move.type, equals(PokemonType.fire));
    });

    test('Paldea Aqua -> Water type', () {
      final result = transformMove(ragingBull,
          const MoveContext(pokemonName: 'Tauros-Paldea-Aqua'));
      expect(result.move.type, equals(PokemonType.water));
    });
  });

  group('Long Reach', () {
    const contactMove = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35, tags: [MoveTags.contact],
    );

    test('removes contact tag', () {
      final result = transformMove(contactMove,
          const MoveContext(ability: 'Long Reach'));
      expect(result.move.tags.contains(MoveTags.contact), isFalse);
    });
  });

  group('Gravity boost (Grav Apple)', () {
    const gravApple = Move(
      name: 'Grav Apple', nameKo: '그래비애플', nameJa: 'グラビアップル',
      type: PokemonType.grass, category: MoveCategory.physical,
      power: 80, accuracy: 100, pp: 10, tags: [MoveTags.gravityBoost],
    );

    test('power * 1.5 under gravity', () {
      final result = transformMove(gravApple,
          const MoveContext(gravity: true));
      expect(result.move.power, equals(120)); // 80 * 1.5
    });

    test('normal power without gravity', () {
      final result = transformMove(gravApple,
          const MoveContext(gravity: false));
      expect(result.move.power, equals(80));
    });
  });

  group('Solar Beam/Blade halved in bad weather', () {
    const solarBeam = Move(
      name: 'Solar Beam', nameKo: '솔라빔', nameJa: 'ソーラービーム',
      type: PokemonType.grass, category: MoveCategory.special,
      power: 120, accuracy: 100, pp: 10, tags: [MoveTags.solarHalve],
    );

    test('halved in rain', () {
      final result = transformMove(solarBeam,
          const MoveContext(weather: Weather.rain));
      expect(result.move.power, equals(60));
    });

    test('halved in sandstorm', () {
      final result = transformMove(solarBeam,
          const MoveContext(weather: Weather.sandstorm));
      expect(result.move.power, equals(60));
    });

    test('halved in snow', () {
      final result = transformMove(solarBeam,
          const MoveContext(weather: Weather.snow));
      expect(result.move.power, equals(60));
    });

    test('halved in heavy rain', () {
      final result = transformMove(solarBeam,
          const MoveContext(weather: Weather.heavyRain));
      expect(result.move.power, equals(60));
    });

    test('normal power in sun', () {
      final result = transformMove(solarBeam,
          const MoveContext(weather: Weather.sun));
      expect(result.move.power, equals(120));
    });
  });

  group('Multi-hit total power', () {
    const icicleSpear = Move(
      name: 'Icicle Spear', nameKo: '고드름침', nameJa: 'つららばり',
      type: PokemonType.ice, category: MoveCategory.physical,
      power: 25, accuracy: 100, pp: 30,
      minHits: 2, maxHits: 5,
    );

    test('hit count of 5 applies total power', () {
      final result = transformMove(icicleSpear,
          const MoveContext(hitCount: 5));
      expect(result.move.power, equals(25 * 5)); // 125
    });

    test('hit count of 3 applies total power', () {
      final result = transformMove(icicleSpear,
          const MoveContext(hitCount: 3));
      expect(result.move.power, equals(25 * 3)); // 75
    });

    test('hit count of 1 does not multiply', () {
      final result = transformMove(icicleSpear,
          const MoveContext(hitCount: 1));
      expect(result.move.power, equals(25)); // no multiplication for 1 hit
    });
  });

  group('Snore', () {
    const snore = Move(
      name: 'Snore', nameKo: '코골기', nameJa: 'いびき',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 50, accuracy: 100, pp: 15,
    );

    test('fails (power 0) when not asleep', () {
      final result = transformMove(snore, const MoveContext());
      expect(result.move.power, equals(0));
    });

    test('works normally when asleep', () {
      final result = transformMove(snore,
          const MoveContext(status: StatusCondition.sleep));
      expect(result.move.power, equals(50));
    });
  });

  group('Turn-order power', () {
    const boltBeak = Move(
      name: 'Bolt Beak', nameKo: '잇따르기', nameJa: 'でんげきくちばし',
      type: PokemonType.electric, category: MoveCategory.physical,
      power: 85, accuracy: 100, pp: 10,
    );

    const payback = Move(
      name: 'Payback', nameKo: '보복', nameJa: 'しっぺがえし',
      type: PokemonType.dark, category: MoveCategory.physical,
      power: 50, accuracy: 100, pp: 10,
    );

    const avalanche = Move(
      name: 'Avalanche', nameKo: '눈사태', nameJa: 'ゆきなだれ',
      type: PokemonType.ice, category: MoveCategory.physical,
      power: 60, accuracy: 100, pp: 10,
    );

    const revenge = Move(
      name: 'Revenge', nameKo: '리벤지', nameJa: 'リベンジ',
      type: PokemonType.fighting, category: MoveCategory.physical,
      power: 60, accuracy: 100, pp: 10,
    );

    test('Bolt Beak doubles when faster', () {
      final result = transformMove(boltBeak,
          const MoveContext(mySpeed: 200, opponentSpeed: 100));
      expect(result.move.power, equals(170));
    });

    test('Bolt Beak normal when slower', () {
      final result = transformMove(boltBeak,
          const MoveContext(mySpeed: 50, opponentSpeed: 100));
      expect(result.move.power, equals(85));
    });

    test('Payback doubles when slower', () {
      final result = transformMove(payback,
          const MoveContext(mySpeed: 50, opponentSpeed: 100));
      expect(result.move.power, equals(100));
    });

    test('Payback normal when faster', () {
      final result = transformMove(payback,
          const MoveContext(mySpeed: 200, opponentSpeed: 100));
      expect(result.move.power, equals(50));
    });

    test('Avalanche doubles when slower', () {
      final result = transformMove(avalanche,
          const MoveContext(mySpeed: 50, opponentSpeed: 100));
      expect(result.move.power, equals(120));
    });

    test('Revenge doubles when slower', () {
      final result = transformMove(revenge,
          const MoveContext(mySpeed: 50, opponentSpeed: 100));
      expect(result.move.power, equals(120));
    });
  });

  group('Electro Ball slower than opponent', () {
    const electroBall = Move(
      name: 'Electro Ball', nameKo: '일렉트릭볼', nameJa: 'エレキボール',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 0, accuracy: 100, pp: 10,
      tags: [MoveTags.electroSpeed],
    );

    test('slower than opponent = 40 power', () {
      final result = transformMove(electroBall,
          const MoveContext(mySpeed: 50, opponentSpeed: 100));
      expect(result.move.power, equals(40));
    });
  });

  group('Weight-based power (Heavy Slam / Heat Crash)', () {
    const heavySlam = Move(
      name: 'Heavy Slam', nameKo: '헤비봄버', nameJa: 'ヘビーボンバー',
      type: PokemonType.steel, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 10, tags: [MoveTags.weightRatio],
    );

    test('ratio >= 5 -> 120 power', () {
      final result = transformMove(heavySlam,
          const MoveContext(myWeight: 500, opponentWeight: 100));
      expect(result.move.power, equals(120));
    });

    test('ratio >= 4 -> 100 power', () {
      final result = transformMove(heavySlam,
          const MoveContext(myWeight: 400, opponentWeight: 100));
      expect(result.move.power, equals(100));
    });

    test('ratio >= 3 -> 80 power', () {
      final result = transformMove(heavySlam,
          const MoveContext(myWeight: 300, opponentWeight: 100));
      expect(result.move.power, equals(80));
    });

    test('ratio >= 2 -> 60 power', () {
      final result = transformMove(heavySlam,
          const MoveContext(myWeight: 200, opponentWeight: 100));
      expect(result.move.power, equals(60));
    });

    test('ratio < 2 -> 40 power', () {
      final result = transformMove(heavySlam,
          const MoveContext(myWeight: 150, opponentWeight: 100));
      expect(result.move.power, equals(40));
    });

    test('no opponent weight -> no change', () {
      final result = transformMove(heavySlam,
          const MoveContext(myWeight: 500));
      expect(result.move.power, equals(0));
    });
  });

  group('Weight target power (Low Kick / Grass Knot)', () {
    const lowKick = Move(
      name: 'Low Kick', nameKo: '로킥', nameJa: 'けたぐり',
      type: PokemonType.fighting, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 20, tags: [MoveTags.weightTarget],
    );

    test('>= 200 kg -> 120 power', () {
      final result = transformMove(lowKick,
          const MoveContext(opponentWeight: 200));
      expect(result.move.power, equals(120));
    });

    test('>= 100 kg -> 100 power', () {
      final result = transformMove(lowKick,
          const MoveContext(opponentWeight: 100));
      expect(result.move.power, equals(100));
    });

    test('>= 50 kg -> 80 power', () {
      final result = transformMove(lowKick,
          const MoveContext(opponentWeight: 50));
      expect(result.move.power, equals(80));
    });

    test('>= 25 kg -> 60 power', () {
      final result = transformMove(lowKick,
          const MoveContext(opponentWeight: 25));
      expect(result.move.power, equals(60));
    });

    test('>= 10 kg -> 40 power', () {
      final result = transformMove(lowKick,
          const MoveContext(opponentWeight: 10));
      expect(result.move.power, equals(40));
    });

    test('< 10 kg -> 20 power', () {
      final result = transformMove(lowKick,
          const MoveContext(opponentWeight: 5));
      expect(result.move.power, equals(20));
    });

    test('no opponent weight -> no change', () {
      final result = transformMove(lowKick, const MoveContext());
      expect(result.move.power, equals(0));
    });
  });

  group('Target HP power (Crush Grip / Hard Press)', () {
    const crushGrip = Move(
      name: 'Crush Grip', nameKo: '쥐어짜기', nameJa: 'にぎりつぶす',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 5, tags: [MoveTags.powerByTargetHp120],
    );

    const hardPress = Move(
      name: 'Hard Press', nameKo: '하드프레스', nameJa: 'ハードプレス',
      type: PokemonType.steel, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 10, tags: [MoveTags.powerByTargetHp100],
    );

    test('Crush Grip at 100% opponent HP -> 120', () {
      final result = transformMove(crushGrip,
          const MoveContext(opponentHpPercent: 100));
      expect(result.move.power, equals(120));
    });

    test('Crush Grip at 50% opponent HP -> 60', () {
      final result = transformMove(crushGrip,
          const MoveContext(opponentHpPercent: 50));
      expect(result.move.power, equals(60));
    });

    test('Crush Grip at 1% opponent HP -> 1', () {
      final result = transformMove(crushGrip,
          const MoveContext(opponentHpPercent: 1));
      expect(result.move.power, equals(1));
    });

    test('Hard Press at 100% opponent HP -> 100', () {
      final result = transformMove(hardPress,
          const MoveContext(opponentHpPercent: 100));
      expect(result.move.power, equals(100));
    });

    test('Hard Press at 50% opponent HP -> 50', () {
      final result = transformMove(hardPress,
          const MoveContext(opponentHpPercent: 50));
      expect(result.move.power, equals(50));
    });

    test('no opponent HP -> no change', () {
      final result = transformMove(crushGrip, const MoveContext());
      expect(result.move.power, equals(0));
    });
  });

  group('Dynamax fixed damage moves', () {
    const dragonRage = Move(
      name: 'Dragon Rage', nameKo: '용의분노', nameJa: 'りゅうのいかり',
      type: PokemonType.dragon, category: MoveCategory.special,
      power: 0, accuracy: 100, pp: 10, tags: [MoveTags.fixed40],
    );

    const sonicBoom = Move(
      name: 'Sonic Boom', nameKo: '소닉붐', nameJa: 'ソニックブーム',
      type: PokemonType.normal, category: MoveCategory.special,
      power: 0, accuracy: 90, pp: 20, tags: [MoveTags.fixed20],
    );

    test('fixed40 move -> Max Guard', () {
      final result = transformMove(dragonRage,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.name, equals('Max Guard'));
      expect(result.move.nameKo, equals('다이월'));
      expect(result.move.power, equals(0));
    });

    test('fixed20 move -> Max Guard', () {
      final result = transformMove(sonicBoom,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.name, equals('Max Guard'));
      expect(result.move.power, equals(0));
    });
  });

  group('Dynamax level-based fixed damage', () {
    const nightShade = Move(
      name: 'Night Shade', nameKo: '나이트헤드', nameJa: 'ナイトヘッド',
      type: PokemonType.ghost, category: MoveCategory.special,
      power: 0, accuracy: 100, pp: 15, tags: [MoveTags.fixedLevel],
    );

    const seismicToss = Move(
      name: 'Seismic Toss', nameKo: '지구던지기', nameJa: 'ちきゅうなげ',
      type: PokemonType.fighting, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 20, tags: [MoveTags.fixedLevel],
    );

    test('Night Shade -> Max Phantasm (100)', () {
      final result = transformMove(nightShade,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.name, equals('Max Phantasm'));
      expect(result.move.nameKo, equals('다이할로우'));
      expect(result.move.nameJa, equals('ダイホロウ'));
      expect(result.move.power, equals(100));
    });

    test('Seismic Toss -> Max Knuckle (75)', () {
      final result = transformMove(seismicToss,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.name, equals('Max Knuckle'));
      expect(result.move.nameKo, equals('다이너클'));
      expect(result.move.power, equals(75));
    });
  });

  group('Dynamax EN/JA names', () {
    test('Max Move has correct EN name', () {
      final result = transformMove(normalMove,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.name, equals('Max Strike'));
      expect(result.move.nameJa, equals('ダイアタック'));
    });

    test('Max Move priority is 0', () {
      const quickAttack = Move(
        name: 'Quick Attack', nameKo: '전광석화', nameJa: 'でんこうせっか',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 40, accuracy: 100, pp: 30, priority: 1,
      );
      final result = transformMove(quickAttack,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.priority, equals(0));
    });
  });

  group('Dynamax power table boundaries', () {
    Move makeMove(int power, PokemonType type) => Move(
      name: 'Test', nameKo: 'T', nameJa: 'T',
      type: type, category: MoveCategory.physical,
      power: power, accuracy: 100, pp: 10,
    );

    test('normal type: 50 -> 100', () {
      final result = transformMove(makeMove(50, PokemonType.normal),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(100));
    });

    test('normal type: 60 -> 110', () {
      final result = transformMove(makeMove(60, PokemonType.normal),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(110));
    });

    test('normal type: 70 -> 120', () {
      final result = transformMove(makeMove(70, PokemonType.normal),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(120));
    });

    test('normal type: 100 -> 130', () {
      final result = transformMove(makeMove(100, PokemonType.normal),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });

    test('normal type: 120 -> 140', () {
      final result = transformMove(makeMove(120, PokemonType.normal),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(140));
    });

    test('fighting type: 40 -> 70 (reduced)', () {
      final result = transformMove(makeMove(40, PokemonType.fighting),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(70));
    });

    test('fighting type: 50 -> 75 (reduced)', () {
      final result = transformMove(makeMove(50, PokemonType.fighting),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(75));
    });

    test('fighting type: 60 -> 80 (reduced)', () {
      final result = transformMove(makeMove(60, PokemonType.fighting),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(80));
    });

    test('fighting type: 70 -> 85 (reduced)', () {
      final result = transformMove(makeMove(70, PokemonType.fighting),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(85));
    });

    test('fighting type: 100 -> 90 (reduced)', () {
      final result = transformMove(makeMove(100, PokemonType.fighting),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(90));
    });

    test('poison type: 130 -> 100 (reduced)', () {
      final result = transformMove(makeMove(130, PokemonType.poison),
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(100));
    });
  });

  group('Dynamax fixed power for special moves', () {
    test('fixedHalfHp move -> fixed 100 max power', () {
      const superFang = Move(
        name: 'Super Fang', nameKo: '분노의앞니', nameJa: 'いかりのまえば',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 0, accuracy: 90, pp: 10, tags: [MoveTags.fixedHalfHp],
      );
      final result = transformMove(superFang,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(100));
    });

    test('rankPower move -> fixed 130 max power', () {
      const storedPower = Move(
        name: 'Stored Power', nameKo: '어시스트파워', nameJa: 'アシストパワー',
        type: PokemonType.psychic, category: MoveCategory.special,
        power: 20, accuracy: 100, pp: 10, tags: [MoveTags.rankPower],
      );
      final result = transformMove(storedPower,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });

    test('weightRatio move -> fixed 130 max power', () {
      const heavySlam = Move(
        name: 'Heavy Slam', nameKo: '헤비봄버', nameJa: 'ヘビーボンバー',
        type: PokemonType.steel, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 10, tags: [MoveTags.weightRatio],
      );
      final result = transformMove(heavySlam,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });

    test('weightTarget move -> fixed 130 max power', () {
      const lowKick = Move(
        name: 'Low Kick', nameKo: '로킥', nameJa: 'けたぐり',
        type: PokemonType.fighting, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 20, tags: [MoveTags.weightTarget],
      );
      final result = transformMove(lowKick,
          const MoveContext(dynamax: DynamaxState.dynamax));
      // weightTarget -> fixed 130, but fighting type reduced table doesn't apply
      // because fixed power bypasses table
      expect(result.move.power, equals(130));
    });

    test('powerByTargetHp120 move -> fixed 130 max power', () {
      const crushGrip = Move(
        name: 'Crush Grip', nameKo: '쥐어짜기', nameJa: 'にぎりつぶす',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 5, tags: [MoveTags.powerByTargetHp120],
      );
      final result = transformMove(crushGrip,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });

    test('powerByTargetHp100 move -> fixed 130 max power', () {
      const hardPress = Move(
        name: 'Hard Press', nameKo: '하드프레스', nameJa: 'ハードプレス',
        type: PokemonType.steel, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 10, tags: [MoveTags.powerByTargetHp100],
      );
      final result = transformMove(hardPress,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });

    test('electroSpeed move -> fixed 130 max power', () {
      const electroBall = Move(
        name: 'Electro Ball', nameKo: '일렉트릭볼', nameJa: 'エレキボール',
        type: PokemonType.electric, category: MoveCategory.special,
        power: 0, accuracy: 100, pp: 10, tags: [MoveTags.electroSpeed],
      );
      final result = transformMove(electroBall,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });

    test('gyroSpeed move -> fixed 130 max power', () {
      const gyroBall = Move(
        name: 'Gyro Ball', nameKo: '자이로볼', nameJa: 'ジャイロボール',
        type: PokemonType.steel, category: MoveCategory.physical,
        power: 0, accuracy: 100, pp: 5, tags: [MoveTags.gyroSpeed],
      );
      final result = transformMove(gyroBall,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.power, equals(130));
    });
  });

  group('G-Max move JA names', () {
    test('Charizard G-Max has correct JA name', () {
      final result = transformMove(fireMove,
          const MoveContext(dynamax: DynamaxState.gigantamax, pokemonName: 'Charizard'));
      expect(result.move.nameJa, equals('キョダイゴクエン'));
    });
  });

  group('Dragonize ability', () {
    test('converts Normal move to Dragon with 1.2x power', () {
      final result = transformMove(normalMove,
          const MoveContext(ability: 'Dragonize'));
      expect(result.move.type, equals(PokemonType.dragon));
      expect(result.move.power, equals(48)); // 40 * 1.2
    });

    test('does not affect non-Normal moves', () {
      final result = transformMove(fireMove,
          const MoveContext(ability: 'Dragonize'));
      expect(result.move.type, equals(PokemonType.fire));
      expect(result.move.power, equals(90));
    });
  });

  group('Terrain power: grounding requirements', () {
    const risingVoltage = Move(
      name: 'Rising Voltage', nameKo: '라이징볼트', nameJa: 'ライジングボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 70, accuracy: 100, pp: 20, tags: [MoveTags.terrainDoubleElectric],
    );

    const expandingForce = Move(
      name: 'Expanding Force', nameKo: '와이드포스', nameJa: 'ワイドフォース',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 80, accuracy: 100, pp: 10, tags: [MoveTags.terrainBoostPsychic],
    );

    const mistyExplosion = Move(
      name: 'Misty Explosion', nameKo: '미스트버스트', nameJa: 'ミストバースト',
      type: PokemonType.fairy, category: MoveCategory.special,
      power: 100, accuracy: 100, pp: 5, tags: [MoveTags.terrainBoostMisty],
    );

    test('Rising Voltage no boost when defender not grounded', () {
      final result = transformMove(risingVoltage,
          const MoveContext(terrain: Terrain.electric, defenderGrounded: false));
      expect(result.move.power, equals(70));
    });

    test('Expanding Force no boost when attacker not grounded', () {
      final result = transformMove(expandingForce,
          const MoveContext(terrain: Terrain.psychic, attackerGrounded: false));
      expect(result.move.power, equals(80));
    });

    test('Misty Explosion no boost when attacker not grounded', () {
      final result = transformMove(mistyExplosion,
          const MoveContext(terrain: Terrain.misty, attackerGrounded: false));
      expect(result.move.power, equals(100));
    });

    test('Terrain Pulse not boosted when not grounded', () {
      const terrainPulse = Move(
        name: 'Terrain Pulse', nameKo: '대지의파동', nameJa: 'テレインパルス',
        type: PokemonType.normal, category: MoveCategory.special,
        power: 50, accuracy: 100, pp: 10,
      );
      final result = transformMove(terrainPulse,
          const MoveContext(terrain: Terrain.electric, attackerGrounded: false));
      // Not grounded, so Terrain Pulse doesn't change type
      expect(result.move.type, equals(PokemonType.normal));
      expect(result.move.power, equals(50));
    });
  });

  group('Struggle (typeless)', () {
    const struggle = Move(
      name: 'Struggle', nameKo: '발버둥', nameJa: 'わるあがき',
      type: PokemonType.typeless, category: MoveCategory.physical,
      power: 50, accuracy: 0, pp: 1,
    );

    test('is not converted to Max Move during Dynamax', () {
      final result = transformMove(struggle,
          const MoveContext(dynamax: DynamaxState.dynamax));
      expect(result.move.name, equals('Struggle'));
      expect(result.move.power, equals(50));
    });
  });

  // ====== Z-Move transformation ======

  group('Z-Move generic', () {
    const thunderbolt = Move(
      name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
      type: PokemonType.electric, category: MoveCategory.special,
      power: 90, accuracy: 100, pp: 15, zPower: 175,
    );

    const tackle40z = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35, zPower: 100,
    );

    test('converts to correct Z-Move name and power', () {
      final result = transformMove(thunderbolt, const MoveContext(zMove: true));
      expect(result.move.name, equals('Gigavolt Havoc'));
      expect(result.move.nameKo, equals('스파킹기가볼트'));
      expect(result.move.power, equals(175));
    });

    test('Z-Move has priority 0', () {
      final priorityMove = Move(
        name: 'Quick Attack', nameKo: '전광석화', nameJa: 'でんこうせっか',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 40, accuracy: 100, pp: 30, priority: 1, zPower: 100,
      );
      final result = transformMove(priorityMove, const MoveContext(zMove: true));
      expect(result.move.priority, equals(0));
    });

    test('Z-Move loses all tags', () {
      final contactMove = Move(
        name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
        type: PokemonType.normal, category: MoveCategory.physical,
        power: 40, accuracy: 100, pp: 35,
        tags: [MoveTags.contact], zPower: 100,
      );
      final result = transformMove(contactMove, const MoveContext(zMove: true));
      expect(result.move.tags, isEmpty);
      expect(result.move.hasTag(MoveTags.contact), isFalse);
    });

    test('status move is NOT converted to Z-attack', () {
      const statusMove = Move(
        name: 'Thunder Wave', nameKo: '전자파', nameJa: 'でんじは',
        type: PokemonType.electric, category: MoveCategory.status,
        power: 0, accuracy: 90, pp: 20,
      );
      final result = transformMove(statusMove, const MoveContext(zMove: true));
      expect(result.move.name, equals('Thunder Wave'));
    });

    test('uses zPower field from move data', () {
      final result = transformMove(tackle40z, const MoveContext(zMove: true));
      expect(result.move.power, equals(100));
      expect(result.move.name, equals('Breakneck Blitz'));
    });

    test('type-specific Z-Move names (Korean)', () {
      const fireMove = Move(
        name: 'Flamethrower', nameKo: '화염방사', nameJa: 'かえんほうしゃ',
        type: PokemonType.fire, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 15, zPower: 175,
      );
      final result = transformMove(fireMove, const MoveContext(zMove: true));
      expect(result.move.nameKo, equals('다이내믹풀플레임'));
    });
  });

  group('Z-Move exclusive', () {
    const voltTackle = Move(
      name: 'Volt Tackle', nameKo: '볼트태클', nameJa: 'ボルテッカー',
      type: PokemonType.electric, category: MoveCategory.physical,
      power: 120, accuracy: 100, pp: 15, zPower: 190,
      tags: [MoveTags.contact, MoveTags.recoil],
    );

    const spiritShackle = Move(
      name: 'Spirit Shackle', nameKo: '그림자꿰매기', nameJa: 'かげぬい',
      type: PokemonType.ghost, category: MoveCategory.physical,
      power: 80, accuracy: 100, pp: 10, zPower: 160,
    );

    test('Pikachu + Volt Tackle → Catastropika', () {
      final result = transformMove(voltTackle,
          const MoveContext(zMove: true, pokemonName: 'Pikachu'));
      expect(result.move.name, equals('Catastropika'));
      expect(result.move.power, equals(210));
      expect(result.move.hasTag(MoveTags.contact), isTrue);
      expect(result.move.priority, equals(0));
    });

    test('Pikachu + non-Volt Tackle → generic Z-Move', () {
      const tbolt = Move(
        name: 'Thunderbolt', nameKo: '10만볼트', nameJa: '10まんボルト',
        type: PokemonType.electric, category: MoveCategory.special,
        power: 90, accuracy: 100, pp: 15, zPower: 175,
      );
      final result = transformMove(tbolt,
          const MoveContext(zMove: true, pokemonName: 'Pikachu'));
      expect(result.move.name, equals('Gigavolt Havoc'));
      expect(result.move.power, equals(175));
    });

    test('Decidueye + Spirit Shackle → Sinister Arrow Raid', () {
      final result = transformMove(spiritShackle,
          const MoveContext(zMove: true, pokemonName: 'Decidueye'));
      expect(result.move.name, equals('Sinister Arrow Raid'));
      expect(result.move.power, equals(180));
    });

    test('Non-Decidueye + Spirit Shackle → generic Z-Move', () {
      final result = transformMove(spiritShackle,
          const MoveContext(zMove: true, pokemonName: 'Gengar'));
      expect(result.move.name, equals('Never-Ending Nightmare'));
      expect(result.move.power, equals(160));
    });

    test('Marshadow + Spectral Thief → Soul-Stealing 7-Star Strike', () {
      const spectralThief = Move(
        name: 'Spectral Thief', nameKo: '그림자훔치기', nameJa: 'シャドースチール',
        type: PokemonType.ghost, category: MoveCategory.physical,
        power: 90, accuracy: 100, pp: 10, zPower: 175,
      );
      final result = transformMove(spectralThief,
          const MoveContext(zMove: true, pokemonName: 'Marshadow'));
      expect(result.move.name, equals('Soul-Stealing 7-Star Strike'));
      expect(result.move.power, equals(195));
    });
  });

  group('Z-Move blocked by other gimmicks', () {
    const tackle = Move(
      name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 40, accuracy: 100, pp: 35, zPower: 100,
    );

    test('Z-Move blocked when Dynamaxed', () {
      final result = transformMove(tackle, const MoveContext(
        zMove: true, dynamax: DynamaxState.dynamax,
      ));
      // Dynamax takes priority → Max Strike
      expect(result.move.name, contains('Max'));
    });

    test('Z-Move blocked when Terastallized', () {
      final result = transformMove(tackle, const MoveContext(
        zMove: true, terastallized: true,
      ));
      // Tera blocks Z → original move unchanged
      expect(result.move.name, equals('Tackle'));
    });

    test('Z-Move blocked when Mega Evolved', () {
      final result = transformMove(tackle, const MoveContext(
        zMove: true, isMega: true,
      ));
      // Mega blocks Z → original move unchanged
      expect(result.move.name, equals('Tackle'));
    });

    test('Z-Move works when no gimmick active', () {
      final result = transformMove(tackle, const MoveContext(zMove: true));
      expect(result.move.name, equals('Breakneck Blitz'));
      expect(result.move.power, equals(100));
    });
  });
}
