import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:damage_calc/controllers/search_picker_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pushRecent', () {
    test('newest first, no duplicates', () {
      expect(pushRecent(['a', 'b', 'c'], 'b'), ['b', 'a', 'c']);
      expect(pushRecent(['a'], 'z'), ['z', 'a']);
      expect(pushRecent([], 'a'), ['a']);
    });
    test('capped', () {
      final full = [for (var i = 0; i < kPickerRecentsCap; i++) 'i$i'];
      final next = pushRecent(full, 'new');
      expect(next.length, kPickerRecentsCap);
      expect(next.first, 'new');
      expect(next, isNot(contains('i${kPickerRecentsCap - 1}')));
    });
    test('the empty id ("no item") is never recorded', () {
      expect(pushRecent(['a'], ''), ['a']);
    });
  });

  group('SearchPickerPrefs', () {
    test('defaults: the caller\'s fallback view, no recents', () async {
      SharedPreferences.setMockInitialValues({});
      await SearchPickerPrefs.instance.load();
      expect(
          SearchPickerPrefs.instance
              .viewMode('pokemon', fallback: PickerViewMode.grid),
          PickerViewMode.grid);
      expect(SearchPickerPrefs.instance.recents('pokemon'), isEmpty);
    });

    test('view mode and recents persist, per kind', () async {
      SharedPreferences.setMockInitialValues({});
      await SearchPickerPrefs.instance.load();
      await SearchPickerPrefs.instance.setViewMode('item', PickerViewMode.grid);
      await SearchPickerPrefs.instance.addRecent('item', 'life-orb');
      await SearchPickerPrefs.instance.addRecent('item', 'leftovers');
      await SearchPickerPrefs.instance.addRecent('pokemon', 'Garchomp');

      // A fresh load reads the same values back from storage.
      await SearchPickerPrefs.instance.load();
      expect(
          SearchPickerPrefs.instance
              .viewMode('item', fallback: PickerViewMode.list),
          PickerViewMode.grid);
      expect(SearchPickerPrefs.instance.recents('item'),
          ['leftovers', 'life-orb']);
      expect(SearchPickerPrefs.instance.recents('pokemon'), ['Garchomp']);
      expect(
          SearchPickerPrefs.instance
              .viewMode('pokemon', fallback: PickerViewMode.list),
          PickerViewMode.list,
          reason: 'kinds do not share a view mode');
    });
  });
}
