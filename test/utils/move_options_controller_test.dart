import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/utils/move_options_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Reset the singleton's in-memory state between tests so each one
    // starts from the documented default (off). The controller is a
    // process-wide singleton so without this the previous test's state
    // leaks in.
    MoveOptionsController.instance.showStatusMoves.value = false;
  });

  test('defaults showStatusMoves to false on first launch', () async {
    await MoveOptionsController.instance.load();
    expect(MoveOptionsController.instance.showStatusMoves.value, isFalse);
  });

  test('setShowStatusMoves persists and reflects in the notifier', () async {
    await MoveOptionsController.instance.setShowStatusMoves(true);
    expect(MoveOptionsController.instance.showStatusMoves.value, isTrue);

    // New process: reset notifier, reload — should see the persisted value.
    MoveOptionsController.instance.showStatusMoves.value = false;
    await MoveOptionsController.instance.load();
    expect(MoveOptionsController.instance.showStatusMoves.value, isTrue);
  });

  test('setShowStatusMoves is a no-op when value already matches', () async {
    var fired = 0;
    void listener() => fired++;
    MoveOptionsController.instance.showStatusMoves.addListener(listener);

    await MoveOptionsController.instance.setShowStatusMoves(false);
    expect(fired, 0);

    MoveOptionsController.instance.showStatusMoves.removeListener(listener);
  });
}
