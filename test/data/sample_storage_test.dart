import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/data/sample_storage.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  BattlePokemonState makeState(String name) =>
      BattlePokemonState(pokemonName: name, type1: PokemonType.normal);

  group('SampleStorage', () {
    test('saveSample + loadSamples round-trip', () async {
      await SampleStorage.saveSample('Alpha', makeState('pikachu'));
      final samples = await SampleStorage.loadSamples();
      expect(samples.length, equals(1));
      expect(samples.first.name, equals('Alpha'));
      expect(samples.first.state.pokemonName, equals('pikachu'));
    });

    test('sampleExists returns true for existing name', () async {
      await SampleStorage.saveSample('Alpha', makeState('pikachu'));
      expect(await SampleStorage.sampleExists('Alpha'), isTrue);
      expect(await SampleStorage.sampleExists('Beta'), isFalse);
    });

    test('overwriteSample replaces existing entry', () async {
      await SampleStorage.saveSample('Alpha', makeState('pikachu'));
      await SampleStorage.overwriteSample('Alpha', makeState('raichu'));
      final samples = await SampleStorage.loadSamples();
      expect(samples.length, equals(1));
      expect(samples.first.name, equals('Alpha'));
      expect(samples.first.state.pokemonName, equals('raichu'));
    });

    test('overwriteSample does not touch other samples', () async {
      await SampleStorage.saveSample('Alpha', makeState('pikachu'));
      await SampleStorage.saveSample('Beta', makeState('charizard'));
      await SampleStorage.overwriteSample('Alpha', makeState('raichu'));
      final samples = await SampleStorage.loadSamples();
      expect(samples.length, equals(2));
      final alpha = samples.firstWhere((s) => s.name == 'Alpha');
      final beta = samples.firstWhere((s) => s.name == 'Beta');
      expect(alpha.state.pokemonName, equals('raichu'));
      expect(beta.state.pokemonName, equals('charizard'));
    });

    test('overwriteSample when name does not exist acts as save', () async {
      await SampleStorage.overwriteSample('Gamma', makeState('eevee'));
      final samples = await SampleStorage.loadSamples();
      expect(samples.length, equals(1));
      expect(samples.first.name, equals('Gamma'));
    });
  });
}
