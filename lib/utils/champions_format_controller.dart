import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singles vs. Doubles Champions roster. The picked format drives the
/// `championsUsageFor` lookups across the app — dex defaults, team-
/// builder curated lists, the rank sheet, the speed-tier sheet — so
/// flipping this swaps every "most-used X / curated list of Y" across
/// the whole app at once.
enum ChampionsFormat { singles, doubles }

/// Global toggle for which Champions format ([ChampionsFormat]) drives
/// the curated stats. Persists between launches like the other display
/// preferences. Same pattern as [SimpleModeController].
class ChampionsFormatController {
  ChampionsFormatController._();
  static final ChampionsFormatController instance =
      ChampionsFormatController._();

  static const _prefsKey = 'championsFormat';

  /// Default to singles — singles has been the only mode for most of
  /// the app's life so existing users land on the same data they're
  /// used to; doubles is opt-in via the settings menu.
  final ValueNotifier<ChampionsFormat> format =
      ValueNotifier<ChampionsFormat>(ChampionsFormat.singles);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    format.value = raw == 'doubles'
        ? ChampionsFormat.doubles
        : ChampionsFormat.singles;
  }

  Future<void> set(ChampionsFormat v) async {
    if (format.value == v) return;
    format.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, v == ChampionsFormat.doubles ? 'doubles' : 'singles');
  }
}
