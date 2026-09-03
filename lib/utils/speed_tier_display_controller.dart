import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the Champions speed tier sheet lists species base Speed
/// (종족값) or realized Lv50 values (실수치) across the standard
/// spreads.
///
/// Persisted like the other display preferences — same controller
/// pattern as [CoverageDisplayController].
enum SpeedTierDisplayMode { base, realized }

class SpeedTierDisplayController {
  SpeedTierDisplayController._();
  static final SpeedTierDisplayController instance =
      SpeedTierDisplayController._();

  static const _prefsKey = 'speedTierDisplay';

  /// Defaults to base Speed — the realized table is three times as
  /// long, and base values are what players quote at each other.
  final ValueNotifier<SpeedTierDisplayMode> mode =
      ValueNotifier<SpeedTierDisplayMode>(SpeedTierDisplayMode.base);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null) return;
    for (final m in SpeedTierDisplayMode.values) {
      if (m.name == saved) {
        mode.value = m;
        return;
      }
    }
  }

  Future<void> set(SpeedTierDisplayMode m) async {
    if (mode.value == m) return;
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, m.name);
  }
}
