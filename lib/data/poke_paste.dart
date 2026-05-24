/// Pokémon Showdown "PokePaste" encoder/decoder for the calculator's
/// share strings. The textual format is much shorter than the legacy
/// JSON+gzip+base64 payload and is directly compatible with Smogon
/// teambuilder exports.
///
/// We carry only the team-builder state — species/item/ability/level/
/// nature/EVs/IVs/moves/tera type. Battle-only state (HP%, rank, status,
/// dynamax/terastal activation, per-move toggles, ally support, ...) is
/// intentionally dropped: on import everything resets to "fresh".

import '../models/battle_pokemon.dart';
import '../models/gender.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/nature.dart';
import '../models/nature_profile.dart';
import '../models/pokemon.dart';
import '../models/stats.dart';
import '../models/terastal.dart';
import '../models/type.dart';
import 'sample_storage.dart' show StoredSample;

class PokePaste {
  PokePaste._();

  // ── Encode ─────────────────────────────────────────────────────────

  /// Encode a single sample as a PokePaste block.
  static String encodeSample(
    StoredSample sample, {
    required Map<String, Item> itemsById,
  }) {
    return _encodeSet(sample.name, sample.state, itemsById: itemsById);
  }

  /// Encode a team. Sets are separated by a blank line. When [teamName]
  /// is non-empty it appears as a PokePaste-style `=== name ===` header.
  static String encodeTeam(
    String? teamName,
    List<({String name, BattlePokemonState state})> members, {
    required Map<String, Item> itemsById,
  }) {
    final buf = StringBuffer();
    if (teamName != null && teamName.isNotEmpty) {
      buf.write('=== $teamName ===\n\n');
    }
    for (var i = 0; i < members.length; i++) {
      if (i > 0) buf.write('\n\n');
      buf.write(_encodeSet(members[i].name, members[i].state,
          itemsById: itemsById));
    }
    return buf.toString();
  }

  static String _encodeSet(
    String nickname,
    BattlePokemonState state, {
    required Map<String, Item> itemsById,
  }) {
    final buf = StringBuffer();

    // Line 1: [Nickname ](Species)[ (Gender)][ @ Item]
    final species = state.pokemonName;
    final showNick = nickname.isNotEmpty && nickname != species;
    if (showNick) {
      buf.write(nickname);
      buf.write(' (');
      buf.write(species);
      buf.write(')');
    } else {
      buf.write(species);
    }
    if (state.gender == Gender.male) {
      buf.write(' (M)');
    } else if (state.gender == Gender.female) {
      buf.write(' (F)');
    }
    final itemId = state.selectedItem;
    if (itemId != null && itemId.isNotEmpty) {
      final display = itemsById[itemId]?.nameEn ?? _kebabToTitle(itemId);
      buf.write(' @ ');
      buf.write(display);
    }

    // Ability
    final ability = state.selectedAbility;
    if (ability != null && ability.isNotEmpty) {
      buf.write('\nAbility: ');
      buf.write(ability);
    }

    // Level (omit when 100)
    if (state.level != 100) {
      buf.write('\nLevel: ');
      buf.write(state.level);
    }

    // Tera Type (only when explicitly chosen)
    final teraType = state.terastal.teraType;
    if (teraType != null) {
      buf.write('\nTera Type: ');
      buf.write(_capitalize(teraType.name));
    }

    // EVs — omit when all zero, list only non-zero stats.
    final evParts = _statParts(state.ev, omit: 0);
    if (evParts.isNotEmpty) {
      buf.write('\nEVs: ');
      buf.write(evParts);
    }

    // Nature
    buf.write('\n');
    buf.write(_capitalize((state.nature.asNature() ?? Nature.hardy).name));
    buf.write(' Nature');

    // IVs — omit when all 31, list only non-31 stats.
    final ivParts = _statParts(state.iv, omit: 31);
    if (ivParts.isNotEmpty) {
      buf.write('\nIVs: ');
      buf.write(ivParts);
    }

    // Moves (up to 4, skip empty slots)
    for (final m in state.moves) {
      if (m == null) continue;
      buf.write('\n- ');
      buf.write(m.name);
    }

    return buf.toString();
  }

  static String _statParts(Stats s, {required int omit}) {
    final parts = <String>[];
    void add(int v, String label) {
      if (v != omit) parts.add('$v $label');
    }
    add(s.hp, 'HP');
    add(s.attack, 'Atk');
    add(s.defense, 'Def');
    add(s.spAttack, 'SpA');
    add(s.spDefense, 'SpD');
    add(s.speed, 'Spe');
    return parts.join(' / ');
  }

