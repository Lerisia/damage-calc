import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/calc/entry_hazards.dart';

/// Stealth Rock as a one-shot, repeatable HP deduction on the defender
/// (user decision 2026-09-13: a button that knocks the HP % once per
/// tap, no stored field state). 1/8 of max HP × Rock effectiveness,
/// floored like the game; Magic Guard blocks it.
void main() {
  BattlePokemonState mon({
    required PokemonType type1, PokemonType? type2, String? ability,
    double hp = 100,
  }) => BattlePokemonState(
      pokemonName: 'Test', type1: type1, type2: type2,
      baseStats: const Stats(hp: 100, attack: 100, defense: 100, spAttack: 100, spDefense: 100, speed: 100),
      selectedAbility: ability ?? 'Blaze',
      iv: const Stats(hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31),
      ev: const Stats(hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0),
      hpPercent: hp);
  // base 100 / 31 IV / 0 EV / Lv50 → max HP 175.

  group('stealthRockDamage', () {
    test('neutral: 1/8 of max HP, floored', () {
      expect(stealthRockDamage(mon(type1: PokemonType.normal)), 21); // 175/8 = 21.875
    });
    test('scales with Rock effectiveness', () {
      expect(stealthRockDamage(mon(type1: PokemonType.fire, type2: PokemonType.flying)), 87); // ×4 → 87.5
      expect(stealthRockDamage(mon(type1: PokemonType.steel, type2: PokemonType.fighting)), 5); // ×0.25 → 5.46
    });
    test('Magic Guard takes nothing', () {
      expect(stealthRockDamage(mon(type1: PokemonType.normal, ability: 'Magic Guard')), 0);
    });
  });

  group('applyStealthRock (one switch-in per tap, repeatable)', () {
    test('knocks the HP % by the damage share, every tap', () {
      final m = mon(type1: PokemonType.fire, type2: PokemonType.flying);
      applyStealthRock(m);
      expect(m.hpPercent, closeTo(50.29, 0.01)); // (175-87)/175
      applyStealthRock(m);
      expect(m.hpPercent, closeTo(0.57, 0.01)); // (88-87)/175
    });
    test('never drops below 0; Magic Guard target is left alone', () {
      final low = mon(type1: PokemonType.fire, type2: PokemonType.flying, hp: 10);
      applyStealthRock(low);
      expect(low.hpPercent, 0);
      final mg = mon(type1: PokemonType.normal, ability: 'Magic Guard');
      applyStealthRock(mg);
      expect(mg.hpPercent, 100);
    });
  });
}
