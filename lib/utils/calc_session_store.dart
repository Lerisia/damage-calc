import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/battle_pokemon.dart';
import '../models/room.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'aura_effects.dart';
import 'ruin_effects.dart';

/// Crash/kill-safe autosave of the calculator's working state.
///
/// Why: Pokémon Champions' mobile release means users alt-tab between
/// the game and this calc constantly, and the OS routinely kills the
/// backgrounded calc to reclaim memory. Losing the half-built matchup
/// (attacker + defender + field state) mid-battle is exactly the
/// moment the tool is supposed to be helping with.
///
/// Design:
///   * [schedule] serializes the full session eagerly (cheap — two
///     `BattlePokemonState.toJson()` plus a handful of enums) and
///     debounces the actual prefs write by 1s so rapid edits don't
///     hammer storage.
///   * [flush] cancels the debounce and writes NOW — called from the
///     screen's `AppLifecycleState.paused/inactive/hidden` hook, i.e.
///     the last code we get to run before the OS may kill us.
///   * [load] returns null on ANY failure (missing key, version
///     mismatch, corrupt JSON, schema drift after an update). A fresh
///     calculator is always an acceptable fallback; a crash-loop on
///     startup is not.
class CalcSessionStore {
  CalcSessionStore._();

  static const _prefsKey = 'calcSessionV1';

  /// Bump when the payload layout changes incompatibly. Loaders see a
  /// different version and discard rather than misparse.
  static const _version = 1;

  static Timer? _debounce;
  static Map<String, dynamic>? _pending;

  /// Serialize the current session and queue a debounced write.
  static void schedule({
    required BattlePokemonState attacker,
    required BattlePokemonState defender,
    required Weather weather,
    required Terrain terrain,
    required RoomConditions room,
    required AuraToggles auras,
    required RuinToggles ruins,
  }) {
    _pending = {
      'v': _version,
      'attacker': attacker.toJson(),
      'defender': defender.toJson(),
      'weather': weather.name,
      'terrain': terrain.name,
      'room': {
        'trickRoom': room.trickRoom,
        'magicRoom': room.magicRoom,
        'wonderRoom': room.wonderRoom,
        'gravity': room.gravity,
      },
      'auras': {
        'fairyAura': auras.fairyAura,
        'darkAura': auras.darkAura,
        'auraBreak': auras.auraBreak,
      },
      'ruins': {
        'tabletsOfRuin': ruins.tabletsOfRuin,
        'swordOfRuin': ruins.swordOfRuin,
        'vesselOfRuin': ruins.vesselOfRuin,
        'beadsOfRuin': ruins.beadsOfRuin,
      },
    };
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      _write();
    });
  }

  /// Write the latest snapshot immediately (lifecycle-pause path).
  static Future<void> flush() async {
    _debounce?.cancel();
    await _write();
  }

  static Future<void> _write() async {
    final payload = _pending;
    if (payload == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {
      // Storage unavailable → silently skip; autosave is best-effort
      // and must never surface an error mid-battle.
    }
  }

  /// Restore the last-saved session, or null when there's nothing
  /// usable. Every failure mode maps to null by design.
  static Future<CalcSession?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['v'] != _version) return null;
      final room = j['room'] as Map<String, dynamic>? ?? const {};
      final auras = j['auras'] as Map<String, dynamic>? ?? const {};
      final ruins = j['ruins'] as Map<String, dynamic>? ?? const {};
      bool b(Map<String, dynamic> m, String k) => m[k] == true;
      return CalcSession(
        attacker: BattlePokemonState.fromJson(
            j['attacker'] as Map<String, dynamic>),
        defender: BattlePokemonState.fromJson(
            j['defender'] as Map<String, dynamic>),
        weather: Weather.values.byName(j['weather'] as String),
        terrain: Terrain.values.byName(j['terrain'] as String),
        room: RoomConditions(
          trickRoom: b(room, 'trickRoom'),
          magicRoom: b(room, 'magicRoom'),
          wonderRoom: b(room, 'wonderRoom'),
          gravity: b(room, 'gravity'),
        ),
        auras: AuraToggles(
          fairyAura: b(auras, 'fairyAura'),
          darkAura: b(auras, 'darkAura'),
          auraBreak: b(auras, 'auraBreak'),
        ),
        ruins: RuinToggles(
          tabletsOfRuin: b(ruins, 'tabletsOfRuin'),
          swordOfRuin: b(ruins, 'swordOfRuin'),
          vesselOfRuin: b(ruins, 'vesselOfRuin'),
          beadsOfRuin: b(ruins, 'beadsOfRuin'),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Deserialized session payload returned by [CalcSessionStore.load].
class CalcSession {
  final BattlePokemonState attacker;
  final BattlePokemonState defender;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final AuraToggles auras;
  final RuinToggles ruins;

  const CalcSession({
    required this.attacker,
    required this.defender,
    required this.weather,
    required this.terrain,
    required this.room,
    required this.auras,
    required this.ruins,
  });
}
