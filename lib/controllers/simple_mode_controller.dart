import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's current mode choice (Simple vs. Normal) across
/// app launches — same pattern as ThemeController.
class SimpleModeController {
  SimpleModeController._();
  static final SimpleModeController instance = SimpleModeController._();

  static const _prefsKey = 'simpleMode';

  /// Starts in Simple Mode for first-time users (and anyone who
  /// hasn't explicitly toggled Normal Mode before).
  final ValueNotifier<bool> isSimple = ValueNotifier<bool>(true);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isSimple.value = prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> setSimple(bool v) async {
    if (isSimple.value == v) return;
    isSimple.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, v);
  }
}
