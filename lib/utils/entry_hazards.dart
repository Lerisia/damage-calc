import 'dart:math' as math;

import '../models/battle_pokemon.dart';
import '../models/type.dart';
import 'stat_calculator.dart';
import 'type_effectiveness.dart';

/// Stealth Rock on the defender's side, modelled as a one-shot deduction
/// from the HP % field (user decision 2026-09-13): every tap of 스록
/// knocks the HP the way one switch-in would, as many times as the user
/// likes, and nothing is stored — the calc keeps reading plain
/// `hpPercent`. (Spikes was dropped: its damage is a fixed fraction the
/// user can type; Stealth Rock's depends on the Rock matchup, which is
/// the part worth a button.)
///
/// Damage follows the game: 1/8 of max HP scaled by Rock's effectiveness
/// against the target, floored to whole HP, blocked by Magic Guard.

int _maxHp(BattlePokemonState s) => StatCalculator.calculate(
      baseStats: s.baseStats, iv: s.iv, ev: s.ev,
      nature: s.nature, level: s.level).hp;

/// HP lost to Stealth Rock on switch-in.
int stealthRockDamage(BattlePokemonState s) {
  if (s.selectedAbility == 'Magic Guard') return 0;
  final eff = getCombinedEffectiveness(
      PokemonType.rock, s.type1, s.type2, defType3: s.type3);
  return (_maxHp(s) * eff / 8).floor();
}

/// Applies one Stealth Rock switch-in to [s.hpPercent].
void applyStealthRock(BattlePokemonState s) {
  final maxHp = _maxHp(s);
  if (maxHp <= 0) return;
  final damage = stealthRockDamage(s);
  if (damage <= 0) return;
  final curHp = (maxHp * s.hpPercent / 100).floor();
  s.hpPercent = math.max(0, curHp - damage) / maxHp * 100;
}
