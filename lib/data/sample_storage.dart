import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/battle_pokemon.dart';

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
}
