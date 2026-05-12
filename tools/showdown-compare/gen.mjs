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
];
// Stick to moves with deterministic damage formulas (no Last Resort
// which requires prior moves used, no Sucker Punch which requires
// the target be selecting an attack, no Counter etc.).
const MOVES = [
  'Body Press','Earthquake','Close Combat','Knock Off',
  'Ice Spinner','U-turn','Flamethrower','Surf',
  'Psychic','Shadow Ball','Moonblast','Dragon Pulse','Thunderbolt',
  'Iron Head','Play Rough','Crunch','Stone Edge','Brave Bird',
  'Outrage','Triple Axel','Bullet Seed','Tachyon Cutter',
  'Hyper Voice','Aura Sphere','Earth Power','Fire Blast',
];
const ITEMS = [
  '','Choice Band','Choice Specs','Choice Scarf','Life Orb',
  'Leftovers','Heavy-Duty Boots','Sitrus Berry','Focus Sash',
  'Silk Scarf','Mystic Water','Charcoal','Miracle Seed',
  'Magnet','Sharp Beak','Wise Glasses','Muscle Band','Expert Belt',
  'Punching Glove','Black Belt','Spell Tag','Dragon Fang','Hard Stone',
  'Black Glasses','Twisted Spoon','Metal Coat','Poison Barb','Soft Sand',
];
const NATURES = ['Adamant','Modest','Jolly','Timid','Bold','Calm','Impish','Careful','Hardy','Naughty'];
const WEATHERS = ['','Sun','Rain','Sand','Snow'];
const TERRAINS = ['','Electric','Grassy','Misty','Psychic'];

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
    status: rand() < 0.1 ? 'brn' : undefined,
  };
}

function showdownRolls(s) {
  try {
    // Resolve a usable ability — @smogon/calc throws on unknown moves
    // for some species, so we let it pick the first ability silently
    // by leaving ability unset where possible.
    const attacker = new Pokemon(gen, s.atkSpec, {
      level: 50,
      item: s.item || undefined,
      nature: s.nature,
      evs: s.evs,
      boosts: {atk: s.atkBoost, spa: s.atkBoost},
      status: s.status,
    });
    const defender = new Pokemon(gen, s.defSpec, {
      level: 50,
      nature: 'Hardy',
      evs: s.defEvs,
      boosts: {def: s.defBoost, spd: s.defBoost},
    });
    const field = new Field({
      weather: s.weather || undefined,
      terrain: s.terrain || undefined,
    });
    const result = calculate(gen, attacker, defender, new Move(gen, s.move), field);
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
