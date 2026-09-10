import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the calculator picks up where it left off on the next
/// launch (attacker, defender, field). On by default — that is what
/// the app always did — but some people want a clean sheet every
/// time, so it's a setting. The session is still written either way;
/// turning this back on restores the latest one.
class SessionRestoreController {
  SessionRestoreController._();
  static final SessionRestoreController instance = SessionRestoreController._();

  static const _prefsKey = 'restoreSessionOnLaunch';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> set(bool v) async {
    if (enabled.value == v) return;
    enabled.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, v);
  }
}
