/// Korean-aware search matching with 초성 search and syllable-prefix support.
///
/// Supports:
/// - Exact match: "피카츄" = 피카츄
/// - Prefix match: "피카" → 피카츄
/// - Contains match: "카츄" → 피카츄
/// - 초성 search: "ㅍㅋㅊ" → 피카츄
/// - Mixed search: "피ㅋ" → 피카츄
/// - Syllable-prefix: "이사" → 이상해씨 (사 matches 상 as incomplete input)

/// Pre-computed search data for fast matching.
class SearchEntry<T> {
  final T item;
  final String koLower;
  final String enLower;
  final String jaLower;
  final List<int> koRunes;
  final List<int> chosungIndices; // 초성 index per syllable
  final List<String> aliasesLower; // 별명 (lowercase)

  SearchEntry(this.item, String nameKo, String nameEn, {String nameJa = '', List<String> aliases = const []})
      : koLower = nameKo.toLowerCase(),
        enLower = nameEn.toLowerCase(),
        jaLower = nameJa.toLowerCase(),
        koRunes = nameKo.toLowerCase().runes.toList(),
        chosungIndices = nameKo.runes.map((c) =>
            _isSyllable(c) ? (c - 0xAC00) ~/ 588 : -1).toList(),
        aliasesLower = aliases.map((a) => a.toLowerCase()).toList();
}

/// Scores a pre-computed entry against a pre-computed query.
int scoreEntry(List<int> qRunes, String qLower, SearchEntry entry) {
  // PC IMEs collapse successive consonants in chosung-only input
  // (ㅂ+ㅅ → ㅄ etc.). Decompose any clusters so 보스로라 is reachable
  // from ㅄㄹㄹ just as it is from ㅂㅅㄹㄹ.
  final expanded = _expandJamoClusters(qRunes);
  if (!identical(expanded, qRunes)) {
    qRunes = expanded;
    qLower = String.fromCharCodes(expanded);
  }

  // 1. Exact match
  if (qLower == entry.koLower) return 100;

  // 2. Prefix match (with syllable-prefix on last char)
  if (qRunes.length <= entry.koRunes.length &&
      _prefixMatchRunes(qRunes, entry.koRunes)) return 80;

  // 3. Contains match
  if (entry.koLower.contains(qLower)) return 60;

  // 4. 초성/mixed prefix match
  if (qRunes.length <= entry.koRunes.length &&
      _chosungPrefixMatchRunes(qRunes, entry.koRunes)) return 50;

  // 5. 초성/mixed contains match
  if (_chosungContainsMatchRunes(qRunes, entry.koRunes)) return 30;

  // 6. Alias match (별명)
  for (final alias in entry.aliasesLower) {
    if (qLower == alias) return 95;
    if (alias.startsWith(qLower)) return 75;
    if (alias.contains(qLower)) return 55;
  }

  // 7. Japanese match
  if (entry.jaLower.isNotEmpty) {
    if (qLower == entry.jaLower) return 95;
    if (entry.jaLower.startsWith(qLower)) return 70;
    if (entry.jaLower.contains(qLower)) return 40;
  }

  // 8. English fallback
  if (entry.enLower.contains(qLower)) return 20;

  return 0;
}

/// Simple tri-language search with Korean chosung support.
/// Use this for any search field that needs KO/EN/JA matching.
/// Returns score > 0 if matched, 0 if not.
int triLanguageScore(String query, {
  required String nameKo,
  String nameEn = '',
  String nameJa = '',
  String internalKey = '',
}) {
  final entry = SearchEntry(null, nameKo, nameEn, nameJa: nameJa);
  final qLower = query.toLowerCase();
  final qRunes = qLower.runes.toList();
  final score = scoreEntry(qRunes, qLower, entry);
  if (score > 0) return score;
  if (internalKey.isNotEmpty && internalKey.toLowerCase().contains(qLower)) return 15;
  return 0;
}

const _chosung = [
  'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ',
  'ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ',
];

/// Returns true if [c] is a Korean syllable block (가-힣).
bool _isSyllable(int c) => c >= 0xAC00 && c <= 0xD7A3;

/// Returns true if [c] is a Hangul Compatibility Jamo (ㄱ-ㅎ, ㅏ-ㅣ).
bool _isJamo(int c) => c >= 0x3131 && c <= 0x314E;

/// Extracts the 초성 index (0-18) from a syllable code point.
int _chosungIndex(int syllableCode) => (syllableCode - 0xAC00) ~/ 588;

/// Extracts the 종성 index (0=none, 1-27) from a syllable code point.
int _jongsungIndex(int syllableCode) => (syllableCode - 0xAC00) % 28;

