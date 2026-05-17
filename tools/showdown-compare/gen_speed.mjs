// Speed-ability comparison harness. The main fuzz (gen.mjs) skips
// speed-modifying abilities (Swift Swim / Chlorophyll / Sand Rush /
// Slush Rush / Surge Surfer / Quick Feet) — they only affect damage
// through speed-based-power moves. This harness pairs those abilities
// with Gyro Ball / Electro Ball under their activation conditions and
// compares the 16-roll damage against @smogon/calc.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';
const gen = Generations.get(9);

const SPECIES = [
  'Garchomp', 'Dragapult', 'Gholdengo', 'Gengar', 'Toxapex',
  'Snorlax', 'Skarmory', 'Bronzong', 'Sylveon', 'Annihilape',
  'Corviknight', 'Hatterene', 'Volcarona', 'Tyranitar',
];
// Gyro Ball / Electro Ball read both Pokemon's speed; Earthquake is a
// speed-independent control.
const MOVES = ['Gyro Ball', 'Electro Ball', 'Gyro Ball', 'Electro Ball', 'Earthquake'];
// Empty-heavy so the no-ability baseline keeps parity with the main set.
const SPEED_ABILITIES = [
  '', '', '',
  'Swift Swim', 'Chlorophyll', 'Sand Rush', 'Slush Rush',
  'Surge Surfer', 'Quick Feet',
];
const NATURES = ['Jolly', 'Timid', 'Adamant', 'Modest', 'Brave', 'Quiet', 'Hardy'];
const WEATHERS = ['', 'Sun', 'Rain', 'Sand', 'Snow'];
const TERRAINS = ['', 'Electric', 'Grassy', 'Psychic'];
const STATUSES = ['', '', '', 'par', 'brn', 'psn'];

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
    atkAbility: pick(SPEED_ABILITIES), defAbility: pick(SPEED_ABILITIES),
    move: pick(MOVES),
    atkNature: pick(NATURES), defNature: pick(NATURES),
    weather: pick(WEATHERS), terrain: pick(TERRAINS),
    atkStatus: pick(STATUSES), defStatus: pick(STATUSES),
    evs: ev(), defEvs: ev(),
    atkSpeedBoost: Math.floor(rand() * 13) - 6,
    defSpeedBoost: Math.floor(rand() * 13) - 6,
    isCrit: rand() < 0.15,
  };
}

function rolls(s) {
  try {
    const atk = new Pokemon(gen, s.atkSpec, {
      level: 50, ability: s.atkAbility || undefined, nature: s.atkNature,
      evs: s.evs, status: s.atkStatus || undefined,
      boosts: {spe: s.atkSpeedBoost},
    });
    const def = new Pokemon(gen, s.defSpec, {
      level: 50, ability: s.defAbility || undefined, nature: s.defNature,
      evs: s.defEvs, status: s.defStatus || undefined,
      boosts: {spe: s.defSpeedBoost},
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
