import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/utils/simple_mode_controller.dart';

/// Simple vs. extended mode choice: Simple by default, persisted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final c = SimpleModeController.instance;

  test('first launch starts in Simple Mode', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    expect(c.isSimple.value, isTrue);
  });

  test('switching to extended persists; a stored false wins on load', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    await c.setSimple(false);
    expect((await SharedPreferences.getInstance()).getBool('simpleMode'), isFalse);
    SharedPreferences.setMockInitialValues({'simpleMode': false});
    await c.load();
    expect(c.isSimple.value, isFalse);
    await c.setSimple(true);
  });
}
