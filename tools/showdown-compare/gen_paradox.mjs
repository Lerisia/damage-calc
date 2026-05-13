// Paradox-focused scenario generator (Quark Drive / Protosynthesis).
// @smogon/calc requires `boostedStat` to be set on the Pokemon for
// the boost to activate; we use 'auto' so it picks the highest stat
// like our calc does. Stat-rank boosts are pinned to 0 — @smogon/calc
// uses rank-modified stats for the "which stat is highest?" check
// (a known divergence from the actual game), while our calc uses
// raw stats. Limiting to rank=0 avoids that ambiguity so the test
// only verifies the boost magnitude, not the auto-pick disagreement.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';

const gen = Generations.get(9);
// Pokémon natively carrying Paradox abilities. Mixed offensive/
// defensive picks so every stat slot gets exercised as "highest".
const PARADOX_SPECIES = [
  // Protosynthesis (ancient)
  'Great Tusk','Scream Tail','Brute Bonnet','Flutter Mane','Slither Wing',
  'Sandy Shocks','Roaring Moon','Walking Wake','Gouging Fire','Raging Bolt',
  // Quark Drive (future)
  'Iron Treads','Iron Bundle','Iron Hands','Iron Jugulis','Iron Moth',
  'Iron Thorns','Iron Valiant','Iron Leaves','Iron Boulder','Iron Crown',
];
// Same defender pool as the main fuzz so we cover varied typings.
const DEF_SPECIES = [
  'Kangaskhan','Garchomp','Skarmory','Snorlax','Blissey',
  'Gholdengo','Dragapult','Sinistcha','Annihilape',
  'Hatterene','Corviknight','Hariyama','Volcarona',
  'Clodsire','Garganacl','Sylveon',
];
const MOVES = [
  'Earthquake','Close Combat','Ice Spinner','Flamethrower','Surf',
  'Psychic','Shadow Ball','Moonblast','Dragon Pulse','Thunderbolt',
  'Iron Head','Play Rough','Crunch','Stone Edge','Brave Bird',
  'Aura Sphere','Earth Power','Fire Blast',
];
const ITEMS = [
  '','Choice Band','Choice Specs','Life Orb','Booster Energy',
  'Leftovers','Heavy-Duty Boots','Silk Scarf','Mystic Water',
  'Charcoal','Miracle Seed','Magnet','Wise Glasses','Muscle Band',
];
const NATURES = ['Adamant','Modest','Jolly','Timid','Bold','Calm','Hardy'];
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
  return {
    atkSpec: pick(PARADOX_SPECIES),
    defSpec: pick(DEF_SPECIES),
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
    // Rank pinned to 0 — see header comment.
    atkBoost: 0,
    defBoost: 0,
    isCrit: rand() < 0.15,
    teraType: rand() < 0.25 ? [
      'Normal','Fire','Water','Electric','Grass','Ice','Fighting',
      'Poison','Ground','Flying','Psychic','Bug','Rock','Ghost',
      'Dragon','Dark','Steel','Fairy',
    ][Math.floor(rand() * 18)] : null,
  };
}

function showdownRolls(s) {
  try {
    const attacker = new Pokemon(gen, s.atkSpec, {
      level: 50,
      item: s.item || undefined,
      nature: s.nature,
      evs: s.evs,
      teraType: s.teraType || undefined,
      boostedStat: 'auto',
    });
    const defender = new Pokemon(gen, s.defSpec, {
      level: 50,
      nature: 'Hardy',
      evs: s.defEvs,
    });
    const field = new Field({
      weather: s.weather || undefined,
      terrain: s.terrain || undefined,
    });
    const result = calculate(gen, attacker, defender,
        new Move(gen, s.move, {isCrit: s.isCrit}), field);
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
while (out.length < COUNT && attempted < COUNT * 6) {
  attempted++;
  const s = buildScenario(rand);
  const rolls = showdownRolls(s);
  if (!rolls || rolls.length !== 16 || rolls.every(d => d === 0)) continue;
  out.push({...s, rolls});
}
console.log(JSON.stringify(out, null, 2));
