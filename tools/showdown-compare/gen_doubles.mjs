// Doubles scenario generator. Adds:
//  - gameType: 'Doubles' on the Field so spread moves (allAdjacent
//    / allAdjacentFoes) auto-apply ×0.75.
//  - Random ally toggles: Helping Hand (×1.5 BP), Power Spot
//    (ally ability, ×1.3), Battery (×1.3 special), Friend Guard
//    (×0.75 damage taken on defender side).
import {Generations, calculate, Pokemon, Move, Field} from '@smogon/calc';

const gen = Generations.get(9);
const SPECIES = [
  'Kangaskhan','Garchomp','Skarmory','Snorlax','Blissey',
  'Gholdengo','Dragapult','Sinistcha','Annihilape',
  'Hatterene','Corviknight','Hariyama','Volcarona',
  'Clodsire','Garganacl','Sylveon',
  'Bronzong','Araquanid','Dragonite','Vaporeon','Gastrodon',
  'Gengar','Toxapex','Ogerpon',
];
// Mix of single-target and spread moves so we exercise both paths.
// Spread: Earthquake / Surf / Hyper Voice (allAdjacent[Foes]).
const MOVES = [
  'Body Press','Earthquake','Close Combat','Knock Off',
  'Ice Spinner','Flamethrower','Surf',
  'Psychic','Shadow Ball','Moonblast','Dragon Pulse','Thunderbolt',
  'Iron Head','Play Rough','Crunch','Stone Edge','Brave Bird',
  'Outrage','Hyper Voice','Aura Sphere','Earth Power','Fire Blast',
];
const ITEMS = [
  '','Choice Band','Choice Specs','Life Orb',
  'Leftovers','Heavy-Duty Boots','Silk Scarf','Mystic Water',
  'Charcoal','Miracle Seed','Wise Glasses','Muscle Band','Expert Belt',
  'Black Belt','Dragon Fang','Hard Stone','Black Glasses',
  'Twisted Spoon','Metal Coat','Soft Sand',
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
    isCrit: rand() < 0.15,
    helpingHand: rand() < 0.18,
    powerSpot: rand() < 0.12,
    battery: rand() < 0.12,
    friendGuard: rand() < 0.15,
  };
}

function showdownRolls(s) {
  try {
    const attacker = new Pokemon(gen, s.atkSpec, {
      level: 50,
      item: s.item || undefined,
      nature: s.nature,
      evs: s.evs,
      boosts: {atk: s.atkBoost, spa: s.atkBoost},
    });
    const defender = new Pokemon(gen, s.defSpec, {
      level: 50,
      nature: 'Hardy',
      evs: s.defEvs,
      boosts: {def: s.defBoost, spd: s.defBoost},
    });
    const field = new Field({
      gameType: 'Doubles',
      weather: s.weather || undefined,
      terrain: s.terrain || undefined,
      attackerSide: {
        isHelpingHand: s.helpingHand,
        isPowerSpot: s.powerSpot,
        isBattery: s.battery,
      },
      defenderSide: {
        isFriendGuard: s.friendGuard,
      },
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
