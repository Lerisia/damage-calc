import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted theme-mode preference. Decoupled from the platform's
/// brightness so users who want a specific mode get it regardless of
/// what their browser/OS is set to.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefKey = 'app_theme_mode';

  /// Emits a new value when the user changes the theme. MaterialApp
  /// rebuilds via ValueListenableBuilder. Defaults to light so first-run
  /// users aren't at the mercy of browser/OS settings.
  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  bool get isDark => mode.value == ThemeMode.dark;

  /// Load the saved theme mode. Call once at startup before runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    mode.value = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, m == ThemeMode.dark ? 'dark' : 'light');
  }

  /// Flip between light and dark.
  Future<void> toggle() async {
    await setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
