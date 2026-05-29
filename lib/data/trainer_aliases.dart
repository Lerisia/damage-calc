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
  'alder': ['노간주', 'アデク'],
  'iris': ['아이리스', 'アイリス'],
  'diantha': ['카르네', 'カルネ'],
  'kukui': ['쿠쿠이', 'ククイ'],
  'hau': ['하우', 'ハウ'],
  'leon': ['단델', 'ダンデ'],
  'mustard': ['머스타드', 'マスタード'],
  'peony': ['피오니', 'ピオニー'],
  'geeta': ['테사', 'オモダカ'],
  'nemona': ['네모', 'ネモ'],
  // Kieran's KO is 카지 (collides with Paldea bug leader Katy — both
  // are 카지 in Korean Pokémon localization)
  'kieran': ['카지', 'スグリ'],
  'carmine': ['시유', 'ゼイユ'],
  // Paldea E4 (SV): hassel/rika/poppy/larry under E4, geeta is
  // Top Champion above. larry is in Gym Leaders too (dual role).
  'hassel': ['팔자크', 'ハッサク'],
  'rika': ['칠리', 'チリ'],
  'poppy': ['뽀삐', 'ポピー'],
  // Indigo Disk E4 (SV DLC): lacey added; crispin/amarys/drayton
  // pending verification, omitted for now to avoid wrong KO.
  'lacey': ['타로', 'タロ'],

  // === Protagonists ========================================
  'ethan': ['금', 'ヒビキ', 'gold'],
  'kris': ['크리스', 'クリス'],
  'lyra': ['하트', 'コトネ'],
  'brendan': ['호일', 'ユウキ'],
  // May's previous alias '미나' collided with Alola Trial Captain Mina
  'may': ['봄이', 'ハルカ'],
  'lucas': ['광휘', 'コウキ'],
  'dawn': ['빛나', 'ヒカリ'],
  'hilbert': ['투지', 'トウヤ'],
  // Hilda's previous alias '벨' was Bianca's name (collision)
  'hilda': ['투희', 'トウコ'],
  // Nate's previous alias '휴이' was Hugh's name (collision)
  'nate': ['공명', 'キョウヘイ'],
  // Rosa's previous alias '메이' was the Japanese name verbatim
  'rosa': ['명희', 'メイ'],
  'calem': ['칼름', 'カルム'],
  'serena': ['세레나', 'セレナ'],
  'elio': ['영태', 'ヨウ', 'sun'],
  'selene': ['미월', 'ミヅキ', 'moon'],
  'victor': ['빅터', 'マサル'],
  'gloria': ['우리', 'ユウリ'],
  'juliana': ['아오이', 'アオイ'],
  'florian': ['하루토', 'ハルト'],

  // === Rivals ==============================================
  'silver': ['실버', 'シルバー'],
  'wally': ['미루', 'ミツル'],
  'barry': ['용식', 'ジュン'],
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
  // Klara (IoA 라이벌). JA was Shauntal's name (シキミ) by mistake.
  'klara': ['도정', 'クララ'],
  // Avery (Isle of Armor 라이벌). Previously held Allister's
  // Japanese name (オニオン) by mistake.
  'avery': ['세이버리', 'セイボリー'],
  'arven': ['페퍼', 'ペパー'],
  'penny': ['모란', 'ボタン'],
  // PLA / BW2 Subway brothers. Korean direct-translation of
  // ノボリ/クダリ (going up/going down).
  'ingo': ['상행', 'ノボリ'],
  'emmet': ['하행', 'クダリ'],
  'hop': ['호브', 'ホップ'],

  // === Villain organisation bosses ========================
  // Promoted out of 'Other' (user flagged that these all appear
  // in the games and shouldn't be uncategorised). Verified KO
  // names via namu.wiki.
  'maxie': ['마적', 'マツブサ', 'team magma boss'],
  'archie': ['아강', 'アオギリ', 'team aqua boss'],
  'cyrus': ['태홍', 'アカギ', 'team galactic boss'],
  'ghetsis': ['게치스', 'ゲーチス', 'team plasma boss'],
  'colress': ['아크로마', 'アクロマ', 'team plasma scientist'],
  'lysandre': ['플라드리', 'フラダリ', 'team flare boss'],
  'guzma': ['구즈마', 'グズマ', 'team skull boss'],
  'lusamine': ['루자미네', 'ルザミーネ', 'aether president'],
  'rose': ['로즈', 'ローズ', 'macro cosmos chairman'],

  // === NPC class additions — namu.wiki round 3 ============
  // 60 NPC class translations newly added in the round-3 audit.
  // Several share KO names with existing classes due to actual
  // Game Freak localization collisions (officer ↔ policeman both
  // 경찰관; sightseer ↔ tourist both 관광객; scientist ↔ researcher
  // both 연구원). Intentional and left as-is.
  'acetrainersnow': ['엘리트 트레이너', 'エリートトレーナー'],
  'acetrainersnowf': ['엘리트 트레이너', 'エリートトレーナー'],
  'artistf': ['예술가', 'げいじゅつか'],
  'ballguy': ['볼가이', 'ボールガイ'],
  'backpacker': ['백패커', 'バックパッカー'],
  'backpackerf': ['백패커', 'バックパッカー'],
  'bodybuilder': ['보디빌더', 'ボディビルダー'],
  'bodybuilderf': ['보디빌더', 'ボディビルダー'],
  'butler': ['집사', 'しつじ'],
  'cabbie': ['택시 드라이버', 'タクシードライバー'],
  'camper': ['캠퍼', 'キャンプボーイ'],
  'clerk': ['비즈니스맨', 'ビジネスマン'],
  'clerkf': ['OL', 'OL'],
  'clown': ['피에로', 'ピエロ'],
  'collector': ['포켓몬 컬렉터', 'ポケモンコレクター'],
  'cook': ['셰프', 'コック'],
  'cowgirl': ['목장걸', 'ぼくじょうギャル'],
  'crushgirl': ['격투가 아가씨', 'かくとうむすめ'],
  'crushkin': ['격투자매', 'かくとうしまい'],
  'cueball': ['빡빡이', 'ボウズあたま'],
  'cyclistf': ['사이클리스트', 'サイクリスト'],
  'delinquent': ['양아치', 'チンピラ'],
  'delinquentf': ['양아치', 'チンピラ'],
  'delinquentf2': ['양아치', 'チンピラ'],
  'depotagent': ['역무원', 'てつどういん'],
  'doctor': ['의사', 'おいしゃさん'],
  'doctorf': ['의사', 'おいしゃさん'],
  'doubleteam': ['더블팀', 'ダブルチーム'],
  'expert': ['달인', 'たつじん'],
  'firefighter': ['소방관', 'しょうぼうし'],
  'fisher': ['낚시꾼', 'つりびと'],
  'furisodegirl': ['기모노드레스', 'フリソデガール'],
  'gamer': ['갬블러', 'ゲーマー'],
  'garcon': ['가르송', 'ギャルソン'],
  'gardener': ['정원사', 'ガーデナー'],
  'golfer': ['골퍼', 'ゴルファー'],
  'hooligans': ['훌리건', 'フーリガン'],
  'hoopster': ['농구선수', 'バスケットせんしゅ'],
  'infielder': ['야구선수', 'やきゅうせんしゅ'],
  'interviewers': ['인터뷰어', 'インタビュアー'],
  'janitor': ['청소부', 'おそうじスタッフ'],
  'jrtrainer': ['미니트레이너', 'ミニトレーナー'],
  'jrtrainerf': ['미니트레이너', 'ミニトレーナー'],
  'kimonogirl': ['전통무용수', 'おどりこ'],
  'kunoichi': ['쿠노이치', 'くノ一'],
  'kunoichi2': ['쿠노이치', 'くノ一'],
  'madame': ['마담', 'マダム'],
  'nurse': ['간호사', 'かんごし'],
  'nurseryaide': ['보육사', 'ほいくし'],
  // officer / policeman both → 경찰관 (intentional collision)
  'officer': ['경찰관', 'けいさつかん'],
  'officeworker': ['비즈니스맨', 'ビジネスマン'],
  'officeworkerf': ['OL', 'OL'],
  'painter': ['화가', 'えかき'],
  'parasollady': ['파라솔 누나', 'パラソルおねえさん'],
  'picnicker': ['피크닉걸', 'ピクニックガール'],
  'pilot': ['파일럿', 'パイロット'],
  'player': ['축구선수', 'サッカーせんしゅ'],
  'playerf': ['축구선수', 'サッカーせんしゅ'],
  'pokekidf': ['포켓 키드', 'ポケモンキッズ'],
  'pokemonbreeder': ['포켓몬브리더', 'ポケモンブリーダー'],
  'pokemonbreederf': ['포켓몬브리더', 'ポケモンブリーダー'],
  'pokemoncenterlady': ['포켓몬센터 누나', 'ポケモンセンタージョーシ'],
  'pokemonranger': ['포켓몬레인저', 'ポケモンレンジャー'],
  'pokemonrangerf': ['포켓몬레인저', 'ポケモンレンジャー'],
  'postman': ['포스트맨', 'ポストマン'],
  'preschooler': ['보육원아', 'ようちえんじ'],
  'preschoolers': ['보육원아', 'ようちえんじ'],
  // CRITICAL: psychic must map to 초능력자 — this is the Psychic-
  // type NPC trainer class. Previously channeler held this name
  // by mistake (channeler is 기도사 per round-1 audit).
  'psychic': ['초능력자', 'サイキッカー'],
  'psychicf': ['초능력자', 'サイキッカー'],
  'psychicfjp': ['초능력자', 'サイキッカー'],
  'rancher': ['목장아저씨', 'ぼくじょうおじさん'],
  'risingstar': ['호프 트레이너', 'ホープトレーナー'],
  'risingstarf': ['호프 트레이너', 'ホープトレーナー'],
  'rollerskater': ['롤러스케이터', 'ローラースケーター'],
  'rollerskaterf': ['롤러스케이터', 'ローラースケーター'],
  'ruinmaniac': ['유적마니아', 'いせきマニア'],
  'schoolkidf': ['스쿨키드', 'がくしゅうきっず'],
  'scubadiver': ['다이버', 'ダイバー'],
  // sightseer / tourist both → 관광객 (intentional collision)
  'sightseer': ['관광객', 'かんこうきゃく'],
  'sightseerf': ['관광객', 'かんこうきゃく'],
  'tourist': ['관광객', 'かんこうきゃく'],
  'touristf': ['관광객', 'かんこうきゃく'],
  'touristf2': ['관광객', 'かんこうきゃく'],
  'skier': ['스키어', 'スキーヤー'],
  'skytrainer': ['스카이 트레이너', 'スカイトレーナー'],
  'skytrainerf': ['스카이 트레이너', 'スカイトレーナー'],
  'streetthug': ['양아치', 'チンピラ'],
  'surfer': ['파도타기맨', 'なみのりやろう'],
  'swimmerf2': ['수영복 소녀', 'すいえいせんしゅ'],
  'swimmerfjp': ['수영복 소녀', 'すいえいせんしゅ'],
  'swimmerm': ['수영팬티 소년', 'すいえいせんしゅ'],
  'trialguide': ['시련서포터', 'しれんサポーター'],
  'trialguidef': ['시련서포터', 'しれんサポーター'],
  'triathletebiker': ['트라이애슬릿', 'トライアスロン'],
  'triathletebikerf': ['트라이애슬릿', 'トライアスロン'],
  'triathletebikerm': ['트라이애슬릿', 'トライアスロン'],
  'triathleterunner': ['트라이애슬릿', 'トライアスロン'],
  'triathleterunnerf': ['트라이애슬릿', 'トライアスロン'],
  'triathleterunnerm': ['트라이애슬릿', 'トライアスロン'],
  'triathleteswimmer': ['트라이애슬릿', 'トライアスロン'],
  'triathleteswimmerf': ['트라이애슬릿', 'トライアスロン'],
  'triathleteswimmerm': ['트라이애슬릿', 'トライアスロン'],
  'worker2': ['작업원', 'こうじげんば'],
  'youngn': ['반바지 꼬마', 'たんパンこぞう'],

  // === Aether Foundation grunts ===========================
  // User specifically flagged that these were untranslated.
  'aetheremployee': ['에테르재단 직원', 'エーテルざいだんしょくいん', 'aether employee'],
  'aetheremployeef': ['에테르재단 직원', 'エーテルざいだんしょくいん', 'aether employee'],
  'aetherfoundation': ['에테르재단 직원', 'エーテルざいだんしょくいん', 'aether foundation'],
  'aetherfoundation2': ['에테르재단 직원', 'エーテルざいだんしょくいん', 'aether foundation'],
  'aetherfoundationf': ['에테르재단 직원', 'エーテルざいだんしょくいん', 'aether foundation'],

  // === Villain admins / executives ========================
  // namu.wiki verified per-character.
  'mars': ['마스', 'マーズ'],
  'jupiter': ['주피터', 'ジュピター'],
  'saturn': ['새턴', 'サターン'],
  'tabitha': ['호걸', 'ホムラ'],
  'courtney': ['구열', 'カガリ'],
  'archer': ['아폴로', 'アポロ'],
  'ariana': ['아테나', 'アテナ'],
  'petrel': ['람다', 'ラムダ'],
  'proton': ['랜스', 'ランス'],
  'oleana': ['올리브', 'オリーヴ'],
  'wicke': ['비케', 'ビッケ'],
  'mela': ['멜로코', 'メロコ'],
  'ortega': ['오르티가', 'オルティガ'],

  // === Professors =========================================
  // namu.wiki — all KO professor names end in '박사'.
  'oak': ['오박사', 'オーキド博士', 'professor oak'],
  'elm': ['공박사', 'ウツギ博士', 'professor elm'],
  'birch': ['털보박사', 'オダマキ博士', 'professor birch'],
  'rowan': ['마박사', 'ナナカマド博士', 'professor rowan'],
  'juniper': ['주박사', 'アララギ博士', 'professor juniper'],
  'sycamore': ['플라타느박사', 'プラターヌ博士', 'professor sycamore'],
  'magnolia': ['매그놀리아박사', 'マグノリア博士', 'professor magnolia'],
  'burnet': ['버넷박사', 'バーネット博士', 'professor burnet'],
  'sada': ['사다박사', 'サダ博士', 'professor sada'],
  'turo': ['투로박사', 'トウロ博士', 'professor turo'],
  'laventon': ['라벤박사', 'ラベン', 'professor laventon'],
  'laventon2': ['라벤박사', 'ラベン', 'professor laventon'],
  'willow': ['윌로우 박사', 'ウィロー博士', 'professor willow'],

  // === Frontier Brains (Hoenn / Sinnoh) ===================
  'anabel': ['리라', 'リラ', 'salon maiden'],
  'cheryl': ['모미', 'モミ'],
  'argenta': ['카틀레야', 'カトレア'],
  'brandon': ['기선', 'ジンダイ', 'pyramid king'],
  'lucy': ['다슬', 'アザミ', 'pike queen'],

  // === Pokemon Conquest cast ==============================
  // namu.wiki/w/포켓몬+노부나가의_야망
  'nobunaga': ['노부나가', 'ノブナガ'],
  'oichi': ['오이치', 'オイチ'],
  'hanbei': ['한베에', 'カンベエ'],
  'masamune': ['마사무네', 'マサムネ'],
  'ginchiyo': ['긴치요', 'ギンチヨ'],
  'ranmaru': ['란마루', 'ランマル'],

  // === Pokemon GO ========================================
  'blanche': ['블랑쉬', 'ブランシェ'],
  'candela': ['칸델라', 'キャンデラ'],
  'spark': ['스파크', 'スパーク'],
  'arlo': ['알로', 'アルロ'],
  'cliff': ['클리프', 'クリフ'],

  // === Hisui (PLA) cast ===================================
  // namu.wiki/w/Pokémon_LEGENDS_아르세우스 + per-character pages
  'adaman': ['세키', 'セキ'],
  'irida': ['주혜', 'カイ'],
  'volo': ['볼로', 'ヴォロ'],
  'sabi': ['사비', 'サボリ'],
  'diamondclanmember': ['금강단', 'コンゴウだん', 'diamond clan'],
  'pearlclanmember': ['진주단', 'シンジュだん', 'pearl clan'],

  // === Team grunt variants (alt sprite keys) ==============
  'rocket': ['로켓단', 'ロケットだん', 'team rocket'],
  'teamrocket': ['로켓단', 'ロケットだん', 'team rocket'],
  'teamrocketgruntm': ['로켓단 조무래기', 'ロケットだんしたっぱ', 'rocket grunt'],
  'teamrocketgruntf': ['로켓단 조무래기', 'ロケットだんしたっぱ', 'rocket grunt'],
  'rainbowrocketgrunt': ['레인보우로켓단 조무래기', 'レインボーロケットだんいん', 'rainbow rocket'],
  'rainbowrocketgruntf': ['레인보우로켓단 조무래기', 'レインボーロケットだんいん', 'rainbow rocket'],
  'teammagmagruntm': ['마그마단 조무래기', 'マグマだんしたっぱ', 'magma grunt'],
  'teammagmagruntf': ['마그마단 조무래기', 'マグマだんしたっぱ', 'magma grunt'],
  'teamaquagruntm': ['아쿠아단 조무래기', 'アクアだんしたっぱ', 'aqua grunt'],
  'teamaquagruntf': ['아쿠아단 조무래기', 'アクアだんしたっぱ', 'aqua grunt'],
  'magmasuit': ['마그마슈트', 'マグマスーツ', 'magma suit'],
  'yellgrunt': ['옐단 조무래기', 'エールだんいん', 'yell grunt'],
  'yellgruntf': ['옐단 조무래기', 'エールだんいん', 'yell grunt'],
  'stargrunt': ['스타단 조무래기', 'スターだんいん', 'star grunt'],
  'stargruntf': ['스타단 조무래기', 'スターだんいん', 'star grunt'],

  // === Other notable named characters =====================
  'ash': ['한지우', 'サトシ', 'anime protagonist'],
  'liko': ['리코', 'リコ', 'horizons protagonist'],
  'toddsnap': ['찰칵이', 'トオル', 'pokemon snap'],
  'toddsnap2': ['찰칵이', 'トオル', 'pokemon snap'],
  'leaf': ['리프', 'リーフ', 'frlg female'],
  'yellow': ['옐로', 'イエロー', 'special manga'],
  'mom': ['어머니', 'おかあさん', 'mom'],
  'alain': ['알랭', 'アラン', 'xy anime'],
  'samsonoak': ['송호 오', 'ナリヤ・オーキド', 'samson oak'],
  'sonia': ['소니아', 'ソニア', 'galar assistant'],
  'kahili': ['카일리', 'カヒリ', 'alola e4'],
  'eusine': ['유시안', 'ミナキ', 'suicune chaser'],
  'dexio': ['덱시오', 'デクシオ', 'sycamore assistant'],
  'fennel': ['주리', 'マコモ', 'dream world researcher'],
  'brycenman': ['담죽맨', 'ハチクマン', 'pokestar movie'],
  'az': ['AZ', 'AZ', 'kalos ancient king'],
  // peony exists earlier in Champions block — skipping duplicate
  'peonia': ['니아', 'シャクヤ', 'peony daughter'],
  'ryuki': ['용규', 'ドラゴ', 'usum wrestler'],
  'drayton': ['타로', 'タロ', 'indigo disk e4'],

  // === Kanto Gym Leaders ==================================
  'brock': ['웅', 'タケシ'],
  'misty': ['이슬', 'カスミ'],
  'ltsurge': ['마티스', 'マチス', 'lt surge', 'surge'],
  'erika': ['민화', 'エリカ'],
  'koga': ['독수', 'キョウ'],
  'sabrina': ['초련', 'ナツメ'],
  'blaine': ['강연', 'カツラ'],
  'giovanni': ['비주기', 'サカキ'],
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
  // Striaton brothers (BW Gym Leaders). Verified via namu.wiki.
  'cilan': ['덴트', 'デント'],
  'chili': ['팟', 'ポッド'],
  'cress': ['콘', 'コーン'],
  'lenora': ['아로에', 'アロエ'],
  'burgh': ['아티', 'アーティ'],
  'elesa': ['카밋트레', 'カミツレ'],
  'clay': ['야콘', 'ヤーコン'],
  'skyla': ['후우로', 'フウロ'],
  'brycen': ['하치쿠', 'ハチク'],
  'drayden': ['샤가', 'シャガ'],
  'roxie': ['홈이카', 'ホミカ'],
  'marlon': ['시즈', 'シズイ'],

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
  'acerola': ['아세로라', 'アセロラ'],
  'mina': ['미나', 'ミナ'],
  'hala': ['하라', 'ハラ'],
  // Olivia (알로라 Kahuna). Previously held Lillie's Korean name
  // (리리이) and Lillie's Japanese name (リーリエ) by mistake.
  'olivia': ['라이치', 'ライチ'],
  'nanu': ['쿠치나시', 'クチナシ'],
  'hapu': ['하푸', 'ハプウ'],

  // === Galar Gym Leaders ==================================
  'milo': ['야로', 'ヤロー'],
  'nessa': ['루리나', 'ルリナ'],
  'kabu': ['순무', 'カブ'],
  'bea': ['채두', 'サイトウ'],
  'allister': ['어니언', 'オニオン'],
  'opal': ['포플라', 'ポプラ'],
  'gordie': ['마쿠와', 'マクワ'],
  'melony': ['멜론', 'メロン'],
  'piers': ['네즈', 'ネズ'],
  'raihan': ['금랑', 'キバナ'],

  // === Paldea Gym Leaders =================================
  'katy': ['카지', 'カエデ'],
  'brassius': ['콜사', 'コルサ'],
  'iono': ['모야모', 'ナンジャモ'],
  // kofu's JA is ハイダイ (sea kelp). ハッサク is Hassel.
  'kofu': ['곤포', 'ハイダイ'],
  'larry': ['아오키', 'アオキ'],
  'ryme': ['라임', 'ライム'],
  'tulip': ['리파', 'リップ'],
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
  // Molayne (알로라 E4). KO was a Pokémon name (마타도가스 = Weezing).
  'molayne': ['멀레인', 'マーレイン'],

  // === Trainer classes (NPC) ==============================
  // NPC trainer class names — verified via namu.wiki / Korean
  // Pokemon Wiki. The previous mapping was largely guessed and
  // had many misses (검은띠 ≠ 태권왕, 초능력자 ≠ 기도사 — the
  // former is Psychic and the user would expect Psychic when
  // searching it, so channeler must NOT use 초능력자).
  'acetrainer': ['엘리트 트레이너', 'エリートトレーナー', 'ace trainer'],
  'acetrainercouple': ['엘리트 커플', 'エリートカップル'],
  'acetrainerf': ['엘리트 트레이너', 'エリートトレーナー', 'ace trainer'],
  'aromalady': ['아로마 아가씨', 'アロマなおねえさん', 'aroma lady'],
  'artist': ['예술가', 'げいじゅつか'],
  'baker': ['파티시에', 'パティシエ'],
  'battlegirl': ['배틀걸', 'バトルガール', 'battle girl'],
  // beauty (びじん) official KO is 비키니 아가씨; previous 아가씨
  // was a partial transliteration. 아가씨 alone belongs to lady.
  'beauty': ['비키니 아가씨', 'びじん'],
  'bellhop': ['벨보이', 'ベルボーイ'],
  'biker': ['폭주족', 'バイカー'],
  'bird-keeper': ['새 조련사', 'とりつかい', 'bird keeper'],
  'birdkeeper': ['새 조련사', 'とりつかい', 'bird keeper'],
  'blackbelt': ['태권왕', 'からておう', 'black belt'],
  'boarder': ['스노보더', 'スノーボーダー'],
  'breeder': ['포켓몬브리더', 'ポケモンブリーダー'],
  'breederf': ['포켓몬브리더', 'ポケモンブリーダー'],
  'bugcatcher': ['벌레잡이 소년', 'むしとりしょうねん', 'bug catcher'],
  'bugmaniac': ['벌레마니아', 'むしとりマニア', 'bug maniac'],
  // burglar's official KO is a famously long phrase verbatim
  'burglar': ['불난집 전문털이범', 'どろぼう'],
  'cameraman': ['카메라맨', 'カメラマン'],
  // CRITICAL: channeler is 기도사, NOT 초능력자 — 초능력자 is the
  // Psychic-type class (likely 'psychic' key elsewhere). Mapping
  // channeler to 초능력자 would surface Psychic-class sprites for
  // a Korean user searching for 초능력자, which is wrong.
  'channeler': ['기도사', 'チャネラー'],
  'cheerleader': ['치어리더', 'チアリーダー'],
  'chef': ['셰프', 'シェフ'],
  'chic': ['멋쟁이', 'おしゃれ'],
  // cooltrainer and acetrainer collapse to the same Korean class
  'cooltrainer': ['엘리트 트레이너', 'エリートトレーナー', 'cool trainer'],
  'cyclist': ['사이클리스트', 'サイクリスト'],
  'dancer': ['댄서', 'ダンサー'],
  'dragontamer': ['드래곤 조련사', 'ドラゴンつかい', 'dragon tamer'],
  'engineer': ['엔지니어', 'エンジニア'],
  // expert is 달인 (PWT veteran-elder class), distinct from
  // acetrainer (엘리트 트레이너). JA original is たつじん.
  'expertm': ['달인', 'たつじん'],
  'expertf': ['달인', 'たつじん'],
  'fairy': ['요정', '妖精'],
  'fairytalegirl': ['메르헨 소녀', 'フェアリーガール'],
  'firebreather': ['불놀이꾼', 'ひぶき'],
  'fisherman': ['낚시꾼', 'つりびと'],
  'gambler': ['갬블러', 'ばくとし'],
  'gameboy': ['게이머', 'ゲームボーイ'],
  'gentleman': ['신사', 'ジェントルマン'],
  'guitarist': ['기타리스트', 'ギタリスト'],
  'hexmaniac': ['오컬트마니아', 'オカルトマニア', 'hex maniac'],
  'hiker': ['등산가', 'ヤマおとこ'],
  'idol': ['아이돌', 'アイドル'],
  'jogger': ['조거', 'ジョギング'],
  'juggler': ['저글러', 'ジャグラー'],
  'kindler': ['불놀이꾼', 'ひぶき', 'kindler'],
  // lady (おじょうさま) is 아가씨. (Previous 아기씨 was a typo,
  // and beauty was the colliding entry — now disambiguated:
  // beauty → 비키니 아가씨, lady → 아가씨.)
  'lady': ['아가씨', 'おじょうさま'],
  'lass': ['미니스커트', 'ミニスカート'],
  'maid': ['메이드', 'メイド'],
  'medium': ['무당', 'おばあさん'],
  'monk': ['수도승', 'おとうさん'],
  'musician': ['뮤지션', 'おんがくか'],
  'ninjaboy': ['닌자놀이', 'ニンジャごっこ'],
  'oldcouple': ['노부부', 'ろうふうふ', 'old couple'],
  'parasolady': ['파라솔 누나', 'パラソルおねえさん'],
  'picknicker': ['피크닉걸', 'ピクニックガール'],
  'pokefan': ['포켓팬', 'ポケファン'],
  'pokefanf': ['포켓팬', 'ポケファン'],
  'pokekid': ['포켓 키드', 'ポケモンキッズ'],
  'pokemaniac': ['포켓몬매니아', 'ポケモンマニア', 'poke maniac'],
  'pokemanic': ['포켓몬매니아', 'ポケモンマニア'],
  'policeman': ['경찰관', 'けいさつかん'],
  'preschoolerm': ['보육원아', 'ようちえんじ'],
  'preschoolerf': ['보육원아', 'ようちえんじ'],
  'pikabro': ['피카브로', 'ピカブロ'],
  'pikachu-libre': ['피카리브레', 'ピカリブレ', 'pikachu libre'],
  'punkgirl': ['펑크걸', 'パンクガール', 'punk girl'],
  'punkguy': ['펑크가이', 'パンクボーイ', 'punk guy'],
  'reporter': ['리포터', 'レポーター'],
  'researcher': ['연구원', 'けんきゅうしゃ'],
  'richboy': ['부잣집 도련님', 'ぼっちゃま', 'rich boy'],
  'roughneck': ['빡빡이', 'スキンヘッズ'],
  // KO villain-team grunt classes all follow 'X단 조무래기'. The
  // previous mapping used the bare team name. Also: Sinnoh team
  // ギンガ団 is 갤럭시단 in KO (NOT 갤럭틱단 which was a fan
  // romanization; 은하단 is the unrelated benevolent PLA team).
  'rocketgrunt': ['로켓단 조무래기', 'ロケットだんいん', 'rocket grunt'],
  'rocketgruntf': ['로켓단 조무래기', 'ロケットだんいん', 'rocket grunt'],
  'magmagrunt': ['마그마단 조무래기', 'マグマだんいん', 'magma grunt'],
  'magmagruntf': ['마그마단 조무래기', 'マグマだんいん', 'magma grunt'],
  'aquagrunt': ['아쿠아단 조무래기', 'アクアだんいん', 'aqua grunt'],
  'aquagruntf': ['아쿠아단 조무래기', 'アクアだんいん', 'aqua grunt'],
  'galacticgrunt': ['갤럭시단 조무래기', 'ギンガだんいん', 'galactic grunt'],
  'galacticgruntf': ['갤럭시단 조무래기', 'ギンガだんいん', 'galactic grunt'],
  'plasmagrunt': ['플라스마단 조무래기', 'プラズマだんいん', 'plasma grunt'],
  'plasmagruntf': ['플라스마단 조무래기', 'プラズマだんいん', 'plasma grunt'],
  'flaregrunt': ['플레어단 조무래기', 'フレアだんいん', 'flare grunt'],
  'flaregruntf': ['플레어단 조무래기', 'フレアだんいん', 'flare grunt'],
  'skullgrunt': ['스컬단 조무래기', 'スカルだんいん', 'skull grunt'],
  'skullgruntf': ['스컬단 조무래기', 'スカルだんいん', 'skull grunt'],
  'machogrunt': ['마초 브로', 'マッチョブロ', 'macho bro'],
  'rangerm': ['포켓몬레인저', 'ポケモンレンジャー'],
  'rangerf': ['포켓몬레인저', 'ポケモンレンジャー'],
  'rocker': ['로커', 'ロッカー'],
  'sage': ['수행자', 'せんにん'],
  'sailor': ['선원', 'セーラー'],
  'schoolboy': ['스쿨보이', 'スクールボーイ'],
  'schoolgirl': ['스쿨걸', 'スクールガール'],
  'schoolkid': ['스쿨키드', 'がくしゅうきっず', 'school kid'],
  'scientist': ['연구원', 'かがくしゃ'],
  'scientistf': ['연구원', 'かがくしゃ'],
  'sisandbro': ['남매', 'きょうだい'],
  'skierm': ['스키어', 'スキーヤー'],
  'skierf': ['스키어', 'スキーヤー'],
  'skyer': ['스카이 트레이너', 'スカイトレーナー'],
  'sr-and-jr': ['시니어와 주니어', 'おじいさんとまご'],
  'srandjr': ['시니어와 주니어', 'おじいさんとまご'],
  'striker': ['축구선수', 'ストライカー', 'soccer player'],
  // JA was wrong (ものまねむすめ is the imitation-girl class, a
  // different sprite). Correct JA for supernerd is りけいのおとこ.
  'supernerd': ['괴짜 연구원', 'りけいのおとこ', 'super nerd'],
  'swimmer': ['수영팬티 소년', 'すいえいせんしゅ', 'swimmer'],
  'swimmerf': ['수영복 소녀', 'すいえいせんしゅ', 'swimmer'],
  'tamer': ['용 사용자', 'ドラゴンつかい'],
  'teacher': ['선생님', 'せんせい'],
  'triathlete': ['트라이애슬릿', 'トライアスロン'],
  'tuber': ['튜브보이', 'うきわっこ'],
  'tuberf': ['튜브보이', 'うきわっこ'],
  'twins': ['쌍둥이', 'ふたごちゃん'],
  'veteran': ['베테랑 트레이너', 'ベテラン'],
  'veteranf': ['베테랑 트레이너', 'ベテラン'],
  'waiter': ['웨이터', 'ウェイター'],
  'waitress': ['웨이트리스', 'ウェイトレス'],
  'worker': ['작업원', 'こうじげんば'],
  'workerice': ['작업원', 'こうじげんば'],
  'workerf': ['작업원', 'こうじげんば'],
  'youngster': ['반바지 꼬마', 'たんパンこぞう'],
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
  villainBoss,
  professor,
  npc,
  other;
}

