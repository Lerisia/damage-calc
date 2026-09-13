part of '../dex_screen.dart';

class _MovesTab extends StatefulWidget {
  final Pokemon? pokemon;
  final Set<String> learnable; // showdown move IDs
  final Map<String, Move> moveDex; // keyed by display name (English)
  final bool loading;

  const _MovesTab({
    required this.pokemon,
    required this.learnable,
    required this.moveDex,
    required this.loading,
  });

  @override
  State<_MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<_MovesTab> {
  String _query = '';
  PokemonType? _typeFilter;
  MoveCategory? _categoryFilter;
  MoveSortKey _sortKey = MoveSortKey.name;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    // Rebuild the move list when the Champions filter flips so
    // non-Champions moves drop out live.
    ChampionsFilterController.instance.championsOnly
        .addListener(_onChampionsFilterChanged);
  }

  void _onChampionsFilterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ChampionsFilterController.instance.championsOnly
        .removeListener(_onChampionsFilterChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(_MovesTab old) {
    super.didUpdateWidget(old);
    // When the pokemon (and so the learnable set) changes, drop any
    // filter that no longer matches anything so the user isn't stuck
    // on an empty list. Safe to mutate directly here — didUpdateWidget
    // runs during rebuild, no extra setState needed.
    if (old.learnable != widget.learnable || old.moveDex != widget.moveDex) {
      final types = _availableTypes();
      if (_typeFilter != null && !types.contains(_typeFilter)) {
        _typeFilter = null;
      }
      final cats = _availableCategories();
      if (_categoryFilter != null && !cats.contains(_categoryFilter)) {
        _categoryFilter = null;
      }
    }
  }

  bool _champOk(Move m) =>
      !ChampionsFilterController.instance.championsOnly.value ||
      isChampionsMove(m.name);

  Set<PokemonType> _availableTypes() {
    final out = <PokemonType>{};
    for (final m in widget.moveDex.values) {
      if (widget.learnable.contains(toShowdownMoveId(m.name)) &&
          _champOk(m)) {
        out.add(m.type);
      }
    }
    return out;
  }

  Set<MoveCategory> _availableCategories() {
    final out = <MoveCategory>{};
    for (final m in widget.moveDex.values) {
      if (widget.learnable.contains(toShowdownMoveId(m.name)) &&
          _champOk(m)) {
        out.add(m.category);
      }
    }
    return out;
  }

  void _toggleSort(MoveSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        // Power/accuracy default to descending (big → small) since
        // that's almost always what you want when ranking moves.
        _sortAsc = moveSortDefaultAsc(key);
      }
    });
  }

  int _compare(Move a, Move b) =>
      compareMoves(a, b, _sortKey, asc: _sortAsc);

  List<Move> _filtered() {
    if (widget.pokemon == null) return [];
    final ids = widget.learnable;
    final champOnly =
        ChampionsFilterController.instance.championsOnly.value;
    // Share the app-wide search engine (초성 / alias / prefix scoring)
    // instead of a bespoke `contains`. Precompute the query runes once;
    // a positive scoreEntry is the match predicate. Column sort below
    // is intentionally kept as this tab's ordering (its headers are
    // tappable), so search only narrows the set — it doesn't reorder.
    final qLower = _query.toLowerCase();
    final qRunes = qLower.runes.toList();
    final searching = _query.isNotEmpty;
    final out = <Move>[];
    for (final m in widget.moveDex.values) {
      // Skip calc-only variants (Magnitude 4-10 etc.) — the canonical
      // synthetic entry shows up via its own row instead.
      if (m.hasTag(MoveTags.dexHidden)) continue;
      final mid = toShowdownMoveId(m.name);
      if (!ids.contains(mid)) continue;
      // Champions-only: hide moves the game doesn't include.
      if (champOnly && !isChampionsMove(m.name)) continue;
      if (_typeFilter != null && m.type != _typeFilter) continue;
      if (_categoryFilter != null && m.category != _categoryFilter) continue;
      if (searching) {
        final entry = SearchEntry(m, m.nameKo, m.name,
            nameJa: m.nameJa, aliases: m.aliases);
        if (scoreEntry(qRunes, qLower, entry) <= 0) continue;
      }
      out.add(m);
    }
    out.sort(_compare);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pokemon == null) {
      return const SizedBox.shrink();
    }
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final moves = _filtered();
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppStrings.t('dex.searchMoves'),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                _typeDropdown(),
                const SizedBox(width: 4),
                _categoryDropdown(),
              ],
            ),
          ),
          const Divider(height: 1),
          _sortHeader(),
          const Divider(height: 1),
          if (moves.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(AppStrings.t('dex.noMovesMatch'),
                  style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            Expanded(
              child: ListView.separated(
                // Dismiss keyboard on scroll — users who start dragging
                // the list shouldn't have to reach up to close it.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                // Match the main tab's bottom inset so the last move
                // row stays comfortably above the system gesture bar.
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: moves.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _moveRow(moves[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _typeDropdown() => TypeFilterChip(
        value: _typeFilter,
        available: _availableTypes(),
        onChanged: (t) => setState(() => _typeFilter = t),
      );

  Widget _categoryDropdown() => CategoryFilterChip(
        value: _categoryFilter,
        available: _availableCategories(),
        onChanged: (c) => setState(() => _categoryFilter = c),
      );

  Widget _sortHeader() => MoveSortHeader(
        sortKey: _sortKey, asc: _sortAsc, onTap: _toggleSort);

  Widget _moveRow(Move m) {
    final categoryLabel = switch (m.category) {
      MoveCategory.physical => AppStrings.t('damage.physical'),
      MoveCategory.special => AppStrings.t('damage.special'),
      MoveCategory.status => AppStrings.t('damage.status'),
    };
    return InkWell(
      // Cross-link to the Move Dex tab's detail of this move. With
      // the RootShell tab architecture this switches to the Move
      // Dex tab and pushes the detail onto its nested navigator —
      // back returns to the move list (still on the Move Dex tab),
      // and switching back to the Pokémon Dex tab restores this
      // pokemon's detail unchanged.
      onTap: () => RootShell.of(context).requestMoveDexDetail(m.name),
      child: Padding(
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
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade700)),
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
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
            ],
          ),
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
}
