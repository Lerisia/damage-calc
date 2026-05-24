import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/battle_pokemon.dart';
import '../models/pokemon.dart';
import 'itemdex.dart';
import 'movedex.dart';
import 'poke_paste.dart';
import 'pokedex.dart';

/// Maximum Pokemon a single team can hold. Mirrors the in-game party
/// size so the team coverage screen and the saved-team picker speak
/// the same language.
const int kMaxTeamSize = 6;

/// One saved Pokemon. The `id` is opaque and only used for cross-
/// references (team membership, move/delete operations); the `name`
/// is the user-facing label and is globally unique within the store.
class StoredSample {
  final String id;
  final String name;
  final BattlePokemonState state;

  const StoredSample({
    required this.id,
    required this.name,
    required this.state,
  });

  StoredSample copyWith({String? name, BattlePokemonState? state}) {
    return StoredSample(
      id: id,
      name: name ?? this.name,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'state': state.toJson(),
      };

  factory StoredSample.fromJson(Map<String, dynamic> json) => StoredSample(
        id: json['id'] as String,
        name: json['name'] as String,
        state: BattlePokemonState.fromJson(
            json['state'] as Map<String, dynamic>),
      );
}

/// A folder grouping up to [kMaxTeamSize] saved Pokemon. Members are
/// referenced by id; the `memberIds` order is preserved so the UI can
/// honour user-chosen slot positions.
class TeamFolder {
  final String id;
  final String name;
  final List<String> memberIds;

  const TeamFolder({
    required this.id,
    required this.name,
    required this.memberIds,
  });

  TeamFolder copyWith({String? name, List<String>? memberIds}) {
    return TeamFolder(
      id: id,
      name: name ?? this.name,
      memberIds: memberIds ?? this.memberIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberIds': memberIds,
      };

  factory TeamFolder.fromJson(Map<String, dynamic> json) => TeamFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        memberIds: List<String>.from(json['memberIds'] as List),
      );
}

/// Top-level structure persisted to SharedPreferences. `teams` and
/// `samples` are both flat lists; loose Pokemon (those not in any
/// team) are derived as `samples` minus all `team.memberIds`.
class SampleStore {
  final List<TeamFolder> teams;
  final List<StoredSample> samples;

  const SampleStore({this.teams = const [], this.samples = const []});

  /// Pokemon not in any team — i.e. the "팀 밖" pool.
  List<StoredSample> get looseSamples {
    final assigned = <String>{
      for (final t in teams) ...t.memberIds,
    };
    return samples.where((s) => !assigned.contains(s.id)).toList();
  }

  /// Returns the team containing [pokemonId], or null if loose.
  TeamFolder? teamOf(String pokemonId) {
    for (final t in teams) {
      if (t.memberIds.contains(pokemonId)) return t;
    }
    return null;
  }

  StoredSample? sampleById(String id) {
    for (final s in samples) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Thrown when an operation would push a team past [kMaxTeamSize].
class TeamFullException implements Exception {
  final String teamId;
  TeamFullException(this.teamId);
  @override
  String toString() => 'Team $teamId is full (max $kMaxTeamSize)';
}

class SampleStorage {
  static const _key = 'pokemon_samples';
  static const _schemaVersion = 2;
  static final _rng = Random();

  // ────────────────────────────────────────────────────────────────
  // ID generation — short base-36 strings, prefixed by entity kind
  // for log readability. Microsecond timestamp + 16-bit random gives
  // ~10^15 combinations per second, more than enough since SharedPrefs
  // is single-process.
  // ────────────────────────────────────────────────────────────────
  static String _genId(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = _rng.nextInt(0xFFFFFF).toRadixString(36).padLeft(4, '0');
    return '${prefix}_${ts}_$rand';
  }

  // ────────────────────────────────────────────────────────────────
  // Load / save (raw)
  // ────────────────────────────────────────────────────────────────

  /// Loads the full store, transparently migrating v1 (flat list) data
  /// into v2 by moving all entries to the loose pool. The migrated
  /// v2 form is written back so subsequent reads are fast.
  static Future<SampleStore> loadStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const SampleStore();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        // v1 flat list — migrate.
        final samples = <StoredSample>[];
        for (final entry in decoded) {
          final m = entry as Map<String, dynamic>;
          samples.add(StoredSample(
            id: _genId('p'),
            name: m['name'] as String,
            state: BattlePokemonState.fromJson(
                m['state'] as Map<String, dynamic>),
          ));
        }
        final store = SampleStore(samples: samples);
        await _writeStore(store);
        return store;
      }
      if (decoded is Map<String, dynamic>) {
        final teams = (decoded['teams'] as List? ?? const [])
            .map((e) => TeamFolder.fromJson(e as Map<String, dynamic>))
            .toList();
        final samples = (decoded['samples'] as List? ?? const [])
            .map((e) => StoredSample.fromJson(e as Map<String, dynamic>))
            .toList();
        return SampleStore(teams: teams, samples: samples);
      }
      return const SampleStore();
    } catch (_) {
      return const SampleStore();
    }
  }