/// Stems classified as Champions across the main-line games.
/// Mirrors the 'Champions' block at the top of [trainerAliases].
/// Many of these stems ALSO appear in other category sets — see
/// [trainerCategoriesOf] for the multi-membership rule (a single
/// character can be Champion AND Rival, Champion AND Gym Leader,
/// etc., and shows up under every applicable tab).
const Set<String> trainerChampionStems = {
  'red', 'blue', 'lance', 'steven', 'wallace', 'cynthia',
  'alder', 'iris', 'diantha', 'kukui', 'hau', 'leon',
  'mustard', 'peony', 'geeta', 'nemona', 'kieran', 'carmine',
  'blue-leader',
};

/// Stems classified as Gym Leaders. Includes Alola Trial Captains
/// and Kahunas under the same bucket — game-mechanic cousins, and
/// adding a 7th tab just for one region is awkward.
const Set<String> trainerGymLeaderStems = {
  // Kanto
  'brock', 'misty', 'ltsurge', 'erika', 'koga', 'sabrina',
  'blaine', 'giovanni', 'janine',
  // Johto
  'falkner', 'bugsy', 'whitney', 'morty', 'chuck', 'jasmine',
  'pryce', 'clair',
  // Hoenn (wallace was Sootopolis leader in RSE before Emerald
  // promoted him to Champion; juan replaced him in Emerald)
  'roxanne', 'brawly', 'wattson', 'flannery', 'norman',
  'winona', 'tate', 'liza', 'juan', 'wallace',
  // Sinnoh
  'roark', 'gardenia', 'maylene', 'crasher_wake', 'crasherwake',
  'fantina', 'byron', 'candice', 'volkner',
  // Unova (iris was Opelucid leader in BW2 before BW had her
  // as Champion; both roles applicable depending on the game)
  'cilan', 'chili', 'cress', 'lenora', 'burgh', 'elesa',
  'clay', 'skyla', 'brycen', 'drayden', 'roxie', 'marlon',
  'iris',
  // Kalos
  'viola', 'grant', 'korrina', 'ramos', 'clemont', 'valerie',
  'olympia', 'wulfric',
  // Galar
  'milo', 'nessa', 'kabu', 'bea', 'allister', 'opal',
  'gordie', 'melony', 'piers', 'raihan',
  // Paldea
  'katy', 'brassius', 'iono', 'kofu', 'larry', 'ryme',
  'tulip', 'grusha',
  // Alola Trial Captains / Kahunas
  'ilima', 'lana', 'kiawe', 'mallow', 'sophocles', 'acerola',
  'mina', 'hala', 'olivia', 'nanu', 'hapu',
};

