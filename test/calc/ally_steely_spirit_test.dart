import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/calc/battle_facade.dart';
import 'package:damage_calc/calc/damage_calculator.dart';
import 'package:damage_calc/calc/doubles_effects.dart';
import 'package:damage_calc/models/battle_pokemon.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/move_tags.dart';
import 'package:damage_calc/models/room.dart';
import 'package:damage_calc/models/terastal.dart';
import 'package:damage_calc/models/terrain.dart';
import 'package:damage_calc/models/type.dart';
import 'package:damage_calc/models/weather.dart';

/// An ally's Steely Spirit. Showdown's `steelyspirit` is an
/// `onAllyBasePower` ×1.5 on Steel-type moves with no self exclusion,
/// so it reaches the holder AND its allies, one ×1.5 per holder on the
/// side: a Steely Spirit attacker next to a Steely Spirit ally lands
/// ×2.25. The attacker's own copy was already modelled; this is the
/// ally's, as a doubles toggle like Battery / Power Spot.
void main() {
  const ironHead = Move(
    name: 'Iron Head', nameKo: '아이언헤드', nameJa: 'アイアンヘッド',
    type: PokemonType.steel, category: MoveCategory.physical,
    power: 80, accuracy: 100, pp: 15, tags: [MoveTags.contact],
  );
  const tackle = Move(
    name: 'Tackle', nameKo: '몸통박치기', nameJa: 'たいあたり',
    type: PokemonType.normal, category: MoveCategory.physical,
    power: 40, accuracy: 100, pp: 35, tags: [MoveTags.contact],
  );
  const teraBlast = Move(
    name: 'Tera Blast', nameKo: '테라버스트', nameJa: 'テラバースト',
    type: PokemonType.normal, category: MoveCategory.special,
    power: 80, accuracy: 100, pp: 10,
  );

  DamageResult damage({
    Move move = ironHead,
    String atkAbility = 'Overgrow',
    bool ally = false,
    TerastalState tera = const TerastalState(),
  }) {
    final atk = BattlePokemonState(
      type1: PokemonType.grass, type2: PokemonType.poison,
      selectedAbility: atkAbility,
      moves: [move, null, null, null],
      terastal: tera,
    )..allySteelySpirit = ally;
    final def = BattlePokemonState(
      type1: PokemonType.normal, type2: null, selectedAbility: 'Overgrow');
    return DamageCalculator.calculate(
      attacker: atk, defender: def, moveIndex: 0,
      weather: Weather.none, terrain: Terrain.none,
      room: const RoomConditions(), doubles: true,
    );
  }

  int power({Move move = ironHead, String atkAbility = 'Overgrow', bool ally = false}) {
    final s = BattlePokemonState(
      type1: PokemonType.grass, type2: PokemonType.poison,
      selectedAbility: atkAbility,
      moves: [move, null, null, null],
    )..allySteelySpirit = ally;
    return BattleFacade.calcOffensivePower(
      state: s, moveIndex: 0,
      weather: Weather.none, terrain: Terrain.none,
      room: const RoomConditions(),
    )!;
  }

  group('damage', () {
    test('a Steel move of an ally of Steely Spirit does ×1.5', () {
      final off = damage();
      final on = damage(ally: true);
      expect(on.maxDamage, closeTo(off.maxDamage * 1.5, 2));
      expect(on.modifierNotes, contains('move:steelySpirit:×1.5'));
    });

    test('the attacker\'s own Steely Spirit stacks with the ally\'s: ×2.25', () {
      final neither = damage();
      final own = damage(atkAbility: 'Steely Spirit');
      final both = damage(atkAbility: 'Steely Spirit', ally: true);
      expect(own.maxDamage, closeTo(neither.maxDamage * 1.5, 2));
      expect(both.maxDamage, closeTo(neither.maxDamage * 2.25, 3));
    });

    test('a non-Steel move is untouched', () {
      final off = damage(move: tackle);
      final on = damage(move: tackle, ally: true);
      expect(on.maxDamage, off.maxDamage);
      expect(on.modifierNotes, isNot(contains('move:steelySpirit:×1.5')));
    });

    test('Tera Blast of a Tera Steel attacker counts as Steel', () {
      const steel = TerastalState(active: true, teraType: PokemonType.steel);
      final off = damage(move: teraBlast, tera: steel);
      final on = damage(move: teraBlast, tera: steel, ally: true);
      expect(on.maxDamage, closeTo(off.maxDamage * 1.5, 2));
      // …and plain Normal Tera Blast is not.
      final plain = damage(move: teraBlast);
      expect(damage(move: teraBlast, ally: true).maxDamage, plain.maxDamage);
    });
  });

  group('결정력', () {
    test('Steel move ×1.5, other moves untouched', () {
      expect(power(ally: true) / power(), closeTo(1.5, 0.05));
      expect(power(move: tackle, ally: true), power(move: tackle));
    });

    test('own + ally ×2.25', () {
      final neither = power();
      final both = power(atkAbility: 'Steely Spirit', ally: true);
      expect(both / neither, closeTo(2.25, 0.1));
    });
  });

  group('state', () {
    test('off by default, survives JSON, cleared by reset', () {
      final s = BattlePokemonState();
      expect(s.allySteelySpirit, isFalse);
      s.allySteelySpirit = true;
      expect(BattlePokemonState.fromJson(s.toJson()).allySteelySpirit, isTrue);
      s.reset();
      expect(s.allySteelySpirit, isFalse);
    });

    test('doubles modifiers emit the note for Steel only', () {
      final s = BattlePokemonState()..allySteelySpirit = true;
      final steel = computeDoublesModifiers(attacker: s, move: ironHead, isDoubles: true);
      expect(steel.offensivePowerMod, 1.5);
      expect(steel.notes, ['move:steelySpirit:×1.5']);
      final normal = computeDoublesModifiers(attacker: s, move: tackle, isDoubles: true);
      expect(normal.offensivePowerMod, 1.0);
      expect(normal.notes, isEmpty);
    });
  });
}
