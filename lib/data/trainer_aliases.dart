/// Search aliases for the bundled Showdown trainer sprite catalog
/// (assets/trainers/<key>.png). Maps asset keys to localized names
/// so the avatar picker's search bar matches in Korean and Japanese
/// in addition to the English asset name.
///
/// Coverage is selective by design: ~1455 sprites × 3 languages is
/// well beyond hand-curation, so we cover the high-recognition
/// characters (champions, gym leaders, rivals, protagonists) plus
/// the common NPC trainer classes. Variants of the same character
/// across generations (e.g. red-gen1, red-gen2, ...) share the
/// same alias entry through stripped-key lookup, so adding 'red'
/// once surfaces every Red sprite.
///
/// Search semantics: a query matches a sprite key K iff the query
/// (case-folded) is a substring of K *or* of any alias mapped to
/// K's character/class prefix. Unmapped keys still match on the
/// raw key text — so naming this list isn't a precondition for
/// the sprite being searchable.
library;

/// Aliases keyed by *character / class stem* — i.e. the asset key
/// with -genN / -ms / -masters / -afa etc. suffixes stripped. Each
/// entry lists every locale form (Korean / Japanese / common
/// English nicknames) we want to surface in search.
const Map<String, List<String>> trainerAliases = {
  // === Champions ===========================================
  'red': ['레드', 'レッド', 'red'],
  'blue': ['블루', 'グリーン', 'green', 'blue'],
  'lance': ['목호', 'ワタル'],
  'steven': ['성호', 'ダイゴ', 'steven stone'],
  'wallace': ['윤진', 'ミクリ'],
  'cynthia': ['난천', 'シロナ'],
  'alder': ['적두', 'アデク'],
  'iris': ['아이리스', 'アイリス'],
  'diantha': ['카르네', 'カルネ'],
  'kukui': ['쿠쿠이', 'ククイ'],
  'hau': ['하우', 'ハウ'],
  'leon': ['단단', 'ダンデ'],
  'mustard': ['머스타드', 'マスタード'],
  'peony': ['피오니', 'ピオニー'],
  'geeta': ['오모대', 'オモダカ'],
  'nemona': ['네모', 'ネモ'],
  'kieran': ['우호이', 'スグリ'],
  'carmine': ['홍모', 'ゼイユ'],

  // === Protagonists ========================================
  'ethan': ['금', 'ヒビキ', 'gold'],
  'kris': ['크리스', 'クリス'],
  'lyra': ['하트', 'コトネ'],
  'brendan': ['호일', 'ユウキ'],
  'may': ['미나', 'ハルカ'],
  'lucas': ['진수', 'コウキ'],
  'dawn': ['빛나', 'ヒカリ'],
  'hilbert': ['투우', 'トウヤ'],
  'hilda': ['벨', 'トウコ'],
  'nate': ['휴이', 'キョウヘイ'],
  'rosa': ['메이', 'メイ'],
  'calem': ['칼름', 'カルム'],
  'serena': ['세레나', 'セレナ'],
  'elio': ['해성', 'ヨウ', 'sun'],
  'selene': ['미온', 'ミヅキ', 'moon'],
  'victor': ['빅터', 'マサル'],
  'gloria': ['글로리아', 'ユウリ'],
  'juliana': ['아오이', 'アオイ'],
  'florian': ['하루토', 'ハルト'],

  // === Rivals ==============================================
  'silver': ['실버', 'シルバー'],
  'wally': ['타로', 'ミツル'],
  'barry': ['웅이', 'ジュン'],
  'cheren': ['체렌', 'チェレン'],
  'bianca': ['벨', 'ベル'],
  'n': ['엔', 'N'],
  'hugh': ['휴이', 'ヒュウ'],
  'shauna': ['사나', 'サナ'],
  'tierno': ['티에르노', 'ティエルノ'],
  'trevor': ['트레버', 'トロバ'],
  'gladion': ['글라디오', 'グラジオ'],
  'lillie': ['릴리에', 'リーリエ'],
  'marnie': ['마리', 'マリィ'],
  'bede': ['비트', 'ビート'],
  'klara': ['색기', 'シキミ'],
  'avery': ['미러', 'オニオン'],
  'arven': ['페퍼', 'ペパー'],
  'penny': ['보탄', 'ボタン'],

  // === Kanto Gym Leaders ==================================
  'brock': ['웅', 'タケシ'],
  'misty': ['이슬', 'カスミ'],
  'ltsurge': ['마티스', 'マチス', 'lt surge', 'surge'],
  'erika': ['민화', 'エリカ'],
  'koga': ['독수', 'キョウ'],
  'sabrina': ['초련', 'ナツメ'],
  'blaine': ['강연', 'カツラ'],
  'giovanni': ['관철', 'サカキ'],
  'janine': ['아네', 'アンズ'],
  'blue-leader': ['블루', 'グリーン'],

  // === Johto Gym Leaders ==================================
  'falkner': ['비조', 'ハヤト'],
  'bugsy': ['갑돌', 'ツクシ'],
  'whitney': ['미희', 'アカネ'],
  'morty': ['단풍', 'マツバ'],
  'chuck': ['시즈오', 'シジマ'],
  'jasmine': ['민영', 'ミカン'],
  'pryce': ['유빙', 'ヤナギ'],
  'clair': ['이향', 'イブキ'],

  // === Hoenn Gym Leaders ==================================
  'roxanne': ['철민', 'ツツジ'],
  'brawly': ['용호', 'トウキ'],
  'wattson': ['철구', 'テッセン'],
  'flannery': ['아랑', 'アスナ'],
  'norman': ['민호', 'センリ'],
  'winona': ['풍연', 'ナギ'],
  'tate': ['풍', 'フウ'],
  'liza': ['란', 'ラン'],
  'juan': ['장이', 'アダン'],

  // === Sinnoh Gym Leaders =================================
  'roark': ['석탄', 'ヒョウタ'],
  'gardenia': ['초목', 'ナタネ'],
  'maylene': ['스모모', 'スモモ'],
  'crasher_wake': ['맥슨', 'マキシ', 'crasher wake'],
  'crasherwake': ['맥슨', 'マキシ', 'crasher wake'],
  'fantina': ['멜리사', 'メリッサ'],
  'byron': ['동', 'トウガン'],
  'candice': ['스즈나', 'スズナ'],
  'volkner': ['전룡', 'デンジ'],

  // === Unova Gym Leaders ==================================
  'cilan': ['데세루', 'デント'],
  'chili': ['포드', 'ポッド'],
  'cress': ['콘', 'コーン'],
  'lenora': ['아로에', 'アロエ'],
  'burgh': ['아티', 'アーティ'],
  'elesa': ['카밋트레', 'カミツレ'],
  'clay': ['옐로', 'ヤーコン'],
  'skyla': ['후우로', 'フウロ'],
  'brycen': ['하치쿠', 'ハチク'],
  'drayden': ['샤가', 'シャガ'],
  'roxie': ['홈이카', 'ホミカ'],
  'marlon': ['시즈이', 'シズイ'],

  // === Kalos Gym Leaders ==================================
  'viola': ['비올라', 'ビオラ'],
  'grant': ['잭', 'ザクロ'],
  'korrina': ['시트론', 'コルニ'],
  'ramos': ['후쿠지', 'フクジ'],
  'clemont': ['시트론', 'シトロン'],
  'valerie': ['마슈', 'マーシュ'],
  'olympia': ['고지카', 'ゴジカ'],
  'wulfric': ['우루프', 'ウルップ'],

  // === Alola Trial Captains / Kahunas ====================
  'ilima': ['이리마', 'イリマ'],
  'lana': ['수련', 'スイレン'],
  'kiawe': ['카키', 'カキ'],
  'mallow': ['마오', 'マオ'],
  'sophocles': ['마마네', 'マーマネ'],
  'acerola': ['아세롤라', 'アセロラ'],
  'mina': ['미나', 'ミナ'],
  'hala': ['하라', 'ハラ'],
  'olivia': ['리리이', 'リーリエ'],
  'nanu': ['쿠치나시', 'クチナシ'],
  'hapu': ['하푸', 'ハプウ'],

  // === Galar Gym Leaders ==================================
  'milo': ['야로', 'ヤロー'],
  'nessa': ['루리나', 'ルリナ'],
  'kabu': ['카부', 'カブ'],
  'bea': ['사이토', 'サイトウ'],
  'allister': ['온이', 'オニオン'],
  'opal': ['포플라', 'ポプラ'],
  'gordie': ['마쿠와', 'マクワ'],
  'melony': ['멜론', 'メロン'],
  'piers': ['네즈', 'ネズ'],
  'raihan': ['키바나', 'キバナ'],

  // === Paldea Gym Leaders =================================
  'katy': ['카지', 'カエデ'],
  'brassius': ['콜사', 'コルサ'],
  'iono': ['난조', 'ナンジャモ'],
  'kofu': ['하사쿠', 'ハッサク'],
  'larry': ['아오키', 'アオキ'],
  'ryme': ['리프', 'ライム'],
  'tulip': ['릴리', 'リップ'],
  'grusha': ['그루샤', 'グルーシャ'],

  // === Elite Four (selected) ==============================
  'lorelei': ['카나', 'カンナ'],
  'bruno': ['시바', 'シバ'],
  'agatha': ['키쿠코', 'キクコ'],
  'will': ['이츠키', 'イツキ'],
  'karen': ['카린', 'カリン'],
  'sidney': ['카게쓰', 'カゲツ'],
  'phoebe': ['후요', 'フヨウ'],
  'glacia': ['프림', 'プリム'],
  'drake': ['겐지', 'ゲンジ'],
  'aaron': ['류바', 'リョウ'],
  'bertha': ['키쿠노', 'キクノ'],
  'flint': ['오바', 'オーバ'],
  'lucian': ['고요', 'ゴヨウ'],
  'shauntal': ['시키미', 'シキミ'],
  'grimsley': ['기마', 'ギーマ'],
  'caitlin': ['카틀레아', 'カトレア'],
  'marshal': ['렌부', 'レンブ'],
  'malva': ['파키라', 'パキラ'],
  'siebold': ['지나', 'ジナ'],
  'wikstrom': ['간세키', 'ガンセキ'],
  'drasna': ['도라세나', 'ドラセナ'],
  'molayne': ['마타도가스', 'マーレイン'],

  // === Trainer classes (NPC) ==============================
  'acetrainer': ['에이스 트레이너', 'エリートトレーナー', 'ace trainer'],
  'acetrainercouple': ['에이스 커플', 'エリートカップル'],
  'acetrainerf': ['에이스 트레이너', 'エリートトレーナー', 'ace trainer'],
  'aromalady': ['아로마 부인', 'アロマなおねえさん', 'aroma lady'],
  'artist': ['아티스트', 'アーティスト'],
  'baker': ['파티시에', 'パティシエ'],
  'battlegirl': ['배틀걸', 'バトルガール', 'battle girl'],
  'beauty': ['미녀', 'びじん'],
  'bellhop': ['벨보이', 'ベルボーイ'],
  'biker': ['바이커', 'バイカー'],
  'bird-keeper': ['새 트레이너', 'とりつかい', 'bird keeper'],
  'birdkeeper': ['새 트레이너', 'とりつかい', 'bird keeper'],
  'blackbelt': ['검은띠', 'からておう', 'black belt'],
  'boarder': ['스노보더', 'スノーボーダー'],
  'breeder': ['브리더', 'ポケモンブリーダー'],
  'breederf': ['브리더', 'ポケモンブリーダー'],
  'bugcatcher': ['벌레잡이', 'むしとりしょうねん', 'bug catcher'],
  'bugmaniac': ['벌레광', 'むしとりマニア', 'bug maniac'],
  'burglar': ['도둑', 'どろぼう'],
  'cameraman': ['카메라맨', 'カメラマン'],
  'channeler': ['초능력자', 'チャネラー'],
  'cheerleader': ['치어리더', 'チアリーダー'],
  'chef': ['셰프', 'シェフ'],
  'chic': ['멋쟁이', 'おしゃれ'],
  'cooltrainer': ['에이스 트레이너', 'エリートトレーナー', 'cool trainer'],
  'cyclist': ['사이클리스트', 'サイクリスト'],
  'dancer': ['댄서', 'ダンサー'],
  'dragontamer': ['용 사용자', 'ドラゴンつかい', 'dragon tamer'],
  'engineer': ['엔지니어', 'エンジニア'],
  'expertm': ['전문가', 'マスター'],
  'expertf': ['전문가', 'マスター'],
  'fairy': ['요정', '妖精'],
  'fairytalegirl': ['동화소녀', 'フェアリーガール'],
  'firebreather': ['불 곡예사', 'ひぶき'],
  'fisherman': ['낚시꾼', 'つりびと'],
  'gambler': ['갬블러', 'ばくとし'],
  'gameboy': ['게이머', 'ゲームボーイ'],
  'gentleman': ['신사', 'ジェントルマン'],
  'guitarist': ['기타리스트', 'ギタリスト'],
  'hexmaniac': ['오컬트 마니아', 'オカルトマニア', 'hex maniac'],
  'hiker': ['등산가', 'ヤマおとこ'],
  'idol': ['아이돌', 'アイドル'],
  'jogger': ['조거', 'ジョギング'],
  'juggler': ['저글러', 'ジャグラー'],
  'kindler': ['불 곡예사', 'ひぶき', 'kindler'],
  'lady': ['아가씨', 'おじょうさま'],
  'lass': ['미니스커트', 'ミニスカート'],
  'maid': ['메이드', 'メイド'],
  'medium': ['영매사', 'おばあさん'],
  'monk': ['수도승', 'おとうさん'],
  'musician': ['뮤지션', 'おんがくか'],
  'ninjaboy': ['닌자보이', 'ニンジャごっこ'],
  'oldcouple': ['노부부', 'ろうふうふ', 'old couple'],
  'parasolady': ['파라솔 부인', 'パラソルおねえさん'],
  'picknicker': ['피크닉 소녀', 'ピクニックガール'],
  'plasmagrunt': ['플라스마단', 'プラズマだんいん', 'plasma grunt'],
  'plasmagruntf': ['플라스마단', 'プラズマだんいん', 'plasma grunt'],
  'pokefan': ['포켓팬', 'ポケファン'],
  'pokefanf': ['포켓팬', 'ポケファン'],
  'pokekid': ['포켓 키드', 'ポケモンキッズ'],
  'pokemaniac': ['포켓광', 'ポケモンマニア', 'poke maniac'],
  'pokemanic': ['포켓광', 'ポケモンマニア'],
  'policeman': ['경찰관', 'けいさつかん'],
  'preschoolerm': ['유치원생', 'ようちえんじ'],
  'preschoolerf': ['유치원생', 'ようちえんじ'],
  'pikabro': ['피카브로', 'ピカブロ'],
  'pikachu-libre': ['피카리브레', 'ピカリブレ', 'pikachu libre'],
  'punkgirl': ['펑크걸', 'パンクガール', 'punk girl'],
  'punkguy': ['펑크가이', 'パンクボーイ', 'punk guy'],
  'reporter': ['리포터', 'レポーター'],
  'researcher': ['연구원', 'けんきゅうしゃ'],
  'richboy': ['부잣집 아들', 'ぼっちゃま', 'rich boy'],
  'roughneck': ['스킨헤드', 'スキンヘッズ'],
  'rocketgrunt': ['로켓단', 'ロケットだんいん', 'rocket grunt'],
  'rocketgruntf': ['로켓단', 'ロケットだんいん', 'rocket grunt'],
  'magmagrunt': ['마그마단', 'マグマだんいん', 'magma grunt'],
  'magmagruntf': ['마그마단', 'マグマだんいん', 'magma grunt'],
  'aquagrunt': ['아쿠아단', 'アクアだんいん', 'aqua grunt'],
  'aquagruntf': ['아쿠아단', 'アクアだんいん', 'aqua grunt'],
  'galacticgrunt': ['갤럭틱단', 'ギンガだんいん', 'galactic grunt'],
  'galacticgruntf': ['갤럭틱단', 'ギンガだんいん', 'galactic grunt'],
  'flaregrunt': ['플레어단', 'フレアだんいん', 'flare grunt'],
  'flaregruntf': ['플레어단', 'フレアだんいん', 'flare grunt'],
  'skullgrunt': ['스컬단', 'スカルだんいん', 'skull grunt'],
  'skullgruntf': ['스컬단', 'スカルだんいん', 'skull grunt'],
  'machogrunt': ['마초단', 'マチョだんいん', 'macho grunt'],
  'rangerm': ['레인저', 'レンジャー'],
  'rangerf': ['레인저', 'レンジャー'],
  'rocker': ['로커', 'ロッカー'],
  'sage': ['선인', 'せんにん'],
  'sailor': ['선원', 'セーラー'],
  'schoolboy': ['스쿨보이', 'スクールボーイ'],
  'schoolgirl': ['스쿨걸', 'スクールガール'],
  'schoolkid': ['스쿨키드', 'がくしゅうきっず', 'school kid'],
  'scientist': ['과학자', 'かがくしゃ'],
  'scientistf': ['과학자', 'かがくしゃ'],
  'sisandbro': ['남매', 'きょうだい'],
  'skierm': ['스키어', 'スキーヤー'],
  'skierf': ['스키어', 'スキーヤー'],
  'skyer': ['스카이 트레이너', 'スカイトレーナー'],
  'sr-and-jr': ['시니어와 주니어', 'おじいさんとまご'],
  'srandjr': ['시니어와 주니어', 'おじいさんとまご'],
  'striker': ['축구선수', 'ストライカー', 'soccer player'],
  'supernerd': ['오타쿠', 'ものまねむすめ', 'super nerd'],
  'swimmer': ['스위머', 'すいえいせんしゅ'],
  'swimmerf': ['스위머', 'すいえいせんしゅ'],
  'tamer': ['용 사용자', 'ドラゴンつかい'],
  'teacher': ['선생님', 'せんせい'],
  'triathlete': ['트라이애슬릿', 'トライアスロン'],
  'tuber': ['튜브 키드', 'うきわっこ'],
  'tuberf': ['튜브 키드', 'うきわっこ'],
  'twins': ['쌍둥이', 'ふたごちゃん'],
  'veteran': ['베테랑', 'ベテラン'],
  'veteranf': ['베테랑', 'ベテラン'],
  'waiter': ['웨이터', 'ウェイター'],
  'waitress': ['웨이트리스', 'ウェイトレス'],
  'worker': ['작업원', 'こうじげんば'],
  'workerice': ['작업원', 'こうじげんば'],
  'workerf': ['작업원', 'こうじげんば'],
  'youngster': ['소년', 'たんパンこぞう'],
  'youngcouple': ['젊은 부부', 'カップル'],
};