/// Stems classified as Elite Four members. Some of these are
/// also in other sets — koga is a Kanto Gym Leader who became
/// a Johto E4 member; acerola/olivia/hala are Alola Trial
/// Captains / Kahunas who also became E4 in USUM / SM.
const Set<String> trainerEliteFourStems = {
  // Kanto (gen 1)
  'lorelei', 'bruno', 'agatha',
  // Johto (gen 2 — koga moved from Kanto Gym Leader to E4,
  // bruno carried over from Kanto)
  'will', 'karen', 'koga',
  // Hoenn
  'sidney', 'phoebe', 'glacia', 'drake',
  // Sinnoh
  'aaron', 'bertha', 'flint', 'lucian',
  // Unova
  'shauntal', 'grimsley', 'caitlin', 'marshal',
  // Kalos
  'malva', 'siebold', 'wikstrom', 'drasna',
  // Alola (USUM): molayne replaced hala, and several Trial
  // Captains / Kahunas show up here too
  'molayne', 'acerola', 'olivia', 'hala', 'kahili',
  // Galar's Champion Cup doesn't have a traditional E4 lineup.
  // Paldea's path-of-titans replaces gyms with an E4-equivalent
  // (rika, poppy, larry, hassel, geeta as top) — geeta lands
  // in Champions, the rest here. Some overlap acceptable.
  'rika', 'poppy', 'hassel',
};

