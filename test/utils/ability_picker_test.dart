import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/ability_picker.dart';
import 'package:damage_calc/utils/korean_search.dart';

/// The shared ability-picker helpers every ability field uses
/// (StatInput, Simple Mode, speed tab, team builder).
void main() {
  const names = {
    'Blaze': '맹화',
    'Solar Power': '선파워',
    'Supreme Overlord 0': '총대장 ×0',
    'Supreme Overlord 1': '총대장 ×1',
    'Supreme Overlord 2': '총대장 ×2',
    'Intimidate': '위협',
    'Levitate': '부유',
  };

  group('expandAbilities', () {
    test('expands a stateful base into the states the dex carries', () {
      expect(expandAbilities(['Supreme Overlord'], names),
          ['Supreme Overlord 0', 'Supreme Overlord 1', 'Supreme Overlord 2']);
    });
    test('passes plain keys through and drops keys the dex lacks', () {
      expect(expandAbilities(['Blaze', 'Solar Power', 'Nonexistent'], names),
          ['Blaze', 'Solar Power']);
    });
  });

  group('buildAbilityIndex + pickerSuggestions', () {
    final index = buildAbilityIndex(names.keys, koOf: (k) => names[k]!);
    int byKo(String a, String b) => names[a]!.compareTo(names[b]!);

    test('empty query: own abilities pinned, the rest A→Z by label', () {
      final r = pickerSuggestions(index, '', pins: ['Solar Power', 'Blaze'], restSort: byKo);
      expect(r.take(2), ['Solar Power', 'Blaze']);
      expect(r.skip(2), ['Levitate', 'Intimidate', 'Supreme Overlord 0', 'Supreme Overlord 1', 'Supreme Overlord 2']);
    });
    test('a query is ranked, in Korean, English or chosung', () {
      expect(pickerSuggestions(index, '위협', restSort: byKo).first, 'Intimidate');
      expect(pickerSuggestions(index, 'levi', restSort: byKo).first, 'Levitate');
      expect(pickerSuggestions(index, 'ㅁㅎ', restSort: byKo).first, 'Blaze');
    });
    test('allow hides entries even from the ranked list', () {
      final r = pickerSuggestions(index, '총대장', allow: (k) => k != 'Supreme Overlord 2');
      expect(r, isNot(contains('Supreme Overlord 2')));
      expect(r, contains('Supreme Overlord 0'));
    });
  });
}
