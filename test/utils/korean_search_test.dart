import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/korean_search.dart';

void main() {
  group('koreanMatchScore', () {
    test('exact match returns 100', () {
      expect(koreanMatchScore('피카츄', '피카츄'), equals(100));
    });

    test('prefix match returns 80', () {
      expect(koreanMatchScore('피카', '피카츄'), equals(80));
    });

    test('contains match returns 60', () {
      expect(koreanMatchScore('카츄', '피카츄'), equals(60));
    });

    test('초성 prefix match returns 50', () {
      expect(koreanMatchScore('ㅍㅋㅊ', '피카츄'), equals(50));
    });

    test('초성 contains match returns 30', () {
      expect(koreanMatchScore('ㅋㅊ', '피카츄'), equals(30));
    });

    test('mixed match (syllable + 초성) gets prefix score', () {
      // 피ㅋ prefix-matches 피카츄 (ㅋ matches 카's 초성)
      expect(koreanMatchScore('피ㅋ', '피카츄'), equals(80));
    });

    test('no match returns 0', () {
      expect(koreanMatchScore('리자몽', '피카츄'), equals(0));
    });

    test('syllable-prefix: 이사 matches 이상해씨 (사→상)', () {
      expect(koreanMatchScore('이사', '이상해씨'), equals(80));
    });

    test('syllable-prefix: 이상 matches 이상해씨 exactly', () {
      expect(koreanMatchScore('이상', '이상해씨'), equals(80));
    });

    test('초성 search: ㅇㅅㅎㅆ matches 이상해씨', () {
      expect(koreanMatchScore('ㅇㅅㅎㅆ', '이상해씨'), equals(50));
    });

    test('mixed: 이ㅅ prefix-matches 이상해씨', () {
      expect(koreanMatchScore('이ㅅ', '이상해씨'), equals(80));
    });

    test('case insensitive English', () {
      expect(koreanMatchScore('pika', 'Pikachu'), equals(80));
    });

    test('double consonant ㄲ prefix-matches 꼬부기', () {
      expect(koreanMatchScore('ㄲ', '꼬부기'), equals(80));
    });

    test('ㄱㄱ does not match 꼬부기 (ㄲ≠ㄱ)', () {
      // ㄱㄱ means first syllable ㄱ + second syllable ㄱ
      // 꼬부기: ㄲ ㅂ ㄱ — first char is ㄲ not ㄱ
      expect(koreanMatchScore('ㄱㄱ', '꼬부기'), equals(0));
    });

    test('폭풍 prefix ranks higher than 모래폭풍 contains', () {
      final prefixScore = koreanMatchScore('폭풍', '폭풍우');
      final containsScore = koreanMatchScore('폭풍', '모래폭풍');
      expect(prefixScore, greaterThan(containsScore));
    });

    // PC Korean IMEs combine consecutive initials in chosung-only input
    // (ㅂ+ㅅ → ㅄ etc.). Decompose so the user reaches the same target
    // whether they typed on mobile (ㅂㅅㄹㄹ) or on PC (ㅄㄹㄹ).
    group('cluster jamo decomposition (PC IME)', () {
      test('mobile-typed ㅂㅅㄹㄹ matches 보스로라 (regression)', () {
        expect(koreanMatchScore('ㅂㅅㄹㄹ', '보스로라'), equals(50));
      });
      test('PC-typed ㅄㄹㄹ matches 보스로라 (cluster decomposed)', () {
        expect(koreanMatchScore('ㅄㄹㄹ', '보스로라'), equals(50));
      });
      test('ㅄ alone matches 보스 (chosung prefix)', () {
        expect(koreanMatchScore('ㅄ', '보스'), equals(50));
      });
      test('ㄶ decomposes to ㄴㅎ', () {
        expect(koreanMatchScore('ㄶ', '난호'), equals(50));
      });
      test('ㄺ decomposes to ㄹㄱ', () {
        expect(koreanMatchScore('ㄺ', '락기'), equals(50));
      });
      test('cluster does not invent a match — ㅄ vs 가가 stays 0', () {
        expect(koreanMatchScore('ㅄ', '가가'), equals(0));
      });
    });
  });

  group('SearchIndex', () {
    // Corpus: (item, ko, en). Items are ints for easy identity.
    SearchIndex<int> build() => SearchIndex<int>([
          SearchEntry(1, '피카츄', 'Pikachu'),
          SearchEntry(2, '라이츄', 'Raichu'),
          SearchEntry(3, '파이리', 'Charmander'),
          SearchEntry(4, '꼬부기', 'Squirtle'),
        ]);

    test('empty query → pins first, then rest', () {
      final r = build().query('', pins: [3]);
      expect(r.first, 3); // pinned floats to top
      expect(r.toSet(), {1, 2, 3, 4});
      expect(r.where((x) => x == 3).length, 1); // pin not duplicated
    });

    test('empty query → rest ordered by restSort', () {
      final r = build().query('', restSort: (a, b) => a.compareTo(b));
      expect(r, [1, 2, 3, 4]);
    });

    test('empty query → pins keep caller order, bypass allow', () {
      // allow hides everything, but pins survive.
      final r = build().query('', pins: [4, 1], allow: (_) => false);
      expect(r, [4, 1]);
    });

    test('empty query → allow filters the rest only', () {
      final r = build().query('',
          allow: (x) => x.isEven, restSort: (a, b) => a.compareTo(b));
      expect(r, [2, 4]);
    });

    test('non-empty query → relevance-ranked, allow applies', () {
      // 초성 ㅊ matches 피카츄(츄) and 라이츄(츄) via contains; exact
      // "피카츄" scores highest.
      final r = build().query('피카츄');
      expect(r.first, 1);
    });

    test('non-empty query → pins do NOT reorder results', () {
      // Even pinned, a non-matching item stays out on a real query.
      final r = build().query('꼬부기', pins: [1]);
      expect(r, [4]); // only the match; pin 1 doesn't appear
    });

    test('non-empty query → allow still filters', () {
      final r = build().query('츄', allow: (x) => x == 2);
      expect(r, [2]); // 라이츄 only; 피카츄 filtered out
    });
  });

  // ------------------------------------------------------------------
  // pickerSuggestions — the shared composition. These pin the
  // "what floats to the top" contract for each usage site, WITH its
  // special conditions, so the picker-consolidation refactor can't
  // silently change any site's ordering.
  // ------------------------------------------------------------------
  group('pickerSuggestions — per-site top-of-list contracts', () {
    // Ability picker corpus (StatInput / Simple Mode / Team Coverage).
    // items are ability keys; ko names drive matching + alpha sort.
    SearchIndex<String> abilityIndex() => SearchIndex<String>([
          SearchEntry('Rough Skin', '까칠한피부', 'Rough Skin'),
          SearchEntry('Sand Veil', '모래숨기', 'Sand Veil'),
          SearchEntry('Contrary', '심술꾸러기', 'Contrary'),
          SearchEntry('Levitate', '부유', 'Levitate'),
          SearchEntry('Intimidate', '위협', 'Intimidate'),
          // A non-mainline ability that the pickable filter should hide
          // from the rest but NOT from a Pokémon that owns it.
          SearchEntry('Beta Ability', '베타특성', 'Beta Ability'),
        ]);

    Comparator<String> koSort(Map<String, String> ko) =>
        (a, b) => ko[a]!.compareTo(ko[b]!);
    const koNames = {
      'Rough Skin': '까칠한피부',
      'Sand Veil': '모래숨기',
      'Contrary': '심술꾸러기',
      'Levitate': '부유',
      'Intimidate': '위협',
      'Beta Ability': '베타특성',
    };

    test('ABILITY empty → own abilities lead, then alpha rest', () {
      final r = pickerSuggestions(
        abilityIndex(),
        '',
        pins: ['Sand Veil', 'Rough Skin'], // this mon's own, in order
        restSort: koSort(koNames),
      );
      // Own first, in given order.
      expect(r.take(2).toList(), ['Sand Veil', 'Rough Skin']);
      // Rest alphabetical by KO (베타→부유→심술→위협).
      expect(r.sublist(2),
          ['Beta Ability', 'Levitate', 'Contrary', 'Intimidate']);
    });

    test('ABILITY empty + pickable filter hides non-mainline from rest '
        'but keeps an owned one', () {
      final r = pickerSuggestions(
        abilityIndex(),
        '',
        pins: ['Beta Ability'], // owned → must appear even if unpickable
        allow: (a) => a != 'Beta Ability', // pickable = mainline only
        restSort: koSort(koNames),
      );
      expect(r.first, 'Beta Ability'); // owned pin survives the filter
      expect(r.contains('Beta Ability'), isTrue);
      // And it's not duplicated in the rest.
      expect(r.where((a) => a == 'Beta Ability').length, 1);
    });

    test('ABILITY query → relevance (심술 → Contrary on top)', () {
      final r = pickerSuggestions(abilityIndex(), '심술',
          pins: ['Sand Veil'], restSort: koSort(koNames));
      expect(r.first, 'Contrary'); // pins do not override a real match
    });

    // Move selector corpus.
    SearchIndex<String> moveIndex() => SearchIndex<String>([
          SearchEntry('Earthquake', '지진', 'Earthquake'),
          SearchEntry('Stealth Rock', '스텔스록', 'Stealth Rock'),
          SearchEntry('Dragon Claw', '드래곤클로', 'Dragon Claw'),
          SearchEntry('Fire Blast', '불대문자', 'Fire Blast'),
          SearchEntry('Swords Dance', '칼춤', 'Swords Dance'),
          SearchEntry('Splash', '튀어오르기', 'Splash'),
        ]);

    test('MOVE empty → selected, then configured slots, then champ top-N, '
        'then learnable-first', () {
      // canLearn: everything except Fire Blast.
      final r = pickerSuggestions(
        moveIndex(),
        '',
        hoist: 'Swords Dance', // currently-selected
        pins: ['Earthquake', 'Stealth Rock', 'Fire Blast'], // slots+champ
        groupFirst: (m) => m != 'Fire Blast', // learnable first
      );
      // Selected leads.
      expect(r.first, 'Swords Dance');
      // Fire Blast, though pinned, is non-learnable → pushed after the
      // learnable group by the stable partition.
      expect(r.last, 'Fire Blast');
      // The learnable pins keep their order right after the selected.
      expect(r.sublist(0, 3), ['Swords Dance', 'Earthquake', 'Stealth Rock']);
    });

    test('MOVE query → relevance, selected hoisted, learnable-first', () {
      final r = pickerSuggestions(
        moveIndex(),
        '드래곤', // matches Dragon Claw
        hoist: 'Swords Dance', // selected, but doesn't match
        groupFirst: (m) => true,
      );
      // Selected isn't in the match set, so top is the actual match.
      expect(r.first, 'Dragon Claw');
    });

    // Pokemon selector corpus.
    SearchIndex<String> dexIndex() => SearchIndex<String>([
          SearchEntry('Garchomp', '한카리아스', 'Garchomp'),
          SearchEntry('Gardevoir', '가디안', 'Gardevoir'),
          SearchEntry('Gengar', '팬텀', 'Gengar'),
          SearchEntry('Pikachu', '피카츄', 'Pikachu'),
        ]);

    test('POKEMON empty → selected first, championsOnly filters rest', () {
      final champ = {'Garchomp', 'Gardevoir', 'Pikachu'}; // Gengar not in
      final r = pickerSuggestions(
        dexIndex(),
        '',
        hoist: 'Pikachu', // selected
        allow: champ.contains, // championsOnly
      );
      expect(r.first, 'Pikachu');
      expect(r.contains('Gengar'), isFalse); // filtered out
    });

    test('POKEMON query → relevance + selected hoisted to top', () {
      final r = pickerSuggestions(
        dexIndex(),
        '가', // 가디안 matches (prefix), 한카리아스 no
        hoist: 'Garchomp', // selected — hoist even though weaker/nomatch
      );
      // Garchomp doesn't match '가' (한카리아스), so top is the real match.
      expect(r.first, 'Gardevoir');
    });

    test('POKEMON query → selected hoisted when it DOES match', () {
      final r = pickerSuggestions(
        dexIndex(),
        'ㄱ', // chosung matches 가디안, 한카리아스? (ㄱ vs 가/한...)
        hoist: 'Gardevoir',
      );
      expect(r.first, 'Gardevoir'); // selected + matches → guaranteed top
    });
  });
}
