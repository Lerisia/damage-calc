// Random scenario generator → JSON. Drives @smogon/calc (Showdown's
// damage calc) and emits the 16-roll damage spread per scenario so
// a Dart-side comparator can replay it against our calc.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';

const gen = Generations.get(9);
// Avoid species with situational abilities that boost stats — they
// often differ between @smogon/calc (which requires explicit
// `boostedStat`) and ours (auto-detects), or apply Sand/Sun powerups
// asymmetrically (Sand Stream / Drought) producing large diffs that
// aren't real calc bugs.
const SPECIES = [
  'Kangaskhan','Garchomp','Skarmory','Snorlax','Blissey',
  'Gholdengo','Dragapult','Sinistcha','Annihilape',
  'Hatterene','Corviknight','Hariyama','Volcarona',
  'Clodsire','Garganacl','Sylveon',
  // Wider ability coverage. Avoid Paradox (Quark Drive / Protosynthesis)
  // because @smogon/calc treats those as inactive unless an explicit
  // `boostedStat` is supplied — our calc auto-detects, so we'd diverge
  // on every Paradox scenario. Goodra-Hisui name doesn't round-trip
  // through our pokedex either, so dropped.
  'Bronzong','Araquanid','Dragonite','Vaporeon','Gastrodon',
  'Gengar','Toxapex','Ogerpon',
];
// Stick to moves with deterministic damage formulas (no Last Resort
// which requires prior moves used, no Sucker Punch which requires
// the target be selecting an attack, no Counter etc.).
const MOVES = [
  'Body Press','Earthquake','Close Combat','Knock Off',
  'Ice Spinner','U-turn','Flamethrower','Surf',
  'Psychic','Shadow Ball','Moonblast','Dragon Pulse','Thunderbolt',
  'Iron Head','Play Rough','Crunch','Stone Edge','Brave Bird',
  'Outrage',
  // Multi-hit moves left out of the single-roll fuzz: @smogon/calc
  // returns [N hits][16 rolls] which doesn't fit the same 16-roll
  // comparison shape. Verified separately in tools/multihit if
  // needed: Bullet Seed, Triple Axel, Tachyon Cutter, Population
  // Bomb, Icicle Spear, Rock Blast, etc.
  'Hyper Voice','Aura Sphere','Earth Power','Fire Blast',
  // Status-aware (Facade ×2 on any status, Hex ×2 vs statused),
  // Speed-aware (Gyro Ball — TR doesn't change speed but pairs commonly),
  // weight-aware Body Press is already above.
  'Facade','Hex','Gyro Ball','Electro Ball',
  // Variable-BP/type/category: foul-play swaps Atk -> target's Atk;
  // weather-ball changes type+BP by weather; acrobatics doubles
  // without item; tera-blast picks category from higher of Atk/SpA
  // when Tera'd; photon-geyser picks category from higher of
  // Atk/SpA always; hidden-power's type is determined by IVs (we
  // pin it to Normal-defaults so both calcs agree).
  'Foul Play','Weather Ball','Acrobatics','Tera Blast',
  'Photon Geyser',
  // % HP scaling moves omitted from fuzz: @smogon/calc uses
  //   floor(N * curHP / maxHP)
  // while our calc uses
  //   floor(N * hpPercent / 100)
  // Whenever maxHP isn't a multiple of 100, these can diverge by 1
  // BP. Water Spout / Eruption / Dragon Energy / Hard Press /
  // Crush Grip / Wring Out all fall under this. Not a calc bug —
  // an int-percent precision loss we live with.
  // Always-crit (we already verified Storm Throw / Frost Breath
  // via the alwaysCrit auto-toggle path)
  'Frost Breath','Storm Throw',
  // Priority + crit interaction
  'Sacred Sword','Drain Punch','Liquidation','Bug Buzz',
];
const ITEMS = [
  '','Choice Band','Choice Specs','Choice Scarf','Life Orb',
  'Leftovers','Heavy-Duty Boots','Sitrus Berry','Focus Sash',
  'Silk Scarf','Mystic Water','Charcoal','Miracle Seed',
  'Magnet','Sharp Beak','Wise Glasses','Muscle Band','Expert Belt',
  'Punching Glove','Black Belt','Spell Tag','Dragon Fang','Hard Stone',
  'Black Glasses','Twisted Spoon','Metal Coat','Poison Barb','Soft Sand',
];
// Defender-side items. Eviolite × 1.5 Def/SpD on non-final-evos,
// Assault Vest × 1.5 SpD, type-resist berries × 0.5 vs super-effective
// hits of the matching type. Berries are weighted so most scenarios
// still get the no-item case.
const DEF_ITEMS = [
  '','','','','','','','',  // mostly no item
  'Eviolite','Assault Vest',
  'Chople Berry','Yache Berry','Occa Berry','Wacan Berry',
  'Roseli Berry','Babiri Berry','Tanga Berry','Charti Berry',
  'Coba Berry','Shuca Berry','Payapa Berry','Rindo Berry',
  'Kebia Berry','Chilan Berry','Kasib Berry','Haban Berry',
  'Colbur Berry',
];
const NATURES = ['Adamant','Modest','Jolly','Timid','Bold','Calm','Impish','Careful','Hardy','Naughty'];
const WEATHERS = ['','Sun','Rain','Sand','Snow'];
const TERRAINS = ['','Electric','Grassy','Misty','Psychic'];
// Damage-relevant abilities. Notes on coverage gaps:
//   - Paradox (Quark Drive / Protosynthesis) — verified separately
//     in tools/showdown-compare/gen_paradox.mjs because @smogon/calc
//     needs an explicit `boostedStat` while we auto-detect.
//   - Auras (Fairy Aura / Dark Aura / Aura Break): require side
//     toggles we don't pass in this harness.
//   - Speed-modifying abilities are covered indirectly via effective
//     speed.
//   - Stance-change forms (Aegislash / Mimikyu Disguise) need form
//     swaps not emulated here.
const ABILITIES = [
  // No ability (or non-damage-relevant) — most common case.
  '', '', '', '',
  // Static type-boost / stat-boost
  'Adaptability','Tinted Lens','Filter','Solid Rock',
  'Sheer Force','Iron Fist','Tough Claws','Strong Jaw',
  'Mega Launcher','Punk Rock','Reckless','Steely Spirit',
  'Steelworker','Transistor',"Dragon's Maw",'Rocky Payload',
  // Type-change "-ate"
  'Pixilate','Aerilate','Refrigerate','Galvanize','Normalize',
  // Defensive / conditional
  'Multiscale','Fluffy','Heatproof','Thick Fat','Ice Scales',
  'Water Bubble','Purifying Salt','Dry Skin',
  // Pinch
  'Blaze','Torrent','Overgrow','Swarm',
  // Status-leveraging
  'Guts','Toxic Boost','Flare Boost','Marvel Scale',
  // STAB / typing tweaks
  'Protean','Libero',
  // Weather / terrain leveragers (don't require side toggles)
  'Sand Force','Solar Power',
  // Mold-breaker family
  'Mold Breaker','Teravolt','Turboblaze',
  // Crit interaction
  'Sniper','Merciless',
  // Misc damage mods. Rivalry skipped — @smogon/calc requires both
  // pokemon to have a non-N gender; without it, no boost/penalty.
  // Our calc expands the ability key to "Rivalry Same" by default
  // and always boosts, so we'd diverge. Stakeout / Analytic depend
  // on game-state we don't simulate either, but our calc ignores
  // those conditions too — they're safe to leave in.
  'Analytic','Stakeout',
  // Immunities that change damage routing
  'Levitate','Flash Fire','Sap Sipper','Lightning Rod',
  'Storm Drain','Volt Absorb','Water Absorb','Earth Eater',
  'Motor Drive','Well-Baked Body',
];