/// Coarse category for picker browsing. Most users won't know
/// 'wattson' by name but *will* recognise 'gym leader of generation
/// 3' — categories let them drill in without typing. Categories
/// are derived from [trainerKeyStem] against the curated sets
/// below; anything we haven't classified falls into [other] so the
/// 'All' tab is always exhaustive even if our hand-curation lags.
enum TrainerCategory {
  all,
  champion,
  gymLeader,
  eliteFour,
  protagonistRival,
  npc,
  other;
}

/// Stems classified as Champions across the main-line games.
/// Mirrors the 'Champions' block at the top of [trainerAliases].
const Set<String> trainerChampionStems = {
  'red', 'blue', 'lance', 'steven', 'wallace', 'cynthia',
  'alder', 'iris', 'diantha', 'kukui', 'hau', 'leon',
  'mustard', 'peony', 'geeta', 'nemona', 'kieran', 'carmine',
  'blue-leader',
};

/// Stems classified as Gym Leaders.
const Set<String> trainerGymLeaderStems = {
  // Kanto
  'brock', 'misty', 'ltsurge', 'erika', 'koga', 'sabrina',
  'blaine', 'giovanni', 'janine',
  // Johto
  'falkner', 'bugsy', 'whitney', 'morty', 'chuck', 'jasmine',
  'pryce', 'clair',
  // Hoenn
  'roxanne', 'brawly', 'wattson', 'flannery', 'norman',
  'winona', 'tate', 'liza', 'juan',
  // Sinnoh
  'roark', 'gardenia', 'maylene', 'crasher_wake', 'crasherwake',
  'fantina', 'byron', 'candice', 'volkner',
  // Unova
  'cilan', 'chili', 'cress', 'lenora', 'burgh', 'elesa',
  'clay', 'skyla', 'brycen', 'drayden', 'roxie', 'marlon',
  // Kalos
  'viola', 'grant', 'korrina', 'ramos', 'clemont', 'valerie',
  'olympia', 'wulfric',
  // Galar
  'milo', 'nessa', 'kabu', 'bea', 'allister', 'opal',
  'gordie', 'melony', 'piers', 'raihan',
  // Paldea
  'katy', 'brassius', 'iono', 'kofu', 'larry', 'ryme',
  'tulip', 'grusha',
  // Alola Trial Captains / Kahunas — game-mechanic cousins of
  // gym leaders, grouped here so the picker doesn't need a
  // 7th tab just for one region.
  'ilima', 'lana', 'kiawe', 'mallow', 'sophocles', 'acerola',
  'mina', 'hala', 'olivia', 'nanu', 'hapu',
};

