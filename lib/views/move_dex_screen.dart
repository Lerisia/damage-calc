import 'package:flutter/material.dart';

import '../data/learnsetdex.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../models/type.dart';
import '../utils/app_strings.dart';
import '../utils/korean_search.dart';
import '../utils/localization.dart';

/// Move dictionary screen. Mirrors the Pokémon dex screen's split layout
/// — search list on the left, selected-move detail on the right (wide)
/// or stacked (narrow). Detail shows base stats, tags, description, and
/// every Pokémon that learns the move (reverse-indexed from the
/// learnsets file).
class MoveDexScreen extends StatefulWidget {
  /// If supplied, the screen opens with this move selected (used by the
  /// future Pokémon-dex → move-dex cross-link).
  final String? initialMoveName;

  const MoveDexScreen({super.key, this.initialMoveName});

  @override
  State<MoveDexScreen> createState() => _MoveDexScreenState();
}

class _MoveDexScreenState extends State<MoveDexScreen> {
  List<Move> _allMoves = const [];
  List<SearchEntry<Move>> _searchEntries = const [];
  Map<String, List<String>> _inverseLearnsets = const {};
  // Showdown pokemon ID → first matching Pokemon. Form variants collapse
  // to whatever Pokémon entry happens to normalize to that Showdown ID;
  // good enough for "who learns this move" since Showdown's learnsets
  // are keyed by base-form anyway.
  Map<String, Pokemon> _showdownIdToPokemon = const {};

  Move? _selected;
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final movesFut = loadAllMoves();
    final invFut = loadInverseLearnsets();
    final pokedexFut = loadPokedex();

    final moves = await movesFut;
    moves.removeWhere((m) => m.moveClass != MoveClass.normal);
    moves.sort((a, b) => a.localizedName.compareTo(b.localizedName));

    final inv = await invFut;
    final pokedex = await pokedexFut;

    final byShowdownId = <String, Pokemon>{};
    for (final p in pokedex) {
      final id = toShowdownPokemonId(p.name,
          nameKo: p.nameKo, dexNumber: p.dexNumber);
      byShowdownId.putIfAbsent(id, () => p);
    }

