// Aura comparison harness. The main fuzz (gen.mjs) skips Fairy Aura /
// Dark Aura / Aura Break because they need field-level toggles. This
// harness drives @smogon/calc with `field.isFairyAura/isDarkAura/
// isAuraBreak` and emits the same toggles for the Dart side to feed
// into `AuraToggles`. Moves are weighted toward Fairy/Dark so the aura
// actually fires; a few neutral moves act as controls.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';
const gen = Generations.get(9);

const SPECIES = [
  'Garchomp', 'Skarmory', 'Snorlax', 'Gholdengo', 'Dragapult',
  'Hatterene', 'Sylveon', 'Gengar', 'Toxapex', 'Bronzong',
  'Dragonite', 'Corviknight', 'Sinistcha', 'Annihilape', 'Volcarona',
];
// Fairy + Dark heavy, plus neutral controls (aura must NOT touch them).
const MOVES = [
  'Moonblast', 'Dazzling Gleam', 'Play Rough', 'Spirit Break',
  'Moonblast', 'Play Rough',
  'Knock Off', 'Crunch', 'Dark Pulse', 'Foul Play',
  'Knock Off', 'Dark Pulse',
  'Earthquake', 'Flamethrower', 'Psychic',
];
const ITEMS = ['', '', 'Life Orb', 'Choice Band', 'Choice Specs', 'Expert Belt'];
const DEF_ITEMS = ['', '', 'Eviolite', 'Assault Vest'];
const NATURES = ['Adamant', 'Modest', 'Jolly', 'Timid', 'Hardy', 'Bold'];
const WEATHERS = ['', 'Sun', 'Rain', 'Sand', 'Snow'];
const TERRAINS = ['', 'Electric', 'Grassy', 'Misty', 'Psychic'];
const TERA = [null, null, null, null, 'Fairy', 'Dark', 'Steel', 'Fire'];
// Aura abilities on a Pokemon are another source of the field aura
// (alongside the toggles) — mostly empty so the toggle path still
// dominates. Exercises attacker-own-aura + Aura Break together.
const AURA_ABILITIES = ['', '', '', '', '', 'Fairy Aura', 'Dark Aura', 'Aura Break'];

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
  return {
    atkSpec: pick(SPECIES), defSpec: pick(SPECIES),
    atkAbility: pick(AURA_ABILITIES), defAbility: pick(AURA_ABILITIES),
    move: pick(MOVES), item: pick(ITEMS), defItem: pick(DEF_ITEMS),
    nature: pick(NATURES), weather: pick(WEATHERS), terrain: pick(TERRAINS),
    evs: {
      hp: Math.floor(rand() * 64) * 4, atk: Math.floor(rand() * 64) * 4,
      def: Math.floor(rand() * 64) * 4, spa: Math.floor(rand() * 64) * 4,
      spd: Math.floor(rand() * 64) * 4, spe: Math.floor(rand() * 64) * 4,
    },
    defEvs: {
      hp: Math.floor(rand() * 64) * 4, def: Math.floor(rand() * 64) * 4,
      spd: Math.floor(rand() * 64) * 4,
    },
    atkBoost: Math.floor(rand() * 13) - 6,
    defBoost: Math.floor(rand() * 13) - 6,
    isCrit: rand() < 0.2,
    teraType: pick(TERA),
    // Aura field toggles — each independently ~50/35/30%.
    fairyAura: rand() < 0.5,
    darkAura: rand() < 0.5,
    auraBreak: rand() < 0.3,
  };
}

function rolls(s) {
  try {
    const atk = new Pokemon(gen, s.atkSpec, {
      level: 50, item: s.item || undefined, nature: s.nature, evs: s.evs,
      ability: s.atkAbility || undefined,
      boosts: {atk: s.atkBoost, spa: s.atkBoost},
      teraType: s.teraType || undefined,
    });
    const def = new Pokemon(gen, s.defSpec, {
      level: 50, item: s.defItem || undefined, nature: 'Hardy', evs: s.defEvs,
      ability: s.defAbility || undefined,
      boosts: {def: s.defBoost, spd: s.defBoost},
    });
    const field = new Field({
      weather: s.weather || undefined, terrain: s.terrain || undefined,
      isFairyAura: s.fairyAura, isDarkAura: s.darkAura, isAuraBreak: s.auraBreak,
    });
    const r = calculate(gen, atk, def, new Move(gen, s.move, {isCrit: s.isCrit}), field);
    const dmg = r.damage;
    return Array.isArray(dmg) ? dmg : [dmg];
  } catch (e) {
    return null;
  }
}

const SEED = Number(process.argv[2] || 42);
const COUNT = Number(process.argv[3] || 2000);
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