/// Stems classified as Elite Four members.
const Set<String> trainerEliteFourStems = {
  'lorelei', 'bruno', 'agatha',
  'will', 'karen',
  'sidney', 'phoebe', 'glacia', 'drake',
  'aaron', 'bertha', 'flint', 'lucian',
  'shauntal', 'grimsley', 'caitlin', 'marshal',
  'malva', 'siebold', 'wikstrom', 'drasna',
  'molayne',
};

/// Stems classified as protagonists or rivals — they share a
/// tab because both fill the 'player surrogate / friendly foil'
/// role and players tend to recognise them together.
const Set<String> trainerProtagonistRivalStems = {
  // Protagonists
  'ethan', 'kris', 'lyra', 'brendan', 'may', 'lucas', 'dawn',
  'hilbert', 'hilda', 'nate', 'rosa', 'calem', 'serena',
  'elio', 'selene', 'victor', 'gloria', 'juliana', 'florian',
  // Rivals
  'silver', 'wally', 'barry', 'cheren', 'bianca', 'n', 'hugh',
  'shauna', 'tierno', 'trevor', 'gladion', 'lillie', 'marnie',
  'bede', 'klara', 'avery', 'arven', 'penny',
};

/// NPC trainer class stems. Mirrors the 'Trainer classes (NPC)'
/// block of [trainerAliases]. Anything not in this set and not
/// in the named-character sets lands in [TrainerCategory.other].
const Set<String> trainerNpcClassStems = {
  'acetrainer', 'acetrainercouple', 'acetrainerf', 'aromalady',
  'artist', 'baker', 'battlegirl', 'beauty', 'bellhop', 'biker',
  'bird-keeper', 'birdkeeper', 'blackbelt', 'boarder', 'breeder',
  'breederf', 'bugcatcher', 'bugmaniac', 'burglar', 'cameraman',
  'channeler', 'cheerleader', 'chef', 'chic', 'cooltrainer',
  'cyclist', 'dancer', 'dragontamer', 'engineer', 'expertm',
  'expertf', 'fairy', 'fairytalegirl', 'firebreather', 'fisherman',
  'gambler', 'gameboy', 'gentleman', 'guitarist', 'hexmaniac',
  'hiker', 'idol', 'jogger', 'juggler', 'kindler', 'lady', 'lass',
  'maid', 'medium', 'monk', 'musician', 'ninjaboy', 'oldcouple',
  'parasolady', 'picknicker', 'plasmagrunt', 'plasmagruntf',
  'pokefan', 'pokefanf', 'pokekid', 'pokemaniac', 'pokemanic',
  'policeman', 'preschoolerm', 'preschoolerf', 'pikabro',
  'pikachu-libre', 'punkgirl', 'punkguy', 'reporter', 'researcher',
  'richboy', 'roughneck', 'rocketgrunt', 'rocketgruntf',
  'magmagrunt', 'magmagruntf', 'aquagrunt', 'aquagruntf',
  'galacticgrunt', 'galacticgruntf', 'flaregrunt', 'flaregruntf',
  'skullgrunt', 'skullgruntf', 'machogrunt', 'rangerm', 'rangerf',
  'rocker', 'sage', 'sailor', 'schoolboy', 'schoolgirl', 'schoolkid',
  'scientist', 'scientistf', 'sisandbro', 'skierm', 'skierf',
  'skyer', 'sr-and-jr', 'srandjr', 'striker', 'supernerd',
  'swimmer', 'swimmerf', 'tamer', 'teacher', 'triathlete',
  'tuber', 'tuberf', 'twins', 'veteran', 'veteranf', 'waiter',
  'waitress', 'worker', 'workerice', 'workerf', 'youngster',
  'youngcouple',
};

