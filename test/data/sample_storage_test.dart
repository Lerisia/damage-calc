import 'dart:convert';
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

  // ──────────────────────────────────────────────────────────────
  // Legacy compat — the existing calculator save/load path lives on
  // top of these wrappers, so they need to keep behaving the same
  // way until phase 2 ports them to the typed API.
  // ──────────────────────────────────────────────────────────────
  group('SampleStorage legacy API', () {
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

    test('overwriteSample replaces existing entry, preserves id', () async {
      await SampleStorage.saveSample('Alpha', makeState('pikachu'));
      final before = (await SampleStorage.loadStore()).samples.first;
      await SampleStorage.overwriteSample('Alpha', makeState('raichu'));
      final after = (await SampleStorage.loadStore()).samples;
      expect(after.length, equals(1));
      expect(after.first.id, equals(before.id),
          reason: 'overwrite should keep the same id so team membership '
              'stays intact');
      expect(after.first.state.pokemonName, equals('raichu'));
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

    test('deleteSample by index removes from store and any team', () async {
      await SampleStorage.saveSample('Alpha', makeState('pikachu'));
      await SampleStorage.saveSample('Beta', makeState('charizard'));
      final teamId = await SampleStorage.createTeam('My Team');
      final beta = (await SampleStorage.loadStore())
          .samples
          .firstWhere((s) => s.name == 'Beta');
      await SampleStorage.movePokemon(beta.id, teamId);

      await SampleStorage.deleteSample(1); // Beta
      final store = await SampleStorage.loadStore();
      expect(store.samples.map((s) => s.name), equals(['Alpha']));
      expect(store.teams.first.memberIds, isEmpty,
          reason: 'deleting a pokemon must also clear its team membership');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Migration — pre-existing v1 data must come through intact and
  // land entirely in the loose pool. The migrated form is written
  // back so the next read sees v2.
  // ──────────────────────────────────────────────────────────────
  group('SampleStorage v1 → v2 migration', () {
    test('flat v1 list becomes loose v2 samples', () async {
      // Seed SharedPreferences with a v1 payload directly.
      SharedPreferences.setMockInitialValues({
        'pokemon_samples': jsonEncode([
          {'name': 'Old Alpha', 'state': makeState('pikachu').toJson()},
          {'name': 'Old Beta', 'state': makeState('charizard').toJson()},
        ]),
      });
      final store = await SampleStorage.loadStore();
      expect(store.samples.length, equals(2));
      expect(store.teams, isEmpty);
      expect(store.looseSamples.length, equals(2));
      expect(store.samples.map((s) => s.name).toSet(),
          equals({'Old Alpha', 'Old Beta'}));
      // Each migrated sample gets a unique id.
      final ids = store.samples.map((s) => s.id).toSet();
      expect(ids.length, equals(2),
          reason: 'migration must mint distinct ids per sample');
    });

    test('migration writes v2 form back to storage', () async {
      SharedPreferences.setMockInitialValues({
        'pokemon_samples': jsonEncode([
          {'name': 'Old Alpha', 'state': makeState('pikachu').toJson()},
        ]),
      });
      await SampleStorage.loadStore(); // triggers write-back
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pokemon_samples')!;
      final decoded = jsonDecode(raw);
      expect(decoded, isA<Map>());
      expect(decoded['version'], equals(2));
      expect(decoded['samples'], hasLength(1));
    });

    test('empty / missing storage yields an empty store', () async {
      final store = await SampleStorage.loadStore();
      expect(store.samples, isEmpty);
      expect(store.teams, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Pokemon CRUD via the typed API.
  // ──────────────────────────────────────────────────────────────
  group('SampleStorage pokemon CRUD', () {
    test('savePokemon without teamId puts pokemon in loose pool', () async {
      final id = await SampleStorage.savePokemon(
          name: 'Loose', state: makeState('eevee'));
      final store = await SampleStorage.loadStore();
      expect(store.samples.first.id, equals(id));
      expect(store.looseSamples.first.id, equals(id));
      expect(store.teamOf(id), isNull);
    });

    test('savePokemon with teamId attaches to team', () async {
      final teamId = await SampleStorage.createTeam('A');
      final pid = await SampleStorage.savePokemon(
          name: 'Member', state: makeState('eevee'), teamId: teamId);
      final store = await SampleStorage.loadStore();
      expect(store.teams.first.memberIds, equals([pid]));
      expect(store.teamOf(pid)?.id, equals(teamId));
    });

    test('savePokemon to a full team throws TeamFullException', () async {
      final teamId = await SampleStorage.createTeam('Full');
      for (int i = 0; i < kMaxTeamSize; i++) {
        await SampleStorage.savePokemon(
            name: 'Member $i', state: makeState('eevee'), teamId: teamId);
      }
      expect(
        () => SampleStorage.savePokemon(
            name: 'Overflow', state: makeState('eevee'), teamId: teamId),
        throwsA(isA<TeamFullException>()),
      );
    });

    test('updatePokemon edits name and/or state in place', () async {
      final id = await SampleStorage.savePokemon(
          name: 'A', state: makeState('pikachu'));
      await SampleStorage.updatePokemon(id, name: 'A2');
      var s = (await SampleStorage.loadStore()).sampleById(id)!;
      expect(s.name, equals('A2'));
      expect(s.state.pokemonName, equals('pikachu'));

      await SampleStorage.updatePokemon(id, state: makeState('raichu'));
      s = (await SampleStorage.loadStore()).sampleById(id)!;
      expect(s.name, equals('A2'));
      expect(s.state.pokemonName, equals('raichu'));
    });

    test('deletePokemon also strips it from any owning team', () async {
      final teamId = await SampleStorage.createTeam('A');
      final pid = await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: teamId);
      await SampleStorage.deletePokemon(pid);
      final store = await SampleStorage.loadStore();
      expect(store.samples, isEmpty);
      expect(store.teams.first.memberIds, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Team CRUD.
  // ──────────────────────────────────────────────────────────────
  group('SampleStorage team CRUD', () {
    test('createTeam yields a unique id and persists', () async {
      final a = await SampleStorage.createTeam('Alpha');
      final b = await SampleStorage.createTeam('Beta');
      expect(a, isNot(equals(b)));
      final store = await SampleStorage.loadStore();
      expect(store.teams.map((t) => t.name), equals(['Alpha', 'Beta']));
    });

    test('renameTeam updates the label', () async {
      final id = await SampleStorage.createTeam('Old');
      await SampleStorage.renameTeam(id, 'New');
      final store = await SampleStorage.loadStore();
      expect(store.teams.first.name, equals('New'));
    });

    test('deleteTeam without deleteMembers releases members to loose',
        () async {
      final id = await SampleStorage.createTeam('A');
      final pid = await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: id);
      await SampleStorage.deleteTeam(id);
      final store = await SampleStorage.loadStore();
      expect(store.teams, isEmpty);
      // Pokemon survives; just no longer attached to a team.
      expect(store.samples.length, equals(1));
      expect(store.looseSamples.first.id, equals(pid));
    });

    test('deleteTeam with deleteMembers removes the underlying pokemon',
        () async {
      final id = await SampleStorage.createTeam('A');
      await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: id);
      await SampleStorage.savePokemon(
          name: 'Y', state: makeState('eevee')); // loose, unaffected
      await SampleStorage.deleteTeam(id, deleteMembers: true);
      final store = await SampleStorage.loadStore();
      expect(store.teams, isEmpty);
      expect(store.samples.map((s) => s.name), equals(['Y']));
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Moves — the most likely source of regressions since the call
  // crosses two collections (samples + team.memberIds).
  // ──────────────────────────────────────────────────────────────
  group('SampleStorage movePokemon', () {
    test('loose → team adds to memberIds', () async {
      final teamId = await SampleStorage.createTeam('A');
      final pid = await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'));
      await SampleStorage.movePokemon(pid, teamId);
      final store = await SampleStorage.loadStore();
      expect(store.teams.first.memberIds, equals([pid]));
      expect(store.looseSamples, isEmpty);
    });

    test('team → loose drops from memberIds', () async {
      final teamId = await SampleStorage.createTeam('A');
      final pid = await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: teamId);
      await SampleStorage.movePokemon(pid, null);
      final store = await SampleStorage.loadStore();
      expect(store.teams.first.memberIds, isEmpty);
      expect(store.looseSamples.first.id, equals(pid));
    });

    test('team → another team flips membership atomically', () async {
      final a = await SampleStorage.createTeam('A');
      final b = await SampleStorage.createTeam('B');
      final pid = await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: a);
      await SampleStorage.movePokemon(pid, b);
      final store = await SampleStorage.loadStore();
      expect(store.teams.firstWhere((t) => t.id == a).memberIds, isEmpty);
      expect(store.teams.firstWhere((t) => t.id == b).memberIds,
          equals([pid]));
    });

    test('move to full team throws and leaves source untouched', () async {
      final src = await SampleStorage.createTeam('Src');
      final dst = await SampleStorage.createTeam('Dst');
      final pid = await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: src);
      for (int i = 0; i < kMaxTeamSize; i++) {
        await SampleStorage.savePokemon(
            name: 'F$i', state: makeState('eevee'), teamId: dst);
      }
      expect(
        () => SampleStorage.movePokemon(pid, dst),
        throwsA(isA<TeamFullException>()),
      );
      final store = await SampleStorage.loadStore();
      expect(store.teams.firstWhere((t) => t.id == src).memberIds,
          equals([pid]),
          reason: 'a rejected move must not strip from the source team');
    });

    test('move into the team it is already in is a no-op', () async {
      final teamId = await SampleStorage.createTeam('A');
      final pid = await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: teamId);
      await SampleStorage.movePokemon(pid, teamId);
      final store = await SampleStorage.loadStore();
      expect(store.teams.first.memberIds, equals([pid]));
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Reorder — used by the future drag-and-drop UI; logic is small
  // enough that it gets one happy-path test here.
  // ──────────────────────────────────────────────────────────────
  group('SampleStorage reorderTeamMember', () {
    test('moves member to a new index within the team', () async {
      final teamId = await SampleStorage.createTeam('A');
      final ids = <String>[];
      for (int i = 0; i < 4; i++) {
        ids.add(await SampleStorage.savePokemon(
            name: 'P$i', state: makeState('eevee'), teamId: teamId));
      }
      // Move the first (index 0) to the end (index 3).
      await SampleStorage.reorderTeamMember(teamId, 0, 3);
      final store = await SampleStorage.loadStore();
      expect(
        store.teams.first.memberIds,
        equals([ids[1], ids[2], ids[3], ids[0]]),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Export / import — both v1 and v2 inputs accepted; v2 always
  // emitted.
  // ──────────────────────────────────────────────────────────────
  group('SampleStorage export/import', () {
    test('exportAsJson emits v2 with teams + samples', () async {
      final teamId = await SampleStorage.createTeam('A');
      await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: teamId);
      await SampleStorage.savePokemon(name: 'Y', state: makeState('eevee'));
      final json = await SampleStorage.exportAsJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['version'], equals(2));
      expect((decoded['teams'] as List).length, equals(1));
      expect((decoded['samples'] as List).length, equals(2));
    });

    test('importFromJson accepts v1 list (all loose)', () async {
      final json = jsonEncode([
        {'name': 'A', 'state': makeState('pikachu').toJson()},
        {'name': 'B', 'state': makeState('charizard').toJson()},
      ]);
      final n = await SampleStorage.importFromJson(json);
      expect(n, equals(2));
      final store = await SampleStorage.loadStore();
      expect(store.teams, isEmpty);
      expect(store.samples.map((s) => s.name).toSet(), equals({'A', 'B'}));
    });

    test('importFromJson accepts v2 object with teams', () async {
      // Round-trip through export.
      final teamId = await SampleStorage.createTeam('My Team');
      await SampleStorage.savePokemon(
          name: 'X', state: makeState('eevee'), teamId: teamId);
      final json = await SampleStorage.exportAsJson();

      // Wipe and re-import.
      SharedPreferences.setMockInitialValues({});
      final n = await SampleStorage.importFromJson(json);
      expect(n, equals(1));
      final store = await SampleStorage.loadStore();
      expect(store.teams.first.name, equals('My Team'));
      expect(store.teams.first.memberIds.length, equals(1));
    });
  });
}
