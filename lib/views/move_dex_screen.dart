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

/// Sort column for the Move Dex list. Mirrors the same enum in
/// [_MovesTabState] (Pokémon Dex) — duplicated rather than shared
/// because the file-private scope keeps each dex's sort state from
/// leaking across screens.
enum _MoveSortKey { name, type, category, power, accuracy }

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
  // Learners (배우는 포켓몬) chip filter — without Champions-only on,
  // some moves' learner list runs to hundreds of species; this filter
  // narrows the visible chips by name. Substring match against
  // localized + English + JP names + aliases.
  final _learnersSearchCtl = TextEditingController();
  String _learnersQuery = '';

  // Filters + sort, mirroring the Pokémon Dex's Moves tab.
  PokemonType? _typeFilter;
  MoveCategory? _categoryFilter;
  // null = no user-driven sort → preserve `_allMoves` registration
  // order (the order they ship in the JSON files, which is roughly
  // chronological by introduction). Tapping a column header cycles
  // through default-direction → opposite-direction → back to null.
  _MoveSortKey? _sortKey;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    _learnersSearchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final movesFut = loadAllMoves();
    final invFut = loadInverseLearnsets();
    final pokedexFut = loadPokedex();

    final moves = await movesFut;
    moves.removeWhere((m) => m.moveClass != MoveClass.normal);
    // Intentionally NOT sorting here — `_allMoves` keeps the JSON
    // load order (≈ registration / chronological). The user can opt
    // into alphabetical or any other column via the sort header.

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

  /// Returns the list to render in the search pane. When the user
  /// has typed a query, results are scored and ordered by match
  /// quality (sort header is ignored — relevance wins). Otherwise
  /// the full move list is filtered by type/category and sorted by
  /// the active column.
  List<Move> _filteredMoves(String query) {
    bool typeOk(Move m) =>
        _typeFilter == null || m.type == _typeFilter;
    bool catOk(Move m) =>
        _categoryFilter == null || m.category == _categoryFilter;

    if (query.isNotEmpty) {
      final qLower = query.toLowerCase();
      final qRunes = qLower.runes.toList();
      final scored = <(Move, int)>[];
      for (final e in _searchEntries) {
        final m = e.item;
        if (!typeOk(m) || !catOk(m)) continue;
        final s = scoreEntry(qRunes, qLower, e);
        if (s > 0) scored.add((m, s));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.map((e) => e.$1).toList();
    }

    final out = _allMoves.where((m) => typeOk(m) && catOk(m)).toList();
    if (_sortKey != null) out.sort(_compare);
    return out;
  }

  int _compare(Move a, Move b) {
    int cmp;
    switch (_sortKey!) {
      case _MoveSortKey.name:
        cmp = a.localizedName.compareTo(b.localizedName);
      case _MoveSortKey.type:
        cmp = KoStrings.getTypeName(a.type)
            .compareTo(KoStrings.getTypeName(b.type));
      case _MoveSortKey.category:
        cmp = a.category.index.compareTo(b.category.index);
      case _MoveSortKey.power:
        cmp = a.power.compareTo(b.power);
      case _MoveSortKey.accuracy:
        cmp = a.accuracy.compareTo(b.accuracy);
    }
    if (cmp == 0 && _sortKey != _MoveSortKey.name) {
      cmp = a.localizedName.compareTo(b.localizedName);
    }
    return _sortAsc ? cmp : -cmp;
  }

  bool _defaultAsc(_MoveSortKey key) =>
      !(key == _MoveSortKey.power || key == _MoveSortKey.accuracy);

  void _toggleSort(_MoveSortKey key) {
    setState(() {
      final defaultAsc = _defaultAsc(key);
      if (_sortKey != key) {
        // First click on this column — start in the column's default
        // direction (numeric desc, text asc).
        _sortKey = key;
        _sortAsc = defaultAsc;
      } else if (_sortAsc == defaultAsc) {
        // Already at default direction → flip.
        _sortAsc = !defaultAsc;
      } else {
        // Already at opposite direction → cycle back to no-sort
        // (registration order). Gives the user a way out without an
        // explicit "reset" button.
        _sortKey = null;
        _sortAsc = true;
      }
    });
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
      // Cap the AppBar's visual chrome (background + shadow + bottom
      // border) at the body width so on wide screens the toolbar
      // sits centered above the panes instead of stretching across
      // the whole window.
      appBar: cappedAppBar(
        maxWidth: 1200,
        appBar: AppBar(
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(AppStrings.t('dex.move.title')),
          ),
        ),
      ),
      // Tap anywhere outside the search field → drop focus so the
      // mobile keyboard collapses and the typeahead-like list isn't
      // hovering "active". Same pattern as the Pokémon dex.
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _allMoves.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : widget.initialMoveName != null
              // Cross-link mode (e.g. tapped from Pokémon Dex's moves
              // tab): the user came for one specific move — render
              // only the detail, no search list. One back returns to
              // wherever they came from instead of stranding them on
              // a Move Dex search list they never asked for.
              ? LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth.clamp(0.0, 1200.0);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(width: w, child: _detailPane()),
                    );
                  },
                )
              : isWide
                  // See dex_screen.dart for why we use LayoutBuilder +
                  // a concrete SizedBox (rather than ConstrainedBox)
                  // for the height cap.
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
                                // Wider on web than the original 320
                                // so the type/category dropdowns +
                                // sortable columns fit comfortably.
                                // Detail pane still gets the larger
                                // half.
                                SizedBox(width: 480, child: _searchPane(pushOnTap: false)),
                                const VerticalDivider(width: 1),
                                Expanded(child: _detailPane()),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  // Narrow: full-screen search list. Tap pushes a
                  // dedicated detail screen so the result has room
                  // to breathe.
                  : _searchPane(pushOnTap: true),
      ),
    );
  }

  Widget _searchPane({bool pushOnTap = false}) {
    final filtered = _filteredMoves(_searchCtl.text);
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
              final results = _filteredMoves(_searchCtl.text);
              if (results.isNotEmpty) {
                _searchFocus.unfocus();
                _pickMove(results.first, pushOnTap);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Row(
            children: [
              _typeDropdown(),
              const SizedBox(width: 6),
              _categoryDropdown(),
            ],
          ),
        ),
        const Divider(height: 1),
        _sortHeader(),
        const Divider(height: 1),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppStrings.t('dex.noMovesMatch'),
                style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          Expanded(
            child: ListView.separated(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = filtered[i];
                final isSelected = _selected?.name == m.name;
                return _moveRow(m, isSelected: isSelected, push: pushOnTap);
              },
            ),
          ),
      ],
    );
  }

  Widget _moveRow(Move m, {required bool isSelected, required bool push}) {
    final categoryLabel = _categoryShort(m.category);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _pickMove(m, push),
      child: Container(
        // Selected row gets a subtle tint so the user can tell which
        // move is in the detail pane after a click.
        color: isSelected
            ? scheme.primary.withValues(alpha: 0.08)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(m.localizedName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 50,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: KoStrings.getTypeColor(m.type),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(KoStrings.getTypeName(m.type),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  child: Text(categoryLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ),
                SizedBox(
                  width: 36,
                  child: Text(m.power > 0 ? '${m.power}' : '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 36,
                  child: Text(m.accuracy > 0 ? '${m.accuracy}' : '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ),
              ],
            ),
            // Two-line description below the columns — same pattern as
            // Pokémon Dex's moves tab so the two lists feel like the
            // same kind of object.
            if (m.localizedDescription != null &&
                m.localizedDescription!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(m.localizedDescription!,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }

  Widget _typeDropdown() {
    // Encode "all types" as -1 — PopupMenuButton can't disambiguate
    // a null selection from a tap-outside dismissal.
    const allSentinel = -1;
    return PopupMenuButton<int>(
      tooltip: AppStrings.t('dex.allTypes'),
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        // Stack with an invisible "all" placeholder keeps the chip
        // width steady across selections so the row doesn't jitter.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(AppStrings.t('dex.allTypes'),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.transparent)),
            Text(
              _typeFilter == null
                  ? AppStrings.t('dex.allTypes')
                  : KoStrings.getTypeName(_typeFilter!),
              style: TextStyle(
                  fontSize: 12,
                  color: _typeFilter != null
                      ? KoStrings.getTypeColor(_typeFilter!)
                      : null,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: allSentinel,
          child: Text(AppStrings.t('dex.allTypes'),
              style: const TextStyle(fontSize: 13)),
        ),
        for (final t in PokemonType.values)
          if (t != PokemonType.typeless)
            PopupMenuItem(
              value: t.index,
              child: Text(KoStrings.getTypeName(t),
                  style: TextStyle(
                      fontSize: 13, color: KoStrings.getTypeColor(t))),
            ),
      ],
      onSelected: (v) => setState(() {
        _typeFilter = v == allSentinel ? null : PokemonType.values[v];
      }),
    );
  }

  Widget _categoryDropdown() {
    String label(MoveCategory? c) {
      if (c == null) return AppStrings.t('dex.allCategories');
      switch (c) {
        case MoveCategory.physical:
          return AppStrings.t('damage.physical');
        case MoveCategory.special:
          return AppStrings.t('damage.special');
        case MoveCategory.status:
          return AppStrings.t('damage.status');
      }
    }

    const allSentinel = -1;
    return PopupMenuButton<int>(
      tooltip: AppStrings.t('dex.allCategories'),
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(label(null),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.transparent)),
            Text(label(_categoryFilter),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: allSentinel,
          child: Text(label(null), style: const TextStyle(fontSize: 13)),
        ),
        for (final c in MoveCategory.values)
          PopupMenuItem(
            value: c.index,
            child: Text(label(c), style: const TextStyle(fontSize: 13)),
          ),
      ],
      onSelected: (v) => setState(() {
        _categoryFilter = v == allSentinel ? null : MoveCategory.values[v];
      }),
    );
  }

  Widget _sortHeader() {
    Widget headerCell({
      required _MoveSortKey key,
      required String label,
      required Widget Function(Widget child) wrap,
    }) {
      final active = _sortKey == key;
      // Hide the arrow when a search query is active — relevance
      // sort overrides column sort, and showing both is misleading.
      final searching = _searchCtl.text.isNotEmpty;
      final arrow = (active && !searching) ? (_sortAsc ? ' ↑' : ' ↓') : '';
      return InkWell(
        onTap: () => _toggleSort(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: wrap(
            Text(
              '$label$arrow',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: (active && !searching)
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: headerCell(
              key: _MoveSortKey.name,
              label: AppStrings.t('move.name'),
              wrap: (c) => Align(alignment: Alignment.centerLeft, child: c),
            ),
          ),
          SizedBox(
            width: 50,
            child: headerCell(
              key: _MoveSortKey.type,
              label: AppStrings.t('move.type'),
              wrap: (c) => Center(child: c),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: headerCell(
              key: _MoveSortKey.category,
              label: AppStrings.t('move.category'),
              wrap: (c) => Center(child: c),
            ),
          ),
          SizedBox(
            width: 36,
            child: headerCell(
              key: _MoveSortKey.power,
              label: AppStrings.t('move.power'),
              wrap: (c) => Center(child: c),
            ),
          ),
          SizedBox(
            width: 36,
            child: headerCell(
              key: _MoveSortKey.accuracy,
              label: AppStrings.t('move.accuracy'),
              wrap: (c) => Center(child: c),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the move detail content. When [move] is supplied, that
  /// move is shown directly — used by narrow's pushed sub-screen so it
  /// doesn't need to mutate `_selected` (which would leave the search
  /// list highlighting the row after the user pops back). Without
  /// [move], falls back to `_selected` for the wide split-pane case.
  Widget _detailPane({Move? move}) {
    final m = move ?? _selected;
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
          // Title row — name + type pill + " / " + category, packed
          // tight against the left so type/category aren't stranded
          // on the far edge of the (~720 px) detail pane. Long names
          // ellipsize before they push the badges off the row.
          Row(
            children: [
              Flexible(
                child: Text(
                  m.localizedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              _typePill(m.type, big: true),
              const SizedBox(width: 6),
              Text('/ ${_categoryShort(m.category)}',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade700)),
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
              final base = championsOnly
                  ? learners.where((p) => isInChampions(p.name)).toList()
                  : learners;
              // Apply the per-move learner-search filter on top of
              // Champions-only.
              final q = _learnersQuery.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? base
                  : base.where((p) {
                      bool match(String s) => s.toLowerCase().contains(q);
                      if (match(p.name) || match(p.nameKo) ||
                          match(p.nameJa)) return true;
                      return p.aliases.any(match);
                    }).toList();
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
                  // Learner-name filter — outer move list can stay
                  // unfiltered while the user narrows just the chips.
                  TextField(
                    controller: _learnersSearchCtl,
                    decoration: InputDecoration(
                      hintText: AppStrings.t('search.pokemon'),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() => _learnersQuery = v),
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
                          // tappable. We `push` (not pushReplacement)
                          // so the user can back out to whatever
                          // screen they were on before this move.
                          .map((p) => ActionChip(
                                onPressed: () => Navigator.of(context)
                                    .push(
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
      // Pass the move explicitly to _detailPane so we don't have to
      // mutate `_selected` — keeping `_selected` clean means the
      // search list underneath won't be left with a highlighted row
      // after the pushed detail is popped.
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(m.localizedName)),
          body: _detailPane(move: m),
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
