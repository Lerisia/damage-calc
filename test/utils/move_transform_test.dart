import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/rank.dart';
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
      power: 55, accuracy: 100, pp: 15, tags: ['custom:double_no_item'],
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
      power: 150, accuracy: 100, pp: 5, tags: ['custom:hp_power_high'],
    );

    const flail = Move(
      name: 'Flail', nameKo: '바둥바둥', nameJa: 'じたばた',
      type: PokemonType.normal, category: MoveCategory.physical,
      power: 0, accuracy: 100, pp: 15, tags: ['custom:hp_power_low'],
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
      power: 70, accuracy: 100, pp: 20, tags: ['custom:terrain_double_electric'],
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
      power: 20, accuracy: 100, pp: 10, tags: ['custom:rank_power'],
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
      power: 70, accuracy: 100, pp: 20, tags: ['custom:facade'],
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
      power: 80, accuracy: 100, pp: 10, tags: ['custom:use_defense'],
    );

    const photonGeyser = Move(
      name: 'Photon Geyser', nameKo: '포톤가이저', nameJa: 'フォトンガイザー',
      type: PokemonType.psychic, category: MoveCategory.special,
      power: 100, accuracy: 100, pp: 5, tags: ['custom:use_higher_atk'],
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
}