/// Returns the 초성 character for a syllable, or the char itself if not a syllable.
String _getChosung(int code) {
  if (_isSyllable(code)) return _chosung[_chosungIndex(code)];
  return String.fromCharCode(code);
}

/// Maps a Compatibility Jamo (ㄱ-ㅎ) to its 초성 index, or -1.
int _jamoToChosungIndex(int code) {
  const map = {
    0x3131: 0,  // ㄱ
    0x3132: 1,  // ㄲ
    0x3134: 2,  // ㄴ
    0x3137: 3,  // ㄷ
    0x3138: 4,  // ㄸ
    0x3139: 5,  // ㄹ
    0x3141: 6,  // ㅁ
    0x3142: 7,  // ㅂ
    0x3143: 8,  // ㅃ
    0x3145: 9,  // ㅅ
    0x3146: 10, // ㅆ
    0x3147: 11, // ㅇ
    0x3148: 12, // ㅈ
    0x3149: 13, // ㅉ
    0x314A: 14, // ㅊ
    0x314B: 15, // ㅋ
    0x314C: 16, // ㅌ
    0x314D: 17, // ㅍ
    0x314E: 18, // ㅎ
  };
  return map[code] ?? -1;
}

/// PC Korean IMEs combine successive consonants in chosung-only input
/// (e.g. typing ㅂ then ㅅ produces ㅄ). Each cluster jamo decomposes
/// back into its two component initials so the chosung matchers see
/// what the user *meant* to type — letting `ㅄㄹㄹ` reach `보스로라`
/// the same way `ㅂㅅㄹㄹ` does on mobile.
const _clusterDecompose = <int, List<int>>{
  0x3133: [0x3131, 0x3145], // ㄳ → ㄱ ㅅ
  0x3135: [0x3134, 0x3148], // ㄵ → ㄴ ㅈ
  0x3136: [0x3134, 0x314E], // ㄶ → ㄴ ㅎ
  0x313A: [0x3139, 0x3131], // ㄺ → ㄹ ㄱ
  0x313B: [0x3139, 0x3141], // ㄻ → ㄹ ㅁ
  0x313C: [0x3139, 0x3142], // ㄼ → ㄹ ㅂ
  0x313D: [0x3139, 0x3145], // ㄽ → ㄹ ㅅ
  0x313E: [0x3139, 0x314C], // ㄾ → ㄹ ㅌ
  0x313F: [0x3139, 0x314D], // ㄿ → ㄹ ㅍ
  0x3140: [0x3139, 0x314E], // ㅀ → ㄹ ㅎ
  0x3144: [0x3142, 0x3145], // ㅄ → ㅂ ㅅ
};

/// Decompose any cluster jamo in [runes] into its component initials.
/// Returns the input list unchanged when no clusters are present so the
/// common case stays allocation-free.
List<int> _expandJamoClusters(List<int> runes) {
  bool any = false;
  for (final c in runes) {
    if (_clusterDecompose.containsKey(c)) {
      any = true;
      break;
    }
  }
  if (!any) return runes;
  final out = <int>[];
  for (final c in runes) {
    final parts = _clusterDecompose[c];
    if (parts != null) {
      out.addAll(parts);
    } else {
      out.add(c);
    }
  }
  return out;
}

/// Match score for search ranking. Higher = better match.
/// Returns 0 for no match.
///
/// Prefer [scoreEntry] with pre-computed [SearchEntry] for batch searches.
int koreanMatchScore(String query, String target) {
  if (query.isEmpty) return 0;

  var q = query.toLowerCase();
  final t = target.toLowerCase();
  // See scoreEntry: PC IMEs combine consecutive consonants in chosung
  // input — decompose clusters back into their component initials.
  final qRunes = q.runes.toList();
  final expanded = _expandJamoClusters(qRunes);
  if (!identical(expanded, qRunes)) {
    q = String.fromCharCodes(expanded);
  }

  // 1. Exact match
  if (q == t) return 100;

  // 2. Prefix match (with syllable-prefix on last char)
  if (_prefixMatch(q, t)) return 80;

  // 3. Contains match
  if (t.contains(q)) return 60;

  // 4. 초성/mixed prefix match
  if (_chosungPrefixMatch(q, t)) return 50;

  // 5. 초성/mixed contains match
  if (_chosungContainsMatch(q, t)) return 30;

  return 0;
}

// ------------------------------------------------------------------
// Runes-based matching (for pre-computed SearchEntry)
// ------------------------------------------------------------------

