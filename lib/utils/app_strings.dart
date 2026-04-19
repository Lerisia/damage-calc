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
    'stat.speedShort': {
      AppLanguage.ko: '스핏',
      AppLanguage.en: 'Spe',
      AppLanguage.ja: 'すば',
    },
    'simple.screens': {
      AppLanguage.ko: '벽',
      AppLanguage.en: 'Screens',
      AppLanguage.ja: '壁',
    },
    'simple.natureNeutral': {
      AppLanguage.ko: '무',
      AppLanguage.en: '–',
      AppLanguage.ja: '無',
    },
    'simple.announceTitle': {
      AppLanguage.ko: '간단 모드가 기본이 되었습니다',
      AppLanguage.en: 'Simple Mode is now the default',
      AppLanguage.ja: 'かんたんモードが既定になりました',
    },
    'simple.announceBody': {
      AppLanguage.ko: '확장 모드는 오른쪽 상단 메뉴(⋮)에서 전환할 수 있습니다.',
      AppLanguage.en: 'Switch to Extended Mode from the top-right menu (⋮).',
      AppLanguage.ja: '拡張モードは右上のメニュー(⋮)から切り替えられます。',
    },
    'simple.extendedAnnounceTitle': {
      AppLanguage.ko: '확장 모드',
      AppLanguage.en: 'Extended Mode',
      AppLanguage.ja: '拡張モード',
    },
    'simple.extendedAnnounceBody': {
      AppLanguage.ko: '언제든 오른쪽 상단 메뉴(⋮)에서 간단 모드로 돌아갈 수 있습니다.',
      AppLanguage.en: 'You can return to Simple Mode any time from the top-right menu (⋮).',
      AppLanguage.ja: 'いつでも右上のメニュー(⋮)からかんたんモードに戻れます。',
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
      AppLanguage.ko: '기술을 선택하세요',
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
      AppLanguage.ko: '배틀환경',
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
      AppLanguage.ko: '내보낸 JSON 데이터를 붙여넣으세요.',
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
    'damage.moveNotSet': {
      AppLanguage.ko: '미설정',
      AppLanguage.en: 'Not Set',
      AppLanguage.ja: '未設定',
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

    // === Snackbar messages ===
    'msg.imageSaved': {
      AppLanguage.ko: '이미지가 저장되었습니다',
      AppLanguage.en: 'Image saved',
      AppLanguage.ja: '画像を保存しました',
    },
    'msg.fullScreenSaved': {
      AppLanguage.ko: '전체 화면이 저장되었습니다',
      AppLanguage.en: 'Full screen saved',
      AppLanguage.ja: '全画面を保存しました',
    },
    'msg.saveFailed': {
      AppLanguage.ko: '저장 실패',
      AppLanguage.en: 'Save failed',
      AppLanguage.ja: '保存に失敗しました',
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
