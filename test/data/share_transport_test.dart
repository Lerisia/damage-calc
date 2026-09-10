import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/itemdex.dart';
import 'package:damage_calc/data/movedex.dart';
import 'package:damage_calc/data/poke_paste.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/data/sample_storage.dart';
import 'package:damage_calc/models/battle_pokemon.dart';

/// A party copied on the web app and pasted on a phone travels through
/// a messenger or notes app first, and those routinely rewrite the
/// text: CRLF line endings, trailing spaces, and — the one that bit
/// users on 2026-09-10 — collapsed blank lines, which made the team
/// parser read six Pokémon as one set and import only the first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> dx;
  late String code;
  const picks = ['Mega Absol Z', 'Indeedee (Female)', 'Pawmot', 'Rillaboom', 'Toxtricity (Low Key Form)', 'Mega Golisopod'];

  setUpAll(() async {
    final pokedex = await loadPokedex(); final moves = await loadMovedex(); final items = await loadItemdex();
    final byName = {for (final p in pokedex) p.name: p};
    dx = {
      'byName': byName, 'items': items, 'moves': moves,
      'displayToId': {for (final e in items.entries) if (e.value.nameEn != null) e.value.nameEn!.toLowerCase(): e.key},
    };
    final members = [for (final s in picks) (name: s, state: BattlePokemonState()..applyPokemon(byName[s]!))];
    code = PokePaste.encodeTeam('M-C 파티', members, itemsById: items);
  });

  int decodeCount(String text) => PokePaste.decodeTeam(text,
      pokemonByName: dx['byName'], itemDisplayToId: dx['displayToId'], moveByName: dx['moves']).members.length;

  final variants = <String, String Function(String)>{
    'as-is': (c) => c,
    'CRLF': (c) => c.replaceAll('\n', '\r\n'),
    'blank lines collapsed': (c) => c.replaceAll(RegExp(r'\n\s*\n'), '\n'),
    'no === header': (c) => c.split('\n').skip(2).join('\n'),
    'trailing spaces': (c) => c.split('\n').map((l) => '$l  ').join('\n'),
  };
  for (final v in variants.entries) {
    test('team survives transport: ${v.key}', () {
      final text = v.value(code);
      expect(SampleStorage.isShareString(text), isTrue);
      expect(SampleStorage.isTeamShareString(text), isTrue);
      expect(decodeCount(text), picks.length);
    });
  }
}
