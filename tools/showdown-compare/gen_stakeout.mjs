// Stakeout comparison harness. Stakeout doubles the damage dealt to a
// target that switched in this turn. @smogon/calc gates it on
// `abilityOn` and applies an atMod of 8192 (×2) with no move-category
// gate — so physical and special moves alike are doubled. This harness
// pairs physical / special moves with Stakeout on and off and compares
// the 16-roll damage against @smogon/calc.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';
const gen = Generations.get(9);

const SPECIES = [
  'Garchomp', 'Snorlax', 'Dragapult', 'Gholdengo', 'Tyranitar',
  'Annihilape', 'Corviknight', 'Hatterene', 'Skarmory', 'Gengar',
  'Sylveon', 'Volcarona',
];
const MOVES = [
  'Earthquake', 'Knock Off', 'Stone Edge', 'Close Combat', 'Iron Head',
  'Flamethrower', 'Shadow Ball', 'Surf', 'Thunderbolt', 'Moonblast',
];
const NATURES = ['Adamant', 'Modest', 'Jolly', 'Timid', 'Hardy', 'Bold'];
const WEATHERS = ['', 'Sun', 'Rain', 'Sand', 'Snow'];
const TERRAINS = ['', 'Electric', 'Grassy', 'Psychic'];

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

function build(rand) {
  const pick = a => a[Math.floor(rand() * a.length)];
  const ev = () => ({
    hp: Math.floor(rand() * 64) * 4, atk: Math.floor(rand() * 64) * 4,
    def: Math.floor(rand() * 64) * 4, spa: Math.floor(rand() * 64) * 4,
    spd: Math.floor(rand() * 64) * 4, spe: Math.floor(rand() * 64) * 4,
  });
  return {
    atkSpec: pick(SPECIES), defSpec: pick(SPECIES),
    abilityOn: rand() < 0.55,
    move: pick(MOVES), nature: pick(NATURES),
    weather: pick(WEATHERS), terrain: pick(TERRAINS),
    evs: ev(), defEvs: ev(),
    atkBoost: Math.floor(rand() * 13) - 6,
    defBoost: Math.floor(rand() * 13) - 6,
    isCrit: rand() < 0.15,
  };
}

function rolls(s) {
  try {
    const atk = new Pokemon(gen, s.atkSpec, {
      level: 50, ability: 'Stakeout', abilityOn: s.abilityOn,
      nature: s.nature, evs: s.evs,
      boosts: {atk: s.atkBoost, spa: s.atkBoost},
    });
    const def = new Pokemon(gen, s.defSpec, {
      level: 50, nature: 'Hardy', evs: s.defEvs,
      boosts: {def: s.defBoost, spd: s.defBoost},
    });
    const field = new Field({
      weather: s.weather || undefined, terrain: s.terrain || undefined,
    });
    const r = calculate(gen, atk, def, new Move(gen, s.move, {isCrit: s.isCrit}), field);
    const dmg = r.damage;
    return Array.isArray(dmg) ? dmg : [dmg];
  } catch (e) {
    return null;
  }
}

const SEED = Number(process.argv[2] || 42);
const COUNT = Number(process.argv[3] || 2500);
const it = rng(SEED);
const r = () => it.next().value;
const out = [];
let attempted = 0;
while (out.length < COUNT && attempted < COUNT * 5) {
  attempted++;
  const s = build(r);
  const got = rolls(s);
  if (got && got.length === 16 && !got.every(d => d === 0)) {
    s.rolls = got;
    out.push(s);
  }
}
console.log(JSON.stringify(out, null, 2));