bool _prefixMatchRunes(List<int> qRunes, List<int> tRunes) {
  for (int i = 0; i < qRunes.length; i++) {
    final qc = qRunes[i];
    final tc = tRunes[i];
    if (i == qRunes.length - 1) {
      if (!_syllableMatch(qc, tc)) return false;
    } else {
      if (qc != tc) return false;
    }
  }
  return true;
}

bool _chosungPrefixMatchRunes(List<int> qRunes, List<int> tRunes) {
  for (int i = 0; i < qRunes.length; i++) {
    final qc = qRunes[i];
    final tc = tRunes[i];
    if (_isJamo(qc)) {
      if (!_isSyllable(tc)) return false;
      final jamoIdx = _jamoToChosungIndex(qc);
      if (jamoIdx < 0 || jamoIdx != _chosungIndex(tc)) return false;
    } else if (i == qRunes.length - 1) {
      if (!_syllableMatch(qc, tc)) return false;
    } else {
      if (qc != tc) return false;
    }
  }
  return true;
}

bool _chosungContainsMatchRunes(List<int> qRunes, List<int> tRunes) {
  final maxStart = tRunes.length - qRunes.length;
  for (int start = 1; start <= maxStart; start++) {
    bool match = true;
    for (int i = 0; i < qRunes.length; i++) {
      final qc = qRunes[i];
      final tc = tRunes[start + i];
      if (_isJamo(qc)) {
        if (!_isSyllable(tc)) { match = false; break; }
        final jamoIdx = _jamoToChosungIndex(qc);
        if (jamoIdx < 0 || jamoIdx != _chosungIndex(tc)) { match = false; break; }
      } else if (i == qRunes.length - 1) {
        if (!_syllableMatch(qc, tc)) { match = false; break; }
      } else {
        if (qc != tc) { match = false; break; }
      }
    }
    if (match) return true;
  }
  return false;
}

/// Prefix match with syllable-prefix support on the last character.
/// "이사" matches "이상해씨" because 사 (no 종성) covers the range 사-삿 (including 상).
bool _prefixMatch(String query, String target) {
  final qRunes = query.runes.toList();
  final tRunes = target.runes.toList();

  if (qRunes.length > tRunes.length) return false;

  for (int i = 0; i < qRunes.length; i++) {
    final qc = qRunes[i];
    final tc = tRunes[i];

    if (i == qRunes.length - 1) {
      // Last char: use syllable-prefix matching
      if (!_syllableMatch(qc, tc)) return false;
    } else {
      // Earlier chars: exact match
      if (qc != tc) return false;
    }
  }
  return true;
}

/// Single character match with syllable-prefix support.
/// If query char is a syllable without 종성, match any syllable in the 28-char range.
bool _syllableMatch(int queryCode, int targetCode) {
  if (queryCode == targetCode) return true;

  // Query is a syllable without 종성 → match range
  if (_isSyllable(queryCode) && _isSyllable(targetCode)) {
    if (_jongsungIndex(queryCode) == 0) {
      return targetCode >= queryCode && targetCode <= queryCode + 27;
    }
  }

  // Query is a jamo → match 초성 of target syllable
  if (_isJamo(queryCode) && _isSyllable(targetCode)) {
    final jamoIdx = _jamoToChosungIndex(queryCode);
    return jamoIdx >= 0 && jamoIdx == _chosungIndex(targetCode);
  }

  return false;
}

/// 초성/mixed prefix match: each query char is either a jamo (match 초성)
/// or a syllable (match exactly, with syllable-prefix on last char).
bool _chosungPrefixMatch(String query, String target) {
  final qRunes = query.runes.toList();
  final tRunes = target.runes.toList();

  if (qRunes.length > tRunes.length) return false;

  for (int i = 0; i < qRunes.length; i++) {
    final qc = qRunes[i];
    final tc = tRunes[i];

    if (_isJamo(qc)) {
      // Jamo: match 초성
      if (!_isSyllable(tc)) return false;
      final jamoIdx = _jamoToChosungIndex(qc);
      if (jamoIdx < 0 || jamoIdx != _chosungIndex(tc)) return false;
    } else if (i == qRunes.length - 1) {
      // Last non-jamo char: syllable-prefix
      if (!_syllableMatch(qc, tc)) return false;
    } else {
      // Earlier non-jamo char: exact
      if (qc != tc) return false;
    }
  }
  return true;
}

/// 초성/mixed contains match: try _chosungPrefixMatch at every position.
bool _chosungContainsMatch(String query, String target) {
  final tRunes = target.runes.toList();
  final qLen = query.runes.length;

  for (int start = 1; start <= tRunes.length - qLen; start++) {
    final sub = String.fromCharCodes(tRunes.sublist(start));
    if (_chosungPrefixMatch(query, sub)) return true;
  }
  return false;
}