/// Stems classified as protagonists or rivals — they share a
/// tab because both fill the 'player surrogate / friendly foil'
/// role and players tend to recognise them together. Many
/// rivals later become Champions (blue/hau/nemona) and are in
/// both sets.
const Set<String> trainerProtagonistRivalStems = {
  // Protagonists
  'ethan', 'kris', 'lyra', 'brendan', 'may', 'lucas', 'dawn',
  'hilbert', 'hilda', 'nate', 'rosa', 'calem', 'serena',
  'elio', 'selene', 'victor', 'gloria', 'juliana', 'florian',
  // Rivals
  'silver', 'wally', 'barry', 'cheren', 'bianca', 'n', 'hugh',
  'shauna', 'tierno', 'trevor', 'gladion', 'lillie', 'marnie',
  'bede', 'klara', 'avery', 'arven', 'penny',
  // Rivals who also became Champions — kept in both sets so
  // they appear under both tabs. The user's example was
  // blue/시게루 (the prototypical rival-turned-Champion).
  'blue', 'hau', 'nemona',
  // SwSh: hop is the main rival; included even though we may
  // not have a verified alias entry yet
  'hop',
};

/// Villain organisation bosses + admins + executive sprites.
/// User direction: anyone clearly tied to a villain team in any
/// main-line game lands here, including team admins/commanders.
const Set<String> trainerVillainBossStems = {
  // Main bosses
  'maxie', 'archie', 'cyrus', 'ghetsis', 'lysandre', 'guzma',
  'lusamine', 'rose', 'colress',
  // Sinnoh Galactic commanders
  'mars', 'jupiter', 'saturn', 'charon',
  // Hoenn Magma admins
  'tabitha', 'courtney', 'mable',
  // Hoenn Aqua admins
  'shelly', 'matt',
  // Johto Rocket executives
  'archer', 'ariana', 'proton', 'petrel',
  // Alola Aether / Skull cast
  'plumeria', 'faba',
  // SwSh Macro Cosmos
  'oleana',
  // Galar GO Rocket leaders (mobile)
  'cliff', 'arlo', 'sierra',
  // Paldea Team Star bosses
  'mela', 'giacomo', 'atticus', 'ortega', 'eri',
  // Hisui ultimate antagonist
  'volo',
  // Generic Rocket sprite labels
  'rocketexecutive', 'rocketexecutivef', 'rocket', 'teamrocket',
};

