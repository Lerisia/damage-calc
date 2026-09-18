import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the HP inputs (Extended Mode HP field, Simple Mode chip and
/// its editor) show and take a percent of max HP or the real value.
///
/// The model underneath is the same either way — an integer HP with
/// the share stored (see calc/hp.dart) — so a typed percent lands on
/// the nearest real HP and displays as that HP's share. Percent is the
/// default because it is what the app always showed; people who read
/// their own mon's HP as a number opt into values in the settings
/// menu. Persisted like the other display preferences.
enum HpDisplayMode { percent, value }

class HpDisplayController {
  HpDisplayController._();
  static final HpDisplayController instance = HpDisplayController._();

  static const _prefsKey = 'hpDisplay';

  final ValueNotifier<HpDisplayMode> mode =
      ValueNotifier<HpDisplayMode>(HpDisplayMode.percent);

  bool get showsValue => mode.value == HpDisplayMode.value;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null) return;
    for (final m in HpDisplayMode.values) {
      if (m.name == saved) {
        mode.value = m;
        return;
      }
    }
  }

  Future<void> set(HpDisplayMode m) async {
    if (mode.value == m) return;
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, m.name);
  }
}
