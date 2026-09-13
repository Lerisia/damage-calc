import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/champions_filter_controller.dart';

/// The global "Champions only" scope: on by default, persisted, and the
/// first-launch prompt answered exactly once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final c = ChampionsFilterController.instance;

  test('defaults to Champions-only with the prompt unanswered', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    expect(c.championsOnly.value, isTrue);
    expect(c.promptShown, isFalse);
  });

  test('set persists and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    var fired = 0;
    void onChange() => fired++;
    c.championsOnly.addListener(onChange);
    await c.set(false);
    c.championsOnly.removeListener(onChange);
    expect(fired, 1);
    expect((await SharedPreferences.getInstance()).getBool('dexChampionsOnly'), isFalse);
    await c.set(true);
  });

  test('a stored choice wins on load', () async {
    SharedPreferences.setMockInitialValues({'dexChampionsOnly': false});
    await c.load();
    expect(c.championsOnly.value, isFalse);
    await c.set(true);
  });

  test('answering the prompt stores the scope and marks it shown', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    await c.answerPrompt(championsOnlyChoice: false);
    expect(c.championsOnly.value, isFalse);
    expect(c.promptShown, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dexChampionsOnly'), isFalse);
    expect(prefs.getBool('dexScopeModeFormatPrompt'), isTrue);
    SharedPreferences.setMockInitialValues({'dexScopeModeFormatPrompt': true});
    await c.load();
    expect(c.promptShown, isTrue);
    await c.set(true);
  });
}
