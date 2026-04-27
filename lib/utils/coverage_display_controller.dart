import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the party-coverage matrix renders multipliers as text
/// ("4×", "½", …) or as the standard Pokemon-game symbol set
/// (◎ / ○ / △ / ▲ / ✕). Persisted across app launches like the
/// language and theme settings — same controller pattern as
/// [SimpleModeController].
enum CoverageDisplayMode { numeric, symbolic }

class CoverageDisplayController {
  CoverageDisplayController._();
  static final CoverageDisplayController instance =
      CoverageDisplayController._();

  static const _prefsKey = 'partyCoverageDisplay';

  /// Defaults to numeric so existing users see no change on first
  /// launch; users who prefer the symbol notation can opt in via the
  /// matrix toggle.
  final ValueNotifier<CoverageDisplayMode> mode =
      ValueNotifier<CoverageDisplayMode>(CoverageDisplayMode.numeric);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null) return;
    final found = CoverageDisplayMode.values
        .where((m) => m.name == saved)
        .firstOrNull;
    if (found != null) mode.value = found;
  }

  Future<void> set(CoverageDisplayMode m) async {
    if (mode.value == m) return;
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, m.name);
  }
}
