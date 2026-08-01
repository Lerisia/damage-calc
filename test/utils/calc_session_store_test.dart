import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';
import 'package:damage_calc/utils/aura_effects.dart';
import 'package:damage_calc/utils/calc_session_store.dart';
import 'package:damage_calc/utils/ruin_effects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalcSessionStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('round-trip preserves the session', () async {
      final atk = BattlePokemonState(
        pokemonName: 'Garchomp',
        pokemonNameKo: '한카리아스',
        type1: PokemonType.dragon,
        type2: PokemonType.ground,
        ev: const Stats(hp: 4, attack: 252, defense: 0,
            spAttack: 0, spDefense: 0, speed: 252),
        selectedAbility: 'Rough Skin',
        selectedItem: 'choice-scarf',
        helpingHand: true,
      );
      atk.moves[0] = const Move(
        name: 'Earthquake', nameKo: '지진', nameJa: 'じしん',
        type: PokemonType.ground, category: MoveCategory.physical,
        power: 100, accuracy: 100, pp: 10,
      );
      final def = BattlePokemonState(
        pokemonName: 'Corviknight',
        pokemonNameKo: '아머까오',
        type1: PokemonType.flying,
        type2: PokemonType.steel,
        hpPercent: 73.5,
        reflect: true,
      );

      CalcSessionStore.schedule(
        attacker: atk,
        defender: def,
        weather: Weather.sandstorm,
        terrain: Terrain.electric,
        room: const RoomConditions(trickRoom: true),
        auras: const AuraToggles(fairyAura: true),
        ruins: const RuinToggles(swordOfRuin: true),
      );
      // flush() must persist without waiting out the debounce —
      // this is the lifecycle-pause path.
      await CalcSessionStore.flush();

      final restored = await CalcSessionStore.load();
      expect(restored, isNotNull);
      expect(restored!.attacker.pokemonName, 'Garchomp');
      expect(restored.attacker.ev.attack, 252);
      expect(restored.attacker.selectedItem, 'choice-scarf');
      expect(restored.attacker.helpingHand, isTrue);
      expect(restored.attacker.moves[0]?.name, 'Earthquake');
      expect(restored.defender.pokemonName, 'Corviknight');
      expect(restored.defender.hpPercent, closeTo(73.5, 0.001));
      expect(restored.defender.reflect, isTrue);
      expect(restored.weather, Weather.sandstorm);
      expect(restored.terrain, Terrain.electric);
      expect(restored.room.trickRoom, isTrue);
      expect(restored.auras.fairyAura, isTrue);
      expect(restored.ruins.swordOfRuin, isTrue);
    });

    test('load returns null with nothing saved', () async {
      expect(await CalcSessionStore.load(), isNull);
    });

    test('load returns null on corrupt payload', () async {
      SharedPreferences.setMockInitialValues(
          {'calcSessionV1': 'not json at all {'});
      expect(await CalcSessionStore.load(), isNull);
    });

    test('load returns null on version mismatch', () async {
      SharedPreferences.setMockInitialValues(
          {'calcSessionV1': '{"v": 999}'});
      expect(await CalcSessionStore.load(), isNull);
    });
  });
}