/// Pokemon Professors across all regions. User direction:
/// separate from villain bosses, given their own browseable tab.
const Set<String> trainerProfessorStems = {
  'oak', 'elm', 'birch', 'rowan', 'juniper', 'sycamore',
  'magnolia', 'burnet', 'sada', 'turo',
  'laventon', 'laventon2',
  'cedricjuniper', 'fennel', 'jacq',
  // Pokemon GO professor
  'willow',
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
  'aquasuit',
  'aetheremployee', 'aetheremployeef',
  'aetherfoundation', 'aetherfoundation2', 'aetherfoundationf',
  // round-3 NPC additions
  'acetrainersnow', 'acetrainersnowf', 'artistf', 'ballguy',
  'backpacker', 'backpackerf', 'bodybuilder', 'bodybuilderf',
  'butler', 'cabbie', 'camper', 'clerk', 'clerkf', 'clown',
  'collector', 'cook', 'cowgirl', 'crushgirl', 'crushkin',
  'cueball', 'cyclistf', 'delinquent', 'delinquentf',
  'delinquentf2', 'depotagent', 'doctor', 'doctorf',
  'doubleteam', 'expert', 'firefighter', 'fisher',
  'furisodegirl', 'gamer', 'garcon', 'gardener', 'golfer',
  'hooligans', 'hoopster', 'infielder', 'interviewers',
  'janitor', 'jrtrainer', 'jrtrainerf', 'kimonogirl',
  'kunoichi', 'kunoichi2', 'madame', 'nurse', 'nurseryaide',
  'officer', 'officeworker', 'officeworkerf', 'painter',
  'parasollady', 'picnicker', 'pilot', 'player', 'playerf',
  'pokekidf', 'pokemonbreeder', 'pokemonbreederf',
  'pokemoncenterlady', 'pokemonranger', 'pokemonrangerf',
  'postman', 'preschooler', 'preschoolers',
  'psychic', 'psychicf', 'psychicfjp',
  'rancher', 'risingstar', 'risingstarf', 'rollerskater',
  'rollerskaterf', 'ruinmaniac', 'schoolkidf', 'scubadiver',
  'sightseer', 'sightseerf', 'tourist', 'touristf', 'touristf2',
  'skier', 'skytrainer', 'skytrainerf', 'streetthug', 'surfer',
  'swimmerf2', 'swimmerfjp', 'swimmerm',
  'trialguide', 'trialguidef',
  'triathletebiker', 'triathletebikerf', 'triathletebikerm',
  'triathleterunner', 'triathleterunnerf', 'triathleterunnerm',
  'triathleteswimmer', 'triathleteswimmerf', 'triathleteswimmerm',
  'worker2', 'youngn',
  'rocker', 'sage', 'sailor', 'schoolboy', 'schoolgirl', 'schoolkid',
  'scientist', 'scientistf', 'sisandbro', 'skierm', 'skierf',
  'skyer', 'sr-and-jr', 'srandjr', 'striker', 'supernerd',
  'swimmer', 'swimmerf', 'tamer', 'teacher', 'triathlete',
  'tuber', 'tuberf', 'twins', 'veteran', 'veteranf', 'waiter',
  'waitress', 'worker', 'workerice', 'workerf', 'youngster',
  'youngcouple',
};

