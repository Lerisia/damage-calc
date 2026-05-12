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
  // Wider ability coverage. Avoid Paradox (Quark Drive / Protosynthesis)
  // because @smogon/calc treats those as inactive unless an explicit
  // `boostedStat` is supplied — our calc auto-detects, so we'd diverge
  // on every Paradox scenario. Goodra-Hisui name doesn't round-trip
  // through our pokedex either, so dropped.
  'Bronzong','Araquanid','Dragonite','Vaporeon','Gastrodon',
  'Gengar','Toxapex','Ogerpon',
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
  // Status-aware (Facade ×2 on any status, Hex ×2 vs statused),
  // Speed-aware (Gyro Ball — TR doesn't change speed but pairs commonly),
  // weight-aware Body Press is already above.
  'Facade','Hex','Gyro Ball','Electro Ball',
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
    // Status: 30 % chance, evenly across the damage-relevant ones.
    // Burn halves physical Atk; Facade doubles vs any status; others
    // exercise Hex/etc. without burn arithmetic.
    status: rand() < 0.3
        ? ['brn','par','psn','tox','frz','slp'][Math.floor(rand() * 6)]
        : undefined,
    defStatus: rand() < 0.3
        ? ['brn','par','psn','tox','frz','slp'][Math.floor(rand() * 6)]
        : undefined,
    isCrit: rand() < 0.2,
    trickRoom: rand() < 0.2,
    wonderRoom: rand() < 0.15,
    gravity: rand() < 0.15,
    // 30 % of scenarios pick a random Terastal type from the standard
    // 18-type pool. Stellar (the special Terapagos case) is omitted —
    // it has its own auto-detection rules that don't slot cleanly
    // into the generic generator.
    teraType: rand() < 0.3 ? [
      'Normal','Fire','Water','Electric','Grass','Ice','Fighting',
      'Poison','Ground','Flying','Psychic','Bug','Rock','Ghost',
      'Dragon','Dark','Steel','Fairy',
    ][Math.floor(rand() * 18)] : null,
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
      teraType: s.teraType || undefined,
    });
    const defender = new Pokemon(gen, s.defSpec, {
      level: 50,
      nature: 'Hardy',
      evs: s.defEvs,
      boosts: {def: s.defBoost, spd: s.defBoost},
      status: s.defStatus,
    });
    const field = new Field({
      weather: s.weather || undefined,
      terrain: s.terrain || undefined,
      isGravity: s.gravity || undefined,
      isWonderRoom: s.wonderRoom || undefined,
      isTrickRoom: s.trickRoom || undefined,
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
while (out.length < COUNT && attempted < COUNT * 5) {
  attempted++;
  const s = buildScenario(rand);
  const rolls = showdownRolls(s);
  if (!rolls || rolls.length !== 16 || rolls.every(d => d === 0)) continue;
  out.push({...s, rolls});
}
console.log(JSON.stringify(out, null, 2));