  // ── Sniffing ───────────────────────────────────────────────────────

  /// Rough check: does [text] look like a PokePaste block?
  static bool looksLikePokePaste(String text) {
    final t = text.trim();
    if (t.isEmpty || t.startsWith('damacalc:')) return false;
    final lines = t.split('\n');
    if (lines.first.trim().isEmpty) return false;
    for (final line in lines.skip(1)) {
      final l = line.trim();
      if (l.startsWith('Ability:') ||
          l.startsWith('- ') ||
          l.endsWith(' Nature') ||
          l.startsWith('EVs:') ||
          l.startsWith('IVs:') ||
          l.startsWith('Tera Type:') ||
          l.startsWith('Level:')) {
        return true;
      }
    }
    return false;
  }

  /// True when the input is a PokePaste TEAM (multiple sets or has a
  /// `=== name ===` header). Single-set blocks return false.
  static bool looksLikePokePasteTeam(String text) {
    final t = text.trim();
    if (t.startsWith('===')) return true;
    final blocks = t.split(RegExp(r'\n\s*\n'))
        .where((b) => b.trim().isNotEmpty)
        .toList();
    return blocks.length > 1 && looksLikePokePaste(blocks.first);
  }

  // ── Decode ─────────────────────────────────────────────────────────

  /// Decode a single set. Throws [FormatException] on missing/unknown
  /// species or otherwise malformed input.
  static StoredSample decodeSample(
    String text, {
    required Map<String, Pokemon> pokemonByName,
    required Map<String, String> itemDisplayToId,
    required Map<String, Move> moveByName,
  }) {
    return _decodeSet(text.trim(),
        pokemonByName: pokemonByName,
        itemDisplayToId: itemDisplayToId,
        moveByName: moveByName);
  }

  /// Decode a team, returning the optional `=== name ===` header and
  /// each member (with the nickname carried as the member name).
  static ({String? name, List<({String name, BattlePokemonState state})> members})
      decodeTeam(
    String text, {
    required Map<String, Pokemon> pokemonByName,
    required Map<String, String> itemDisplayToId,
    required Map<String, Move> moveByName,
  }) {
    var body = text.trim();
    String? teamName;
    final header = RegExp(r'^===\s*(.+?)\s*===\s*\n?').firstMatch(body);
    if (header != null) {
      teamName = header.group(1);
      body = body.substring(header.end).trim();
    }
    final blocks = body
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    if (blocks.isEmpty) {
      throw const FormatException('No sets found in team text');
    }
    final members = <({String name, BattlePokemonState state})>[];
    for (final b in blocks) {
      final s = _decodeSet(b,
          pokemonByName: pokemonByName,
          itemDisplayToId: itemDisplayToId,
          moveByName: moveByName);
      members.add((name: s.name, state: s.state));
    }
    return (name: teamName, members: members);
  }

  static StoredSample _decodeSet(
    String text, {
    required Map<String, Pokemon> pokemonByName,
    required Map<String, String> itemDisplayToId,
    required Map<String, Move> moveByName,
  }) {
    final lines = text.split('\n').map((l) => l.trimRight()).toList();
    if (lines.isEmpty || lines.first.trim().isEmpty) {
      throw const FormatException('Missing species line');
    }
    final head = _parseHeaderLine(lines.first.trim());
    final species = head.species;
    final nickname = head.nickname ?? species;

    // Species lookup (exact, then case-insensitive fallback).
    var pokemon = pokemonByName[species];
    if (pokemon == null) {
      final lower = species.toLowerCase();
      for (final entry in pokemonByName.entries) {
        if (entry.key.toLowerCase() == lower) {
          pokemon = entry.value;
          break;
        }
      }
    }
    if (pokemon == null) {
      throw FormatException('Unknown species: $species');
    }

    final state = BattlePokemonState();
    state.applyPokemon(pokemon);
    if (head.gender != null) state.gender = head.gender!;

    if (head.item != null) {
      final id = itemDisplayToId[head.item!.toLowerCase()] ??
          _titleToKebab(head.item!);
      state.selectedItem = id;
    }

    var evs = const Stats(
        hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);
    var ivs = const Stats(
        hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);
    Nature? nature;
    final moves = <Move>[];

    for (final raw in lines.skip(1)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('Ability:')) {
        state.selectedAbility =
            line.substring('Ability:'.length).trim();
      } else if (line.startsWith('Level:')) {
        final v = int.tryParse(line.substring('Level:'.length).trim());
        if (v != null) state.level = v.clamp(1, 100);
      } else if (line.startsWith('Tera Type:')) {
        final raw = line.substring('Tera Type:'.length).trim().toLowerCase();
        for (final t in PokemonType.values) {
          if (t.name == raw) {
            state.terastal = TerastalState(teraType: t);
            break;
          }
        }
      } else if (line.startsWith('EVs:')) {
        evs = _parseStatLine(line.substring('EVs:'.length).trim(),
            fill: 0);
      } else if (line.startsWith('IVs:')) {
        ivs = _parseStatLine(line.substring('IVs:'.length).trim(),
            fill: 31);
      } else if (line.startsWith('- ')) {
        final name = line.substring(2).trim();
        // "Hidden Power [Type]" → bare "Hidden Power" for lookup.
        final hp = RegExp(r'^Hidden Power(\s*\[.+\])?$').firstMatch(name);
        final lookup = hp != null ? 'Hidden Power' : name;
        final m = moveByName[lookup] ??
            moveByName[lookup.toLowerCase()] ??
            _moveByLooseName(moveByName, lookup);
        if (m != null && moves.length < 4) moves.add(m);
      } else if (line.endsWith(' Nature')) {
        final n = line
            .substring(0, line.length - ' Nature'.length)
            .trim()
            .toLowerCase();
        for (final nat in Nature.values) {
          if (nat.name == n) {
            nature = nat;
            break;
          }
        }
      }
      // Silently skip Shiny:, Happiness:, Dynamax Level: etc.
    }

