/// Localization strings for the damage calculator.
/// Supports Korean (ko), English (en), and Japanese (ja).
///
/// No trademarked terms (Pokemon, etc.) are used.

import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { ko, en, ja }

class AppStrings {
  static const _prefKey = 'app_language';
  static AppLanguage _current = AppLanguage.ko;

  static AppLanguage get current => _current;

  static void setLanguage(AppLanguage lang) {
    _current = lang;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefKey, lang.name);
    });
  }

  /// Test-only: set language without touching SharedPreferences.
  static void setLanguageForTest(AppLanguage lang) => _current = lang;

  /// Load saved language preference, or detect from system locale.
  /// Call once at startup.
  static Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _current = AppLanguage.values.where((l) => l.name == saved).firstOrNull
          ?? AppLanguage.ko;
    } else {
      _current = _detectSystemLanguage();
    }
  }

  /// Detect language from system locale.
  static AppLanguage _detectSystemLanguage() {
    final locale = ui.PlatformDispatcher.instance.locale;
    switch (locale.languageCode) {
      case 'ko':
        return AppLanguage.ko;
      case 'ja':
        return AppLanguage.ja;
      default:
        return AppLanguage.en;
    }
  }

  static String get(String key) => (_strings[key]?[_current]) ?? key;

  // Shorthand
  static String t(String key) => get(key);

  /// Returns the localized name from a data object with nameKo/nameEn/nameJa fields.
  /// Falls back: current lang → English → Korean → name.
  static String name({
    required String nameKo,
    String? nameEn,
    String? nameJa,
    String? name,
  }) {
    return switch (_current) {
      AppLanguage.ko => nameKo,
      AppLanguage.en => nameEn ?? name ?? nameKo,
      AppLanguage.ja => nameJa ?? nameKo,
    };
  }

  /// Returns the correct Korean subject particle (이/가) for [name]
  /// based on the last Hangul syllable's jongseong (받침). Names that
  /// don't end in a Hangul syllable (e.g. English/Japanese names shown
  /// untranslated) default to "가".
  static String koSubjectParticle(String name) {
    if (name.isEmpty) return '가';
    final last = name.runes.last;
    // Hangul syllable block U+AC00 ~ U+D7A3.
    if (last < 0xAC00 || last > 0xD7A3) return '가';
    return ((last - 0xAC00) % 28) == 0 ? '가' : '이';
  }

  /// Like [name] but returns null when the corresponding field is null
  /// (no language fallback). Used for optional fields like ability /
  /// move descriptions where we'd rather show nothing than the wrong
  /// language.
  static String? maybeName({
    String? nameKo,
    String? nameEn,
    String? nameJa,
  }) {
    return switch (_current) {
      AppLanguage.ko => nameKo ?? nameEn ?? nameJa,
      AppLanguage.en => nameEn ?? nameKo ?? nameJa,
      AppLanguage.ja => nameJa ?? nameEn ?? nameKo,
    };
  }

  static const Map<String, Map<AppLanguage, String>> _strings = {
    // === App ===
    'app.title': {
      AppLanguage.ko: '결정력 계산기',
      AppLanguage.en: 'Damage Calculator',
      AppLanguage.ja: 'ダメージ計算機',
    },
    'app.about': {
      AppLanguage.ko: '앱 소개',
      AppLanguage.en: 'About',
      AppLanguage.ja: 'アプリについて',
    },
    'team.title': {
      AppLanguage.ko: '파티 구축',
      AppLanguage.en: 'Team Builder',
      AppLanguage.ja: 'パーティ構築',
    },
    'team.tab.party': {
      AppLanguage.ko: '파티',
      AppLanguage.en: 'Party',
      AppLanguage.ja: 'パーティ',
    },
    'team.slot.tapToAdd': {
      AppLanguage.ko: '탭하여 포켓몬 추가',
      AppLanguage.en: 'Tap to add a Pokémon',
      AppLanguage.ja: 'タップしてポケモンを追加',
    },
    'team.slot.delete': {
      AppLanguage.ko: '슬롯 비우기',
      AppLanguage.en: 'Clear slot',
      AppLanguage.ja: 'スロットを空に',
    },
    'team.slot.save': {
      AppLanguage.ko: '슬롯 저장',
      AppLanguage.en: 'Save slot',
      AppLanguage.ja: 'スロットを保存',
    },
    'msg.saved': {
      AppLanguage.ko: '저장되었습니다',
      AppLanguage.en: 'Saved',
      AppLanguage.ja: '保存しました',
    },
    // ── Reverse-calc (역산) dialog ────────────────────────────────
    // Defender is the user's own pokemon (already in the calc);
    // they type the damage they actually took and we list the
    // attacker (EV, nature) candidates that match it.
    'reverse.title': {
      AppLanguage.ko: '역산',
      AppLanguage.en: 'Reverse calc',
      AppLanguage.ja: '逆算',
    },
    'reverse.subtitle': {
      AppLanguage.ko: '상대 노력치 추정',
      AppLanguage.en: 'opponent EV / nature',
      AppLanguage.ja: '相手の努力値推定',
    },
    'reverse.observed': {
      AppLanguage.ko: '받은 대미지',
      AppLanguage.en: 'Damage taken',
      AppLanguage.ja: '受けたダメージ',
    },
    // ── Party-image export (camera button on the team builder) ──
    'team.image.tooltip': {
      AppLanguage.ko: '파티 사진 저장',
      AppLanguage.en: 'Save party image',
      AppLanguage.ja: 'パーティ画像を保存',
    },
    // Party-tab capture flow: ask user whether to save a plain party
    // list or build a trainer card. Defense/offense tabs skip this
    // popup and capture directly.
    'team.captureChoice.title': {
      AppLanguage.ko: '무엇을 저장할까요?',
      AppLanguage.en: 'What would you like to save?',
      AppLanguage.ja: '何を保存しますか?',
    },
    'team.captureChoice.party': {
      AppLanguage.ko: '파티 목록',
      AppLanguage.en: 'Party list',
      AppLanguage.ja: 'パーティ一覧',
    },
    'team.captureChoice.trainerCard': {
      AppLanguage.ko: '트레이너 카드',
      AppLanguage.en: 'Trainer card',
      AppLanguage.ja: 'トレーナーカード',
    },
    'team.captureChoice.confirm': {
      AppLanguage.ko: '확인',
      AppLanguage.en: 'OK',
      AppLanguage.ja: '確認',
    },
    'common.comingSoon': {
      AppLanguage.ko: '곧 추가될 기능입니다.',
      AppLanguage.en: 'Coming soon.',
      AppLanguage.ja: '近日公開予定です。',
    },
    'trainerCard.title': {
      AppLanguage.ko: '트레이너 카드',
      AppLanguage.en: 'Trainer card',
      AppLanguage.ja: 'トレーナーカード',
    },
    'trainerCard.nameLabel': {
      AppLanguage.ko: '이름',
      AppLanguage.en: 'Name',
      AppLanguage.ja: '名前',
    },
    'trainerCard.seasonLabel': {
      AppLanguage.ko: '시즌 / 대회',
      AppLanguage.en: 'Season / event',
      AppLanguage.ja: 'シーズン / 大会',
    },
    'trainerCard.seasonHint': {
      AppLanguage.ko: '예: 챔피언스 시즌 1 / 자유 입력',
      AppLanguage.en: 'e.g., Champions Season 1 / free text',
      AppLanguage.ja: '例: チャンピオンズ シーズン1 / 自由記入',
    },
    'trainerCard.scoreLabel': {
      AppLanguage.ko: '점수 (선택)',
      AppLanguage.en: 'Score (optional)',
      AppLanguage.ja: 'スコア (任意)',
    },
    'trainerCard.scoreHint': {
      AppLanguage.ko: '예: 1850',
      AppLanguage.en: 'e.g., 1850',
      AppLanguage.ja: '例: 1850',
    },
    'trainerCard.scoreSuffix': {
      AppLanguage.ko: '점',
      AppLanguage.en: ' pts',
      AppLanguage.ja: '点',
    },
    'trainerCard.scorePrefix.final': {
      AppLanguage.ko: '최종',
      AppLanguage.en: 'Final',
      AppLanguage.ja: '最終',
    },
    'trainerCard.scorePrefix.best': {
      AppLanguage.ko: '최고',
      AppLanguage.en: 'Best',
      AppLanguage.ja: '最高',
    },
    'trainerCard.scorePrefix.current': {
      AppLanguage.ko: '현재',
      AppLanguage.en: 'Current',
      AppLanguage.ja: '現在',
    },
    'trainerCard.preview.title': {
      AppLanguage.ko: '이대로 저장할까요?',
      AppLanguage.en: 'Save this image?',
      AppLanguage.ja: 'この画像を保存しますか?',
    },
    'trainerCard.preview.confirm': {
      AppLanguage.ko: '저장',
      AppLanguage.en: 'Save',
      AppLanguage.ja: '保存',
    },
    'trainerCard.preview.back': {
      AppLanguage.ko: '돌아가기',
      AppLanguage.en: 'Back',
      AppLanguage.ja: '戻る',
    },
    'trainerCard.avatarSource.title': {
      AppLanguage.ko: '아바타 출처를 골라주세요',
      AppLanguage.en: 'Pick avatar source',
      AppLanguage.ja: 'アバターの取得元を選んでください',
    },
    'trainerCard.avatarSource.curated': {
      AppLanguage.ko: '트레이너 셋에서 고르기',
      AppLanguage.en: 'Pick from trainer set',
      AppLanguage.ja: 'トレーナーセットから選ぶ',
    },
    'trainerCard.avatarSource.upload': {
      AppLanguage.ko: '사진에서 업로드',
      AppLanguage.en: 'Upload from photos',
      AppLanguage.ja: '写真からアップロード',
    },
    'firstLaunch.welcomeTitle': {
      AppLanguage.ko: '결정력 계산기에 오신 것을 환영합니다',
      AppLanguage.en: 'Welcome to the Damage Calculator',
      AppLanguage.ja: 'ダメージ計算機へようこそ',
    },
    'firstLaunch.welcomeSub': {
      AppLanguage.ko: '시작하기 전에 한 가지만 정해 주세요!',
      AppLanguage.en: 'Please choose one option before you start.',
      AppLanguage.ja: '始める前に一つだけ選んでください。',
    },
    'firstLaunch.scopeLabel': {
      AppLanguage.ko: '계산기에서 다룰 포켓몬',
      AppLanguage.en: 'Which Pokémon should the calculator handle?',
      AppLanguage.ja: '計算機で扱うポケモン',
    },
    'firstLaunch.scopeChampions': {
      AppLanguage.ko: '포켓몬 챔피언스 등장 포켓몬만',
      AppLanguage.en: 'Pokémon Champions roster only',
      AppLanguage.ja: 'ポケモンチャンピオンズ登場ポケモンのみ',
    },
    'firstLaunch.scopeAll': {
      AppLanguage.ko: '모든 포켓몬',
      AppLanguage.en: 'All Pokémon',
      AppLanguage.ja: 'すべてのポケモン',
    },
    'firstLaunch.scopeNote': {
      AppLanguage.ko: '※ 설정에서 언제든지 바꿀 수 있습니다.',
      AppLanguage.en: 'You can change this anytime in settings.',
      AppLanguage.ja: '※ 設定からいつでも変更できます。',
    },
    'firstLaunch.modeLabel': {
      AppLanguage.ko: '어떤 모드를 선호하시나요?',
      AppLanguage.en: 'Which mode do you prefer?',
      AppLanguage.ja: 'どちらのモードを使いますか?',
    },
    'firstLaunch.modeSimple': {
      AppLanguage.ko: '간단 모드 — 배틀 중 빠른 대미지 계산',
      AppLanguage.en: 'Simple mode — quick damage check during battle',
      AppLanguage.ja: '簡単モード — 対戦中の素早いダメージ計算',
    },
    'firstLaunch.modeExtended': {
      AppLanguage.ko: '확장 모드 — 정교한 샘플 조정',
      AppLanguage.en: 'Extended mode — fine-tune sample sets',
      AppLanguage.ja: '拡張モード — 詳細なサンプル調整',
    },
    'firstLaunch.start': {
      AppLanguage.ko: '시작',
      AppLanguage.en: 'Start',
      AppLanguage.ja: '開始',
    },
    'sprite.combinedDownload': {
      AppLanguage.ko: '전체 팩 다운로드',
      AppLanguage.en: 'Download combined pack',
      AppLanguage.ja: '統合パックをダウンロード',
    },
    'sprite.combinedImport': {
      AppLanguage.ko: '전체 팩 가져오기',
      AppLanguage.en: 'Import combined pack',
      AppLanguage.ja: '統合パックを取り込み',
    },
    'sprite.combinedHowTo': {
      AppLanguage.ko: '"전체 팩 다운로드"를 누르면 브라우저에서 Showdown CDN으로부터 BW/Dex/박스 아이콘/트레이너를 한 번에 받아 ZIP으로 묶어줍니다. 받은 파일을 "전체 팩 가져오기"로 선택해주세요.',
      AppLanguage.en: 'Tap "Download combined pack" — your browser fetches BW / Dex / box icons / trainer sprites from Showdown\'s CDN and bundles them into one ZIP. Then tap "Import combined pack" and pick that file.',
      AppLanguage.ja: '「統合パックをダウンロード」をタップするとブラウザがShowdownのCDNからBW/Dex/ボックスアイコン/トレーナーを取得しZIPにまとめます。そのファイルを「統合パックを取り込み」で選択してください。',
    },
    'sprite.smogonDownload': {
      AppLanguage.ko: 'Smogon에서 다운로드',
      AppLanguage.en: 'Download from Smogon',
      AppLanguage.ja: 'Smogonからダウンロード',
    },
    'trainerCard.searchHint': {
      AppLanguage.ko: '검색 (예: 레드, 난천, 엘리트)',
      AppLanguage.en: 'Search (e.g., red, cynthia, ace)',
      AppLanguage.ja: '検索 (例: レッド, シロナ, エリート)',
    },
    'trainerCard.tapAvatarHint': {
      AppLanguage.ko: '아바타 영역을 눌러 사진을 변경할 수 있습니다.',
      AppLanguage.en: 'Tap the avatar area to change the photo.',
      AppLanguage.ja: 'アバター部分をタップして写真を変更できます。',
    },
    'trainerCard.category.all': {
      AppLanguage.ko: '전체',
      AppLanguage.en: 'All',
      AppLanguage.ja: 'すべて',
    },
    'trainerCard.category.champion': {
      AppLanguage.ko: '챔피언',
      AppLanguage.en: 'Champion',
      AppLanguage.ja: 'チャンピオン',
    },
    'trainerCard.category.gymLeader': {
      AppLanguage.ko: '체육관 관장',
      AppLanguage.en: 'Gym Leader',
      AppLanguage.ja: 'ジムリーダー',
    },
    'trainerCard.category.eliteFour': {
      AppLanguage.ko: '사천왕',
      AppLanguage.en: 'Elite Four',
      AppLanguage.ja: '四天王',
    },
    'trainerCard.category.protagonistRival': {
      AppLanguage.ko: '주인공·라이벌',
      AppLanguage.en: 'Protagonist · Rival',
      AppLanguage.ja: '主人公・ライバル',
    },
    'trainerCard.category.villainBoss': {
      AppLanguage.ko: '악의 조직',
      AppLanguage.en: 'Villain teams',
      AppLanguage.ja: '悪の組織',
    },
    'trainerCard.category.professor': {
      AppLanguage.ko: '박사',
      AppLanguage.en: 'Professors',
      AppLanguage.ja: '博士',
    },
    'trainerCard.category.npc': {
      AppLanguage.ko: '일반 트레이너',
      AppLanguage.en: 'NPC trainers',
      AppLanguage.ja: '一般トレーナー',
    },
    'trainerCard.category.other': {
      AppLanguage.ko: '기타',
      AppLanguage.en: 'Other',
      AppLanguage.ja: 'その他',
    },
    'trainerCard.gen.all': {
      AppLanguage.ko: '전 세대',
      AppLanguage.en: 'All gens',
      AppLanguage.ja: '全世代',
    },
    'trainerCard.gen.1': {
      AppLanguage.ko: '1세대',
      AppLanguage.en: 'Gen 1',
      AppLanguage.ja: '第1世代',
    },
    'trainerCard.gen.2': {
      AppLanguage.ko: '2세대',
      AppLanguage.en: 'Gen 2',
      AppLanguage.ja: '第2世代',
    },
    'trainerCard.gen.3': {
      AppLanguage.ko: '3세대',
      AppLanguage.en: 'Gen 3',
      AppLanguage.ja: '第3世代',
    },
    'trainerCard.gen.4': {
      AppLanguage.ko: '4세대',
      AppLanguage.en: 'Gen 4',
      AppLanguage.ja: '第4世代',
    },
    'trainerCard.gen.5': {
      AppLanguage.ko: '5세대',
      AppLanguage.en: 'Gen 5',
      AppLanguage.ja: '第5世代',
    },
    'trainerCard.gen.6': {
      AppLanguage.ko: '6세대',
      AppLanguage.en: 'Gen 6',
      AppLanguage.ja: '第6世代',
    },
    'trainerCard.gen.7': {
      AppLanguage.ko: '7세대',
      AppLanguage.en: 'Gen 7',
      AppLanguage.ja: '第7世代',
    },
    'trainerCard.gen.8': {
      AppLanguage.ko: '8세대',
      AppLanguage.en: 'Gen 8',
      AppLanguage.ja: '第8世代',
    },
    'trainerCard.gen.9': {
      AppLanguage.ko: '9세대',
      AppLanguage.en: 'Gen 9',
      AppLanguage.ja: '第9世代',
    },
    'trainerCard.gen.masters': {
      AppLanguage.ko: '마스터즈',
      AppLanguage.en: 'Masters',
      AppLanguage.ja: 'マスターズ',
    },
    'trainerCard.gen.other': {
      AppLanguage.ko: '기타',
      AppLanguage.en: 'Other',
      AppLanguage.ja: 'その他',
    },
    'trainerCard.themeColor': {
      AppLanguage.ko: '카드 테마',
      AppLanguage.en: 'Card theme',
      AppLanguage.ja: 'カードテーマ',
    },
    'trainerCard.showVariants': {
      AppLanguage.ko: '변종 포함',
      AppLanguage.en: 'Include variants',
      AppLanguage.ja: 'バリエーション込み',
    },
    'trainerCard.variant.default': {
      AppLanguage.ko: '기본',
      AppLanguage.en: 'Default',
      AppLanguage.ja: '基本',
    },
    'trainerCard.noMatches': {
      AppLanguage.ko: '검색 결과가 없습니다.',
      AppLanguage.en: 'No matches.',
      AppLanguage.ja: '一致するものがありません。',
    },
    'trainerCard.pickAvatar': {
      AppLanguage.ko: '아바타 선택',
      AppLanguage.en: 'Pick avatar',
      AppLanguage.ja: 'アバター選択',
    },
    'trainerCard.avatarMissing': {
      AppLanguage.ko: '아바타 없음',
      AppLanguage.en: 'No avatar',
      AppLanguage.ja: 'アバターなし',
    },
    'trainerCard.save': {
      AppLanguage.ko: '저장',
      AppLanguage.en: 'Save',
      AppLanguage.ja: '保存',
    },
    'trainerCard.defaultName': {
      AppLanguage.ko: '트레이너',
      AppLanguage.en: 'Trainer',
      AppLanguage.ja: 'トレーナー',
    },
    'team.image.empty': {
      AppLanguage.ko: '파티가 비어있어 저장할 사진이 없습니다.',
      AppLanguage.en: 'Add at least one Pokémon before saving an image.',
      AppLanguage.ja: 'パーティが空のため保存できる画像がありません。',
    },
    'team.image.saved': {
      AppLanguage.ko: '파티 사진을 저장했습니다.',
      AppLanguage.en: 'Party image saved.',
      AppLanguage.ja: 'パーティ画像を保存しました。',
    },
    'team.image.failed': {
      AppLanguage.ko: '저장에 실패했습니다',
      AppLanguage.en: 'Save failed',
      AppLanguage.ja: '保存に失敗しました',
    },
    'team.image.defaultName': {
      AppLanguage.ko: '파티',
      AppLanguage.en: 'Party',
      AppLanguage.ja: 'パーティ',
    },
    'reverse.hpBefore': {
      AppLanguage.ko: '맞기 전 HP',
      AppLanguage.en: 'HP before',
      AppLanguage.ja: '被弾前 HP',
    },
    'reverse.hpAfter': {
      AppLanguage.ko: '맞은 후 HP',
      AppLanguage.en: 'HP after',
      AppLanguage.ja: '被弾後 HP',
    },
    'reverse.observedHint': {
      AppLanguage.ko: '예: 48',
      AppLanguage.en: 'e.g., 48',
      AppLanguage.ja: '例: 48',
    },
    'reverse.run': {
      // Inside the popup itself the button reads '계산' — the
      // popup's own title is '역산', and the idle-hint copy says
      // "계산을 누르세요", so the verb on the button stays
      // consistent with the surrounding language. The chip that
      // opens the popup stays '역산' (reverse.chip).
      AppLanguage.ko: '계산',
      AppLanguage.en: 'Calc',
      AppLanguage.ja: '計算',
    },
    'reverse.idleHint': {
      AppLanguage.ko: '실제 받은 대미지를 입력하고 계산을 누르세요.',
      AppLanguage.en: 'Type the damage you actually took and press Calc.',
      AppLanguage.ja: '実際に受けたダメージを入力して計算を押してください。',
    },
    'reverse.invalid': {
      AppLanguage.ko: '양의 정수만 입력 가능합니다.',
      AppLanguage.en: 'Positive integers only.',
      AppLanguage.ja: '正の整数のみ入力可能です。',
    },
    'reverse.noMatch': {
      AppLanguage.ko: '일치하는 노력치 조합이 없습니다. 아이템 / 특성 / 랭크 가정을 점검해 보세요.',
      AppLanguage.en: 'No EV / nature combo matches. Re-check the item / ability / rank assumptions.',
      AppLanguage.ja: '一致する努力値の組み合わせがありません。持ち物・特性・ランクの仮定を見直してください。',
    },
    'reverse.chip': {
      AppLanguage.ko: '역산',
      AppLanguage.en: 'Reverse',
      AppLanguage.ja: '逆算',
    },
    // Count line above the candidate list. `{n}` substitutes the
    // candidate count. Searched-total is intentionally NOT shown —
    // users found '32/192' confusing.
    'reverse.countLine': {
      AppLanguage.ko: '검색 결과 총 {n}건',
      AppLanguage.en: '{n} matches',
      AppLanguage.ja: '検索結果 {n} 件',
    },
    'nature.neutralShort': {
      AppLanguage.ko: '무보정 성격',
      AppLanguage.en: 'No boost',
      AppLanguage.ja: '無補正',
    },
    'nature.boostShort': {
      AppLanguage.ko: '상승 성격',
      AppLanguage.en: 'Boost',
      AppLanguage.ja: '上昇補正',
    },
    'nature.dropShort': {
      AppLanguage.ko: '하락 성격',
      AppLanguage.en: 'Drop',
      AppLanguage.ja: '下降補正',
    },
    'dex.shinyToggle': {
      AppLanguage.ko: '색이 다른',
      AppLanguage.en: 'Shiny',
      AppLanguage.ja: '色違い',
    },
    'team.slot.shinyToggle': {
      AppLanguage.ko: '색이 다른 모습',
      AppLanguage.en: 'Show shiny',
      AppLanguage.ja: '色違いを表示',
    },
    'team.slot.toAttacker': {
      AppLanguage.ko: '공격측으로',
      AppLanguage.en: 'Send to attacker',
      AppLanguage.ja: '攻撃側へ',
    },
    'team.slot.toDefender': {
      AppLanguage.ko: '방어측으로',
      AppLanguage.en: 'Send to defender',
      AppLanguage.ja: '防御側へ',
    },
    // Team-builder-only abbreviation: the slot popup's EV row puts
    // 6 narrow cells side-by-side, and "스피드" (5 chars) was the
    // longest label by a wide margin — it wrapped or ellipsized
    // while the others sat comfortably. "스핏" reads as Speed in
    // context and fits the same width as the other 2-char labels.
    'stat.speedShort': {
      AppLanguage.ko: '스핏',
      AppLanguage.en: 'Spe',
      AppLanguage.ja: 'すば',
    },
    'team.tab.defense': {
      AppLanguage.ko: '방어 상성',
      AppLanguage.en: 'Defense',
      AppLanguage.ja: '防御相性',
    },
    'team.tab.offense': {
      AppLanguage.ko: '공격 상성',
      AppLanguage.en: 'Offense',
      AppLanguage.ja: '攻撃相性',
    },
    'team.slot.empty': {
      AppLanguage.ko: '비어있음',
      AppLanguage.en: 'Empty slot',
      AppLanguage.ja: '空きスロット',
    },
    'team.matrix.weak': {
      AppLanguage.ko: '약점',
      AppLanguage.en: 'Weak',
      AppLanguage.ja: '弱点',
    },
    'team.matrix.resist': {
      AppLanguage.ko: '저항',
      AppLanguage.en: 'Resist',
      AppLanguage.ja: '耐性',
    },
    'team.matrix.immune': {
      AppLanguage.ko: '무효',
      AppLanguage.en: 'Immune',
      AppLanguage.ja: '無効',
    },
    'team.matrix.empty': {
      AppLanguage.ko: '포켓몬을 먼저 추가해 주십시오.',
      AppLanguage.en: 'Add at least one Pokemon to see coverage.',
      AppLanguage.ja: 'まずポケモンを追加してください。',
    },
    'team.item.none': {
      AppLanguage.ko: '아이템 없음',
      AppLanguage.en: 'No item',
      AppLanguage.ja: '道具なし',
    },
    'team.sample.load': {
      AppLanguage.ko: '저장된 샘플 불러오기',
      AppLanguage.en: 'Load saved sample',
      AppLanguage.ja: '保存されたサンプルを読み込む',
    },
    'team.sample.empty': {
      AppLanguage.ko: '저장된 샘플이 없습니다.',
      AppLanguage.en: 'No saved samples yet.',
      AppLanguage.ja: '保存されたサンプルがありません。',
    },
    'team.resetAll': {
      AppLanguage.ko: '초기화',
      AppLanguage.en: 'Reset',
      AppLanguage.ja: 'リセット',
    },
    'team.resetAll.confirm': {
      AppLanguage.ko: '6마리 전부 비우시겠습니까?',
      AppLanguage.en: 'Clear all 6 slots?',
      AppLanguage.ja: '6体すべてクリアしますか？',
    },
    'team.load': {
      AppLanguage.ko: '불러오기',
      AppLanguage.en: 'Load',
      AppLanguage.ja: '読込',
    },
    'team.save': {
      AppLanguage.ko: '파티 저장',
      AppLanguage.en: 'Save party',
      AppLanguage.ja: 'パーティ保存',
    },
    'team.load.title': {
      AppLanguage.ko: '불러올 파티',
      AppLanguage.en: 'Pick a party',
      AppLanguage.ja: 'パーティ選択',
    },
    'team.load.noTeams': {
      AppLanguage.ko: '저장된 파티가 없습니다',
      AppLanguage.en: 'No saved parties yet',
      AppLanguage.ja: '保存されたパーティがありません',
    },
    'team.load.replaceConfirm': {
      AppLanguage.ko: '현재 입력된 포켓몬이 사라집니다. 계속하시겠습니까?',
      AppLanguage.en: 'Current slots will be replaced. Continue?',
      AppLanguage.ja: '現在のスロットが置き換わります。続行しますか？',
    },
    'team.save.title': {
      AppLanguage.ko: '새 파티 이름',
      AppLanguage.en: 'New party name',
      AppLanguage.ja: '新しいパーティ名',
    },
    'team.save.empty': {
      AppLanguage.ko: '저장할 포켓몬이 없습니다',
      AppLanguage.en: 'No pokemon to save',
      AppLanguage.ja: '保存するポケモンがありません',
    },
    'team.save.done': {
      AppLanguage.ko: '저장 완료',
      AppLanguage.en: 'Saved',
      AppLanguage.ja: '保存完了',
    },
    'team.save.overwrite.title': {
      AppLanguage.ko: '같은 이름의 파티가 있습니다',
      AppLanguage.en: 'Party with this name exists',
      AppLanguage.ja: '同じ名前のパーティがあります',
    },
    'team.save.overwrite.body': {
      AppLanguage.ko: '기존 파티를 덮어쓰시겠습니까?',
      AppLanguage.en: 'Overwrite the existing party?',
      AppLanguage.ja: '既存のパーティを上書きしますか？',
    },
    'team.matrix.display.numeric': {
      AppLanguage.ko: '숫자',
      AppLanguage.en: 'Numbers',
      AppLanguage.ja: '数値',
    },
    'team.matrix.display.symbolic': {
      AppLanguage.ko: '기호',
      AppLanguage.en: 'Symbols',
      AppLanguage.ja: '記号',
    },
    'team.matrix.showOffensive': {
      AppLanguage.ko: '공격 상성표',
      AppLanguage.en: 'Offensive coverage',
      AppLanguage.ja: '攻撃相性表',
    },
    'team.matrix.lineup': {
      AppLanguage.ko: '선출',
      AppLanguage.en: 'Lineup',
      AppLanguage.ja: '選出',
    },
    'team.opponent': {
      AppLanguage.ko: '상대',
      AppLanguage.en: 'Opponents',
      AppLanguage.ja: '相手',
    },
    'team.opponent.add': {
      AppLanguage.ko: '상대 추가',
      AppLanguage.en: 'Add opponent',
      AppLanguage.ja: '相手を追加',
    },
    'team.matrix.lineup.hint': {
      AppLanguage.ko: '표 위 이름을 눌러 선출에 추가/제외',
      AppLanguage.en: 'Tap a header name to add / remove from the lineup',
      AppLanguage.ja: '表の名前をタップして選出に追加 / 除外',
    },
    'team.matrix.defensive': {
      AppLanguage.ko: '방어 상성표',
      AppLanguage.en: 'Defensive coverage',
      AppLanguage.ja: '防御相性表',
    },
    'label.move': {
      AppLanguage.ko: '기술',
      AppLanguage.en: 'Move',
      AppLanguage.ja: '技',
    },
    // ── Sample storage / party folders (load + save sheets) ──────
    'sample.team.add': {
      AppLanguage.ko: '파티 추가',
      AppLanguage.en: 'Add party',
      AppLanguage.ja: 'パーティ追加',
    },
    'sample.team.namePrompt': {
      AppLanguage.ko: '파티 이름',
      AppLanguage.en: 'Party name',
      AppLanguage.ja: 'パーティ名',
    },
    'sample.team.rename': {
      AppLanguage.ko: '이름 변경',
      AppLanguage.en: 'Rename',
      AppLanguage.ja: '名前を変更',
    },
    'sample.team.delete': {
      AppLanguage.ko: '파티 삭제',
      AppLanguage.en: 'Delete party',
      AppLanguage.ja: 'パーティ削除',
    },
    'sample.team.delete.title': {
      AppLanguage.ko: '파티 삭제',
      AppLanguage.en: 'Delete party',
      AppLanguage.ja: 'パーティ削除',
    },
    'sample.team.delete.body': {
      AppLanguage.ko: '소속 포켓몬은 어떻게 처리하시겠습니까?',
      AppLanguage.en: 'What should happen to the pokemon in this party?',
      AppLanguage.ja: 'このパーティのポケモンはどうしますか？',
    },
    'sample.team.delete.keep': {
      AppLanguage.ko: '분리',
      AppLanguage.en: 'Detach',
      AppLanguage.ja: '分離',
    },
    'sample.team.delete.cascade': {
      AppLanguage.ko: '함께 삭제',
      AppLanguage.en: 'Delete all',
      AppLanguage.ja: '一緒に削除',
    },
    'sample.team.empty': {
      AppLanguage.ko: '비어있음',
      AppLanguage.en: 'Empty',
      AppLanguage.ja: '空',
    },
    'sample.team.full': {
      AppLanguage.ko: '가득참',
      AppLanguage.en: 'Full',
      AppLanguage.ja: '満員',
    },
    'sample.loose.title': {
      AppLanguage.ko: '파티 없음',
      AppLanguage.en: 'No party',
      AppLanguage.ja: 'パーティなし',
    },
    'sample.pokemon.rename': {
      AppLanguage.ko: '이름 변경',
      AppLanguage.en: 'Rename',
      AppLanguage.ja: '名前を変更',
    },
    'sample.pokemon.move': {
      AppLanguage.ko: '다른 파티로 이동',
      AppLanguage.en: 'Move to party…',
      AppLanguage.ja: '他のパーティへ移動',
    },
    'sample.pokemon.delete': {
      AppLanguage.ko: '삭제',
      AppLanguage.en: 'Delete',
      AppLanguage.ja: '削除',
    },
    'sample.move.title': {
      AppLanguage.ko: '어디로 이동하시겠습니까?',
      AppLanguage.en: 'Move to where?',
      AppLanguage.ja: 'どこへ移動しますか？',
    },
    'sample.move.toLoose': {
      AppLanguage.ko: '파티 없음으로',
      AppLanguage.en: 'No party',
      AppLanguage.ja: 'パーティなしへ',
    },
    'sample.team.fullSnack': {
      AppLanguage.ko: '파티가 가득 찼습니다 (6/6)',
      AppLanguage.en: 'Party is full (6/6)',
      AppLanguage.ja: 'パーティが満員です (6/6)',
    },
    'sample.name.dup': {
      AppLanguage.ko: '같은 이름이 이미 있습니다',
      AppLanguage.en: 'A sample with this name already exists',
      AppLanguage.ja: '同じ名前のサンプルが既にあります',
    },
    'sample.save.team': {
      AppLanguage.ko: '저장 파티',
      AppLanguage.en: 'Save into',
      AppLanguage.ja: '保存先',
    },
    'sample.save.team.none': {
      AppLanguage.ko: '파티 없음',
      AppLanguage.en: 'No party',
      AppLanguage.ja: 'パーティなし',
    },
    'sample.save.team.create': {
      AppLanguage.ko: '+ 새 파티 만들기',
      AppLanguage.en: '+ New party…',
      AppLanguage.ja: '+ 新しいパーティ…',
    },
    'app.theme': {
      AppLanguage.ko: '테마',
      AppLanguage.en: 'Theme',
      AppLanguage.ja: 'テーマ',
    },
    'battle.format': {
      AppLanguage.ko: '배틀 형식',
      AppLanguage.en: 'Battle format',
      AppLanguage.ja: 'バトル形式',
    },
    'battle.singles': {
      AppLanguage.ko: '싱글',
      AppLanguage.en: 'Singles',
      AppLanguage.ja: 'シングル',
    },
    'battle.doubles': {
      AppLanguage.ko: '더블',
      AppLanguage.en: 'Doubles',
      AppLanguage.ja: 'ダブル',
    },
    'battle.formatSwitchTitle': {
      AppLanguage.ko: '배틀 형식 전환',
      AppLanguage.en: 'Switch battle format',
      AppLanguage.ja: 'バトル形式の切替',
    },
    'battle.formatSwitchMessage': {
      AppLanguage.ko: '입력한 정보가 모두 초기화됩니다. 계속하시겠습니까?',
      AppLanguage.en: 'All entered data will be reset. Continue?',
      AppLanguage.ja: '入力した内容がすべてリセットされます。続けますか？',
    },
    'app.themeLight': {
      AppLanguage.ko: '라이트 모드',
      AppLanguage.en: 'Light mode',
      AppLanguage.ja: 'ライトモード',
    },
    'app.themeDark': {
      AppLanguage.ko: '다크 모드',
      AppLanguage.en: 'Dark mode',
      AppLanguage.ja: 'ダークモード',
    },
    'app.spriteStyle': {
      AppLanguage.ko: '스프라이트 스타일',
      AppLanguage.en: 'Sprite style',
      AppLanguage.ja: 'スプライトスタイル',
    },
    'sprite.style.bw': {
      AppLanguage.ko: 'BW 도트',
      AppLanguage.en: 'BW Pixel',
      AppLanguage.ja: 'BWドット',
    },
    'sprite.style.ani': {
      AppLanguage.ko: '애니메이션',
      AppLanguage.en: 'Animated',
      AppLanguage.ja: 'アニメーション',
    },
    'sprite.style.dex': {
      AppLanguage.ko: 'HOME 3D',
      AppLanguage.en: 'HOME 3D',
      AppLanguage.ja: 'HOME 3D',
    },
    'sprite.mobileNotice': {
      AppLanguage.ko: '모바일에서는 이미지팩을 직접 받아 가져와야 표시됩니다. 웹은 자동으로 표시됩니다.',
      AppLanguage.en: 'Mobile shows sprites only after you import a sprite pack. Web loads them automatically.',
      AppLanguage.ja: 'モバイルではスプライトパックを取り込むと表示されます。Web版は自動表示。',
    },
    'sprite.installed': {
      AppLanguage.ko: '설치됨',
      AppLanguage.en: 'Installed',
      AppLanguage.ja: 'インストール済み',
    },
    'sprite.notInstalled': {
      AppLanguage.ko: '미설치',
      AppLanguage.en: 'Not installed',
      AppLanguage.ja: '未インストール',
    },
    'sprite.downloadPack': {
      AppLanguage.ko: 'Smogon 스프라이트 ZIP 다운로드',
      AppLanguage.en: 'Download Smogon sprite ZIP',
      AppLanguage.ja: 'Smogon スプライト ZIP をダウンロード',
    },
    'sprite.importZip': {
      AppLanguage.ko: '이미지팩 가져오기',
      AppLanguage.en: 'Import sprite pack',
      AppLanguage.ja: '画像パックを取り込み',
    },
    'sprite.removePack': {
      AppLanguage.ko: '이미지팩 제거',
      AppLanguage.en: 'Remove sprite pack',
      AppLanguage.ja: '画像パックを削除',
    },
    'sprite.importHowTo': {
      AppLanguage.ko: 'Smogon Sprite Project의 ZIP을 다운받아 가져옵니다 (본 앱이 이미지를 호스팅하지 않습니다).\n1) "Smogon 스프라이트 ZIP 다운로드"로 ZIP을 받으신 뒤  2) "이미지팩 가져오기"로 그 파일을 선택해주세요. 한 번 가져오면 오프라인에서도 표시됩니다.',
      AppLanguage.en: 'This downloads ZIPs from the Smogon Sprite Project (we do not host sprite images).\n1) Tap "Download Smogon sprite ZIP" to grab the file, then  2) tap "Import sprite pack" and pick it. Once imported, sprites work offline.',
      AppLanguage.ja: 'Smogon Sprite Project の ZIP をダウンロードして取り込みます (本アプリは画像をホストしていません)。\n1)「Smogon スプライト ZIP をダウンロード」でファイルを取得 → 2)「画像パックを取り込み」でファイルを選択。取り込み後はオフラインでも表示されます。',
    },
    'sprite.importedCount': {
      AppLanguage.ko: '{n}개의 스프라이트를 가져왔습니다.',
      AppLanguage.en: 'Imported {n} sprites.',
      AppLanguage.ja: '{n}件のスプライトを取り込みました。',
    },
    'sprite.importFailed': {
      AppLanguage.ko: '가져오기 실패: {err}',
      AppLanguage.en: 'Import failed: {err}',
      AppLanguage.ja: '取り込みに失敗しました: {err}',
    },
    'sprite.importWrongStyle': {
      AppLanguage.ko: '선택한 ZIP에는 이 스타일에 맞는 이미지가 없습니다. 다른 스타일의 팩을 잘못 고르셨는지 확인해주세요.',
      AppLanguage.en: 'The selected ZIP contains no images for this style. Did you pick a different style\'s pack by mistake?',
      AppLanguage.ja: '選択したZIPにこのスタイルの画像がありません。別スタイルのパックを選んでいないか確認してください。',
    },
    'sprite.importNotZip': {
      AppLanguage.ko: '선택한 파일이 ZIP 형식이 아닙니다. 다운로드한 이미지팩 zip 파일을 선택해주세요.',
      AppLanguage.en: 'The selected file is not a ZIP archive. Please pick the downloaded sprite-pack zip.',
      AppLanguage.ja: '選択したファイルはZIP形式ではありません。ダウンロードしたパックのzipファイルを選択してください。',
    },
    'sprite.confirmRemove': {
      AppLanguage.ko: '이 스타일의 이미지팩을 제거하시겠습니까? 다시 사용하려면 새로 가져와야 합니다.',
      AppLanguage.en: 'Remove this style\'s sprite pack? You\'ll need to re-import it to use again.',
      AppLanguage.ja: 'このスタイルの画像パックを削除しますか？再利用するには再度取り込みが必要です。',
    },
    'sprite.override.title': {
      AppLanguage.ko: '포켓몬별 이미지 설정',
      AppLanguage.en: 'Per-Pokémon images',
      AppLanguage.ja: 'ポケモン別の画像設定',
    },
    'sprite.override.menu': {
      AppLanguage.ko: '포켓몬별 이미지 변경',
      AppLanguage.en: 'Customize per Pokémon',
      AppLanguage.ja: 'ポケモン別画像を変更',
    },
    'sprite.override.howTo': {
      AppLanguage.ko: '포켓몬을 추가한 뒤 각 슬롯을 탭하면 이미지 파일을 골라 업로드할 수 있습니다. 길게 누르면 그 슬롯의 이미지가 제거됩니다.',
      AppLanguage.en: 'Add a Pokémon, then tap a slot to upload a custom image. Long-press a slot to clear just that image.',
      AppLanguage.ja: 'ポケモンを追加した後、各スロットをタップして画像をアップロードできます。長押しでそのスロットだけ削除。',
    },
    'sprite.override.add': {
      AppLanguage.ko: '포켓몬 추가',
      AppLanguage.en: 'Add Pokémon',
      AppLanguage.ja: 'ポケモンを追加',
    },
    'sprite.override.large': {
      AppLanguage.ko: '큰 이미지',
      AppLanguage.en: 'Large',
      AppLanguage.ja: '大きな画像',
    },
    'sprite.override.small': {
      AppLanguage.ko: '작은 이미지',
      AppLanguage.en: 'Small',
      AppLanguage.ja: '小さな画像',
    },
    'sprite.override.tapToUpload': {
      AppLanguage.ko: '슬롯을 탭해서 업로드하세요',
      AppLanguage.en: 'Tap a slot to upload',
      AppLanguage.ja: 'スロットをタップしてアップロード',
    },
    'sprite.override.removeRow': {
      AppLanguage.ko: '이 포켓몬의 모든 이미지 제거',
      AppLanguage.en: 'Remove both images for this Pokémon',
      AppLanguage.ja: 'このポケモンの画像をすべて削除',
    },
    'sprite.override.empty': {
      AppLanguage.ko: '아직 개별 이미지를 등록한 포켓몬이 없습니다. "포켓몬 추가"로 시작하세요.',
      AppLanguage.en: 'No per-Pokémon images yet. Tap "Add Pokémon" to start.',
      AppLanguage.ja: '個別画像を登録したポケモンはまだありません。「ポケモンを追加」から始めてください。',
    },
    'sprite.creditTitle': {
      AppLanguage.ko: '스프라이트 출처',
      AppLanguage.en: 'Sprite credit',
      AppLanguage.ja: 'スプライト出典',
    },
    'sprite.creditBody': {
      AppLanguage.ko: '포켓몬 스프라이트는 Pokémon Showdown CDN(play.pokemonshowdown.com/sprites)에서 직접 불러옵니다. BW 도트는 Smogon Sprite Project 커뮤니티가 제작하여 비영리 사용에 한해 사용을 허용한 것입니다. 본 앱은 어떤 이미지도 자체 호스팅하지 않습니다.',
      AppLanguage.en: 'Pokémon sprites are streamed directly from the Pokémon Showdown CDN (play.pokemonshowdown.com/sprites). The BW pixel set is produced by the Smogon Sprite Project community and licensed for non-profit use. This app hosts none of the images itself.',
      AppLanguage.ja: 'ポケモンのスプライトはPokémon ShowdownのCDN（play.pokemonshowdown.com/sprites）から直接読み込みます。BWドットはSmogon Sprite Projectのコミュニティが制作し、非営利利用に限り許諾されたものです。本アプリは画像を自前ホストしていません。',
    },
    'sprite.credits.title': {
      AppLanguage.ko: '스프라이트 크레딧',
      AppLanguage.en: 'Sprite credits',
      AppLanguage.ja: 'スプライトクレジット',
    },
    'sprite.credits.viewCredits': {
      AppLanguage.ko: '크레딧 보기',
      AppLanguage.en: 'View credits',
      AppLanguage.ja: 'クレジットを見る',
    },
    'sprite.credits.tabProjects': {
      AppLanguage.ko: '프로젝트별',
      AppLanguage.en: 'By project',
      AppLanguage.ja: 'プロジェクト別',
    },
    'sprite.credits.tabArtists': {
      AppLanguage.ko: '작가별',
      AppLanguage.en: 'By artist',
      AppLanguage.ja: '作者別',
    },
    'sprite.credits.leadArtists': {
      AppLanguage.ko: '리드',
      AppLanguage.en: 'Leads',
      AppLanguage.ja: 'リード',
    },
    'sprite.credits.spriteCount': {
      AppLanguage.ko: '스프라이트 {n}건',
      AppLanguage.en: '{n} sprites',
      AppLanguage.ja: 'スプライト {n}件',
    },

    // === Tabs ===
    'tab.attacker': {
      AppLanguage.ko: '공격측',
      AppLanguage.en: 'Attacker',
      AppLanguage.ja: '攻撃側',
    },
    'tab.defender': {
      AppLanguage.ko: '방어측',
      AppLanguage.en: 'Defender',
      AppLanguage.ja: '防御側',
    },
    'tab.damage': {
      AppLanguage.ko: '대미지',
      AppLanguage.en: 'Damage',
      AppLanguage.ja: 'ダメージ',
    },
    'tab.speed': {
      AppLanguage.ko: '스피드',
      AppLanguage.en: 'Speed',
      AppLanguage.ja: 'スピード',
    },

    // === Dex ===
    'dex.title': {
      AppLanguage.ko: '포켓몬 도감',
      AppLanguage.en: 'Pokédex',
      AppLanguage.ja: 'ポケモン図鑑',
    },
    'dex.move.title': {
      AppLanguage.ko: '기술 도감',
      AppLanguage.en: 'Move Dex',
      AppLanguage.ja: 'わざ図鑑',
    },
    'dex.menu': {
      AppLanguage.ko: '도감',
      AppLanguage.en: 'Dex',
      AppLanguage.ja: '図鑑',
    },
    'nav.calc': {
      AppLanguage.ko: '계산기',
      AppLanguage.en: 'Calc',
      AppLanguage.ja: '計算機',
    },
    'nav.dex': {
      AppLanguage.ko: '포켓몬 도감',
      AppLanguage.en: 'Pokédex',
      AppLanguage.ja: 'ポケモン図鑑',
    },
    'nav.moveDex': {
      AppLanguage.ko: '기술 도감',
      AppLanguage.en: 'Move Dex',
      AppLanguage.ja: 'わざ図鑑',
    },
    'nav.teamBuilder': {
      AppLanguage.ko: '파티 구축',
      AppLanguage.en: 'Team Builder',
      AppLanguage.ja: 'パーティ構築',
    },
    'dex.championsOnly': {
      AppLanguage.ko: '챔피언스만',
      AppLanguage.en: 'Champions only',
      AppLanguage.ja: 'チャンピオンズのみ',
    },
    'tag.contact': {
      AppLanguage.ko: '접촉',
      AppLanguage.en: 'Contact',
      AppLanguage.ja: '接触',
    },
    'tag.punch': {
      AppLanguage.ko: '펀치',
      AppLanguage.en: 'Punch',
      AppLanguage.ja: 'パンチ',
    },
    'tag.sound': {
      AppLanguage.ko: '음파',
      AppLanguage.en: 'Sound',
      AppLanguage.ja: '音',
    },
    'tag.bite': {
      AppLanguage.ko: '이빨',
      AppLanguage.en: 'Bite',
      AppLanguage.ja: '牙',
    },
    'tag.pulse': {
      AppLanguage.ko: '파동',
      AppLanguage.en: 'Pulse',
      AppLanguage.ja: '波動',
    },
    'tag.slice': {
      AppLanguage.ko: '베기',
      AppLanguage.en: 'Slice',
      AppLanguage.ja: '切',
    },
    'tag.recoil': {
      AppLanguage.ko: '반동',
      AppLanguage.en: 'Recoil',
      AppLanguage.ja: '反動',
    },
    'tag.ball': {
      AppLanguage.ko: '탄',
      AppLanguage.en: 'Ball',
      AppLanguage.ja: '弾',
    },
    'tag.powder': {
      AppLanguage.ko: '가루',
      AppLanguage.en: 'Powder',
      AppLanguage.ja: '粉',
    },
    'tag.wind': {
      AppLanguage.ko: '바람',
      AppLanguage.en: 'Wind',
      AppLanguage.ja: '風',
    },
    'dex.move.search': {
      AppLanguage.ko: '기술 검색',
      AppLanguage.en: 'Search moves',
      AppLanguage.ja: 'わざを検索',
    },
    'dex.move.learners': {
      AppLanguage.ko: '배우는 포켓몬',
      AppLanguage.en: 'Learnt by',
      AppLanguage.ja: '覚えるポケモン',
    },
    'dex.move.noLearners': {
      AppLanguage.ko: '배우는 포켓몬 없음',
      AppLanguage.en: 'No Pokémon learn this move',
      AppLanguage.ja: '覚えるポケモンなし',
    },
    'dex.move.alsoLearns': {
      AppLanguage.ko: '함께 배우는 기술',
      AppLanguage.en: 'Also learns',
      AppLanguage.ja: '一緒に覚える技',
    },
    'dex.move.addFilterHint': {
      AppLanguage.ko: '기술 추가 (최대 3개)',
      AppLanguage.en: 'Add a move (up to 3)',
      AppLanguage.ja: '技を追加（最大3つ）',
    },
    'dex.move.noIntersect': {
      AppLanguage.ko: '조건을 모두 만족하는 포켓몬이 없습니다',
      AppLanguage.en: 'No Pokémon learns all of these',
      AppLanguage.ja: 'すべて覚えるポケモンがいません',
    },
    'dex.tabMain': {
      AppLanguage.ko: '메인',
      AppLanguage.en: 'Main',
      AppLanguage.ja: 'メイン',
    },
    'dex.tabMoves': {
      AppLanguage.ko: '기술',
      AppLanguage.en: 'Moves',
      AppLanguage.ja: '技',
    },
    'dex.weight': {
      AppLanguage.ko: '무게',
      AppLanguage.en: 'Weight',
      AppLanguage.ja: '重さ',
    },
    'dex.height': {
      AppLanguage.ko: '키',
      AppLanguage.en: 'Height',
      AppLanguage.ja: '高さ',
    },
    'dex.gender': {
      AppLanguage.ko: '성별',
      AppLanguage.en: 'Gender',
      AppLanguage.ja: '性別',
    },
    'dex.genderless': {
      AppLanguage.ko: '성별 없음',
      AppLanguage.en: 'Genderless',
      AppLanguage.ja: '性別不明',
    },
    'dex.statTotal': {
      AppLanguage.ko: '합계',
      AppLanguage.en: 'Total',
      AppLanguage.ja: '合計',
    },
    'dex.colName': {
      AppLanguage.ko: '이름',
      AppLanguage.en: 'Name',
      AppLanguage.ja: '名前',
    },
    'dex.colHp': {
      AppLanguage.ko: 'HP',
      AppLanguage.en: 'HP',
      AppLanguage.ja: 'HP',
    },
    'dex.colAtk': {
      AppLanguage.ko: '공',
      AppLanguage.en: 'Atk',
      AppLanguage.ja: '攻',
    },
    'dex.colDef': {
      AppLanguage.ko: '방',
      AppLanguage.en: 'Def',
      AppLanguage.ja: '防',
    },
    'dex.colSpa': {
      AppLanguage.ko: '특공',
      AppLanguage.en: 'SpA',
      AppLanguage.ja: '特攻',
    },
    'dex.colSpd': {
      AppLanguage.ko: '특방',
      AppLanguage.en: 'SpD',
      AppLanguage.ja: '特防',
    },
    'dex.colSpe': {
      AppLanguage.ko: '스핏',
      AppLanguage.en: 'Spe',
      AppLanguage.ja: '速',
    },
    'dex.colBst': {
      AppLanguage.ko: '합',
      AppLanguage.en: 'BST',
      AppLanguage.ja: '合',
    },
    'dex.abilities': {
      AppLanguage.ko: '특성',
      AppLanguage.en: 'Abilities',
      AppLanguage.ja: '特性',
    },
    'dex.calcAbility': {
      AppLanguage.ko: '특성',
      AppLanguage.en: 'Ability',
      AppLanguage.ja: '特性',
    },
    'dex.calcAbility.none': {
      AppLanguage.ko: '특성 없음',
      AppLanguage.en: 'No ability',
      AppLanguage.ja: '特性なし',
    },
    'dex.typeMatchups': {
      AppLanguage.ko: '타입 상성',
      AppLanguage.en: 'Type Matchups',
      AppLanguage.ja: 'タイプ相性',
    },
    'dex.searchMoves': {
      AppLanguage.ko: '기술 검색',
      AppLanguage.en: 'Search moves',
      AppLanguage.ja: '技を検索',
    },
    'dex.allTypes': {
      AppLanguage.ko: '모든 타입',
      AppLanguage.en: 'All types',
      AppLanguage.ja: '全タイプ',
    },
    'dex.filterByType': {
      AppLanguage.ko: '타입으로 검색',
      AppLanguage.en: 'Filter by type',
      AppLanguage.ja: 'タイプで検索',
    },
    'dex.allCategories': {
      AppLanguage.ko: '모든 분류',
      AppLanguage.en: 'All categories',
      AppLanguage.ja: '全分類',
    },
    'dex.noDescription': {
      AppLanguage.ko: '설명 없음',
      AppLanguage.en: 'No description',
      AppLanguage.ja: '説明なし',
    },
    'dex.abilityUnrevealed': {
      AppLanguage.ko: '미공개',
      AppLanguage.en: 'Unrevealed',
      AppLanguage.ja: '未公開',
    },
    'dex.abilityUnrevealedDesc': {
      AppLanguage.ko: '아직 특성이 공개되지 않았습니다. 공식 정보가 공개되면 업데이트됩니다.',
      AppLanguage.en: "This ability hasn't been revealed yet. It'll be updated once official info is available.",
      AppLanguage.ja: '特性はまだ公開されていません。公式情報が公開され次第、更新されます。',
    },
    'dex.bulk': {
      AppLanguage.ko: '내구 체계',
      AppLanguage.en: 'Bulk Metric',
      AppLanguage.ja: '耐久指数',
    },
    'dex.bulkPhysical': {
      AppLanguage.ko: '물리',
      AppLanguage.en: 'Physical',
      AppLanguage.ja: '物理',
    },
    'dex.bulkSpecial': {
      AppLanguage.ko: '특수',
      AppLanguage.en: 'Special',
      AppLanguage.ja: '特殊',
    },
    'dex.bulkNone': {
      AppLanguage.ko: '무보정',
      AppLanguage.en: 'No investment',
      AppLanguage.ja: '無補正',
    },
    'dex.bulkHp': {
      AppLanguage.ko: 'HP 보정',
      AppLanguage.en: 'HP only',
      AppLanguage.ja: 'HPのみ',
    },
    'dex.bulkFull': {
      AppLanguage.ko: '극보정',
      AppLanguage.en: 'Full',
      AppLanguage.ja: '極振り',
    },
    'dex.bulkH': {
      AppLanguage.ko: 'H32',
      AppLanguage.en: 'H32',
      AppLanguage.ja: 'H32',
    },
    'dex.bulkHB': {
      AppLanguage.ko: 'HB 극보정',
      AppLanguage.en: 'HB 252+',
      AppLanguage.ja: 'HB 極振り↑',
    },
    'dex.bulkHD': {
      AppLanguage.ko: 'HD 극보정',
      AppLanguage.en: 'HD 252+',
      AppLanguage.ja: 'HD 極振り↑',
    },
    'dex.bulkFormula': {
      AppLanguage.ko: 'HP × 방어 / HP × 특방',
      AppLanguage.en: 'HP × Def / HP × SpD',
      AppLanguage.ja: 'HP × 防御 / HP × 特防',
    },
    'dex.decisive': {
      AppLanguage.ko: '주요 결정력',
      AppLanguage.en: 'Key Output',
      AppLanguage.ja: '主要決定力',
    },
    'dex.decisiveFormula': {
      AppLanguage.ko: '공격력 × 기술 위력 × 자속',
      AppLanguage.en: 'Atk × move power × STAB',
      AppLanguage.ja: '攻撃 × 技威力 × タイプ一致',
    },
    'dex.decisiveHalf': {
      AppLanguage.ko: '준보정',
      AppLanguage.en: 'Half',
      AppLanguage.ja: '準補正',
    },
    // Mobile-web → install-the-native-app banner.
    'banner.mobileWebMsg': {
      AppLanguage.ko: '이 계산기는 모바일 앱으로 개발되었습니다. 앱 버전의 반응속도가 훨씬 빠르므로, 모바일에서는 앱 다운로드를 권장합니다.',
      AppLanguage.en: 'This calculator was built as a native mobile app. The app version is much faster — installation is recommended on mobile.',
      AppLanguage.ja: 'この計算機はモバイルアプリとして開発されました。アプリ版のほうがはるかに高速なので、モバイルではアプリのダウンロードをおすすめします。',
    },
    'banner.getAndroid': {
      AppLanguage.ko: 'Android 앱',
      AppLanguage.en: 'Android app',
      AppLanguage.ja: 'Android版',
    },
    'banner.getIos': {
      AppLanguage.ko: 'iOS 앱',
      AppLanguage.en: 'iOS app',
      AppLanguage.ja: 'iOS版',
    },
    'dex.noMovesMatch': {
      AppLanguage.ko: '검색 결과 없음',
      AppLanguage.en: 'No matches',
      AppLanguage.ja: '結果なし',
    },
    'dex.sendToAttacker': {
      AppLanguage.ko: '공격측으로',
      AppLanguage.en: 'To attacker',
      AppLanguage.ja: '攻撃側へ',
    },
    'dex.sendToDefender': {
      AppLanguage.ko: '방어측으로',
      AppLanguage.en: 'To defender',
      AppLanguage.ja: '防御側へ',
    },
    'dex.advancedSearch': {
      AppLanguage.ko: '상세 검색',
      AppLanguage.en: 'Advanced search',
      AppLanguage.ja: '詳細検索',
    },
    'dex.advTypes': {
      AppLanguage.ko: '타입 (최대 2개)',
      AppLanguage.en: 'Types (up to 2)',
      AppLanguage.ja: 'タイプ (最大2つ)',
    },
    'dex.advTypesHint': {
      AppLanguage.ko: '2개 선택 시 정확히 일치하는 조합만 검색합니다.',
      AppLanguage.en: 'With 2 types selected, matches only the exact combo.',
      AppLanguage.ja: '2つ選択時は完全一致の組み合わせのみ検索します。',
    },
    'dex.advStats': {
      AppLanguage.ko: '종족값 범위',
      AppLanguage.en: 'Base stat ranges',
      AppLanguage.ja: '種族値の範囲',
    },
    'dex.advAddStat': {
      AppLanguage.ko: '능력치 추가',
      AppLanguage.en: 'Add stat',
      AppLanguage.ja: '能力値追加',
    },
    'dex.advPickStat': {
      AppLanguage.ko: '능력치 선택',
      AppLanguage.en: 'Pick stat',
      AppLanguage.ja: '能力値を選択',
    },
    'dex.advDefenseType': {
      AppLanguage.ko: '타입 약점 / 내성',
      AppLanguage.en: 'Type weakness / resistance',
      AppLanguage.ja: 'タイプ弱点 / 耐性',
    },
    'dex.advDefenseTypePick': {
      AppLanguage.ko: '공격 타입 선택',
      AppLanguage.en: 'Pick attacking type',
      AppLanguage.ja: '攻撃タイプを選択',
    },
    'dex.advAddDefense': {
      AppLanguage.ko: '타입 추가',
      AppLanguage.en: 'Add type',
      AppLanguage.ja: 'タイプ追加',
    },
    'dex.advWeakness': {
      AppLanguage.ko: '약점',
      AppLanguage.en: 'Weak to',
      AppLanguage.ja: '弱点',
    },
    'dex.advResistance': {
      AppLanguage.ko: '내성',
      AppLanguage.en: 'Resists',
      AppLanguage.ja: '耐性',
    },
    'dex.advImmunity': {
      AppLanguage.ko: '면역',
      AppLanguage.en: 'Immune',
      AppLanguage.ja: '無効',
    },
    'dex.advAbility': {
      AppLanguage.ko: '특성',
      AppLanguage.en: 'Ability',
      AppLanguage.ja: '特性',
    },
    'dex.advAbilityHint': {
      AppLanguage.ko: '특성 이름 입력',
      AppLanguage.en: 'Type ability name',
      AppLanguage.ja: '特性名を入力',
    },
    'dex.advMoves': {
      AppLanguage.ko: '기술 (최대 4개)',
      AppLanguage.en: 'Moves (up to 4)',
      AppLanguage.ja: '技 (最大4つ)',
    },
    'dex.advMovesMatch': {
      AppLanguage.ko: '일치',
      AppLanguage.en: 'Match',
      AppLanguage.ja: '一致',
    },
    'dex.advMovesAnd': {
      AppLanguage.ko: '모두',
      AppLanguage.en: 'All',
      AppLanguage.ja: 'すべて',
    },
    'dex.advMovesOr': {
      AppLanguage.ko: '하나라도',
      AppLanguage.en: 'Any',
      AppLanguage.ja: 'いずれか',
    },
    'dex.advMoveSlot': {
      AppLanguage.ko: '기술 이름 입력',
      AppLanguage.en: 'Type move name',
      AppLanguage.ja: '技名を入力',
    },

    // === Panel sections ===
    'section.species': {
      AppLanguage.ko: '종',
      AppLanguage.en: 'Species',
      AppLanguage.ja: '種族',
    },
    'section.stats': {
      AppLanguage.ko: '능력치',
      AppLanguage.en: 'Stats',
      AppLanguage.ja: '能力値',
    },
    'section.moves': {
      AppLanguage.ko: '기술',
      AppLanguage.en: 'Moves',
      AppLanguage.ja: 'わざ',
    },
    'section.doubles': {
      AppLanguage.ko: '더블 전용 옵션',
      AppLanguage.en: 'Doubles-only options',
      AppLanguage.ja: 'ダブル専用オプション',
    },
    'section.aura': {
      AppLanguage.ko: '오라',
      AppLanguage.en: 'Aura',
      AppLanguage.ja: 'オーラ',
    },
    'section.ruin': {
      AppLanguage.ko: '재앙',
      AppLanguage.en: 'Ruin',
      AppLanguage.ja: 'わざわい',
    },
    'section.bulk': {
      AppLanguage.ko: '내구',
      AppLanguage.en: 'Bulk',
      AppLanguage.ja: '耐久',
    },
    'section.physBulk': {
      AppLanguage.ko: '물리 내구',
      AppLanguage.en: 'Physical Bulk',
      AppLanguage.ja: '物理耐久',
    },
    'section.specBulk': {
      AppLanguage.ko: '특수 내구',
      AppLanguage.en: 'Special Bulk',
      AppLanguage.ja: '特殊耐久',
    },

    // === Stat labels ===
    'stat.attack': {
      AppLanguage.ko: '공격',
      AppLanguage.en: 'Atk',
      AppLanguage.ja: '攻撃',
    },
    'stat.defense': {
      AppLanguage.ko: '방어',
      AppLanguage.en: 'Def',
      AppLanguage.ja: '防御',
    },
    'stat.spAttack': {
      AppLanguage.ko: '특공',
      AppLanguage.en: 'SpA',
      AppLanguage.ja: '特攻',
    },
    'stat.spDefense': {
      AppLanguage.ko: '특방',
      AppLanguage.en: 'SpD',
      AppLanguage.ja: '特防',
    },
    'stat.speed': {
      AppLanguage.ko: '스피드',
      AppLanguage.en: 'Spe',
      AppLanguage.ja: 'すばやさ',
    },
    'stat.hp': {
      AppLanguage.ko: 'HP',
      AppLanguage.en: 'HP',
      AppLanguage.ja: 'HP',
    },
    'simple.screens': {
      AppLanguage.ko: '벽',
      AppLanguage.en: 'Screens',
      AppLanguage.ja: '壁',
    },
    'simple.natureNeutral': {
      AppLanguage.ko: '성격',
      AppLanguage.en: 'Nat',
      AppLanguage.ja: '性格',
    },
    'simple.rankNeutral': {
      AppLanguage.ko: '랭크',
      AppLanguage.en: 'Rnk',
      AppLanguage.ja: '段階',
    },
    'announce.sprites.title': {
      AppLanguage.ko: '색이 다른 포켓몬 스프라이트가 추가되었습니다',
      AppLanguage.en: 'Shiny Pokémon sprites added',
      AppLanguage.ja: '色違いポケモンスプライトが追加されました',
    },
    'announce.sprites.body': {
      AppLanguage.ko: '계산기/도감/파티 구축 어디에서나 색이 다른 포켓몬을 켜고 끌 수 있습니다. 웹은 자동으로 적용되지만, 모바일에서는 이미지팩을 반드시 다시 받아주셔야 색이 다른 이미지가 표시됩니다. 스타일 변경과 팩 재다운로드는 설정(⚙️)의 스프라이트 스타일에서 합니다.',
      AppLanguage.en: 'Shiny variants are now toggleable everywhere — calculator, dex, and team builder. The web build picks them up automatically; on mobile you must re-import the sprite pack to see shiny art. Change style and re-download from Settings (⚙️) → Sprite style.',
      AppLanguage.ja: '計算機・図鑑・パーティ構築のどこでも色違いに切り替えられます。Web版は自動反映されますが、モバイルでは色違い画像を表示するためにイメージパックの再ダウンロードが必要です。スタイル変更とパック再取得は設定（⚙️）のスプライトスタイルから行います。',
    },
    // One-shot notice for the in-game roster expansion shipped on
    // 2026-06-17 — learnsets for the new Champions Pokémon haven't
    // been datamined upstream yet, so the move pool we show may
    // include moves that are no longer learnable, or miss moves
    // that are. Cleared once ChampionsLab refreshes.
    'action.dontShowAgain': {
      AppLanguage.ko: '다시 보지 않기',
      AppLanguage.en: "Don't show again",
      AppLanguage.ja: '今後表示しない',
    },
    'action.ok': {
      AppLanguage.ko: '확인',
      AppLanguage.en: 'OK',
      AppLanguage.ja: '確認',
    },
    'action.snoozeWeek': {
      AppLanguage.ko: '일주일 안 보기',
      AppLanguage.en: 'Hide for a week',
      AppLanguage.ja: '1週間表示しない',
    },
    'action.snoozeMonth': {
      AppLanguage.ko: '한 달 안 보기',
      AppLanguage.en: 'Hide for a month',
      AppLanguage.ja: '1か月表示しない',
    },
    'sprite.update.title': {
      AppLanguage.ko: '이미지팩 업데이트가 있습니다',
      AppLanguage.en: 'Sprite pack update available',
      AppLanguage.ja: '画像パックの更新があります',
    },
    'sprite.update.body': {
      AppLanguage.ko: '설치된 이미지팩이 최신 버전이 아닙니다. 설정(⚙️)의 스프라이트 스타일에서 새 팩을 받아 가져와주세요.',
      AppLanguage.en: 'Your installed sprite pack is out of date. Open Settings (⚙️) → Sprite style and re-download the latest pack.',
      AppLanguage.ja: 'インストール済みの画像パックが最新ではありません。設定（⚙️）のスプライトスタイルから最新のパックを取り直して取り込んでください。',
    },
    'simple.shortExtended': {
      AppLanguage.ko: '확장',
      AppLanguage.en: 'Ext.',
      AppLanguage.ja: '拡張',
    },
    'simple.shortSimple': {
      AppLanguage.ko: '간단',
      AppLanguage.en: 'Simple',
      AppLanguage.ja: '簡単',
    },
    'simple.title': {
      AppLanguage.ko: '간단 모드',
      AppLanguage.en: 'Simple Mode',
      AppLanguage.ja: 'かんたんモード',
    },
    'simple.menu': {
      AppLanguage.ko: '간단 모드',
      AppLanguage.en: 'Simple Mode',
      AppLanguage.ja: 'かんたんモード',
    },
    'simple.backToNormal': {
      AppLanguage.ko: '확장 모드',
      AppLanguage.en: 'Extended Mode',
      AppLanguage.ja: '拡張モード',
    },
    'simple.natureUp': {
      AppLanguage.ko: '성격 ↑',
      AppLanguage.en: 'Nature ↑',
      AppLanguage.ja: '性格 ↑',
    },
    'simple.natureDown': {
      AppLanguage.ko: '성격 ↓',
      AppLanguage.en: 'Nature ↓',
      AppLanguage.ja: '性格 ↓',
    },
    'simple.multiplier': {
      AppLanguage.ko: '추가 배수',
      AppLanguage.en: 'Extra multiplier',
      AppLanguage.ja: '追加倍率',
    },
    'simple.noMove': {
      AppLanguage.ko: '기술을 선택해 주십시오',
      AppLanguage.en: 'Pick a move',
      AppLanguage.ja: '技を選択',
    },
    'simple.atkFirst': {
      AppLanguage.ko: '공격자 선공',
      AppLanguage.en: 'Attacker moves first',
      AppLanguage.ja: '攻撃側が先攻',
    },
    'simple.defFirst': {
      AppLanguage.ko: '방어자 선공',
      AppLanguage.en: 'Defender moves first',
      AppLanguage.ja: '防御側が先攻',
    },
    'simple.atkFasterBy': {
      AppLanguage.ko: '공격측이 방어측보다 {n} 빠름',
      AppLanguage.en: 'Attacker is {n} faster than defender',
      AppLanguage.ja: '攻撃側が防御側より {n} 速い',
    },
    'simple.defFasterBy': {
      AppLanguage.ko: '방어측이 공격측보다 {n} 빠름',
      AppLanguage.en: 'Defender is {n} faster than attacker',
      AppLanguage.ja: '防御側が攻撃側より {n} 速い',
    },
    // Named variant used when the two sides aren't a mirror match.
    // {a} = faster pokemon, {b} = slower pokemon, {n} = speed diff.
    // {p} is the Korean particle (이/가), inserted at the call site.
    'simple.namedFasterBy': {
      AppLanguage.ko: '{a}{p} {b}보다 {n} 빠름',
      AppLanguage.en: '{a} is {n} faster than {b}',
      AppLanguage.ja: '{a}が{b}より {n} 速い',
    },
    'simple.tiedSpeed': {
      AppLanguage.ko: '스피드 동률',
      AppLanguage.en: 'Speed tie',
      AppLanguage.ja: 'すばやさ同値',
    },
    'simple.priorityFirst': {
      AppLanguage.ko: '선공 기술',
      AppLanguage.en: 'Priority move (first)',
      AppLanguage.ja: '先制技',
    },
    'simple.priorityLast': {
      AppLanguage.ko: '후공 기술',
      AppLanguage.en: 'Priority move (last)',
      AppLanguage.ja: '後攻技',
    },
    'simple.ohko': {
      AppLanguage.ko: '1타 확정',
      AppLanguage.en: 'Guaranteed OHKO',
      AppLanguage.ja: '1発確定',
    },
    'simple.nhkoConfirmed': {
      AppLanguage.ko: '{n}타 확정',
      AppLanguage.en: 'Guaranteed {n}HKO',
      AppLanguage.ja: '{n}発確定',
    },
    'simple.nhkoRange': {
      AppLanguage.ko: '{min}~{max}타',
      AppLanguage.en: '{min}-{max}HKO',
      AppLanguage.ja: '{min}~{max}発',
    },
    'stat.base': {
      AppLanguage.ko: '종족',
      AppLanguage.en: 'Base',
      AppLanguage.ja: '種族',
    },
    'stat.iv': {
      AppLanguage.ko: '개체',
      AppLanguage.en: 'IV',
      AppLanguage.ja: '個体',
    },
    'stat.ev': {
      AppLanguage.ko: '노력',
      AppLanguage.en: 'EV',
      AppLanguage.ja: '努力',
    },
    'stat.rank': {
      AppLanguage.ko: '랭크',
      AppLanguage.en: 'Rank',
      AppLanguage.ja: 'ランク',
    },
    'stat.actual': {
      AppLanguage.ko: '실수치',
      AppLanguage.en: 'Stat',
      AppLanguage.ja: '実数値',
    },
    'stat.total': {
      AppLanguage.ko: '합계',
      AppLanguage.en: 'Total',
      AppLanguage.ja: '合計',
    },

    // === Move table headers ===
    'move.name': {
      AppLanguage.ko: '기술명',
      AppLanguage.en: 'Move',
      AppLanguage.ja: 'わざ名',
    },
    'move.type': {
      AppLanguage.ko: '타입',
      AppLanguage.en: 'Type',
      AppLanguage.ja: 'タイプ',
    },
    'move.category': {
      AppLanguage.ko: '분류',
      AppLanguage.en: 'Cat.',
      AppLanguage.ja: '分類',
    },
    'move.power': {
      AppLanguage.ko: '위력',
      AppLanguage.en: 'BP',
      AppLanguage.ja: '威力',
    },
    'move.accuracy': {
      AppLanguage.ko: '명중',
      AppLanguage.en: 'Acc',
      AppLanguage.ja: '命中',
    },
    'move.critical': {
      AppLanguage.ko: '급소',
      AppLanguage.en: 'Crit',
      AppLanguage.ja: '急所',
    },
    'move.offensive': {
      AppLanguage.ko: '결정력',
      AppLanguage.en: 'Dmg',
      AppLanguage.ja: '火力',
    },
    'move.fixed': {
      AppLanguage.ko: '고정',
      AppLanguage.en: 'Fixed',
      AppLanguage.ja: '固定',
    },
    'move.priority': {
      AppLanguage.ko: '우선도',
      AppLanguage.en: 'Priority',
      AppLanguage.ja: '優先度',
    },
    'move.hits': {
      AppLanguage.ko: '히트수',
      AppLanguage.en: 'Hits',
      AppLanguage.ja: '攻撃回数',
    },
    'move.showStatus': {
      AppLanguage.ko: '변화기 보기',
      AppLanguage.en: 'Show status moves',
      AppLanguage.ja: '変化技を表示',
    },

    // === Labels ===
    'label.level': {
      AppLanguage.ko: '레벨',
      AppLanguage.en: 'Level',
      AppLanguage.ja: 'レベル',
    },
    'label.ability': {
      AppLanguage.ko: '특성',
      AppLanguage.en: 'Ability',
      AppLanguage.ja: '特性',
    },
    'label.item': {
      AppLanguage.ko: '아이템',
      AppLanguage.en: 'Item',
      AppLanguage.ja: 'もちもの',
    },
    'label.otherModifier': {
      AppLanguage.ko: '기타 보정',
      AppLanguage.en: 'Other mod',
      AppLanguage.ja: 'その他補正',
    },
    'label.nature': {
      AppLanguage.ko: '성격',
      AppLanguage.en: 'Nature',
      AppLanguage.ja: '性格',
    },
    'label.status': {
      AppLanguage.ko: '상태이상',
      AppLanguage.en: 'Status',
      AppLanguage.ja: '状態異常',
    },
    'label.none': {
      AppLanguage.ko: '없음',
      AppLanguage.en: 'None',
      AppLanguage.ja: 'なし',
    },
    'label.foe': {
      AppLanguage.ko: '(상대)',
      AppLanguage.en: '(opp)',
      AppLanguage.ja: '(相手)',
    },
    'label.terastal': {
      AppLanguage.ko: '테라스탈 타입',
      AppLanguage.en: 'Tera Type',
      AppLanguage.ja: 'テラスタルタイプ',
    },
    'label.noTera': {
      AppLanguage.ko: '테라 안함',
      AppLanguage.en: 'No Tera',
      AppLanguage.ja: 'テラなし',
    },
    'label.terastalShort': {
      AppLanguage.ko: '테라',
      AppLanguage.en: 'Tera',
      AppLanguage.ja: 'テラ',
    },

    // === Toolbar ===
    'toolbar.weather': {
      AppLanguage.ko: '날씨',
      AppLanguage.en: 'Weather',
      AppLanguage.ja: '天候',
    },
    'toolbar.terrain': {
      AppLanguage.ko: '필드',
      AppLanguage.en: 'Terrain',
      AppLanguage.ja: 'フィールド',
    },
    'toolbar.room': {
      AppLanguage.ko: '룸',
      AppLanguage.en: 'Room',
      AppLanguage.ja: 'ルーム',
    },
    'toolbar.battleConditions': {
      AppLanguage.ko: '환경',
      AppLanguage.en: 'Field',
      AppLanguage.ja: '場の状態',
    },
    'toolbar.conditionsReset': {
      AppLanguage.ko: '초기화',
      AppLanguage.en: 'Reset',
      AppLanguage.ja: 'リセット',
    },
    'toolbar.swap': {
      AppLanguage.ko: '공수전환',
      AppLanguage.en: 'Swap',
      AppLanguage.ja: '攻守入替',
    },
    'toolbar.reset': {
      AppLanguage.ko: '전체 초기화',
      AppLanguage.en: 'Reset All',
      AppLanguage.ja: '全リセット',
    },
    'toolbar.capture': {
      AppLanguage.ko: '캡처',
      AppLanguage.en: 'Capture',
      AppLanguage.ja: 'キャプチャ',
    },

    // === Actions ===
    'action.save': {
      AppLanguage.ko: '저장',
      AppLanguage.en: 'Save',
      AppLanguage.ja: '保存',
    },
    'action.cancel': {
      AppLanguage.ko: '취소',
      AppLanguage.en: 'Cancel',
      AppLanguage.ja: 'キャンセル',
    },
    'action.confirm': {
      AppLanguage.ko: '확인',
      AppLanguage.en: 'OK',
      AppLanguage.ja: '確認',
    },
    'action.close': {
      AppLanguage.ko: '닫기',
      AppLanguage.en: 'Close',
      AppLanguage.ja: '閉じる',
    },
    'action.export': {
      AppLanguage.ko: '내보내기',
      AppLanguage.en: 'Export',
      AppLanguage.ja: 'エクスポート',
    },
    'action.import': {
      AppLanguage.ko: '가져오기',
      AppLanguage.en: 'Import',
      AppLanguage.ja: 'インポート',
    },

    'action.reset': {
      AppLanguage.ko: '초기화',
      AppLanguage.en: 'Reset',
      AppLanguage.ja: 'リセット',
    },
    'action.apply': {
      AppLanguage.ko: '적용',
      AppLanguage.en: 'Apply',
      AppLanguage.ja: '適用',
    },
    'action.clear': {
      AppLanguage.ko: '지우기',
      AppLanguage.en: 'Clear',
      AppLanguage.ja: 'クリア',
    },

    'type.picker.title': {
      AppLanguage.ko: '타입 선택 (최대 3개)',
      AppLanguage.en: 'Pick types (max 3)',
      AppLanguage.ja: 'タイプ選択 (最大3つ)',
    },
    'type.picker.clear': {
      AppLanguage.ko: '선택 해제',
      AppLanguage.en: 'Clear',
      AppLanguage.ja: '選択解除',
    },
    'type.none': {
      AppLanguage.ko: '없음',
      AppLanguage.en: 'None',
      AppLanguage.ja: 'なし',
    },

    // === Sample ===
    'sample.save': {
      AppLanguage.ko: '샘플 저장',
      AppLanguage.en: 'Save Preset',
      AppLanguage.ja: 'プリセット保存',
    },
    'sample.load': {
      AppLanguage.ko: '불러오기',
      AppLanguage.en: 'Load',
      AppLanguage.ja: '読込',
    },
    'sample.name': {
      AppLanguage.ko: '샘플 이름',
      AppLanguage.en: 'Preset Name',
      AppLanguage.ja: 'プリセット名',
    },
    'sample.search': {
      AppLanguage.ko: '샘플 검색',
      AppLanguage.en: 'Search Presets',
      AppLanguage.ja: 'プリセット検索',
    },
    'sample.empty': {
      AppLanguage.ko: '저장된 샘플이 없습니다',
      AppLanguage.en: 'No saved presets',
      AppLanguage.ja: '保存されたプリセットはありません',
    },
    'sample.browserWarning': {
      AppLanguage.ko: '브라우저 데이터 삭제 시 저장된 샘플이 사라질 수 있습니다.',
      AppLanguage.en: 'Saved presets may be lost if browser data is cleared.',
      AppLanguage.ja: 'ブラウザデータ削除時、保存プリセットが消える場合があります。',
    },
    'sample.exported': {
      AppLanguage.ko: '샘플 데이터를 내보냈습니다',
      AppLanguage.en: 'Presets exported',
      AppLanguage.ja: 'プリセットデータをエクスポートしました',
    },
    'sample.importedN': {
      AppLanguage.ko: '개의 샘플을 가져왔습니다',
      AppLanguage.en: ' presets imported',
      AppLanguage.ja: '件のプリセットをインポートしました',
    },
    'sample.invalidFormat': {
      AppLanguage.ko: '잘못된 파일 형식입니다',
      AppLanguage.en: 'Invalid file format',
      AppLanguage.ja: '無効なファイル形式です',
    },
    'sample.pasteJson': {
      AppLanguage.ko: '내보낸 JSON 데이터를 붙여넣어 주십시오.',
      AppLanguage.en: 'Paste exported JSON data.',
      AppLanguage.ja: 'エクスポートしたJSONデータを貼り付けてください。',
    },
    'sample.duplicateTitle': {
      AppLanguage.ko: '이름 중복',
      AppLanguage.en: 'Duplicate name',
      AppLanguage.ja: '名前の重複',
    },
    'sample.duplicateMessage': {
      AppLanguage.ko: '같은 이름의 샘플이 이미 있습니다. 덮어쓰시겠습니까?',
      AppLanguage.en: 'A preset with the same name already exists. Overwrite?',
      AppLanguage.ja: '同じ名前のプリセットが既にあります。上書きしますか？',
    },
    'action.overwrite': {
      AppLanguage.ko: '덮어쓰기',
      AppLanguage.en: 'Overwrite',
      AppLanguage.ja: '上書き',
    },
    'sample.share.copy': {
      AppLanguage.ko: '공유 코드 복사',
      AppLanguage.en: 'Copy share code',
      AppLanguage.ja: '共有コードをコピー',
    },
    'sample.share.copied': {
      AppLanguage.ko: '공유 코드가 클립보드에 복사되었습니다',
      AppLanguage.en: 'Share code copied to clipboard',
      AppLanguage.ja: '共有コードをクリップボードにコピーしました',
    },
    'sample.share.dialog.title': {
      AppLanguage.ko: '공유 코드',
      AppLanguage.en: 'Share code',
      AppLanguage.ja: '共有コード',
    },
    'sample.share.dialog.desc': {
      AppLanguage.ko: '아래 코드가 클립보드에 복사되었습니다. 붙여넣어 전달하십시오.',
      AppLanguage.en: 'The code below is on your clipboard — paste it to share.',
      AppLanguage.ja: '下記のコードをクリップボードにコピーしました。貼り付けて共有してください。',
    },
    'sample.share.dialog.chars': {
      AppLanguage.ko: '자',
      AppLanguage.en: ' chars',
      AppLanguage.ja: '文字',
    },
    'sample.share.dialog.recopy': {
      AppLanguage.ko: '다시 복사',
      AppLanguage.en: 'Copy again',
      AppLanguage.ja: '再コピー',
    },
    'sample.share.import': {
      AppLanguage.ko: '코드로 가져오기',
      AppLanguage.en: 'Import code',
      AppLanguage.ja: 'コードでインポート',
    },
    'sample.share.import.title': {
      AppLanguage.ko: '공유 코드 가져오기',
      AppLanguage.en: 'Import share code',
      AppLanguage.ja: '共有コードのインポート',
    },
    'sample.share.import.hint': {
      AppLanguage.ko: 'damacalc:… 으로 시작하는 포켓몬/파티 코드를 붙여넣으십시오.',
      AppLanguage.en: 'Paste a Pokémon or team code starting with damacalc:…',
      AppLanguage.ja: 'damacalc:… で始まるポケモン／パーティーコードを貼り付けてください。',
    },
    'sample.share.import.paste': {
      AppLanguage.ko: '클립보드에서 붙여넣기',
      AppLanguage.en: 'Paste from clipboard',
      AppLanguage.ja: 'クリップボードから貼り付け',
    },
    'sample.share.import.invalid': {
      AppLanguage.ko: '잘못된 공유 코드입니다',
      AppLanguage.en: 'Invalid share code',
      AppLanguage.ja: '無効な共有コードです',
    },
    'sample.share.import.success': {
      AppLanguage.ko: '"{name}" 을(를) 가져왔습니다',
      AppLanguage.en: 'Imported "{name}"',
      AppLanguage.ja: '「{name}」をインポートしました',
    },

    // === Champions speed tier sheet ===
    'speedTier.title': {
      AppLanguage.ko: '챔피언스 스피드표',
      AppLanguage.en: 'Champions Speed Tier',
      AppLanguage.ja: 'チャンピオンズ スピード表',
    },
    'speedTier.menuLabel': {
      AppLanguage.ko: '스피드표',
      AppLanguage.en: 'Speed tier',
      AppLanguage.ja: 'スピード表',
    },
    'speedTier.empty': {
      AppLanguage.ko: '데이터가 아직 로드되지 않았습니다.',
      AppLanguage.en: 'Data is still loading.',
      AppLanguage.ja: 'データ読み込み中です。',
    },

    // === Champions usage-rank sheet ===
    'usageRank.title': {
      AppLanguage.ko: '챔피언스 채용 순위',
      AppLanguage.en: 'Champions Usage Ranking',
      AppLanguage.ja: 'チャンピオンズ 採用ランキング',
    },
    'usageRank.menuLabel': {
      AppLanguage.ko: '순위표',
      AppLanguage.en: 'Usage rank',
      AppLanguage.ja: '採用ランキング',
    },
    'usageRank.updatedAt': {
      AppLanguage.ko: '갱신: {date}',
      AppLanguage.en: 'Updated: {date}',
      AppLanguage.ja: '更新: {date}',
    },
    'usageRank.empty': {
      AppLanguage.ko: '순위 데이터가 아직 로드되지 않았습니다.',
      AppLanguage.en: 'Ranking data is still loading.',
      AppLanguage.ja: 'ランキングデータ読み込み中です。',
    },
    'usageRank.bigSprites': {
      AppLanguage.ko: '큰 그림',
      AppLanguage.en: 'Big sprite',
      AppLanguage.ja: '大きい絵',
    },

    // === Champions format (Singles / Doubles) ===
    'championsFormat.singles': {
      AppLanguage.ko: '싱글',
      AppLanguage.en: 'Singles',
      AppLanguage.ja: 'シングル',
    },
    'championsFormat.doubles': {
      AppLanguage.ko: '더블',
      AppLanguage.en: 'Doubles',
      AppLanguage.ja: 'ダブル',
    },
    'championsFormat.settingLabel': {
      AppLanguage.ko: '통계',
      AppLanguage.en: 'Stats',
      AppLanguage.ja: '統計',
    },

    // === Type chart sheet ===
    'typeChart.title': {
      AppLanguage.ko: '타입 상성표',
      AppLanguage.en: 'Type Effectiveness',
      AppLanguage.ja: 'タイプ相性表',
    },
    'typeChart.menuLabel': {
      AppLanguage.ko: '상성표',
      AppLanguage.en: 'Type chart',
      AppLanguage.ja: '相性表',
    },
    'typeChart.defender': {
      AppLanguage.ko: '방어',
      AppLanguage.en: 'Defender',
      AppLanguage.ja: '防御',
    },
    'typeChart.legend': {
      AppLanguage.ko: '행: 공격 / 열: 방어 · 빨강 ×2, 초록 ×½, 회색 ×0',
      AppLanguage.en: 'Rows: attacker · Cols: defender · Red ×2, Green ×½, Grey ×0',
      AppLanguage.ja: '行: 攻撃 / 列: 防御 · 赤 ×2, 緑 ×½, グレー ×0',
    },

    // === Speed tab ===
    'speed.baseValue': {
      AppLanguage.ko: '종족값',
      AppLanguage.en: 'Base',
      AppLanguage.ja: '種族値',
    },
    'speed.actual': {
      AppLanguage.ko: '실수치',
      AppLanguage.en: 'Actual',
      AppLanguage.ja: '実数値',
    },
    'speed.final': {
      AppLanguage.ko: '최종',
      AppLanguage.en: 'Final',
      AppLanguage.ja: '最終',
    },
    'speed.atkFasterBy': {
      AppLanguage.ko: '공격측이 방어측보다 {n} 빠름',
      AppLanguage.en: 'Attacker faster by {n}',
      AppLanguage.ja: '攻撃側が防御側より{n}速い',
    },
    'speed.defFasterBy': {
      AppLanguage.ko: '방어측이 공격측보다 {n} 빠름',
      AppLanguage.en: 'Defender faster by {n}',
      AppLanguage.ja: '防御側が攻撃側より{n}速い',
    },
    // Named variant used when the two sides aren't a mirror match.
    // {a} = faster pokemon, {b} = slower pokemon, {n} = speed diff.
    // {p} is the Korean particle (이/가), inserted at the call site.
    'speed.namedFasterBy': {
      AppLanguage.ko: '{a}{p} {b}보다 {n} 빠름',
      AppLanguage.en: '{a} is {n} faster than {b}',
      AppLanguage.ja: '{a}が{b}より{n}速い',
    },
    'speed.tie': {
      AppLanguage.ko: '동속',
      AppLanguage.en: 'Speed tie',
      AppLanguage.ja: '同速',
    },
    'speed.atkGuaranteedFirst': {
      AppLanguage.ko: '공격측 확정 선공',
      AppLanguage.en: 'Attacker always moves first',
      AppLanguage.ja: '攻撃側 確定先制',
    },
    'speed.defGuaranteedFirst': {
      AppLanguage.ko: '방어측 확정 선공',
      AppLanguage.en: 'Defender always moves first',
      AppLanguage.ja: '防御側 確定先制',
    },

    // Panel-level speed comparison (relative to "opponent")
    'speed.faster': {
      AppLanguage.ko: '상대보다 빠름 ▲',
      AppLanguage.en: 'Faster ▲',
      AppLanguage.ja: '相手より速い ▲',
    },
    'speed.slower': {
      AppLanguage.ko: '상대보다 느림 ▼',
      AppLanguage.en: 'Slower ▼',
      AppLanguage.ja: '相手より遅い ▼',
    },
    'speed.guaranteedFirst': {
      AppLanguage.ko: '확정 선공',
      AppLanguage.en: 'Always first',
      AppLanguage.ja: '確定先制',
    },
    'speed.guaranteedLast': {
      AppLanguage.ko: '확정 후공',
      AppLanguage.en: 'Always last',
      AppLanguage.ja: '確定後攻',
    },

    // === Damage tab ===
    'damage.reflect': {
      AppLanguage.ko: '리플렉터',
      AppLanguage.en: 'Reflect',
      AppLanguage.ja: 'リフレクター',
    },
    'damage.lightScreen': {
      AppLanguage.ko: '빛의장막',
      AppLanguage.en: 'Light Screen',
      AppLanguage.ja: 'ひかりのかべ',
    },
    'damage.spread': {
      AppLanguage.ko: '분산',
      AppLanguage.en: '2 targets',
      AppLanguage.ja: '複数対象',
    },
    'damage.helpingHand': {
      AppLanguage.ko: '도우미',
      AppLanguage.en: 'Helping Hand',
      AppLanguage.ja: 'てだすけ',
    },
    'damage.allyPowerSpot': {
      AppLanguage.ko: '파워스폿',
      AppLanguage.en: 'Power Spot',
      AppLanguage.ja: 'パワースポット',
    },
    'damage.allyBattery': {
      AppLanguage.ko: '배터리',
      AppLanguage.en: 'Battery',
      AppLanguage.ja: 'バッテリー',
    },
    'damage.allyFlowerGift': {
      AppLanguage.ko: '플라워기프트',
      AppLanguage.en: 'Flower Gift',
      AppLanguage.ja: 'フラワーギフト',
    },
    'damage.allyPlusMinus': {
      AppLanguage.ko: '플러스/마이너스',
      AppLanguage.en: 'Plus/Minus',
      AppLanguage.ja: 'プラス・マイナス',
    },
    'damage.allyFriendGuard': {
      AppLanguage.ko: '프렌드가드',
      AppLanguage.en: 'Friend Guard',
      AppLanguage.ja: 'フレンドガード',
    },
    'damage.tailwind': {
      AppLanguage.ko: '순풍',
      AppLanguage.en: 'Tailwind',
      AppLanguage.ja: 'おいかぜ',
    },
    'damage.allyAuraBreak': {
      AppLanguage.ko: '오라브레이크',
      AppLanguage.en: 'Aura Break',
      AppLanguage.ja: 'オーラブレイク',
    },
    'damage.allyTabletsOfRuin': {
      AppLanguage.ko: '재앙의목간',
      AppLanguage.en: 'Tablets of Ruin',
      AppLanguage.ja: 'わざわいのおふだ',
    },
    'damage.allySwordOfRuin': {
      AppLanguage.ko: '재앙의검',
      AppLanguage.en: 'Sword of Ruin',
      AppLanguage.ja: 'わざわいのつるぎ',
    },
    'damage.allyVesselOfRuin': {
      AppLanguage.ko: '재앙의그릇',
      AppLanguage.en: 'Vessel of Ruin',
      AppLanguage.ja: 'わざわいのうつわ',
    },
    'damage.allyBeadsOfRuin': {
      AppLanguage.ko: '재앙의구슬',
      AppLanguage.en: 'Beads of Ruin',
      AppLanguage.ja: 'わざわいのたま',
    },
    'damage.allyFairyAura': {
      AppLanguage.ko: '페어리오라',
      AppLanguage.en: 'Fairy Aura',
      AppLanguage.ja: 'フェアリーオーラ',
    },
    'damage.allyDarkAura': {
      AppLanguage.ko: '다크오라',
      AppLanguage.en: 'Dark Aura',
      AppLanguage.ja: 'ダークオーラ',
    },
    'damage.physical': {
      AppLanguage.ko: '물리',
      AppLanguage.en: 'Physical',
      AppLanguage.ja: '物理',
    },
    'damage.special': {
      AppLanguage.ko: '특수',
      AppLanguage.en: 'Special',
      AppLanguage.ja: '特殊',
    },
    'damage.status': {
      AppLanguage.ko: '변화',
      AppLanguage.en: 'Status',
      AppLanguage.ja: '変化',
    },
    'damage.moveNotSet': {
      AppLanguage.ko: '미설정',
      AppLanguage.en: 'Not Set',
      AppLanguage.ja: '未設定',
    },

    // === Damage sum (대미지 합산) ===
    'damage.sum.title': {
      AppLanguage.ko: '합산',
      AppLanguage.en: 'Sum',
      AppLanguage.ja: '合算',
    },
    'damage.sum.emptyHint': {
      AppLanguage.ko: '기술 카드를 탭해서 합산에 추가',
      AppLanguage.en: 'Tap a move card to add it to the sum',
      AppLanguage.ja: 'わざカードをタップして合算に追加',
    },
    'damage.sum.reset': {
      AppLanguage.ko: '초기화',
      AppLanguage.en: 'Reset',
      AppLanguage.ja: 'リセット',
    },
    // {n} is replaced at render time with the integer set count.
    'damage.sum.guaranteedSet': {
      AppLanguage.ko: '확정 {n}세트',
      AppLanguage.en: 'Guaranteed in {n} set(s)',
      AppLanguage.ja: '確定{n}セット',
    },
    'damage.sum.randomSet': {
      AppLanguage.ko: '난수 {n}세트',
      AppLanguage.en: 'Random in {n} set(s)',
      AppLanguage.ja: '乱数{n}セット',
    },
    'damage.sum.disclaimer': {
      AppLanguage.ko: '* 능력 변동 미반영',
      AppLanguage.en: '* Stat changes between hits are not applied',
      AppLanguage.ja: '* 能力変化は反映されません',
    },

    // === Effectiveness ===
    'eff.immune': {
      AppLanguage.ko: '효과 없음',
      AppLanguage.en: 'Immune',
      AppLanguage.ja: '効果なし',
    },
    'eff.superEffective4x': {
      AppLanguage.ko: '효과 매우 굉장함',
      AppLanguage.en: 'Extremely Effective',
      AppLanguage.ja: '効果はちょうバツグン',
    },
    'eff.superEffective': {
      AppLanguage.ko: '효과 굉장함',
      AppLanguage.en: 'Super Effective',
      AppLanguage.ja: '効果はバツグン',
    },
    'eff.notVeryEffective025': {
      AppLanguage.ko: '효과 매우 별로',
      AppLanguage.en: 'Mostly Ineffective',
      AppLanguage.ja: '効果はかなりいまひとつ',
    },
    'eff.notVeryEffective': {
      AppLanguage.ko: '효과 별로',
      AppLanguage.en: 'Not Very Effective',
      AppLanguage.ja: '効果はいまひとつ',
    },
    'eff.neutral': {
      AppLanguage.ko: '효과 보통',
      AppLanguage.en: 'Neutral',
      AppLanguage.ja: '等倍',
    },

    // === KO ===
    // Format: ko="확정 1타", en="guaranteed OHKO", ja="確定1発"
    'ko.guaranteed': {
      AppLanguage.ko: '확정',
      AppLanguage.en: 'guaranteed',
      AppLanguage.ja: '確定',
    },
    'ko.random': {
      AppLanguage.ko: '난수',
      AppLanguage.en: 'possible',
      AppLanguage.ja: '乱数',
    },
    'ko.hit': {
      AppLanguage.ko: '타',
      AppLanguage.en: 'HKO',
      AppLanguage.ja: '発',
    },
    'ko.ohko': {
      AppLanguage.ko: '1타',
      AppLanguage.en: 'OHKO',
      AppLanguage.ja: '1発',
    },

    // === EV ===
    'ev.remaining': {
      AppLanguage.ko: '잔여',
      AppLanguage.en: 'Remaining',
      AppLanguage.ja: '残り',
    },
    'ev.exceeded': {
      AppLanguage.ko: '초과',
      AppLanguage.en: 'Over',
      AppLanguage.ja: '超過',
    },

    // === Search ===
    'search.pokemon': {
      AppLanguage.ko: '이름 검색',
      AppLanguage.en: 'Search',
      AppLanguage.ja: '名前検索',
    },
    'search.move': {
      AppLanguage.ko: '기술 이름',
      AppLanguage.en: 'Move Name',
      AppLanguage.ja: 'わざ名',
    },
    'search.noResults': {
      AppLanguage.ko: '검색 결과 없음',
      AppLanguage.en: 'No results',
      AppLanguage.ja: '検索結果なし',
    },

    // === Reset dialog ===
    'reset.title': {
      AppLanguage.ko: '전체 초기화',
      AppLanguage.en: 'Reset All',
      AppLanguage.ja: '全リセット',
    },
    'reset.message': {
      AppLanguage.ko: '공격측, 방어측과 배틀환경이 모두 초기화됩니다.',
      AppLanguage.en: 'Attacker, defender, and field conditions will all be reset.',
      AppLanguage.ja: '攻撃側・防御側・場の状態がすべてリセットされます。',
    },

    // === Modifier notes ===
    'note.reflect': {
      AppLanguage.ko: '리플렉터 ×0.5',
      AppLanguage.en: 'Reflect ×0.5',
      AppLanguage.ja: 'リフレクター ×0.5',
    },
    'note.lightScreen': {
      AppLanguage.ko: '빛의장막 ×0.5',
      AppLanguage.en: 'Light Screen ×0.5',
      AppLanguage.ja: 'ひかりのかべ ×0.5',
    },
    'note.critBypass': {
      AppLanguage.ko: '급소: 벽 무시',
      AppLanguage.en: 'Crit: bypasses screens',
      AppLanguage.ja: '急所: 壁無視',
    },
    'note.infiltrator': {
      AppLanguage.ko: '침투: 벽 무시',
      AppLanguage.en: 'Infiltrator: bypasses screens',
      AppLanguage.ja: 'すりぬけ: 壁無視',
    },
    'note.knockOff': {
      AppLanguage.ko: '아이템 소지',
      AppLanguage.en: 'Holding item',
      AppLanguage.ja: 'アイテム所持',
    },
    'note.hex': {
      AppLanguage.ko: '상태이상',
      AppLanguage.en: 'Status condition',
      AppLanguage.ja: '状態異常',
    },
    'note.venoshock': {
      AppLanguage.ko: '독 상태',
      AppLanguage.en: 'Poisoned',
      AppLanguage.ja: 'どく状態',
    },
    'note.collision': {
      AppLanguage.ko: '효과 굉장함',
      AppLanguage.en: 'Super effective',
      AppLanguage.ja: '効果ばつぐん',
    },
    'note.solarHalve': {
      AppLanguage.ko: '비/모래/눈',
      AppLanguage.en: 'Rain/Sand/Snow',
      AppLanguage.ja: '雨/砂/雪',
    },
    'note.gravity': {
      AppLanguage.ko: '중력',
      AppLanguage.en: 'Gravity',
      AppLanguage.ja: 'じゅうりょく',
    },
    'note.sleep': {
      AppLanguage.ko: '수면 상태',
      AppLanguage.en: 'Asleep',
      AppLanguage.ja: 'ねむり状態',
    },
    'note.paralysis': {
      AppLanguage.ko: '마비 상태',
      AppLanguage.en: 'Paralyzed',
      AppLanguage.ja: 'まひ状態',
    },
    'note.brine': {
      AppLanguage.ko: 'HP 절반 이하',
      AppLanguage.en: 'HP ≤ 50%',
      AppLanguage.ja: 'HP半分以下',
    },
    'note.boltBeak': {
      AppLanguage.ko: '선공',
      AppLanguage.en: 'Moves first',
      AppLanguage.ja: '先制',
    },
    'note.payback': {
      AppLanguage.ko: '후공',
      AppLanguage.en: 'Moves last',
      AppLanguage.ja: '後攻',
    },
    'note.spread': {
      AppLanguage.ko: '분산',
      AppLanguage.en: 'Spread',
      AppLanguage.ja: '複数対象',
    },
    'note.helpingHand': {
      AppLanguage.ko: '도우미',
      AppLanguage.en: 'Helping Hand',
      AppLanguage.ja: 'てだすけ',
    },
    'note.powerSpot': {
      AppLanguage.ko: '파워스폿',
      AppLanguage.en: 'Power Spot',
      AppLanguage.ja: 'パワースポット',
    },
    'note.battery': {
      AppLanguage.ko: '배터리',
      AppLanguage.en: 'Battery',
      AppLanguage.ja: 'バッテリー',
    },
    'note.flowerGift': {
      AppLanguage.ko: '플라워기프트',
      AppLanguage.en: 'Flower Gift',
      AppLanguage.ja: 'フラワーギフト',
    },
    'note.plusMinus': {
      AppLanguage.ko: '플러스/마이너스',
      AppLanguage.en: 'Plus/Minus',
      AppLanguage.ja: 'プラス・マイナス',
    },
    'note.friendGuard': {
      AppLanguage.ko: '프렌드가드',
      AppLanguage.en: 'Friend Guard',
      AppLanguage.ja: 'フレンドガード',
    },
    'note.abilityImmune': {
      AppLanguage.ko: '특성에 의해 무효',
      AppLanguage.en: 'Nullified by ability',
      AppLanguage.ja: '特性により無効',
    },
    'note.gravityDisabled': {
      AppLanguage.ko: '중력: 사용 불가',
      AppLanguage.en: 'Gravity: unusable',
      AppLanguage.ja: 'じゅうりょく: 使用不可',
    },
    'note.weatherNegate': {
      AppLanguage.ko: '날씨 무효',
      AppLanguage.en: 'Weather negated',
      AppLanguage.ja: '天候無効',
    },
    'note.moldBreakerBypass': {
      AppLanguage.ko: '틀깨기 효과로 무시됨',
      AppLanguage.en: 'ignored by Mold Breaker',
      AppLanguage.ja: 'かたやぶり効果で無視',
    },
    'note.stab': {
      AppLanguage.ko: '자속',
      AppLanguage.en: 'STAB',
      AppLanguage.ja: 'タイプ一致',
    },
    'note.teraStab': {
      AppLanguage.ko: '테라스탈 자속',
      AppLanguage.en: 'Tera STAB',
      AppLanguage.ja: 'テラスタル一致',
    },
    'note.stellarStab': {
      AppLanguage.ko: '스텔라 자속',
      AppLanguage.en: 'Stellar STAB',
      AppLanguage.ja: 'ステラ一致',
    },
    'note.teraMin60': {
      AppLanguage.ko: '테라 60 위력 보정',
      AppLanguage.en: 'Tera 60 BP floor',
      AppLanguage.ja: 'テラスタル 60威力 補正',
    },
    'note.critical': {
      AppLanguage.ko: '급소',
      AppLanguage.en: 'Critical hit',
      AppLanguage.ja: '急所',
    },
    'note.burn': {
      AppLanguage.ko: '화상',
      AppLanguage.en: 'Burn',
      AppLanguage.ja: 'やけど',
    },
    // Weather names — match the existing Localizations.weatherKo etc.
    'note.weather.sun':       {AppLanguage.ko: '쾌청',     AppLanguage.en: 'Sun',          AppLanguage.ja: 'はれ'},
    'note.weather.rain':      {AppLanguage.ko: '비',       AppLanguage.en: 'Rain',         AppLanguage.ja: 'あめ'},
    'note.weather.harshSun':  {AppLanguage.ko: '강한 햇살', AppLanguage.en: 'Harsh Sun',    AppLanguage.ja: 'おおひでり'},
    'note.weather.heavyRain': {AppLanguage.ko: '강한 비',   AppLanguage.en: 'Heavy Rain',   AppLanguage.ja: 'おおあめ'},
    // Terrain names.
    'note.terrain.electric':  {AppLanguage.ko: '일렉트릭필드', AppLanguage.en: 'Electric Terrain', AppLanguage.ja: 'エレキフィールド'},
    'note.terrain.grassy':    {AppLanguage.ko: '그래스필드',   AppLanguage.en: 'Grassy Terrain',   AppLanguage.ja: 'グラスフィールド'},
    'note.terrain.psychic':   {AppLanguage.ko: '사이코필드',   AppLanguage.en: 'Psychic Terrain',  AppLanguage.ja: 'サイコフィールド'},
    'note.terrain.misty':     {AppLanguage.ko: '미스트필드',   AppLanguage.en: 'Misty Terrain',    AppLanguage.ja: 'ミストフィールド'},
    // Aura ability names.
    'note.aura.fairy': {AppLanguage.ko: '페어리오라',  AppLanguage.en: 'Fairy Aura',  AppLanguage.ja: 'フェアリーオーラ'},
    'note.aura.dark':  {AppLanguage.ko: '다크오라',   AppLanguage.en: 'Dark Aura',   AppLanguage.ja: 'ダークオーラ'},
    'note.aura.break': {AppLanguage.ko: '오라브레이크', AppLanguage.en: 'Aura Break',  AppLanguage.ja: 'オーラブレイク'},
    // Ruin ability names (the two that touch the attacker's stat).
    'note.ruin.tablets': {AppLanguage.ko: '재앙의목간', AppLanguage.en: 'Tablets of Ruin', AppLanguage.ja: 'わざわいのおふだ'},
    'note.ruin.vessel':  {AppLanguage.ko: '재앙의그릇', AppLanguage.en: 'Vessel of Ruin',  AppLanguage.ja: 'わざわいのうつわ'},
    'note.parentalBond': {
      AppLanguage.ko: '부자유친',
      AppLanguage.en: 'Parental Bond',
      AppLanguage.ja: 'おやこあい',
    },
    'note.charge': {
      AppLanguage.ko: '충전',
      AppLanguage.en: 'Charge',
      AppLanguage.ja: 'じゅうでん',
    },
    'breakdown.title': {
      AppLanguage.ko: '결정력 상세',
      AppLanguage.en: 'Offensive Power Breakdown',
      AppLanguage.ja: '決定力 詳細',
    },
    'breakdown.empty': {
      AppLanguage.ko: '추가 보정 없음',
      AppLanguage.en: 'No additional modifiers',
      AppLanguage.ja: '追加補正なし',
    },
    'breakdown.note': {
      AppLanguage.ko: '※ 타입 상성, 달인의띠(효과가 굉장할 때 한정), 리플렉터·빛의장막처럼 상대에 따라 달라지는 보정은 결정력에 들어가지 않습니다. 정확한 대미지는 대미지 탭을 확인해주세요.',
      AppLanguage.en: '※ Matchup-conditional modifiers (type effectiveness, Expert Belt on super-effective hits only, Reflect / Light Screen, etc.) are not folded into 결정력. See the Damage tab for exact values.',
      AppLanguage.ja: '※ タイプ相性、たつじんのおび(効果ばつぐんの時のみ)、リフレクター・ひかりのかべなど相手依存の補正は決定力には含まれません。正確なダメージはダメージタブをご確認ください。',
    },
    'note.terrainNegate': {
      AppLanguage.ko: '필드 무효',
      AppLanguage.en: 'Terrain negated',
      AppLanguage.ja: 'フィールド無効',
    },
    'note.disguiseDamage': {
      AppLanguage.ko: '최대 HP의 1/8 대미지',
      AppLanguage.en: '1/8 max HP damage',
      AppLanguage.ja: '最大HPの1/8ダメージ',
    },
    'note.keeBerryBoost': {
      AppLanguage.ko: '연속기 2타 이후 방어↑',
      AppLanguage.en: 'Defense ↑ after 1st hit',
      AppLanguage.ja: '連続技2発目以降 防御↑',
    },
    'note.marangaBerryBoost': {
      AppLanguage.ko: '연속기 2타 이후 특방↑',
      AppLanguage.en: 'Sp.Def ↑ after 1st hit',
      AppLanguage.ja: '連続技2発目以降 特防↑',
    },
    'note.defUp1': {
      AppLanguage.ko: '연속기 2타 이후 방어↑',
      AppLanguage.en: 'Defense ↑ after 1st hit',
      AppLanguage.ja: '連続技2発目以降 防御↑',
    },
    'note.defUp2': {
      AppLanguage.ko: '연속기 2타 이후 방어↑↑',
      AppLanguage.en: 'Defense ↑↑ after 1st hit',
      AppLanguage.ja: '連続技2発目以降 防御↑↑',
    },
    'note.defDown1': {
      AppLanguage.ko: '연속기 2타 이후 방어↓',
      AppLanguage.en: 'Defense ↓ after 1st hit',
      AppLanguage.ja: '連続技2発目以降 防御↓',
    },
    'note.groundImmune': {
      AppLanguage.ko: '비접지: 땅 타입 기술 무효',
      AppLanguage.en: 'Ungrounded: Ground immune',
      AppLanguage.ja: '非接地: じめん技無効',
    },
    'note.typeImmune': {
      AppLanguage.ko: '타입 상성에 의해 무효',
      AppLanguage.en: 'Type immunity',
      AppLanguage.ja: 'タイプ相性により無効',
    },
    'note.strongWinds': {
      AppLanguage.ko: '난기류: 비행 약점 무효화',
      AppLanguage.en: 'Strong Winds: Flying weakness negated',
      AppLanguage.ja: '乱気流: ひこう弱点無効',
    },
    'note.harshSunWater': {
      AppLanguage.ko: '강한 햇살: 물 기술 무효',
      AppLanguage.en: 'Harsh Sun: Water nullified',
      AppLanguage.ja: '強い日差し: みず技無効',
    },
    'note.heavyRainFire': {
      AppLanguage.ko: '강한 비: 불꽃 기술 무효',
      AppLanguage.en: 'Heavy Rain: Fire nullified',
      AppLanguage.ja: '大雨: ほのお技無効',
    },

    // === Status conditions ===
    'status.none': {
      AppLanguage.ko: '없음',
      AppLanguage.en: 'None',
      AppLanguage.ja: 'なし',
    },
    'status.burn': {
      AppLanguage.ko: '화상',
      AppLanguage.en: 'Burn',
      AppLanguage.ja: 'やけど',
    },
    'status.poison': {
      AppLanguage.ko: '독',
      AppLanguage.en: 'Poison',
      AppLanguage.ja: 'どく',
    },
    'status.badlyPoisoned': {
      AppLanguage.ko: '맹독',
      AppLanguage.en: 'Toxic',
      AppLanguage.ja: 'もうどく',
    },
    'status.paralysis': {
      AppLanguage.ko: '마비',
      AppLanguage.en: 'Paralysis',
      AppLanguage.ja: 'まひ',
    },
    'status.sleep': {
      AppLanguage.ko: '잠듦',
      AppLanguage.en: 'Sleep',
      AppLanguage.ja: 'ねむり',
    },
    'status.freeze': {
      AppLanguage.ko: '얼음',
      AppLanguage.en: 'Freeze',
      AppLanguage.ja: 'こおり',
    },

    // === Speed tier descriptions ===
    'speed.maxSpeed': {
      AppLanguage.ko: '최속',
      AppLanguage.en: 'Max',
      AppLanguage.ja: '最速',
    },
    'speed.neutralSpeed': {
      AppLanguage.ko: '준속',
      AppLanguage.en: 'Neutral',
      AppLanguage.ja: '準速',
    },
    'speed.unboostedSpeed': {
      AppLanguage.ko: '무보정',
      AppLanguage.en: 'Uninvested',
      AppLanguage.ja: '無振',
    },
    'speed.outspeeds': {
      AppLanguage.ko: '추월',
      AppLanguage.en: 'outspeeds',
      AppLanguage.ja: '抜き',
    },
    'speed.sameTier': {
      AppLanguage.ko: '동속',
      AppLanguage.en: 'ties',
      AppLanguage.ja: '同速',
    },

    // === Dynamax ===
    'label.dynamax': {
      AppLanguage.ko: '다이맥스',
      AppLanguage.en: 'Dynamax',
      AppLanguage.ja: 'ダイマックス',
    },
    'label.gigantamax': {
      AppLanguage.ko: '거다이맥스',
      AppLanguage.en: 'Gigantamax',
      AppLanguage.ja: 'キョダイマックス',
    },

    // === Nature ===
    'nature.none': {
      AppLanguage.ko: '없음',
      AppLanguage.en: '—',
      AppLanguage.ja: 'なし',
    },
    'nature.buffLabel': {
      AppLanguage.ko: '성격 ↑',
      AppLanguage.en: 'Nature ↑',
      AppLanguage.ja: '性格 ↑',
    },
    'nature.nerfLabel': {
      AppLanguage.ko: '성격 ↓',
      AppLanguage.en: 'Nature ↓',
      AppLanguage.ja: '性格 ↓',
    },
    'nature.neutral': {
      AppLanguage.ko: '무보정',
      AppLanguage.en: 'Neutral',
      AppLanguage.ja: '無補正',
    },

    // === About Dialog ===
    'about.description': {
      AppLanguage.ko: '실전 배틀 유저를 위한 결정력 계산기',
      AppLanguage.en: 'A damage calculator for competitive battle players.',
      AppLanguage.ja: '実戦バトルプレイヤーのためのダメージ計算機',
    },
    'about.subtitle': {
      AppLanguage.ko: '취미로 제작한 무료 어플리케이션입니다.',
      AppLanguage.en: 'A free application made as a hobby project.',
      AppLanguage.ja: '趣味で制作した無料アプリです。',
    },
    'about.beta': {
      AppLanguage.ko: '문의 및 버그 리포트는 GitHub Issues로 부탁드립니다.',
      AppLanguage.en: 'Bug reports and suggestions are welcome via GitHub Issues.',
      AppLanguage.ja: 'バグ報告やご要望はGitHub Issuesまでお願いします。',
    },
    'about.disclaimer': {
      AppLanguage.ko: '본 앱은 Nintendo, Game Freak, The Pokémon Company와 관련이 없는 비공식 팬메이드 앱입니다.\n관련 데이터의 저작권은 원저작자에게 있습니다.',
      AppLanguage.en: 'This is an unofficial fan-made project not affiliated with Nintendo, Game Freak, or The Pokémon Company.\nAll related data belongs to their respective owners.',
      AppLanguage.ja: '本アプリは任天堂、ゲームフリーク、株式会社ポケモンとは無関係の非公式ファンメイドアプリです。\n関連データの著作権は各権利者に帰属します。',
    },
  };
}