    if (!mounted) return;
    setState(() {
      _allMoves = moves;
      _searchEntries = moves
          .map((m) => SearchEntry(m, m.nameKo, m.name,
              nameJa: m.nameJa, aliases: m.aliases))
          .toList();
      _inverseLearnsets = inv;
      _showdownIdToPokemon = byShowdownId;
      if (widget.initialMoveName != null) {
        _selected = moves.firstWhere(
          (m) => m.name == widget.initialMoveName,
          orElse: () => moves.first,
        );
      }
    });
  }

  List<Move> _filteredMoves(String query) {
    if (query.isEmpty) return _allMoves;
    final qLower = query.toLowerCase();
    final qRunes = qLower.runes.toList();
    final scored = <(Move, int)>[];
    for (final e in _searchEntries) {
      final s = scoreEntry(qRunes, qLower, e);
      if (s > 0) scored.add((e.item, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  List<Pokemon> _learnersOf(Move m) {
    final id = toShowdownMoveId(m.name);
    final ids = _inverseLearnsets[id];
    if (ids == null || ids.isEmpty) return const [];
    final out = <Pokemon>[];
    final seen = <String>{};
    for (final pid in ids) {
      final p = _showdownIdToPokemon[pid];
      if (p != null && seen.add(p.name)) out.add(p);
    }
    out.sort((a, b) => a.dexNumber.compareTo(b.dexNumber));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('dex.move.title'))),
      body: _allMoves.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : isWide
              // Wide: search left, detail right — both visible at once.
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 320, child: _searchPane(pushOnTap: false)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _detailPane()),
                  ],
                )
              // Narrow: full-screen search list. Tap pushes a dedicated
              // detail screen so the result has room to breathe.
              : _searchPane(pushOnTap: true),
    );
  }

  Widget _searchPane({bool pushOnTap = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: _searchCtl,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: AppStrings.t('dex.move.search'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              final filtered = _filteredMoves(_searchCtl.text);
              if (filtered.isNotEmpty) {
                _searchFocus.unfocus();
                _pickMove(filtered.first, pushOnTap);
              }
            },
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            final filtered = _filteredMoves(_searchCtl.text);
            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final m = filtered[i];
                final isSelected = _selected?.name == m.name;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  selected: isSelected,
                  title: Text(m.localizedName, style: const TextStyle(fontSize: 14)),
                  subtitle: Row(
                    children: [
                      _typePill(m.type),
                      const SizedBox(width: 6),
                      Text(_categoryShort(m.category),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      if (m.power > 0) ...[
                        const SizedBox(width: 8),
                        Text('${m.power}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                  onTap: () => _pickMove(m, pushOnTap),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _detailPane() {
    final m = _selected;
    if (m == null) {
      return Center(
        child: Text(AppStrings.t('dex.move.search'),
            style: TextStyle(color: Colors.grey[500])),
      );
    }
    final learners = _learnersOf(m);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.localizedName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              _typePill(m.type, big: true),
              const SizedBox(width: 6),
              Text(_categoryShort(m.category),
                  style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _statsRow(m),
          if (m.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 4, runSpacing: 4,
              children: m.tags
                  .map((t) => Chip(
                        label: Text(_tagDisplay(t),
                            style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          if ((m.localizedDescription ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(m.localizedDescription!,
                style: TextStyle(fontSize: 13, color: Colors.grey[800])),
          ],
          const SizedBox(height: 20),
          Text('${AppStrings.t('dex.move.learners')} (${learners.length})',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (learners.isEmpty)
            Text(AppStrings.t('dex.move.noLearners'),
                style: TextStyle(fontSize: 13, color: Colors.grey[500]))
          else
            Wrap(
              spacing: 6, runSpacing: 6,
              children: learners
                  .map((p) => Chip(
                        label: Text(
                          '#${p.dexNumber}  ${p.localizedName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _statsRow(Move m) {
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Row(
      children: [
        cell(AppStrings.t('move.power'), m.power == 0 ? '—' : '${m.power}'),
        cell(AppStrings.t('move.accuracy'),
            m.accuracy == 0 ? '—' : '${m.accuracy}'),
        cell('PP', '${m.pp}'),
        cell(AppStrings.t('move.priority'),
            m.priority == 0 ? '0' : (m.priority > 0 ? '+${m.priority}' : '${m.priority}')),
        if (m.isMultiHit)
          cell(AppStrings.t('move.hits'),
              m.minHits == m.maxHits ? '${m.minHits}' : '${m.minHits}~${m.maxHits}'),
      ],
    );
  }

  Widget _typePill(PokemonType t, {bool big = false}) {
    final color = KoStrings.getTypeColor(t);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 8 : 6, vertical: big ? 3 : 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(KoStrings.getTypeName(t),
          style: TextStyle(
              fontSize: big ? 12 : 10,
              color: Colors.white,
              fontWeight: FontWeight.bold)),
    );
  }

  void _pickMove(Move m, bool push) {
    if (push) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(m.localizedName)),
          body: Builder(builder: (_) {
            // Temporarily set _selected so _detailPane reads off the
            // tapped move; the wrapper Scaffold owns the back button.
            _selected = m;
            return _detailPane();
          }),
        ),
      ));
    } else {
      setState(() => _selected = m);
    }
  }

  String _categoryShort(MoveCategory c) => switch (c) {
        MoveCategory.physical => AppStrings.t('damage.physical'),
        MoveCategory.special => AppStrings.t('damage.special'),
        MoveCategory.status => AppStrings.t('move.fixed'),
      };

  String _tagDisplay(String tag) {
    // Standard (non-custom) tags get a localized label; custom internals
    // (always_crit, has_secondary, etc.) fall back to their bare slug
    // for now.
    const standard = {
      'contact': 'tag.contact',
      'punch': 'tag.punch',
      'sound': 'tag.sound',
      'bite': 'tag.bite',
      'pulse': 'tag.pulse',
      'slice': 'tag.slice',
      'recoil': 'tag.recoil',
      'ball': 'tag.ball',
      'powder': 'tag.powder',
      'wind': 'tag.wind',
    };
    final key = standard[tag];
    if (key != null) return AppStrings.t(key);
    if (tag.startsWith('custom:')) return tag.substring(7);
    return tag;
  }
}
