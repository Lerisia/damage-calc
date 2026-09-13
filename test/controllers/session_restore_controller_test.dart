import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/session_restore_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to restoring, as the app always did', () async {
    SharedPreferences.setMockInitialValues({});
    await SessionRestoreController.instance.load();
    expect(SessionRestoreController.instance.enabled.value, isTrue);
  });

  test('turning it off persists', () async {
    SharedPreferences.setMockInitialValues({});
    await SessionRestoreController.instance.load();
    await SessionRestoreController.instance.set(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('restoreSessionOnLaunch'), isFalse);
    await SessionRestoreController.instance.set(true);
  });

  test('a stored false wins on load', () async {
    SharedPreferences.setMockInitialValues({'restoreSessionOnLaunch': false});
    await SessionRestoreController.instance.load();
    expect(SessionRestoreController.instance.enabled.value, isFalse);
    await SessionRestoreController.instance.set(true);
  });
}
