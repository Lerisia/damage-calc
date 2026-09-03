// Max Move base power, straight from Showdown's move data.
//
// Two things decide it (sim/dex-moves.ts):
//   1. `maxMove.basePower` on the move itself, when the game assigns
//      one. These are irregular — Icicle Spear 130 but Arm Thrust
//      none, Double Kick 80, Multi-Attack 95 — because they're
//      datamined values, not a formula. Spot-checked against
//      Bulbapedia's Max Move table, which agrees on every one.
//   2. Otherwise: base power 0 becomes 100 *before* the type tables,
//      then Fighting / Poison take a reduced table and everything
//      else the standard one.
//
// Emits {moveName: maxPower} for every damaging move, keyed by
// Showdown's display name so the Dart side can look ours up by
// `Move.name`. Z-moves and Max moves are skipped — they can't be the
// base move of a Max Move.
//
// Usage: node gen_maxmove.mjs > /tmp/max_move_power.json
import {Generations} from '@smogon/calc';

const gen = Generations.get(9);
const out = {};

for (const move of gen.moves) {
  if (!move.bp && move.category === 'Status') continue;
  if (move.isMax || move.isZ) continue;
  const maxBp = move.maxMove?.basePower;
  if (maxBp) {
    out[move.name] = maxBp;
    continue;
  }
  if (move.category === 'Status') continue;
  if (!move.bp) {
    out[move.name] = 100;
    continue;
  }
  const reduced = move.type === 'Fighting' || move.type === 'Poison';
  const table = reduced
    ? [[150, 100], [110, 95], [75, 90], [65, 85], [55, 80], [45, 75]]
    : [[150, 150], [110, 140], [75, 130], [65, 120], [55, 110], [45, 100]];
  let power = reduced ? 70 : 90;
  for (const [threshold, value] of table) {
    if (move.bp >= threshold) { power = value; break; }
  }
  out[move.name] = power;
}

console.log(JSON.stringify(out, null, 2));
