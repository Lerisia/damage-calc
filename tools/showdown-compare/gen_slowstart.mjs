// Slow Start comparison harness. Slow Start halves Attack and Speed
// for the first 5 turns. @smogon/calc gates both on `abilityOn`:
// attack via an atMod (physical only), speed via getFinalSpeed. This
// harness pairs physical / special / speed-based moves with Slow Start
// on and off and compares the 16-roll damage against @smogon/calc.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';
const gen = Generations.get(9);

const SPECIES = [
  'Regigigas', 'Garchomp', 'Snorlax', 'Dragapult', 'Gholdengo',
  'Tyranitar', 'Annihilape', 'Corviknight', 'Hatterene', 'Skarmory',
];
// Regigigas is excluded as a defender: it natively has Slow Start, and
// our calc would apply the 'Slow Start Active' default to it (halving
// its Speed → changes Gyro Ball's target-speed BP) while @smogon's
// unconfigured defender leaves abilityOn off. Only the attacker's Slow
// Start state is what this harness controls.
const DEF_SPECIES = SPECIES.filter(s => s !== 'Regigigas');
// Physical (attack-halved) + speed-based (Gyro/Electro Ball) +
// special controls (Slow Start must NOT touch Sp.Atk).
const MOVES = [
  'Earthquake', 'Knock Off', 'Stone Edge', 'Iron Head', 'Close Combat',
  'Gyro Ball', 'Electro Ball', 'Gyro Ball', 'Electro Ball',
  'Flamethrower', 'Shadow Ball', 'Surf',
];
const NATURES = ['Adamant', 'Jolly', 'Modest', 'Timid', 'Brave', 'Quiet', 'Hardy'];
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
    atkSpec: pick(SPECIES), defSpec: pick(DEF_SPECIES),
    abilityOn: rand() < 0.55,
    move: pick(MOVES),
    atkNature: pick(NATURES), defNature: pick(NATURES),
    weather: pick(WEATHERS), terrain: pick(TERRAINS),
    evs: ev(), defEvs: ev(),
    atkSpeedBoost: Math.floor(rand() * 13) - 6,
    defSpeedBoost: Math.floor(rand() * 13) - 6,
    isCrit: rand() < 0.15,
  };
}

function rolls(s) {
  try {
    const atk = new Pokemon(gen, s.atkSpec, {
      level: 50, ability: 'Slow Start', abilityOn: s.abilityOn,
      nature: s.atkNature, evs: s.evs, boosts: {spe: s.atkSpeedBoost},
    });
    const def = new Pokemon(gen, s.defSpec, {
      level: 50, nature: s.defNature, evs: s.defEvs,
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
