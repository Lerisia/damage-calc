import '../utils/app_strings.dart';

/// Pokemon natures that affect stat growth
///
/// Each nature boosts one stat by 1.1x and reduces another by 0.9x.
/// Neutral natures have no effect.
enum Nature {
  hardy,    // neutral
  lonely,   // +Atk  -Def
  brave,    // +Atk  -Spe
  adamant,  // +Atk  -SpA
  naughty,  // +Atk  -SpD
  bold,     // +Def  -Atk
  docile,   // neutral
  relaxed,  // +Def  -Spe
  impish,   // +Def  -SpA
  lax,      // +Def  -SpD
  timid,    // +Spe  -Atk
  hasty,    // +Spe  -Def
  serious,  // neutral
  jolly,    // +Spe  -SpA
  naive,    // +Spe  -SpD
  modest,   // +SpA  -Atk
  mild,     // +SpA  -Def
  quiet,    // +SpA  -Spe
  bashful,  // neutral
  rash,     // +SpA  -SpD
  calm,     // +SpD  -Atk
  gentle,   // +SpD  -Def
  sassy,    // +SpD  -Spe
  careful,  // +SpD  -SpA
  quirky;   // neutral

  String get nameKo => _nameKo[this]!;
  String get nameJa => _nameJa[this]!;
  String get localizedName => AppStrings.name(nameKo: nameKo, nameEn: name, nameJa: nameJa);

  /// Returns the nature modifier for each stat: 1.1, 0.9, or 1.0
  double get attackModifier => _modifiers[this]![0];
  double get defenseModifier => _modifiers[this]![1];
  double get spAttackModifier => _modifiers[this]![2];
  double get spDefenseModifier => _modifiers[this]![3];
  double get speedModifier => _modifiers[this]![4];

  // [Atk, Def, SpA, SpD, Spe]
  static const Map<Nature, List<double>> _modifiers = {
    hardy:   [1.0, 1.0, 1.0, 1.0, 1.0],
    lonely:  [1.1, 0.9, 1.0, 1.0, 1.0],
    brave:   [1.1, 1.0, 1.0, 1.0, 0.9],
    adamant: [1.1, 1.0, 0.9, 1.0, 1.0],
    naughty: [1.1, 1.0, 1.0, 0.9, 1.0],
    bold:    [0.9, 1.1, 1.0, 1.0, 1.0],
    docile:  [1.0, 1.0, 1.0, 1.0, 1.0],
    relaxed: [1.0, 1.1, 1.0, 1.0, 0.9],
    impish:  [1.0, 1.1, 0.9, 1.0, 1.0],
    lax:     [1.0, 1.1, 1.0, 0.9, 1.0],
    timid:   [0.9, 1.0, 1.0, 1.0, 1.1],
    hasty:   [1.0, 0.9, 1.0, 1.0, 1.1],
    serious: [1.0, 1.0, 1.0, 1.0, 1.0],
    jolly:   [1.0, 1.0, 0.9, 1.0, 1.1],
    naive:   [1.0, 1.0, 1.0, 0.9, 1.1],
    modest:  [0.9, 1.0, 1.1, 1.0, 1.0],
    mild:    [1.0, 0.9, 1.1, 1.0, 1.0],
    quiet:   [1.0, 1.0, 1.1, 1.0, 0.9],
    bashful: [1.0, 1.0, 1.0, 1.0, 1.0],
    rash:    [1.0, 1.0, 1.1, 0.9, 1.0],
    calm:    [0.9, 1.0, 1.0, 1.1, 1.0],
    gentle:  [1.0, 0.9, 1.0, 1.1, 1.0],
    sassy:   [1.0, 1.0, 1.0, 1.1, 0.9],
    careful: [1.0, 1.0, 0.9, 1.1, 1.0],
    quirky:  [1.0, 1.0, 1.0, 1.0, 1.0],
  };

  static const Map<Nature, String> _nameKo = {
    hardy: '노력', lonely: '외로움', adamant: '고집', naughty: '개구쟁이', brave: '용감',
    bold: '대담', docile: '온순', impish: '장난꾸러기', lax: '촐랑', relaxed: '무사태평',
    modest: '조심', mild: '의젓', bashful: '수줍음', rash: '덜렁', quiet: '냉정',
    calm: '차분', gentle: '얌전', careful: '신중', quirky: '변덕', sassy: '건방',
    timid: '겁쟁이', hasty: '성급', jolly: '명랑', naive: '천진난만', serious: '성실',
  };

  static const Map<Nature, String> _nameJa = {
    hardy: 'がんばりや', lonely: 'さみしがり', adamant: 'いじっぱり', naughty: 'やんちゃ', brave: 'ゆうかん',
    bold: 'ずぶとい', docile: 'すなお', impish: 'わんぱく', lax: 'のうてんき', relaxed: 'のんき',
    modest: 'ひかえめ', mild: 'おっとり', bashful: 'てれや', rash: 'うっかりや', quiet: 'れいせい',
    calm: 'おだやか', gentle: 'おとなしい', careful: 'しんちょう', quirky: 'きまぐれ', sassy: 'なまいき',
    timid: 'おくびょう', hasty: 'せっかち', jolly: 'ようき', naive: 'むじゃき', serious: 'まじめ',
  };
}

/// Frequently used natures first, then the rest in original order.
const sortedNatures = [
  Nature.hardy, Nature.adamant, Nature.jolly, Nature.modest,
  Nature.timid, Nature.impish, Nature.bold, Nature.calm, Nature.careful,
  // rest in enum order
  Nature.lonely, Nature.brave, Nature.naughty, Nature.docile,
  Nature.relaxed, Nature.lax, Nature.hasty, Nature.serious, Nature.naive,
  Nature.mild, Nature.quiet, Nature.bashful, Nature.rash,
  Nature.gentle, Nature.sassy, Nature.quirky,
];