    state.ev = evs;
    state.iv = ivs;
    state.nature = NatureProfile.fromNature(nature ?? Nature.hardy);
    state.moves = [
      moves.isNotEmpty ? moves[0] : null,
      moves.length > 1 ? moves[1] : null,
      moves.length > 2 ? moves[2] : null,
      moves.length > 3 ? moves[3] : null,
    ];

    return StoredSample(id: '', name: nickname, state: state);
  }

  static ({String species, String? nickname, Gender? gender, String? item})
      _parseHeaderLine(String line) {
    var rest = line;
    String? item;
    final atIdx = rest.lastIndexOf('@');
    if (atIdx >= 0) {
      item = rest.substring(atIdx + 1).trim();
      rest = rest.substring(0, atIdx).trim();
    }
    Gender? gender;
    final gMatch = RegExp(r'\((M|F)\)$').firstMatch(rest);
    if (gMatch != null) {
      gender = gMatch.group(1) == 'M' ? Gender.male : Gender.female;
      rest = rest.substring(0, gMatch.start).trim();
    }
    final nick = RegExp(r'^(.+?)\s*\((.+)\)$').firstMatch(rest);
    if (nick != null) {
      return (
        species: nick.group(2)!.trim(),
        nickname: nick.group(1)!.trim(),
        gender: gender,
        item: item,
      );
    }
    return (species: rest.trim(), nickname: null, gender: gender, item: item);
  }

  static Stats _parseStatLine(String spec, {required int fill}) {
    var hp = fill, atk = fill, def = fill;
    var spa = fill, spd = fill, spe = fill;
    for (final part in spec.split('/').map((p) => p.trim())) {
      final m = RegExp(r'^(\d+)\s+([A-Za-z]+)$').firstMatch(part);
      if (m == null) continue;
      final v = int.parse(m.group(1)!);
      switch (m.group(2)!.toLowerCase()) {
        case 'hp':
          hp = v;
          break;
        case 'atk':
          atk = v;
          break;
        case 'def':
          def = v;
          break;
        case 'spa':
          spa = v;
          break;
        case 'spd':
          spd = v;
          break;
        case 'spe':
          spe = v;
          break;
      }
    }
    return Stats(
        hp: hp,
        attack: atk,
        defense: def,
        spAttack: spa,
        spDefense: spd,
        speed: spe);
  }

  /// Last-ditch case-insensitive move lookup.
  static Move? _moveByLooseName(Map<String, Move> moveByName, String name) {
    final lower = name.toLowerCase();
    for (final e in moveByName.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }
    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────────

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  /// `focus-sash` → `Focus Sash`. Used as a fallback for items we have
  /// no `nameEn` for (rare — items.json typically supplies it).
  static String _kebabToTitle(String kebab) =>
      kebab.split('-').map(_capitalize).join(' ');

  /// `Focus Sash` → `focus-sash`. Fallback for unknown item display
  /// names; the items-by-display map handles the common case.
  static String _titleToKebab(String display) => display
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
