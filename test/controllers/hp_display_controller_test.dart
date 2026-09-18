import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/hp_display_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to percent, as the app always showed', () async {
    SharedPreferences.setMockInitialValues({});
    await HpDisplayController.instance.load();
    expect(HpDisplayController.instance.mode.value, HpDisplayMode.percent);
    expect(HpDisplayController.instance.showsValue, isFalse);
  });

  test('switching to values persists', () async {
    SharedPreferences.setMockInitialValues({});
    await HpDisplayController.instance.load();
    await HpDisplayController.instance.set(HpDisplayMode.value);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('hpDisplay'), 'value');
    await HpDisplayController.instance.set(HpDisplayMode.percent);
  });

  test('a stored value mode wins on load', () async {
    SharedPreferences.setMockInitialValues({'hpDisplay': 'value'});
    await HpDisplayController.instance.load();
    expect(HpDisplayController.instance.showsValue, isTrue);
    await HpDisplayController.instance.set(HpDisplayMode.percent);
  });
}
