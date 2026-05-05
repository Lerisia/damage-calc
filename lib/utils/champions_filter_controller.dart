import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global "show Champions Pokémon only" toggle, shared across the
/// Pokémon Dex's species selector and the Move Dex's learners list.
/// Persisted between launches like the other display preferences.
class ChampionsFilterController {
  ChampionsFilterController._();
  static final ChampionsFilterController instance =
      ChampionsFilterController._();

  static const _prefsKey = 'dexChampionsOnly';

  /// Defaults to off — first-launch users see the full Pokédex; the
  /// filter is opt-in.
  final ValueNotifier<bool> championsOnly = ValueNotifier<bool>(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    championsOnly.value = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> set(bool v) async {
    if (championsOnly.value == v) return;
    championsOnly.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, v);
  }
}