function* rng(seed) {
  // Mulberry32
  let s = seed >>> 0;
  while (true) {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t ^= t + (Math.imul(t ^ (t >>> 7), t | 61) >>> 0);
    yield ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
}

function buildScenario(rand) {
  const pick = arr => arr[Math.floor(rand() * arr.length)];
  return {
    atkSpec: pick(SPECIES),
    defSpec: pick(SPECIES),
    move: pick(MOVES),
    item: pick(ITEMS),
    defItem: pick(DEF_ITEMS),
    nature: pick(NATURES),
    weather: pick(WEATHERS),
    terrain: pick(TERRAINS),
    evs: {
      hp: Math.floor(rand() * 64) * 4,
      atk: Math.floor(rand() * 64) * 4,
      def: Math.floor(rand() * 64) * 4,
      spa: Math.floor(rand() * 64) * 4,
      spd: Math.floor(rand() * 64) * 4,
      spe: Math.floor(rand() * 64) * 4,
    },
    defEvs: {
      hp: Math.floor(rand() * 64) * 4,
      def: Math.floor(rand() * 64) * 4,
      spd: Math.floor(rand() * 64) * 4,
    },
    atkBoost: Math.floor(rand() * 13) - 6,
    defBoost: Math.floor(rand() * 13) - 6,
    // Status: 30 % chance, evenly across the damage-relevant ones.
    // Burn halves physical Atk; Facade doubles vs any status; others
    // exercise Hex/etc. without burn arithmetic.
    status: rand() < 0.3
        ? ['brn','par','psn','tox','frz','slp'][Math.floor(rand() * 6)]
        : undefined,
    defStatus: rand() < 0.3
        ? ['brn','par','psn','tox','frz','slp'][Math.floor(rand() * 6)]
        : undefined,
    isCrit: rand() < 0.2,
    trickRoom: rand() < 0.2,
    wonderRoom: rand() < 0.15,
    gravity: rand() < 0.15,
    // Defender side screens. Reflect halves physical damage, Light
    // Screen halves special, Aurora Veil halves both (Snow-only).
    reflect: rand() < 0.18,
    lightScreen: rand() < 0.18,
    auroraVeil: rand() < 0.12,
    // Defender dynamax: doubles HP and shifts thresholds for
    // Multiscale / target-HP-scaling moves.
    defDynamax: rand() < 0.15,
    // Attacker dynamax excluded from this harness: @smogon/calc
    // builds the Max move at Move-construction time off the DB BP,
    // while our calc keeps Dynamax as the LAST transform so any
    // pre-Max BP adjustments (Facade status×2, Water Spout HP%,
    // -ate ×1.2 boost, Normalize retype, Knock Off, …) fold into
    // the Max BP. A philosophical disagreement, not a bug — the
    // attacker-Dynamax fuzz is intentionally left out.
    atkDynamax: false,
    // 30 % of scenarios pick a random Terastal type from the standard
    // 18-type pool. Stellar (the special Terapagos case) is omitted —
    // it has its own auto-detection rules that don't slot cleanly
    // into the generic generator.
    // teraType is resolved *after* buildScenario in showdownRolls,
    // since Tera + attacker Dynamax never co-occur in real play.
    _wantTera: rand() < 0.3,
    _teraTypeRand: Math.floor(rand() * 18),
    // Random ability override. The pool is weighted so half the
    // scenarios get the species default (empty string) — keeps a
    // baseline that matches the pre-ability test set.
    atkAbility: pick(ABILITIES),
    defAbility: pick(ABILITIES),
    // HP percent: 80 % stay full, 20 % roll 1-99 % so multiscale /
    // pinch / defeatist / target-HP-scaling moves get exercised.
    atkHpPct: rand() < 0.8 ? 100 : 1 + Math.floor(rand() * 99),
    defHpPct: rand() < 0.8 ? 100 : 1 + Math.floor(rand() * 99),
  };
}

function showdownRolls(s) {
  // Mutually exclude Tera and attacker Dynamax: real game never
  // allows both, and @smogon/calc has surprising behaviour for the
  // combo (useMax locks the Max-move type before the Tera type swap
  // takes effect).
  if (!s.atkDynamax && s._wantTera) {
    s.teraType = [
      'Normal','Fire','Water','Electric','Grass','Ice','Fighting',
      'Poison','Ground','Flying','Psychic','Bug','Rock','Ghost',
      'Dragon','Dark','Steel','Fairy',
    ][s._teraTypeRand];
  } else {
    s.teraType = null;
  }
  delete s._wantTera; delete s._teraTypeRand;
  try {
    // Resolve a usable ability — @smogon/calc throws on unknown moves
    // for some species, so we let it pick the first ability silently
    // by leaving ability unset where possible.
    // Resolve curHP via a side Pokemon used only to read maxHP. We
    // can't assign `attacker.curHP = N` directly — that shadows the
    // curHP() method and silently leaves the calc thinking the mon
    // is at full HP. Instead we pass curHP through the constructor,
    // which sets originalCurHP correctly.
    const atkMaxRef = new Pokemon(gen, s.atkSpec, {level: 50, evs: s.evs});
    const defMaxRef = new Pokemon(gen, s.defSpec, {level: 50, evs: s.defEvs});
    const atkCurHP = s.atkHpPct < 100
        ? Math.max(1, Math.floor(atkMaxRef.maxHP() * s.atkHpPct / 100))
        : undefined;
    const defCurHP = s.defHpPct < 100
        ? Math.max(1, Math.floor(defMaxRef.maxHP() * s.defHpPct / 100))
        : undefined;
    // Re-derive the integer hpPercent from the actual curHP so our
    // Dart side, which only stores `hpPercent`, agrees with @smogon/calc
    // on Water Spout / Eruption / Hard Press / Multiscale thresholds.
    // Without this, floor(150*pct/100) and floor(150*curHP/maxHP) can
    // disagree by 1 BP whenever maxHP isn't a multiple of 100.
    if (atkCurHP !== undefined) {
      s.atkHpPct = Math.floor(atkCurHP * 100 / atkMaxRef.maxHP());
    }
    if (defCurHP !== undefined) {
      s.defHpPct = Math.floor(defCurHP * 100 / defMaxRef.maxHP());
    }
    const attacker = new Pokemon(gen, s.atkSpec, {
      level: 50,
      item: s.item || undefined,
      ability: s.atkAbility || undefined,
      nature: s.nature,
      evs: s.evs,
      boosts: {atk: s.atkBoost, spa: s.atkBoost},
      status: s.status,
      teraType: s.teraType || undefined,
      curHP: atkCurHP,
      isDynamaxed: s.atkDynamax || undefined,
    });
    const defender = new Pokemon(gen, s.defSpec, {
      level: 50,
      ability: s.defAbility || undefined,
      item: s.defItem || undefined,
      nature: 'Hardy',
      evs: s.defEvs,
      boosts: {def: s.defBoost, spd: s.defBoost},
      status: s.defStatus,
      curHP: defCurHP,
      isDynamaxed: s.defDynamax || undefined,
    });
    const field = new Field({
      weather: s.weather || undefined,
      terrain: s.terrain || undefined,
      isGravity: s.gravity || undefined,
      isWonderRoom: s.wonderRoom || undefined,
      isTrickRoom: s.trickRoom || undefined,
      defenderSide: {
        isReflect: s.reflect,
        isLightScreen: s.lightScreen,
        isAuroraVeil: s.auroraVeil,
      },
    });
    const result = calculate(gen, attacker, defender,
        new Move(gen, s.move, {
          isCrit: s.isCrit,
          useMax: s.atkDynamax || undefined,
        }), field);
    const dmg = result.damage;
    return Array.isArray(dmg) ? dmg : [dmg];
  } catch (e) {
    return null;
  }
}

const SEED = Number(process.argv[2] || 42);
const COUNT = Number(process.argv[3] || 200);
const it = rng(SEED);
const rand = () => it.next().value;

const out = [];
let attempted = 0;
while (out.length < COUNT && attempted < COUNT * 5) {
  attempted++;
  const s = buildScenario(rand);
  const rolls = showdownRolls(s);
  if (!rolls || rolls.length !== 16 || rolls.every(d => d === 0)) continue;
  out.push({...s, rolls});
}
console.log(JSON.stringify(out, null, 2));
