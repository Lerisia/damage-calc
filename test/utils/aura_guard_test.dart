import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/abilitydex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/move.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/utils/ability_effects.dart';

/// Aura Guard (파동의방호 / はどうのぼうご) — Mega Lucario Z's signature
/// ability, new in Pokémon Champions Regulation Set M-C.
///
/// "Halves the damage the Pokémon takes from contact moves."
/// Long Reach removes contact, so a move made non-contact deals full
/// damage.
void main() {
  late final Map<String, Move> moves;
  late final Map<String, Pokemon> byName;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    moves = await loadMovedex();
    final dex = await loadPokedex();
    byName = {for (final p in dex) p.name: p};
  });

  double mult(String moveName) => getDefensiveAbilityDamageMultiplier(
        'Aura Guard',
        move: moves[moveName]!,
      );

  test('halves contact moves', () {
    // Physical contact
    expect(mult('Close Combat'), equals(0.5));
    expect(mult('Play Rough'), equals(0.5));
    // Special moves make contact too when tagged as such (Draining
    // Kiss, Grass Knot is not) — drive off the tag, not the category.
    expect(mult('Draining Kiss'), equals(0.5));
  });

  test('leaves non-contact moves alone', () {
    expect(mult('Earthquake'), equals(1.0));
    expect(mult('Flamethrower'), equals(1.0));
    expect(mult('Aura Sphere'), equals(1.0));
    expect(mult('Rock Slide'), equals(1.0));
  });

  test('is type-agnostic, unlike Fluffy', () {
    // Fluffy doubles Fire damage; Aura Guard has no type clause, so a
    // Fire contact move is simply halved.
    expect(mult('Flare Blitz'), equals(0.5));
    expect(
      getDefensiveAbilityDamageMultiplier('Fluffy',
          move: moves['Flare Blitz']!),
      equals(1.0),
      reason: 'Fluffy: Fire x2 and contact x0.5 cancel out',
    );
  });

  group('data', () {
    test('Mega Lucario Z has Aura Guard', () {
      expect(byName['Mega Lucario Z']!.abilities, equals(['Aura Guard']));
    });

    test('the ability is registered with its localized names', () async {
      // Registered in assets/abilities.json so the picker and the
      // ability detail sheet can show it.
      final abilities = await loadAbilitydex();
      final a = abilities['Aura Guard'];
      expect(a, isNotNull);
      expect(a!.nameKo, equals('파동의방호'));
      expect(a.nameJa, equals('はどうのぼうご'));
    });
  });
}
