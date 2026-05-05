import 'package:flutter/material.dart';

import '../data/champions_usage.dart';
import '../data/learnsetdex.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../models/type.dart';
import '../utils/app_strings.dart';
import '../utils/champions_filter_controller.dart';
import '../utils/korean_search.dart';
import '../utils/localization.dart';
import '../utils/page_routes.dart';
import 'dex_screen.dart';

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
  // Per-move learners cache, populated on first lookup. Detail pane
  // rebuilds on every setState (e.g. theme change) so without this we
  // were re-walking + sorting ~60 entries per frame.
  final Map<String, List<Pokemon>> _learnersCache = {};

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
    final cached = _learnersCache[id];
    if (cached != null) return cached;
    final ids = _inverseLearnsets[id];
    if (ids == null || ids.isEmpty) {
      _learnersCache[id] = const [];
      return const [];
    }
    final out = <Pokemon>[];
    final seen = <String>{};
    for (final pid in ids) {
      final p = _showdownIdToPokemon[pid];
      if (p != null && seen.add(p.name)) out.add(p);
    }
    out.sort((a, b) => a.dexNumber.compareTo(b.dexNumber));
    _learnersCache[id] = out;
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // Match the coverage screen's wide breakpoint (1050) and cap so
    // both dex screens feel consistent on the same device. On 4K
    // monitors the detail pane used to stretch the whole width — now
    // it stops at iPad-Pro-landscape * a bit.
    final isWide = MediaQuery.of(context).size.width >= 1050;
    return Scaffold(
      // Cap the AppBar title to match the body width so the title text
      // visually anchors above the body cap on wide windows. AppBar
      // background still spans full width as standard chrome.
      appBar: AppBar(
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              // Match the leading icon's natural inset so the title
              // sits where you'd expect, not flush against the back
              // arrow.
              padding: const EdgeInsets.only(left: 8),
              child: Text(AppStrings.t('dex.move.title')),
            ),
          ),
        ),
      ),
      body: _allMoves.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : isWide
              // See dex_screen.dart for why we use LayoutBuilder + a
              // concrete SizedBox (rather than ConstrainedBox) for
              // the height cap.
              ? LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth.clamp(0.0, 1200.0);
                    final h = c.maxHeight.clamp(0.0, 900.0);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 320, child: _searchPane(pushOnTap: false)),
                            const VerticalDivider(width: 1),
                            Expanded(child: _detailPane()),
                          ],
                        ),
                      ),
                    );
                  },
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
          // Hide internal `custom:*` tags from the dex — they're game-
          // logic flags (has_secondary, use_opponent_atk, …) that read
          // as noise to a casual reader. Only the standard contact /
          // punch / sound / etc. set is shown.
          if (m.tags.any((t) => !t.startsWith('custom:'))) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 4, runSpacing: 4,
              children: m.tags
                  .where((t) => !t.startsWith('custom:'))
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
          ValueListenableBuilder<bool>(
            valueListenable:
                ChampionsFilterController.instance.championsOnly,
            builder: (context, championsOnly, _) {
              final filtered = championsOnly
                  ? learners.where((p) => isInChampions(p.name)).toList()
                  : learners;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${AppStrings.t('dex.move.learners')} (${filtered.length})',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      _MoveDexChampionsToggle(
                        value: championsOnly,
                        onChanged: (v) => ChampionsFilterController
                            .instance
                            .set(v ?? false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Text(AppStrings.t('dex.move.noLearners'),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500]))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: filtered
                          // ActionChip (not Chip) so each pill is
                          // tappable. pushReplacement keeps the nav
                          // stack flat: cross-linking Pokémon Dex ↔
                          // Move Dex never deepens beyond the calc →
                          // dex pair.
                          .map((p) => ActionChip(
                                onPressed: () => Navigator.of(context)
                                    .pushReplacement(
                                  fadeRoute((_) => DexScreen(
                                      initialPokemonName: p.name)),
                                ),
                                label: Text(
                                  '#${p.dexNumber}  ${p.localizedName}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                ],
              );
            },
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
    final isStatus = m.category == MoveCategory.status;
    return Row(
      children: [
        // Status moves carry no damage; hide the power column entirely
        // rather than show "0" or "—".
        if (!isStatus)
          cell(AppStrings.t('move.power'), '${m.power}'),
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
        MoveCategory.status => AppStrings.t('damage.status'),
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

/// Compact "Champions only" checkbox used inside the Move Dex's
/// learners-list header. Matches the AppBar variant in dex_screen.dart
/// but without the right-side AppBar padding.
class _MoveDexChampionsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _MoveDexChampionsToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Text(AppStrings.t('dex.championsOnly'),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
