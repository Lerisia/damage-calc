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
  });
}
