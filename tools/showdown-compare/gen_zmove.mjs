// Z-move scenario generator. Pairs each move with its matching
// Z-Crystal item so both calcs converge on the same Z-move name and
// BP. Sticks to a small move pool whose base→Z BP mapping is well
// defined.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';

const gen = Generations.get(9);
const SPECIES = [
  'Kangaskhan','Garchomp','Skarmory','Snorlax',
  'Gholdengo','Dragapult','Annihilape','Hatterene',
  'Corviknight','Hariyama','Volcarona','Sylveon',
  'Bronzong','Dragonite','Vaporeon','Gengar',
];
// move → matching Z-Crystal. Base BP / Z power per @smogon/calc
// table — we don't pin power, just let useZ resolve.
const MOVE_ZCRYSTAL = [
  ['Outrage', 'Dragonium Z'],
  ['Earthquake', 'Groundium Z'],
  ['Close Combat', 'Fightinium Z'],
  ['Ice Spinner', 'Icium Z'],
  ['Flamethrower', 'Firium Z'],
  ['Surf', 'Waterium Z'],
  ['Psychic', 'Psychium Z'],
  ['Shadow Ball', 'Ghostium Z'],
  ['Moonblast', 'Fairium Z'],
  ['Dragon Pulse', 'Dragonium Z'],
  ['Thunderbolt', 'Electrium Z'],
  ['Iron Head', 'Steelium Z'],
  ['Play Rough', 'Fairium Z'],
  ['Crunch', 'Darkinium Z'],
  ['Stone Edge', 'Rockium Z'],
  ['Brave Bird', 'Flyinium Z'],
  ['Aura Sphere', 'Fightinium Z'],
  ['Earth Power', 'Groundium Z'],
  ['Fire Blast', 'Firium Z'],
  ['Hyper Voice', 'Normalium Z'],
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
  const [moveName, item] = pick(MOVE_ZCRYSTAL);
  return {
    atkSpec: pick(SPECIES),
    defSpec: pick(SPECIES),
    move: moveName,
    item,
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
    atkBoost: Math.floor(rand() * 7) - 3,
    defBoost: Math.floor(rand() * 7) - 3,
    isCrit: rand() < 0.15,
  };
}

function showdownRolls(s) {
  try {
    const attacker = new Pokemon(gen, s.atkSpec, {
      level: 50, item: s.item, nature: s.nature, evs: s.evs,
      boosts: {atk: s.atkBoost, spa: s.atkBoost},
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
        new Move(gen, s.move, {useZ: true, isCrit: s.isCrit}), field);
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