/// Generation bucket for the secondary picker filter. Derived
/// from the trailing suffix on the asset key — Showdown tags
/// every per-game variant (e.g. 'red-gen1rb' for the FRLG remake
/// of the gen-1 Red sprite). Plain keys with no suffix are the
/// canonical 'latest' sprite for that character/class; we file
/// those under [other] rather than guessing.
enum TrainerGeneration {
  all,
  gen1,
  gen2,
  gen3,
  gen4,
  gen5,
  gen6,
  gen7,
  gen8,
  gen9,
  masters,
  other;
}

/// Map raw suffix → generation bucket. Compiled from the actual
/// suffix histogram of assets/trainers/ — anything not listed
/// here lands in [TrainerGeneration.other], which keeps the
/// 'other' tab as a useful catch-all for spinoffs (Conquest,
/// Unite, Festival Plaza, Pokéstar, anime/isekai variants).
const Map<String, TrainerGeneration> _suffixToGen = {
  // Gen 1
  'gen1': TrainerGeneration.gen1,
  'gen1rb': TrainerGeneration.gen1,
  'lgpe': TrainerGeneration.gen1,
  // Gen 2
  'gen2': TrainerGeneration.gen2,
  'gen2jp': TrainerGeneration.gen2,
  // Gen 3
  'gen3': TrainerGeneration.gen3,
  'gen3rs': TrainerGeneration.gen3,
  'gen3jp': TrainerGeneration.gen3,
  'rs': TrainerGeneration.gen3,
  'rse': TrainerGeneration.gen3,
  // Gen 4
  'gen4': TrainerGeneration.gen4,
  'gen4dp': TrainerGeneration.gen4,
  'gen4pt': TrainerGeneration.gen4,
  'bdsp': TrainerGeneration.gen4,
  'pla': TrainerGeneration.gen4,
  // Gen 5
  'gen5': TrainerGeneration.gen5,
  'gen5bw': TrainerGeneration.gen5,
  'gen5bw2': TrainerGeneration.gen5,
  'bw': TrainerGeneration.gen5,
  'bw2': TrainerGeneration.gen5,
  // Gen 6
  'gen6': TrainerGeneration.gen6,
  'gen6xy': TrainerGeneration.gen6,
  'gen6oras': TrainerGeneration.gen6,
  'xy': TrainerGeneration.gen6,
  'oras': TrainerGeneration.gen6,
  // Gen 7
  'gen7': TrainerGeneration.gen7,
  'sm': TrainerGeneration.gen7,
  'usum': TrainerGeneration.gen7,
  // Gen 8
  'gen8': TrainerGeneration.gen8,
  'swsh': TrainerGeneration.gen8,
  // Gen 9
  'gen9': TrainerGeneration.gen9,
  'sv': TrainerGeneration.gen9,
  // Pokémon Masters EX
  'masters': TrainerGeneration.masters,
  'masters2': TrainerGeneration.masters,
  'masters3': TrainerGeneration.masters,
  'masters4': TrainerGeneration.masters,
};

