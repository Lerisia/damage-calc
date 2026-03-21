import 'package:flutter_test/flutter_test.dart';
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

    test('Normalize converts all moves to Normal with 1.2x power', () {
      final result = transformMove(fireMove,
          const MoveContext(ability: 'Normalize'));
      expect(result.move.type, equals(PokemonType.normal));
      expect(result.move.power, equals(108)); // 90 * 1.2
    });

    test('Normalize does not boost already-Normal moves', () {
      final result = transformMove(normalMove,
          const MoveContext(ability: 'Normalize'));
      expect(result.move.type, equals(PokemonType.normal));
      expect(result.move.power, equals(40)); // unchanged
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

    test('stays unchanged in harsh sun', () {
      final result = applyWeatherToMove(weatherBall, Weather.harshSun);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(50));
    });

    test('stays unchanged in heavy rain', () {
      final result = applyWeatherToMove(weatherBall, Weather.heavyRain);
      expect(result.type, equals(PokemonType.normal));
      expect(result.power, equals(50));
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
      expect(result.move.power, equals(100));
    });
  });
}
