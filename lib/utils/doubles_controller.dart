import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted battle-format preference. Same pattern as ThemeController /
/// AppStrings — loaded once at startup, changes persist across sessions.
class DoublesController {
  DoublesController._();
  static final DoublesController instance = DoublesController._();

  static const _prefKey = 'app_battle_format';

  /// true when the app is in Doubles mode, false for Singles. MaterialApp
  /// subtrees rebuild via ValueListenableBuilder when this changes.
  final ValueNotifier<bool> isDoubles = ValueNotifier<bool>(false);

  /// Load the saved preference. Call once at startup before runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDoubles.value = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setDoubles(bool value) async {
    isDoubles.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }
}
