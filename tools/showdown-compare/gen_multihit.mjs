// Multi-hit scenario generator. Returns scenarios with explicit
// `hits` count and per-hit damage arrays so the Dart side can
// compare against our `perHitAllRolls`.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';

const gen = Generations.get(9);
// Species likely to actually hit with the multi-hit moves we test.
// Same caveat as the main fuzz: no Paradox (Quark Drive requires
// explicit boostedStat), no Goodra-Hisui rename issues.
const SPECIES = [
  'Kangaskhan','Garchomp','Skarmory','Snorlax','Blissey',
  'Gholdengo','Dragapult','Sinistcha','Annihilape',
  'Hatterene','Corviknight','Hariyama','Volcarona',
  'Clodsire','Garganacl','Sylveon',
  'Bronzong','Araquanid','Dragonite','Vaporeon','Gastrodon',
  'Gengar','Toxapex','Ogerpon',
];
// Multi-hit moves. Each has a fixed hit-count distribution; we set
// `hits` explicitly so @smogon/calc returns a 2D damage array we
// can compare hit-by-hit.
// - Bullet Seed / Rock Blast / Pin Missile / Icicle Spear: 2-5 hits, equal BP.
// - Tachyon Cutter: 2 hits, equal BP.
// - Triple Axel: 3 hits, escalating BP 20/40/60.
// - Surging Strikes / Wicked Blow: 3 hits / 1 hit always-crit.
// - Population Bomb: 1-10 hits.
// Tachyon Cutter omitted: our movedex doesn't carry its 2-hit info,
// so it'd never run as multi-hit on our side (data gap, not a calc
// bug). Bullet/Rock/Pin/Icicle Spear are 2-5 hit equal-BP, exercised
// here at the max-hit count. Triple Axel exercises escalating BP.
// Surging Strikes is always-crit + 3 hits.
const MULTI_HIT_MOVES = [
  ['Bullet Seed', 5],
  ['Rock Blast', 5],
  ['Pin Missile', 5],
  ['Icicle Spear', 5],
  ['Triple Axel', 3],
  ['Surging Strikes', 3],
];
const ITEMS = [
  '','Choice Band','Choice Specs','Life Orb','Loaded Dice',
  'Silk Scarf','Mystic Water','Wise Glasses','Muscle Band','Expert Belt',
  'Punching Glove','Black Belt','Soft Sand',
];
const NATURES = ['Adamant','Modest','Jolly','Timid','Bold','Calm','Impish','Careful','Hardy','Naughty'];
const WEATHERS = ['','Sun','Rain','Sand','Snow'];
const TERRAINS = ['','Electric','Grassy','Misty','Psychic'];

function* rng(seed) {
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
  const [moveName, hits] = pick(MULTI_HIT_MOVES);
  return {
    atkSpec: pick(SPECIES),
    defSpec: pick(SPECIES),
    move: moveName,
    hits,
    item: pick(ITEMS),
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
    teraType: rand() < 0.3 ? [
      'Normal','Fire','Water','Electric','Grass','Ice','Fighting',
      'Poison','Ground','Flying','Psychic','Bug','Rock','Ghost',
      'Dragon','Dark','Steel','Fairy',
    ][Math.floor(rand() * 18)] : null,
  };
}

function showdownRolls(s) {
  try {
    const attacker = new Pokemon(gen, s.atkSpec, {
      level: 50, item: s.item || undefined, nature: s.nature,
      evs: s.evs, boosts: {atk: s.atkBoost, spa: s.atkBoost},
      teraType: s.teraType || undefined,
    });
    const defender = new Pokemon(gen, s.defSpec, {
      level: 50, nature: 'Hardy', evs: s.defEvs,
      boosts: {def: s.defBoost, spd: s.defBoost},
    });
    const field = new Field({
      weather: s.weather || undefined,
      terrain: s.terrain || undefined,
    });
    const result = calculate(gen, attacker, defender,
        new Move(gen, s.move, {hits: s.hits}), field);
    const dmg = result.damage;
    if (!Array.isArray(dmg)) return null;
    // Single-hit fallback (some moves we listed may be single-hit
    // for the target species — skip them).
    if (typeof dmg[0] === 'number') return null;
    // Expect [hits][16]. Each inner array length 16.
    if (dmg.length !== s.hits) return null;
    for (const h of dmg) if (!Array.isArray(h) || h.length !== 16) return null;
    return dmg;
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
while (out.length < COUNT && attempted < COUNT * 6) {
  attempted++;
  const s = buildScenario(rand);
  const rolls = showdownRolls(s);
  if (!rolls) continue;
  // Skip zero-damage scenarios.
  if (rolls.every(h => h.every(d => d === 0))) continue;
  out.push({...s, rolls});
}
console.log(JSON.stringify(out, null, 2));
