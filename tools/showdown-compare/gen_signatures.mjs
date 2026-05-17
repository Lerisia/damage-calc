// Signature-move / form-specific harness. Emits scenarios pairing each
// form species with its signature move, since the main fuzz pool is
// limited to species shared between our pokedex and @smogon/calc by
// the same name. Form pokemon use different naming conventions:
//   ours: "Ogerpon (Wellspring Mask)", "Terapagos (Stellar Form)"
//   showdown: "Ogerpon-Wellspring", "Terapagos-Stellar"
// We emit BOTH names so each side picks its own.
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';
const gen = Generations.get(9);

// [ours_name, showdown_name, signature_move, item?]
// Items use the display-name form (e.g. 'Hearthflame Mask') —
// @smogon/calc keys items by display name; the Dart harness slugifies
// via _itemSlug() for our side.
const PAIRS = [
  ['Terapagos (Stellar Form)', 'Terapagos-Stellar', 'Tera Starstorm', null],
  ['Terapagos (Stellar Form)', 'Terapagos-Stellar', 'Earth Power', null],
  ['Ice Rider Calyrex', 'Calyrex-Ice', 'Glacial Lance', null],
  ['Shadow Rider Calyrex', 'Calyrex-Shadow', 'Astral Barrage', null],
  ['Dusk Mane Necrozma', 'Necrozma-Dusk-Mane', 'Sunsteel Strike', null],
  ['Dawn Wings Necrozma', 'Necrozma-Dawn-Wings', 'Moongeist Beam', null],
  ['Dusk Mane Necrozma', 'Necrozma-Dusk-Mane', 'Photon Geyser', null],
  ['Ogerpon', 'Ogerpon', 'Ivy Cudgel', null],
  ['Ogerpon (Wellspring Mask)', 'Ogerpon-Wellspring', 'Ivy Cudgel', 'Wellspring Mask'],
  ['Ogerpon (Hearthflame Mask)', 'Ogerpon-Hearthflame', 'Ivy Cudgel', 'Hearthflame Mask'],
  ['Ogerpon (Cornerstone Mask)', 'Ogerpon-Cornerstone', 'Ivy Cudgel', 'Cornerstone Mask'],
  ['Paldean Tauros (Combat Breed)', 'Tauros-Paldea-Combat', 'Raging Bull', null],
  ['Paldean Tauros (Blaze Breed)', 'Tauros-Paldea-Blaze', 'Raging Bull', null],
  ['Paldean Tauros (Aqua Breed)', 'Tauros-Paldea-Aqua', 'Raging Bull', null],
  ['Morpeko', 'Morpeko', 'Aura Wheel', null],
];

const DEFENDERS = [
  ['Garchomp', 'Garchomp'],
  ['Snorlax', 'Snorlax'],
  ['Toxapex', 'Toxapex'],
  ['Gholdengo', 'Gholdengo'],
  ['Sylveon', 'Sylveon'],
  ['Skarmory', 'Skarmory'],
  ['Bronzong', 'Bronzong'],
];

const NATURES = ['Adamant','Modest','Jolly','Timid','Hardy'];
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

function build(rand) {
  const pick = a => a[Math.floor(rand() * a.length)];
  const [atkOurs, atkSd, move, item] = pick(PAIRS);
  const [defOurs, defSd] = pick(DEFENDERS);
  return {
    atkSpecOurs: atkOurs, atkSpec: atkSd,
    defSpecOurs: defOurs, defSpec: defSd,
    move,
    item: item || '',
    nature: pick(NATURES),
    weather: pick(WEATHERS),
    terrain: pick(TERRAINS),
    evs: {hp: 0, atk: Math.floor(rand()*64)*4, def: 0, spa: Math.floor(rand()*64)*4, spd: 0, spe: 0},
    defEvs: {hp: Math.floor(rand()*64)*4, def: Math.floor(rand()*64)*4, spd: Math.floor(rand()*64)*4},
    atkBoost: Math.floor(rand()*7),
    defBoost: Math.floor(rand()*7),
    isCrit: rand() < 0.15,
    teraType: rand() < 0.2 ? ['Normal','Fire','Water','Electric','Grass','Ice','Fighting','Poison','Ground','Flying','Psychic','Bug','Rock','Ghost','Dragon','Dark','Steel','Fairy'][Math.floor(rand()*18)] : null,
    atkHpPct: rand() < 0.85 ? 100 : 1 + Math.floor(rand()*99),
    defHpPct: rand() < 0.85 ? 100 : 1 + Math.floor(rand()*99),
  };
}

function rolls(s) {
  try {
    const atkMaxRef = new Pokemon(gen, s.atkSpec, {level: 50, evs: s.evs});
    const defMaxRef = new Pokemon(gen, s.defSpec, {level: 50, evs: s.defEvs});
    const atk = new Pokemon(gen, s.atkSpec, {
      level: 50, item: s.item || undefined, nature: s.nature, evs: s.evs,
      boosts: {atk: s.atkBoost, spa: s.atkBoost},
      teraType: s.teraType || undefined,
      curHP: s.atkHpPct < 100 ? Math.max(1, Math.floor(atkMaxRef.maxHP() * s.atkHpPct / 100)) : undefined,
    });
    const def = new Pokemon(gen, s.defSpec, {
      level: 50, nature: 'Hardy', evs: s.defEvs,
      boosts: {def: s.defBoost, spd: s.defBoost},
      curHP: s.defHpPct < 100 ? Math.max(1, Math.floor(defMaxRef.maxHP() * s.defHpPct / 100)) : undefined,
    });
    const field = new Field({weather: s.weather || undefined, terrain: s.terrain || undefined});
    const r = calculate(gen, atk, def, new Move(gen, s.move, {isCrit: s.isCrit}), field);
    const dmg = r.damage;
    return Array.isArray(dmg) ? dmg : [dmg];
  } catch (e) {
    return null;
  }
}

const SEED = Number(process.argv[2] || 42);
const COUNT = Number(process.argv[3] || 200);
const it = rng(SEED);
const r = () => it.next().value;
const out = [];
for (let i = 0; i < COUNT; i++) {
  const s = build(r);
  const got = rolls(s);
  if (got && got.length === 16) { s.rolls = got; out.push(s); }
}
console.log(JSON.stringify(out, null, 2));