  static Future<void> _writeStore(SampleStore store) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'version': _schemaVersion,
      'teams': store.teams.map((t) => t.toJson()).toList(),
      'samples': store.samples.map((s) => s.toJson()).toList(),
    };
    await prefs.setString(_key, jsonEncode(payload));
  }

  // ────────────────────────────────────────────────────────────────
  // Pokemon CRUD
  // ────────────────────────────────────────────────────────────────

  /// Creates a new sample, returning its id. If [teamId] is given,
  /// the sample is added to that team's membership; throws
  /// [TeamFullException] if the team is already at [kMaxTeamSize].
  static Future<String> savePokemon({
    required String name,
    required BattlePokemonState state,
    String? teamId,
  }) async {
    final store = await loadStore();
    if (teamId != null) {
      final team = store.teams.firstWhere(
        (t) => t.id == teamId,
        orElse: () => throw ArgumentError('Unknown team: $teamId'),
      );
      if (team.memberIds.length >= kMaxTeamSize) {
        throw TeamFullException(teamId);
      }
    }
    final id = _genId('p');
    final newSample = StoredSample(id: id, name: name, state: state);
    final newSamples = [...store.samples, newSample];
    final newTeams = teamId == null
        ? store.teams
        : store.teams
            .map((t) => t.id == teamId
                ? t.copyWith(memberIds: [...t.memberIds, id])
                : t)
            .toList();
    await _writeStore(SampleStore(teams: newTeams, samples: newSamples));
    return id;
  }

  /// Updates an existing sample. Pass either or both of [name]/[state]
  /// to change just those fields.
  static Future<void> updatePokemon(
    String id, {
    String? name,
    BattlePokemonState? state,
  }) async {
    final store = await loadStore();
    final newSamples = store.samples
        .map((s) => s.id == id ? s.copyWith(name: name, state: state) : s)
        .toList();
    await _writeStore(SampleStore(teams: store.teams, samples: newSamples));
  }

  /// Deletes a sample and removes it from any team it belonged to.
  static Future<void> deletePokemon(String id) async {
    final store = await loadStore();
    final newSamples = store.samples.where((s) => s.id != id).toList();
    final newTeams = store.teams
        .map((t) => t.copyWith(
              memberIds: t.memberIds.where((m) => m != id).toList(),
            ))
        .toList();
    await _writeStore(SampleStore(teams: newTeams, samples: newSamples));
  }

  /// Moves [pokemonId] to [targetTeamId], or to the loose pool when
  /// [targetTeamId] is null. No-op if already in the target. Throws
  /// [TeamFullException] if the target team is full.
  static Future<void> movePokemon(
      String pokemonId, String? targetTeamId) async {
    final store = await loadStore();
    final currentTeam = store.teamOf(pokemonId);
    if (currentTeam?.id == targetTeamId) return;
    if (targetTeamId != null) {
      final target = store.teams.firstWhere(
        (t) => t.id == targetTeamId,
        orElse: () => throw ArgumentError('Unknown team: $targetTeamId'),
      );
      if (target.memberIds.length >= kMaxTeamSize) {
        throw TeamFullException(targetTeamId);
      }
    }
    final newTeams = store.teams.map((t) {
      // Remove from any team that has it…
      var members = t.memberIds.where((m) => m != pokemonId).toList();
      // …and add to the target.
      if (t.id == targetTeamId) members = [...members, pokemonId];
      return t.copyWith(memberIds: members);
    }).toList();
    await _writeStore(SampleStore(teams: newTeams, samples: store.samples));
  }

  /// Reorders the member at [oldIndex] to [newIndex] within [teamId].
  /// Used by drag-and-drop in the team load sheet (phase 5).
  static Future<void> reorderTeamMember(
      String teamId, int oldIndex, int newIndex) async {
    final store = await loadStore();
    final newTeams = store.teams.map((t) {
      if (t.id != teamId) return t;
      final members = [...t.memberIds];
      final moved = members.removeAt(oldIndex);
      members.insert(newIndex, moved);
      return t.copyWith(memberIds: members);
    }).toList();
    await _writeStore(SampleStore(teams: newTeams, samples: store.samples));
  }

  // ────────────────────────────────────────────────────────────────
  // Team CRUD
  // ────────────────────────────────────────────────────────────────

  /// Creates an empty team and returns its id.
  static Future<String> createTeam(String name) async {
    final store = await loadStore();
    final id = _genId('t');
    final team = TeamFolder(id: id, name: name, memberIds: const []);
    await _writeStore(
        SampleStore(teams: [...store.teams, team], samples: store.samples));
    return id;
  }

  static Future<void> renameTeam(String teamId, String newName) async {
    final store = await loadStore();
    final newTeams = store.teams
        .map((t) => t.id == teamId ? t.copyWith(name: newName) : t)
        .toList();
    await _writeStore(SampleStore(teams: newTeams, samples: store.samples));
  }

  /// Deletes a team. By default, members are released to the loose
  /// pool. Pass [deleteMembers] to also remove the underlying samples.
  static Future<void> deleteTeam(
    String teamId, {
    bool deleteMembers = false,
  }) async {
    final store = await loadStore();
    final target = store.teams.firstWhere(
      (t) => t.id == teamId,
      orElse: () => throw ArgumentError('Unknown team: $teamId'),
    );
    final newTeams = store.teams.where((t) => t.id != teamId).toList();
    final newSamples = deleteMembers
        ? store.samples.where((s) => !target.memberIds.contains(s.id)).toList()
        : store.samples;
    await _writeStore(SampleStore(teams: newTeams, samples: newSamples));
  }

  // ────────────────────────────────────────────────────────────────
  // Backward-compatible legacy API. New UI code should prefer the
  // typed `loadStore` / `savePokemon` / etc. above; these wrappers
  // exist so the calculator's existing save/load flow keeps working
  // until phase 2 ports it over.
  // ────────────────────────────────────────────────────────────────

  static Future<List<({String name, BattlePokemonState state})>>
      loadSamples() async {
    final store = await loadStore();
    return [
      for (final s in store.samples) (name: s.name, state: s.state),
    ];
  }

  static Future<void> saveSample(String name, BattlePokemonState state) async {
    await savePokemon(name: name, state: state);
  }

  static Future<bool> sampleExists(String name) async {
    final store = await loadStore();
    return store.samples.any((s) => s.name == name);
  }

  /// Replaces the sample with [name] (preserving id and team
  /// membership), or creates a new loose sample if none exists.
  static Future<void> overwriteSample(
      String name, BattlePokemonState state) async {
    final store = await loadStore();
    final existing = store.samples
        .where((s) => s.name == name)
        .firstOrNull;
    if (existing != null) {
      await updatePokemon(existing.id, state: state);
    } else {
      await savePokemon(name: name, state: state);
    }
  }

  /// Deletes by index into the flat [loadSamples] list. Kept for the
  /// existing calc UI; new team-aware UI uses [deletePokemon] by id.
  static Future<void> deleteSample(int index) async {
    final store = await loadStore();
    if (index < 0 || index >= store.samples.length) return;
    await deletePokemon(store.samples[index].id);
  }

  /// Export the store as a JSON string. Always emits the v2 format.
  static Future<String> exportAsJson() async {
    final store = await loadStore();
    return jsonEncode({
      'version': _schemaVersion,
      'teams': store.teams.map((t) => t.toJson()).toList(),
      'samples': store.samples.map((s) => s.toJson()).toList(),
    });
  }

  /// Import samples from a JSON string. Accepts both v1 (flat list)
  /// and v2 (object) formats; v1 imports land entirely in the loose
  /// pool. Returns the number of pokemon imported.
  static Future<int> importFromJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    final SampleStore store;
    if (decoded is List) {
      // Validate v1 shape.
      for (final entry in decoded) {
        final m = entry as Map<String, dynamic>;
        if (!m.containsKey('name') || !m.containsKey('state')) {
          throw const FormatException('Invalid sample format');
        }
      }
      store = SampleStore(
        samples: [
          for (final entry in decoded)
            StoredSample(
              id: _genId('p'),
              name: (entry as Map<String, dynamic>)['name'] as String,
              state: BattlePokemonState.fromJson(
                  entry['state'] as Map<String, dynamic>),
            ),
        ],
      );
    } else if (decoded is Map<String, dynamic>) {
      final teams = (decoded['teams'] as List? ?? const [])
          .map((e) => TeamFolder.fromJson(e as Map<String, dynamic>))
          .toList();
      final samples = (decoded['samples'] as List? ?? const [])
          .map((e) => StoredSample.fromJson(e as Map<String, dynamic>))
          .toList();
      store = SampleStore(teams: teams, samples: samples);
    } else {
      throw const FormatException('Unrecognized export format');
    }
    await _writeStore(store);
    return store.samples.length;
  }

  /// Whether the current platform stores data in browser localStorage.
  static bool get isWebStorage => kIsWeb;

  // ────────────────────────────────────────────────────────────────
  // Share-string export / import — copy-paste a single Pokémon (or a
  // whole team) as a self-contained string. The current format is
  // Pokémon Showdown's PokePaste (plain text, ~150 chars per Pokémon,
  // directly compatible with Smogon teambuilder exports). Only
  // team-builder state is carried — battle-only fields (HP %, rank,
  // status, dynamax/terastal activation, per-move toggles, …) reset
  // to fresh on import.
  // ────────────────────────────────────────────────────────────────

  // Legacy scheme prefixes (kept for decode so existing share codes in
  // the wild still import — encoder emits raw PokePaste now):
  //   damacalc:p1: = single pokemon, JSON + base64        (v1.7.x)
  //   damacalc:p2: = single pokemon, JSON + gzip + base64 (v1.8.x)
  //   damacalc:t1: = team,           JSON + gzip + base64 (v1.8.x)
  static const _kShareSchemePrefixV1 = 'damacalc:p1:';
  static const _kShareSchemePrefixV2 = 'damacalc:p2:';
  static const _kTeamShareSchemePrefix = 'damacalc:t1:';

  static String _gunzipUtf8(String b64) {
    final compressed = base64.decode(b64);
    final raw = GZipDecoder().decodeBytes(compressed);
    return utf8.decode(raw);
  }

  /// Encode [sample] into a PokePaste-format share string. The
  /// sample's name lands in the nickname slot; battle-only state
  /// (HP %, rank, status, dynamax/terastal activation, …) is dropped
  /// — those reset to fresh on import.
  static Future<String> exportSampleString(StoredSample sample) async {
    final items = await loadItemdex();
    return PokePaste.encodeSample(sample, itemsById: items);
  }

  /// True if [input] looks like any share string this app accepts —
  /// either the current PokePaste format or a legacy `damacalc:` code.
  static bool isShareString(String input) {
    final t = input.trim();
    if (t.startsWith(_kShareSchemePrefixV1) ||
        t.startsWith(_kShareSchemePrefixV2) ||
        t.startsWith(_kTeamShareSchemePrefix)) {
      return true;
    }
    return PokePaste.looksLikePokePaste(t);
  }

  /// True if [input] is a team share string (vs single pokemon).
  /// Lets paste UIs branch between the per-pokemon and team import
  /// flows without round-tripping the payload.
  static bool isTeamShareString(String input) {
    final t = input.trim();
    if (t.startsWith(_kTeamShareSchemePrefix)) return true;
    return PokePaste.looksLikePokePasteTeam(t);
  }

  /// Decode a single-pokemon share string into a [StoredSample]
  /// without persisting it. Accepts the current PokePaste format and
  /// the legacy `damacalc:p1/p2` codes. Throws [FormatException] on
  /// any decode failure or if [input] is a team share string.
  static Future<StoredSample> decodeSampleString(String input) async {
    final s = input.trim();
    // Legacy paths — JSON+(gzip+)base64.
    if (s.startsWith(_kShareSchemePrefixV2) ||
        s.startsWith(_kShareSchemePrefixV1)) {
      final String json;
      try {
        json = s.startsWith(_kShareSchemePrefixV2)
            ? _gunzipUtf8(s.substring(_kShareSchemePrefixV2.length))
            : utf8.decode(
                base64.decode(s.substring(_kShareSchemePrefixV1.length)));
      } on FormatException {
        rethrow;
      } catch (e) {
        throw FormatException('Invalid share string: $e');
      }
      final Map<String, dynamic> m;
      try {
        m = jsonDecode(json) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Invalid share string: $e');
      }
      final name = m['name'] as String?;
      final stateJson = m['state'] as Map<String, dynamic>?;
      if (name == null || stateJson == null) {
        throw const FormatException('Share string missing name/state');
      }
      return StoredSample(
        id: _genId('p'),
        name: name,
        state: BattlePokemonState.fromJson(stateJson),
      );
    }
    if (s.startsWith(_kTeamShareSchemePrefix)) {
      throw const FormatException(
          'Got a team share string — use decodeTeamString.');
    }
    // PokePaste — needs the pokedex / itemdex / movedex.
    if (!PokePaste.looksLikePokePaste(s)) {
      throw const FormatException('Not a recognised share string');
    }
    final pokemonByName = await _pokemonByName();
    final itemDisplayToId = await _itemDisplayToId();
    final moveByName = await loadMovedex();
    final decoded = PokePaste.decodeSample(
      s,
      pokemonByName: pokemonByName,
      itemDisplayToId: itemDisplayToId,
      moveByName: moveByName,
    );
    return StoredSample(
      id: _genId('p'),
      name: decoded.name,
      state: decoded.state,
    );
  }

  static Future<Map<String, Pokemon>> _pokemonByName() async {
    final list = await loadPokedex();
    return {for (final p in list) p.name: p};
  }

  static Future<Map<String, String>> _itemDisplayToId() async {
    final items = await loadItemdex();
    final out = <String, String>{};
    for (final entry in items.entries) {
      final display = entry.value.nameEn;
      if (display != null) out[display.toLowerCase()] = entry.key;
    }
    return out;
  }

  /// Decode + persist a share string into the store, optionally adding
  /// to a team. If a sample with the embedded name already exists,
  /// the new entry's name gets a `(2)`, `(3)`, … suffix to avoid
  /// the unique-name collision. Returns the new stored sample.
  static Future<StoredSample> importSampleString(
    String input, {
    String? teamId,
  }) async {
    final decoded = await decodeSampleString(input);
    final store = await loadStore();
    final taken = store.samples.map((s) => s.name).toSet();
    String finalName = decoded.name;
    if (taken.contains(finalName)) {
      var n = 2;
      while (taken.contains('$finalName ($n)')) {
        n++;
      }
      finalName = '$finalName ($n)';
    }
    if (teamId != null) {
      final team = store.teams.firstWhere(
        (t) => t.id == teamId,
        orElse: () => throw ArgumentError('Unknown team: $teamId'),
      );
      if (team.memberIds.length >= kMaxTeamSize) {
        throw TeamFullException(teamId);
      }
    }
    final sample = StoredSample(
      id: decoded.id,
      name: finalName,
      state: decoded.state,
    );
    final newTeams = teamId == null
        ? store.teams
        : store.teams
            .map((t) => t.id == teamId
                ? t.copyWith(memberIds: [...t.memberIds, sample.id])
                : t)
            .toList();
    await _writeStore(SampleStore(
      teams: newTeams,
      samples: [...store.samples, sample],
    ));
    return sample;
  }

  // ────────────────────────────────────────────────────────────────
  // Team share strings — copy-paste an entire party (name + members).
  // Format: damacalc:t1:<gzip+base64>; payload is
  //   {"name": "<team name>", "members": [{state: ...}, ...]}
  // Member ids and original team id are not preserved across share —
  // a fresh team and fresh member ids are minted on import.
  // ────────────────────────────────────────────────────────────────

  /// Encode [team] (with its [members] in slot order) into a PokePaste
  /// share string — sets separated by blank lines, team name as a
  /// `=== name ===` header. Member ids and any battle-only state are
  /// stripped (restored fresh on import).
  static Future<String> exportTeamString(
      TeamFolder team, List<StoredSample> members) async {
    final items = await loadItemdex();
    return PokePaste.encodeTeam(
      team.name,
      [for (final m in members) (name: m.name, state: m.state)],
      itemsById: items,
    );
  }

  /// Decode a team share string into a transient (team-name, member-
  /// list) pair without persisting. Accepts PokePaste and the legacy
  /// `damacalc:t1:` code. Throws [FormatException] on any decode
  /// failure or if [input] is a single-pokemon share string.
  static Future<({String name, List<StoredSample> members})> decodeTeamString(
      String input) async {
    final s = input.trim();
    // Legacy gzip+base64 path.
    if (s.startsWith(_kTeamShareSchemePrefix)) {
      final String json;
      try {
        json = _gunzipUtf8(s.substring(_kTeamShareSchemePrefix.length));
      } on FormatException {
        rethrow;
      } catch (e) {
        throw FormatException('Invalid team share string: $e');
      }
      final Map<String, dynamic> m;
      try {
        m = jsonDecode(json) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Invalid team share string: $e');
      }
      final name = m['name'] as String?;
      final members = m['members'] as List?;
      if (name == null || members == null) {
        throw const FormatException('Team share string missing name/members');
      }
      final out = <StoredSample>[];
      for (final raw in members) {
        final mm = raw as Map<String, dynamic>;
        out.add(StoredSample(
          id: _genId('p'),
          name: mm['name'] as String? ?? 'Pokemon',
          state: BattlePokemonState.fromJson(
              mm['state'] as Map<String, dynamic>),
        ));
      }
      return (name: name, members: out);
    }
    if (s.startsWith(_kShareSchemePrefixV1) ||
        s.startsWith(_kShareSchemePrefixV2)) {
      throw const FormatException(
          'Got a single-pokemon share string — use decodeSampleString.');
    }
    // PokePaste team — needs a `=== name ===` header or multiple sets
    // separated by blank lines. A bare single set is rejected here so
    // callers route it through `decodeSampleString` instead.
    if (!PokePaste.looksLikePokePasteTeam(s)) {
      throw const FormatException('Not a team share string');
    }
    final pokemonByName = await _pokemonByName();
    final itemDisplayToId = await _itemDisplayToId();
    final moveByName = await loadMovedex();
    final decoded = PokePaste.decodeTeam(
      s,
      pokemonByName: pokemonByName,
      itemDisplayToId: itemDisplayToId,
      moveByName: moveByName,
    );
    final out = [
      for (final m in decoded.members)
        StoredSample(id: _genId('p'), name: m.name, state: m.state),
    ];
    return (name: decoded.name ?? 'Imported team', members: out);
  }

  /// Decode + persist a team share string. Always creates a fresh
  /// team folder (even if a party with the same name already
  /// exists, a `(2)` suffix is added so the user doesn't lose the
  /// previous one). Member names are also de-duplicated against the
  /// existing store with `(2)`, `(3)`, … suffixes.
  static Future<TeamFolder> importTeamString(String input) async {
    final decoded = await decodeTeamString(input);
    final store = await loadStore();

    String _uniqueName(String base, Set<String> taken) {
      if (!taken.contains(base)) return base;
      var n = 2;
      while (taken.contains('$base ($n)')) {
        n++;
      }
      return '$base ($n)';
    }

    final teamNamesTaken = store.teams.map((t) => t.name).toSet();
    final teamName = _uniqueName(decoded.name, teamNamesTaken);

    final pokemonNamesTaken = store.samples.map((s) => s.name).toSet();
    final newSamples = <StoredSample>[];
    for (final m in decoded.members.take(kMaxTeamSize)) {
      final unique = _uniqueName(m.name, pokemonNamesTaken);
      pokemonNamesTaken.add(unique);
      newSamples.add(StoredSample(id: m.id, name: unique, state: m.state));
    }

    final newTeam = TeamFolder(
      id: _genId('t'),
      name: teamName,
      memberIds: [for (final s in newSamples) s.id],
    );

    await _writeStore(SampleStore(
      teams: [...store.teams, newTeam],
      samples: [...store.samples, ...newSamples],
    ));
    return newTeam;
  }
}
