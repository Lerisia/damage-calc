/// Localization strings for the damage calculator.
/// Supports Korean (ko), English (en), and Japanese (ja).
///
/// No trademarked terms (Pokemon, etc.) are used.

enum AppLanguage { ko, en, ja }

class AppStrings {
  static AppLanguage _current = AppLanguage.ko;

  static AppLanguage get current => _current;
  static void setLanguage(AppLanguage lang) => _current = lang;

  static String get(String key) => (_strings[key]?[_current]) ?? key;

  // Shorthand
  static String t(String key) => get(key);

  static const Map<String, Map<AppLanguage, String>> _strings = {
    // === App ===
    'app.title': {
      AppLanguage.ko: '결정력 계산기',
      AppLanguage.en: 'Damage Calculator',
      AppLanguage.ja: '決定力計算機',
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
      AppLanguage.ja: '素早',
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
      AppLanguage.en: 'Actual',
      AppLanguage.ja: '実数値',
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
      AppLanguage.en: 'Pow',
      AppLanguage.ja: '威力',
    },
    'move.critical': {
      AppLanguage.ko: '급소',
      AppLanguage.en: 'Crit',
      AppLanguage.ja: '急所',
    },
    'move.offensive': {
      AppLanguage.ko: '결정력',
      AppLanguage.en: 'Power',
      AppLanguage.ja: '決定力',
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
    'toolbar.swap': {
      AppLanguage.ko: '공수교대',
      AppLanguage.en: 'Swap',
      AppLanguage.ja: '攻守交代',
    },
    'toolbar.reset': {
      AppLanguage.ko: '초기화',
      AppLanguage.en: 'Reset',
      AppLanguage.ja: 'リセット',
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

    // === Sample ===
    'sample.save': {
      AppLanguage.ko: '샘플 저장',
      AppLanguage.en: 'Save Sample',
      AppLanguage.ja: 'サンプル保存',
    },
    'sample.load': {
      AppLanguage.ko: '샘플 불러오기',
      AppLanguage.en: 'Load Sample',
      AppLanguage.ja: 'サンプル読込',
    },
    'sample.name': {
      AppLanguage.ko: '샘플 이름',
      AppLanguage.en: 'Sample Name',
      AppLanguage.ja: 'サンプル名',
    },
    'sample.search': {
      AppLanguage.ko: '샘플 검색',
      AppLanguage.en: 'Search Samples',
      AppLanguage.ja: 'サンプル検索',
    },
    'sample.empty': {
      AppLanguage.ko: '저장된 샘플이 없습니다',
      AppLanguage.en: 'No saved samples',
      AppLanguage.ja: '保存されたサンプルはありません',
    },
    'sample.browserWarning': {
      AppLanguage.ko: '브라우저 데이터 삭제 시 저장된 샘플이 사라질 수 있습니다.',
      AppLanguage.en: 'Saved samples may be lost if browser data is cleared.',
      AppLanguage.ja: 'ブラウザデータ削除時、保存サンプルが消える場合があります。',
    },
    'sample.exported': {
      AppLanguage.ko: '샘플 데이터를 내보냈습니다',
      AppLanguage.en: 'Samples exported',
      AppLanguage.ja: 'サンプルデータをエクスポートしました',
    },
    'sample.importedN': {
      AppLanguage.ko: '개의 샘플을 가져왔습니다',
      AppLanguage.en: ' samples imported',
      AppLanguage.ja: '件のサンプルをインポートしました',
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
    'speed.tie': {
      AppLanguage.ko: '동속',
      AppLanguage.en: 'Speed Tie',
      AppLanguage.ja: '同速',
    },
    'speed.guaranteedFirst': {
      AppLanguage.ko: '확정 선공',
      AppLanguage.en: 'Guaranteed First',
      AppLanguage.ja: '確定先攻',
    },
    'speed.guaranteedLast': {
      AppLanguage.ko: '확정 후공',
      AppLanguage.en: 'Guaranteed Last',
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
      AppLanguage.ko: '효과 매우 좋음',
      AppLanguage.en: 'Super Effective',
      AppLanguage.ja: '効果ばつぐん',
    },
    'eff.superEffective': {
      AppLanguage.ko: '효과 좋음',
      AppLanguage.en: 'Super Effective',
      AppLanguage.ja: '効果ばつぐん',
    },
    'eff.notVeryEffective025': {
      AppLanguage.ko: '효과 매우 별로',
      AppLanguage.en: 'Not Very Effective',
      AppLanguage.ja: '効果いまひとつ',
    },
    'eff.notVeryEffective': {
      AppLanguage.ko: '효과 별로',
      AppLanguage.en: 'Not Very Effective',
      AppLanguage.ja: '効果いまひとつ',
    },
    'eff.neutral': {
      AppLanguage.ko: '효과 보통',
      AppLanguage.en: 'Neutral',
      AppLanguage.ja: '等倍',
    },

    // === KO ===
    'ko.guaranteed': {
      AppLanguage.ko: '확정',
      AppLanguage.en: 'guaranteed',
      AppLanguage.ja: '確定',
    },
    'ko.random': {
      AppLanguage.ko: '난수',
      AppLanguage.en: 'random',
      AppLanguage.ja: '乱数',
    },
    'ko.hit': {
      AppLanguage.ko: '타',
      AppLanguage.en: 'HKO',
      AppLanguage.ja: '発',
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
      AppLanguage.ko: '초기화',
      AppLanguage.en: 'Reset',
      AppLanguage.ja: 'リセット',
    },
    'reset.message': {
      AppLanguage.ko: '양측 설정과 날씨/필드/룸이 모두 초기화됩니다',
      AppLanguage.en: 'All settings including weather, terrain, and room will be reset',
      AppLanguage.ja: '両側の設定と天候/フィールド/ルームがすべてリセットされます',
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
      AppLanguage.ko: '효과 좋음',
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
  };
}