/// Classify a sprite key into one of the picker tabs. Uses the
/// stem (suffix-stripped key) so e.g. 'cynthia-masters3' and
/// 'cynthia-gen4' both land in [TrainerCategory.champion].
TrainerCategory trainerCategoryOf(String key) {
  final stem = trainerKeyStem(key);
  if (trainerChampionStems.contains(stem) ||
      trainerChampionStems.contains(key)) {
    return TrainerCategory.champion;
  }
  if (trainerGymLeaderStems.contains(stem) ||
      trainerGymLeaderStems.contains(key)) {
    return TrainerCategory.gymLeader;
  }
  if (trainerEliteFourStems.contains(stem) ||
      trainerEliteFourStems.contains(key)) {
    return TrainerCategory.eliteFour;
  }
  if (trainerProtagonistRivalStems.contains(stem) ||
      trainerProtagonistRivalStems.contains(key)) {
    return TrainerCategory.protagonistRival;
  }
  if (trainerNpcClassStems.contains(stem) ||
      trainerNpcClassStems.contains(key)) {
    return TrainerCategory.npc;
  }
  return TrainerCategory.other;
}

/// Strip generation/format suffixes from an asset key so we can
/// look up the alias of the underlying character/class. Example:
///   'red-gen1rb' → 'red'
///   'acetrainer-gen6xy' → 'acetrainer'
///   'cynthia-masters' → 'cynthia'
/// Keys without a suffix come through unchanged.
String trainerKeyStem(String key) {
  // Strip everything from the first hyphen onwards, *unless* the
  // hyphen is part of a multi-word stem we explicitly listed (like
  // 'crasher_wake' or 'sr-and-jr'). The alias map already covers
  // those by including the hyphenated stem as a literal key, so a
  // straight "first hyphen" split is safe — if the stem after the
  // split misses, lookup just falls back to no alias.
  final dash = key.indexOf('-');
  if (dash < 0) return key;
  return key.substring(0, dash);
}

/// Returns the lower-case search corpus for [key] — the key text
/// itself plus any matching alias forms. Used by the picker to
/// decide whether a query matches a given sprite.
List<String> trainerSearchCorpus(String key) {
  final stem = trainerKeyStem(key);
  final aliases = trainerAliases[key] ?? trainerAliases[stem] ?? const [];
  return [
    key.toLowerCase(),
    if (stem != key) stem.toLowerCase(),
    ...aliases.map((a) => a.toLowerCase()),
  ];
}
