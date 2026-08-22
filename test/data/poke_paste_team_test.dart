import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/poke_paste.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/battle_pokemon.dart';

/// Team-level (multi-member, `=== name ===` header) round-trip with a
/// roster deliberately mixing base species, regional/parenthesised
/// forms, a nicknamed form (nested parens), and a gendered mon.
void main() {
  late final Map<String, dynamic> dexes;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pokedex = await loadPokedex();
    final moves = await loadMovedex();
    final items = await loadItemdex();
    dexes = {
      'byName': {for (final p in pokedex) p.name: p},
      'items': items,
      'displayToId': {
        for (final e in items.entries)
          if (e.value.nameEn != null) e.value.nameEn!.toLowerCase(): e.key,
      },
      'moves': moves,
    };
  });

  test('team with mixed forms encode → decode preserves order/species/names',
      () {
    final byName = dexes['byName'] as Map;
    final picks = <({String species, String nick})>[
      (species: 'Garchomp', nick: 'Speedy'),
      (species: 'Landorus (Therian Forme)', nick: 'Landorus (Therian Forme)'),
      (species: 'Urshifu (Rapid Strike Style)', nick: 'Water Boi'),
      (species: 'Meowstic (Female)', nick: 'Meowstic (Female)'),
      (species: 'Deoxys (Attack Forme)', nick: 'Deoxys (Attack Forme)'),
      (species: 'Incineroar', nick: 'Incineroar'),
    ];
    final members = <({String name, BattlePokemonState state})>[];
    for (final pk in picks) {
      final p = byName[pk.species];
      if (p == null) continue; // tolerate dex naming drift
      members.add((
        name: pk.nick,
        state: BattlePokemonState()..applyPokemon(p),
      ));
    }
    expect(members.length, picks.length, reason: 'all picks present in dex');

    final code = PokePaste.encodeTeam('My Squad', members,
        itemsById: dexes['items']);
    final decoded = PokePaste.decodeTeam(code,
        pokemonByName: dexes['byName'],
        itemDisplayToId: dexes['displayToId'],
        moveByName: dexes['moves']);

    expect(decoded.name, 'My Squad');
    expect(decoded.members.length, members.length);
    for (var i = 0; i < members.length; i++) {
      expect(decoded.members[i].state.pokemonName,
          members[i].state.pokemonName);
      expect(decoded.members[i].name, members[i].name);
    }
  });
}
