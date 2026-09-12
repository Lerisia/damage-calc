import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/stats.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/utils/entry_hazards.dart';

/// Entry hazards as one-shot HP deductions on the defender (user
/// decision 2026-09-13: buttons that knock the HP % field, no stored
/// field state). Stealth Rock: 1/8 of max HP × Rock effectiveness.
/// Spikes: 1/8, 1/6, 1/4 of max HP for 1, 2, 3 layers, grounded
/// targets only. Magic Guard blocks both. Damage floors like the game.
void main() {
  BattlePokemonState mon({
    required PokemonType type1, PokemonType? type2, String? ability, String? item,
    int baseHp = 100, double hp = 100,
  }) => BattlePokemonState(
      pokemonName: 'Test', type1: type1, type2: type2,
      baseStats: Stats(hp: baseHp, attack: 100, defense: 100, spAttack: 100, spDefense: 100, speed: 100),
      selectedAbility: ability ?? 'Blaze', selectedItem: item,
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

  group('spikesDamage', () {
    test('1/8, 1/6, 1/4 by layer count', () {
      final m = mon(type1: PokemonType.normal);
      expect(spikesDamage(m, layers: 1), 21); // 21.875
      expect(spikesDamage(m, layers: 2), 29); // 29.16
      expect(spikesDamage(m, layers: 3), 43); // 43.75
    });
    test('ungrounded targets are untouched; Gravity grounds them', () {
      expect(spikesDamage(mon(type1: PokemonType.flying), layers: 1), 0);
      expect(spikesDamage(mon(type1: PokemonType.normal, ability: 'Levitate'), layers: 1), 0);
      expect(spikesDamage(mon(type1: PokemonType.normal, item: 'air-balloon'), layers: 1), 0);
      expect(spikesDamage(mon(type1: PokemonType.flying), layers: 1, gravity: true), 21);
    });
    test('Magic Guard takes nothing', () {
      expect(spikesDamage(mon(type1: PokemonType.normal, ability: 'Magic Guard'), layers: 3), 0);
    });
  });

  group('applyEntryHazard (one-shot on the HP % field)', () {
    test('Stealth Rock knocks the HP % by its damage share', () {
      final m = mon(type1: PokemonType.fire, type2: PokemonType.flying);
      applyEntryHazard(m, EntryHazard.stealthRock);
      expect(m.hpPercent, closeTo(50.29, 0.01)); // (175-87)/175
    });
    test('each Spikes tap adds one layer: the delta between layer totals', () {
      final m = mon(type1: PokemonType.normal);
      applyEntryHazard(m, EntryHazard.spikes, spikesLayers: 1); // −21
      expect(m.hpPercent, closeTo(88.0, 0.01));
      applyEntryHazard(m, EntryHazard.spikes, spikesLayers: 2); // −(29−21)
      expect(m.hpPercent, closeTo(83.43, 0.01));
      applyEntryHazard(m, EntryHazard.spikes, spikesLayers: 3); // −(43−29)
      expect(m.hpPercent, closeTo(75.43, 0.01));
    });
    test('never drops below 0 and leaves an immune target alone', () {
      final low = mon(type1: PokemonType.fire, type2: PokemonType.flying, hp: 10);
      applyEntryHazard(low, EntryHazard.stealthRock);
      expect(low.hpPercent, 0);
      final bird = mon(type1: PokemonType.flying);
      applyEntryHazard(bird, EntryHazard.spikes, spikesLayers: 1);
      expect(bird.hpPercent, 100);
    });
  });
}
