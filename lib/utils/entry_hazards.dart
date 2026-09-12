import 'dart:math' as math;

import '../models/battle_pokemon.dart';
import '../models/type.dart';
import 'grounded.dart';
import 'stat_calculator.dart';
import 'type_effectiveness.dart';

/// Entry hazards on the defender's side, modelled as one-shot deductions
/// from the HP % field (user decision 2026-09-13): tapping 스록 / 압정
/// knocks the HP the way switching in would, and nothing is stored —
/// the calc keeps reading plain `hpPercent`.
///
/// Damage follows the game: Stealth Rock takes 1/8 of max HP scaled by
/// Rock's effectiveness against the target; Spikes take 1/8, 1/6, 1/4
/// for one, two, three layers and only hit grounded targets. Both are
/// floored to whole HP and blocked by Magic Guard.
enum EntryHazard { stealthRock, spikes }

int _maxHp(BattlePokemonState s) => StatCalculator.calculate(
      baseStats: s.baseStats, iv: s.iv, ev: s.ev,
      nature: s.nature, level: s.level).hp;

bool _magicGuard(BattlePokemonState s) => s.selectedAbility == 'Magic Guard';

/// HP lost to Stealth Rock on switch-in.
int stealthRockDamage(BattlePokemonState s) {
  if (_magicGuard(s)) return 0;
  final eff = getCombinedEffectiveness(
      PokemonType.rock, s.type1, s.type2, defType3: s.type3);
  return (_maxHp(s) * eff / 8).floor();
}

/// HP lost to [layers] (1–3) of Spikes on switch-in — the total for that
/// layer count, not the increment.
int spikesDamage(BattlePokemonState s, {required int layers, bool gravity = false}) {
  if (layers <= 0 || _magicGuard(s)) return 0;
  final grounded = isGrounded(
      type1: s.type1, type2: s.type2, type3: s.type3,
      ability: s.selectedAbility, item: s.selectedItem, gravity: gravity);
  if (!grounded) return 0;
  final divisor = switch (layers.clamp(1, 3)) { 1 => 8, 2 => 6, _ => 4 };
  return (_maxHp(s) / divisor).floor();
}

/// Applies one hazard tap to [s.hpPercent]. For Spikes, [spikesLayers] is
/// the layer count *after* this tap, so the deduction is the difference
/// between that total and the previous layer's — three taps land on
/// exactly 1/4 of max HP.
void applyEntryHazard(BattlePokemonState s, EntryHazard hazard,
    {int spikesLayers = 1, bool gravity = false}) {
  final maxHp = _maxHp(s);
  if (maxHp <= 0) return;
  final int damage = switch (hazard) {
    EntryHazard.stealthRock => stealthRockDamage(s),
    EntryHazard.spikes => spikesDamage(s, layers: spikesLayers, gravity: gravity) -
        spikesDamage(s, layers: spikesLayers - 1, gravity: gravity),
  };
  if (damage <= 0) return;
  final curHp = (maxHp * s.hpPercent / 100).floor();
  final newHp = math.max(0, curHp - damage);
  s.hpPercent = newHp / maxHp * 100;
}