/// Classify a sprite key into a generation bucket using the
/// trailing suffix after the last hyphen. Keys without a hyphen
/// (plain stem files like 'red.png') and keys whose suffix isn't
/// in [_suffixToGen] land in [TrainerGeneration.other].
TrainerGeneration trainerGenerationOf(String key) {
  final dash = key.lastIndexOf('-');
  if (dash < 0) return TrainerGeneration.other;
  final suffix = key.substring(dash + 1).toLowerCase();
  return _suffixToGen[suffix] ?? TrainerGeneration.other;
}

/// Classify a sprite key into every picker tab it belongs to.
/// Uses the stem (suffix-stripped key) so e.g. 'cynthia-masters3'
/// and 'cynthia-gen4' both pick up [TrainerCategory.champion].
///
/// A single character can live in multiple categories — blue is
/// a Rival who became Champion (so {champion, protagonistRival});
/// koga is a Kanto Gym Leader and Johto E4 (so {gymLeader,
/// eliteFour}); acerola is an Alola Trial Captain and a USUM E4.
/// The picker treats 'show category X' as 'show every key whose
/// classification set contains X', so multi-category characters
/// appear under every applicable tab without being awkwardly
/// pinned to one.
///
/// Keys with no classification fall back to [TrainerCategory.other]
/// — the 'All' tab still shows everything either way.
Set<TrainerCategory> trainerCategoriesOf(String key) {
  final stem = trainerKeyStem(key);
  final cats = <TrainerCategory>{};
  if (trainerChampionStems.contains(stem) ||
      trainerChampionStems.contains(key)) {
    cats.add(TrainerCategory.champion);
  }
  if (trainerGymLeaderStems.contains(stem) ||
      trainerGymLeaderStems.contains(key)) {
    cats.add(TrainerCategory.gymLeader);
  }
  if (trainerEliteFourStems.contains(stem) ||
      trainerEliteFourStems.contains(key)) {
    cats.add(TrainerCategory.eliteFour);
  }
  if (trainerProtagonistRivalStems.contains(stem) ||
      trainerProtagonistRivalStems.contains(key)) {
    cats.add(TrainerCategory.protagonistRival);
  }
  if (trainerVillainBossStems.contains(stem) ||
      trainerVillainBossStems.contains(key)) {
    cats.add(TrainerCategory.villainBoss);
  }
  if (trainerProfessorStems.contains(stem) ||
      trainerProfessorStems.contains(key)) {
    cats.add(TrainerCategory.professor);
  }
  if (trainerNpcClassStems.contains(stem) ||
      trainerNpcClassStems.contains(key)) {
    cats.add(TrainerCategory.npc);
  }
  if (cats.isEmpty) cats.add(TrainerCategory.other);
  return cats;
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

/// Display-friendly name for [key] — used as the label under
/// each sprite tile in the picker grid. By alias-map convention
/// the first entry is the Korean form, so this returns it as-is
/// (preserves casing / spacing, unlike [trainerSearchCorpus]).
/// Falls back to the raw stem when no alias is registered.
String trainerDisplayName(String key) {
  final stem = trainerKeyStem(key);
  final aliases = trainerAliases[key] ?? trainerAliases[stem];
  if (aliases != null && aliases.isNotEmpty) return aliases.first;
  return stem;
}

/// Group sprite keys by their stem. Used by the two-level picker:
/// top level shows one tile per group (one per character or NPC
/// class), tap drills into a sub-dialog that lists every per-game
/// variant of that group.
Map<String, List<String>> groupTrainerKeysByStem(List<String> keys) {
  final groups = <String, List<String>>{};
  for (final k in keys) {
    final stem = trainerKeyStem(k);
    groups.putIfAbsent(stem, () => []).add(k);
  }
  // Sort each group: bare stem first (canonical sprite), then by
  // generation/suffix alphabetical. Makes the sub-dialog's first
  // tile the 'default' variant.
  for (final entry in groups.entries) {
    entry.value.sort((a, b) {
      if (a == entry.key && b != entry.key) return -1;
      if (b == entry.key && a != entry.key) return 1;
      return a.compareTo(b);
    });
  }
  return groups;
}

/// Pick the sprite key that should represent a group on the
/// top-level picker tile. Prefers the bare stem (canonical
/// sprite, no -genN suffix) when available; otherwise falls
/// back to the alphabetically-first variant.
String trainerGroupRepresentative(String stem, List<String> variants) {
  if (variants.contains(stem)) return stem;
  return variants.first;
}

/// Extract the variant tag suffix from a key — e.g.
/// 'red-gen1rb' → 'gen1rb', 'cynthia-masters3' → 'masters3'.
/// Returns null for bare-stem keys (canonical sprite).
String? trainerVariantTag(String key, String stem) {
  if (key == stem) return null;
  if (key.length <= stem.length + 1) return null;
  return key.substring(stem.length + 1);
}
