import 'package:flutter/material.dart';

import '../data/abilitydex.dart';
import '../data/champions_moves.dart';
import '../data/champions_usage.dart';
import '../data/learnsetdex.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../models/ability.dart';
import '../models/battle_pokemon.dart';
import '../models/move.dart';
import '../models/move_tags.dart';
import '../models/nature_profile.dart';
import '../models/pokemon.dart';
import '../models/room.dart';
import '../models/stats.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';
import '../i18n/app_strings.dart';
import '../calc/battle_facade.dart';
import '../controllers/champions_filter_controller.dart';
import '../search/korean_search.dart';
import '../platform/page_routes.dart';
import '../i18n/localization.dart';
import '../calc/stacking_moves.dart';
import '../calc/terrain_effects.dart' show abilityTerrainMap;
import '../calc/ability_effects.dart';
import '../calc/weather_effects.dart' show abilityWeatherMap;
import 'root_shell.dart';
import 'widgets/app_bottom_nav.dart' show AppNavTab;
import 'widgets/app_settings_menu.dart';
import 'widgets/dex_search_filter_dialog.dart';
import 'widgets/matchup_badge.dart';
import 'widgets/move_selector.dart';
import 'widgets/pokemon_sprite.dart';
import '../data/ability_variants.dart';
import 'widgets/type_chip.dart';
import 'widgets/move_table_controls.dart';

part 'dex/main_tab.dart';
part 'dex/header.dart';
part 'dex/sections.dart';
part 'dex/moves_tab.dart';

/// Pokédex screen — browse Pokémon and see species info, abilities,
/// type matchups, and learnable moves. Reuses KoStrings for type
/// colors / names so the visual language matches the calculator.
/// Sort column for the Pokémon Dex browse list. A null sort key keeps
/// dex-number order; tapping a stat header sorts by that stat.
enum _DexSortKey { name, hp, atk, def, spa, spd, spe, bst }

class DexScreen extends StatefulWidget {
  /// If non-null, opens directly on this Pokemon's page (used by the
  /// "open in dex" button on the calculator panels).
  final String? initialPokemonName;

  /// True when this DexScreen was pushed on top of the browse list
  /// (narrow-width tap on a row). Lets the detail page's PopScope
  /// allow iOS swipe-back, since the route below is the list and a
  /// normal pop lands the user back on the list with all state
  /// preserved via [_DexBrowseStore]. Cross-link mode from the
  /// calculator keeps canPop=false because the route below is the
  /// calc, not a list — the back arrow's pushReplacement handles
  /// that path instead.
  final bool fromList;

  const DexScreen({
    super.key,
    this.initialPokemonName,
    this.fromList = false,
  });

  @override
  State<DexScreen> createState() => _DexScreenState();
}

/// Process-lifetime store for the browse-mode list's view state —
/// scroll offset, name search text, advanced search filter, and
/// sort. Persists across the cross-link detail flow (pushed on top
/// of the list) AND across the pushReplacement the dex back-button
/// uses to land users on the list from the calc cross-link. The
/// fresh DexScreen seeds its controllers from here in initState so
/// nothing visible resets when the user pops a detail. Cleared
/// only on app restart.
class _DexBrowseStore {
  _DexBrowseStore._();
  static double scrollOffset = 0.0;
  static String searchText = '';
  static DexSearchFilter filter = DexSearchFilter.empty;
  static _DexSortKey? sortKey;
  static bool sortAsc = true;
}

class _DexScreenState extends State<DexScreen> {
  Pokemon? _selected;

  List<Pokemon> _allPokemon = const [];
  List<SearchEntry<Pokemon>> _searchEntries = const [];
  Map<String, Ability> _abilityDex = const {};
  Map<String, Move> _moveDex = const {};
  /// Showdown move IDs each species can learn (form variants resolved).
  /// Precomputed once on load so the advanced search "기술" filter is a
  /// sync Set lookup, not an async learnset call per Pokémon per
  /// filter-refresh.
  Map<String, Set<String>> _movesByPokemon = const {};
  Set<String> _learnable = const {};
  bool _loadingMoves = false;

  // Browse-list state (used only in browse mode — see _buildBrowse).
  // Search/filter/sort/scroll seed from [_DexBrowseStore] so the
  // dex back-button's pushReplacement doesn't visibly wipe the
  // user's typing, advanced filters, or position.
  late final TextEditingController _searchCtl;
  final _searchFocus = FocusNode();
  late final ScrollController _browseListScroll;
  late DexSearchFilter _filter;
  late _DexSortKey? _sortKey;
  late bool _sortAsc;

  @override
  void initState() {
    super.initState();
    _searchCtl =
        TextEditingController(text: _DexBrowseStore.searchText);
    _searchCtl.addListener(_persistBrowseSearch);
    _filter = _DexBrowseStore.filter;
    _sortKey = _DexBrowseStore.sortKey;
    _sortAsc = _DexBrowseStore.sortAsc;
    _browseListScroll = ScrollController(
      initialScrollOffset: _DexBrowseStore.scrollOffset,
    );
    _browseListScroll.addListener(_persistBrowseScroll);
    _loadDexes();
  }

  void _persistBrowseScroll() {
    if (!_browseListScroll.hasClients) return;
    _DexBrowseStore.scrollOffset = _browseListScroll.offset;
  }

  void _persistBrowseSearch() {
    _DexBrowseStore.searchText = _searchCtl.text;
  }

  @override
  void dispose() {
    _searchCtl.removeListener(_persistBrowseSearch);
    _searchCtl.dispose();
    _searchFocus.dispose();
    _browseListScroll.removeListener(_persistBrowseScroll);
    _browseListScroll.dispose();
    super.dispose();
  }

  Future<void> _loadDexes() async {
    final results = await Future.wait([
      loadAbilitydex(),
      loadMovedex(),
      loadPokedex(),
      // Warm the learnset cache up-front so the per-species lookup
      // below resolves off the cached map.
      loadLearnsets(),
    ]);
    if (!mounted) return;
    // Stable dex-number order so form variants (Mega / regional) sit
    // right after their base — they share the base's dex number, and
    // the pokedex loads base entries before forms.
    final loaded = results[2] as List<Pokemon>;
    final indexed = [
      for (var i = 0; i < loaded.length; i++) (loaded[i], i),
    ]..sort((a, b) {
        final c = a.$1.dexNumber.compareTo(b.$1.dexNumber);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
    final allPokemon = [for (final e in indexed) e.$1];
    // Precompute moves-per-species so the advanced-search "기술" filter
    // is fast. getLearnableMoves handles all the regional/form/Mega
    // name resolution; the underlying cache is warm from the
    // Future.wait above so each await here is a microtask hop.
    final movesByPokemon = <String, Set<String>>{};
    for (final p in allPokemon) {
      movesByPokemon[p.name] = await getLearnableMoves(
        p.name,
        nameKo: p.nameKo,
        dexNumber: p.dexNumber,
      );
    }
    if (!mounted) return;
    // Cross-link mode (opened on a specific Pokémon via
    // initialPokemonName) auto-selects it; browse mode starts with no
    // selection — the list itself is the entry point.
    Pokemon? initial;
    final initialName = widget.initialPokemonName;
    if (initialName != null) {
      initial = allPokemon.firstWhere(
        (p) => p.name == initialName,
        orElse: () => allPokemon.first,
      );
    }
    setState(() {
      _abilityDex = results[0] as Map<String, Ability>;
      _moveDex = results[1] as Map<String, Move>;
      _allPokemon = allPokemon;
      _movesByPokemon = movesByPokemon;
      _searchEntries = [
        for (final p in allPokemon)
          SearchEntry(p, p.nameKo, p.name,
              nameJa: p.nameJa, aliases: p.aliases),
      ];
      _selected = initial;
    });
    if (initial != null) _loadLearnsetFor(initial);
  }

  Future<void> _loadLearnsetFor(Pokemon p) async {
    setState(() => _loadingMoves = true);
    final moves = await getLearnableMoves(
      p.name,
      nameKo: p.nameKo,
      dexNumber: p.dexNumber,
    );
    if (!mounted) return;
    setState(() {
      _learnable = moves;
      _loadingMoves = false;
    });
  }

  void _onSelect(Pokemon p) {
    setState(() => _selected = p);
    _loadLearnsetFor(p);
  }

  @override
  Widget build(BuildContext context) {
    // Opened on a specific Pokémon → detail-only (cross-link); opened
    // from the nav menu → the browsable list.
    if (widget.initialPokemonName != null) return _buildCrossLink();
    return _buildBrowse();
  }

  Widget _buildCrossLink() {
    // Wide viewports: show Main + Moves side by side so users don't
    // need to swap tabs. Threshold chosen to roughly match the calc's
    // wide layout switch (1050) — anything narrower is phone/tablet
    // portrait where the tab UI works better.
    final wide = MediaQuery.of(context).size.width >= 1050;
    final mainTab = _MainTab(
      pokemon: _selected,
      abilityDex: _abilityDex,
      moveDex: _moveDex,
    );
    final movesTab = _MovesTab(
      pokemon: _selected,
      learnable: _learnable,
      moveDex: _moveDex,
      loading: _loadingMoves,
    );
    return PopScope(
      // Cross-link from the calc: block swipe-back (canPop=false), so
      // accidental edge drags don't slingshot the user out of the dex
      // and back into the calc. Detail-pushed-from-the-list:
      // canPop=true so the iOS swipe-back gesture lands the user on
      // the browse list naturally — that IS the route below, and
      // _DexBrowseStore preserves scroll/search/filter/sort so the
      // restore is lossless.
      canPop: widget.fromList,
      onPopInvokedWithResult: (didPop, _) {},
      child: DefaultTabController(
      length: 2,
      child: Scaffold(
        // Cap AppBar visual width to match the body. The whole
        // toolbar — chrome, shadow, bottom border, the lot — sits
        // in the same 1200 column the panes live in below.
        appBar: cappedAppBar(
          maxWidth: 1200,
          appBar: AppBar(
            // Species name appears large in the body header, so the
            // app bar drops it and uses send buttons + settings in
            // actions.
            //
            // Back arrow always shows. With the RootShell tab
            // architecture this pops the current route off the
            // nearest navigator — for cross-tab detail (pushed onto
            // the dex tab's nested nav over the list) that lands on
            // the dex list; for the calc-side picker (pushed via
            // root navigator above the IndexedStack) that returns
            // to calc with whatever result is on the stack (null if
            // none).
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip:
                  MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const SizedBox.shrink(),
            actions: [
                  AppSettingsMenu(onLanguageChanged: () => setState(() {})),
            ],
            bottom: wide
                ? null
                : TabBar(
                    tabs: [
                      Tab(text: AppStrings.t('dex.tabMain')),
                      Tab(text: AppStrings.t('dex.tabMoves')),
                    ],
                  ),
          ),
        ),
        body: GestureDetector(
          // Tap outside the typeahead → blur it. Without this the
          // suggestion box stays mounted because flutter_typeahead's
          // hideOnUnfocus needs an actual focus change.
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: wide
              // Two-pane split — capped so 4K monitors don't stretch
              // the dex into illegibility. Width tighter than the
              // coverage screen because two panes don't need 1600.
              // We pin the cap to a *concrete* height (LayoutBuilder
              // → SizedBox) so the empty space below the cap stays
              // empty instead of getting absorbed by the inner Row
              // children — a bare ConstrainedBox(maxHeight: 900)
              // loosens back to the children's intrinsic heights on
              // web, which made the top-pin invisible.
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
                            Expanded(child: mainTab),
                            const VerticalDivider(width: 1),
                            Expanded(child: movesTab),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    mainTab,
                    movesTab,
                  ],
                ),
        ),
      ),
      ),
    );
  }

  // ── Browse mode (list + detail) ──────────────────────────────────

  /// List-based browse layout, reached when the dex is opened without
  /// a target Pokémon. Wide ≥1400 → list | Main | Moves (3-pane);
  /// 1050–1400 → list | tabbed detail; narrower → list, tap pushes the
  /// cross-link detail.
  Widget _buildBrowse() {
    final width = MediaQuery.of(context).size.width;
    final veryWide = width >= 1400;
    final wide = width >= 1050;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: cappedAppBar(
          maxWidth: 1500,
          appBar: AppBar(
            // Wide-only back arrow (narrow widths return via the
            // bottom nav's '계산기' tab). Wide layouts hide the
            // bottom nav, and this screen is the root route of the
            // dex tab's nested navigator so there's nothing to pop
            // — the back button semantically means "go to calc".
            automaticallyImplyLeading: false,
            leading: MediaQuery.sizeOf(context).width >= 1050
                ? IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const BackButtonIcon(),
                    onPressed: () =>
                        RootShell.of(context).setTab(AppNavTab.calc),
                  )
                : null,
            centerTitle: true,
            title: Text(AppStrings.t('dex.title'),
                style: const TextStyle(fontSize: 18)),
            actions: [
                  AppSettingsMenu(onLanguageChanged: () => setState(() {})),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          // Refilter the list when the Champions-only toggle flips.
          child: ValueListenableBuilder<bool>(
            valueListenable:
                ChampionsFilterController.instance.championsOnly,
            builder: (context, _, __) {
              if (_allPokemon.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!wide) return _listPane(pushOnTap: true);
              return LayoutBuilder(
                builder: (context, c) {
                  final w =
                      c.maxWidth.clamp(0.0, veryWide ? 1500.0 : 1200.0);
                  final h = c.maxHeight.clamp(0.0, 900.0);
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: veryWide
                            ? [
                                SizedBox(width: 430, child: _listPane()),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  child: _MainTab(
                                    pokemon: _selected,
                                    abilityDex: _abilityDex,
                                    moveDex: _moveDex,
                                  ),
                                ),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  child: _MovesTab(
                                    pokemon: _selected,
                                    learnable: _learnable,
                                    moveDex: _moveDex,
                                    loading: _loadingMoves,
                                  ),
                                ),
                              ]
                            : [
                                SizedBox(width: 460, child: _listPane()),
                                const VerticalDivider(width: 1),
                                Expanded(child: _detailTabbed()),
                              ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Main + Moves under a TabBar — the detail pane for the 2-pane
  /// (non-very-wide) browse layout.
  Widget _detailTabbed() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: AppStrings.t('dex.tabMain')),
              Tab(text: AppStrings.t('dex.tabMoves')),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MainTab(
                  pokemon: _selected,
                  abilityDex: _abilityDex,
                  moveDex: _moveDex,
                ),
                _MovesTab(
                  pokemon: _selected,
                  learnable: _learnable,
                  moveDex: _moveDex,
                  loading: _loadingMoves,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listPane({bool pushOnTap = false}) {
    final filtered = _filteredPokemon(_searchCtl.text);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: _searchCtl,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: AppStrings.t('search.pokemon'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            // Dex browse — Enter only dismisses the keyboard. Per
            // user direction, browsing the dex should NEVER auto-pick
            // the top result on submit (that's calc-picker behaviour,
            // not browse). The user explicitly taps a row to view it.
            onSubmitted: (_) => _searchFocus.unfocus(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: _advancedSearchButton(),
        ),
        const Divider(height: 1),
        _dexSortHeader(),
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
              controller: _browseListScroll,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = filtered[i];
                return _pokemonRow(p,
                    isSelected: _selected?.name == p.name,
                    push: pushOnTap);
              },
            ),
          ),
      ],
    );
  }

  /// Horizontal type chips next to the species name (under it on
  /// two-line rows). The leftmost slot of each row now holds a sprite,
  /// so the old vertical type column is gone.
  Widget _typeChipsRow(Pokemon p) {
    Widget chip(PokemonType t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: KoStrings.getTypeColor(t),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(KoStrings.getTypeName(t),
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(p.type1),
        if (p.type2 != null) ...[const SizedBox(width: 3), chip(p.type2!)],
      ],
    );
  }

  Widget _pokemonRow(Pokemon p,
      {required bool isSelected, required bool push}) {
    final scheme = Theme.of(context).colorScheme;
    final s = p.baseStats;
    final bst = s.hp + s.attack + s.defense + s.spAttack + s.spDefense + s.speed;
    Widget stat(int v) => SizedBox(
          width: 30,
          child: Text('$v',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()])),
        );
    // Sprite layout: box icon takes the leftmost slot and the type
    // chips drop onto a second line under the name. The row is already
    // two lines tall (the old vertical type column), so this costs no
    // extra height. The slot is always rendered (pokéball placeholder
    // when no sprite is available) so every row stays the same shape.
    return InkWell(
      onTap: () => _pickPokemon(p, push),
      child: Container(
        color: isSelected ? scheme.primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            PokemonSprite(pokemonName: p.name, size: 46, useBoxIcon: true),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.localizedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  _typeChipsRow(p),
                ],
              ),
            ),
            const SizedBox(width: 4),
            stat(s.hp),
            stat(s.attack),
            stat(s.defense),
            stat(s.spAttack),
            stat(s.spDefense),
            stat(s.speed),
            SizedBox(
              width: 36,
              child: Text('$bst',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dexSortHeader() {
    Widget cell(_DexSortKey key, String label,
        {double? width, bool nameCol = false}) {
      // Sort state renders during search too — column sort now
      // applies on top of search results (it used to be ignored,
      // which is why the arrow was hidden while a query was live).
      final active = _sortKey == key;
      final arrow = active ? (_sortAsc ? ' ↑' : ' ↓') : '';
      final tappable = InkWell(
        onTap: () => _toggleSort(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '$label$arrow',
            textAlign: nameCol ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade700,
            ),
          ),
        ),
      );
      return nameCol
          ? Expanded(child: tappable)
          : SizedBox(width: width, child: tappable);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 52), // type column — not sortable
          cell(_DexSortKey.name, AppStrings.t('dex.colName'), nameCol: true),
          const SizedBox(width: 4),
          cell(_DexSortKey.hp, AppStrings.t('dex.colHp'), width: 30),
          cell(_DexSortKey.atk, AppStrings.t('dex.colAtk'), width: 30),
          cell(_DexSortKey.def, AppStrings.t('dex.colDef'), width: 30),
          cell(_DexSortKey.spa, AppStrings.t('dex.colSpa'), width: 30),
          cell(_DexSortKey.spd, AppStrings.t('dex.colSpd'), width: 30),
          cell(_DexSortKey.spe, AppStrings.t('dex.colSpe'), width: 30),
          cell(_DexSortKey.bst, AppStrings.t('dex.colBst'), width: 36),
        ],
      ),
    );
  }

  /// Single button that opens the advanced search dialog. Shows the
  /// active-filter count as a "(N)" suffix so users can tell at a
  /// glance whether any condition is in effect.
  Widget _advancedSearchButton() {
    final scheme = Theme.of(context).colorScheme;
    final n = _filter.activeCount;
    final label = n == 0
        ? AppStrings.t('dex.advancedSearch')
        : '${AppStrings.t('dex.advancedSearch')} ($n)';
    final highlight = n > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final allMoves = _moveDex.values
            .where((m) => m.moveClass == MoveClass.normal)
            .toList();
        final result = await showDexSearchFilterDialog(
          context: context,
          current: _filter,
          abilityDex: _abilityDex,
          allMoves: allMoves,
        );
        if (!mounted || identical(result, kDexFilterDismissed)) return;
        if (result is DexSearchFilter) {
          setState(() {
            _filter = result;
            _DexBrowseStore.filter = result;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.08)
              : null,
          border: Border.all(
            color: highlight
                ? scheme.primary.withValues(alpha: 0.6)
                : Colors.grey.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.tune,
                size: 16,
                color: highlight ? scheme.primary : Colors.grey.shade700),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: highlight ? scheme.primary : null,
                ),
              ),
            ),
            if (highlight)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _filter = DexSearchFilter.empty;
                  _DexBrowseStore.filter = DexSearchFilter.empty;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.close,
                      size: 16,
                      color: scheme.primary.withValues(alpha: 0.8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Filters by the advanced-search [DexSearchFilter] + Champions toggle.
  /// Ordering:
  ///   * query + no active sort column → relevance-scored (exact >
  ///     prefix > chosung), so typing "리자" surfaces 리자몽 first.
  ///   * query + active sort column → the matched set sorted by that
  ///     column. The user explicitly asked for a column order; honor
  ///     it over relevance. (Previously column sort was ignored during
  ///     search entirely — reported as "search breaks sorting".)
  ///   * no query → active column sort, else dex-number order.
  List<Pokemon> _filteredPokemon(String query) {
    final championsOnly =
        ChampionsFilterController.instance.championsOnly.value;
    final filter = _filter;
    final filterActive = !filter.isEmpty;
    bool ok(Pokemon p) {
      if (championsOnly && !isInChampions(p.name)) return false;
      if (filterActive &&
          !matchesDexFilter(p, filter, movesByPokemon: _movesByPokemon)) {
        return false;
      }
      return true;
    }

    if (query.isNotEmpty) {
      final qLower = query.toLowerCase();
      final qRunes = qLower.runes.toList();
      final scored = <(Pokemon, int)>[];
      for (final e in _searchEntries) {
        if (!ok(e.item)) continue;
        final s = scoreEntry(qRunes, qLower, e);
        if (s > 0) scored.add((e.item, s));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final matched = [for (final e in scored) e.$1];
      // An explicitly-picked sort column wins over relevance order.
      if (_sortKey != null) matched.sort(_compareDex);
      return matched;
    }

    final out = _allPokemon.where(ok).toList();
    if (_sortKey != null) out.sort(_compareDex);
    return out;
  }

  int _bstOf(Pokemon p) {
    final s = p.baseStats;
    return s.hp + s.attack + s.defense + s.spAttack + s.spDefense + s.speed;
  }

  int _compareDex(Pokemon a, Pokemon b) {
    int cmp;
    switch (_sortKey!) {
      case _DexSortKey.name:
        cmp = a.localizedName.compareTo(b.localizedName);
      case _DexSortKey.hp:
        cmp = a.baseStats.hp.compareTo(b.baseStats.hp);
      case _DexSortKey.atk:
        cmp = a.baseStats.attack.compareTo(b.baseStats.attack);
      case _DexSortKey.def:
        cmp = a.baseStats.defense.compareTo(b.baseStats.defense);
      case _DexSortKey.spa:
        cmp = a.baseStats.spAttack.compareTo(b.baseStats.spAttack);
      case _DexSortKey.spd:
        cmp = a.baseStats.spDefense.compareTo(b.baseStats.spDefense);
      case _DexSortKey.spe:
        cmp = a.baseStats.speed.compareTo(b.baseStats.speed);
      case _DexSortKey.bst:
        cmp = _bstOf(a).compareTo(_bstOf(b));
    }
    // Stat ties fall back to dex order so the list stays stable.
    if (cmp == 0 && _sortKey != _DexSortKey.name) {
      cmp = a.dexNumber.compareTo(b.dexNumber);
    }
    return _sortAsc ? cmp : -cmp;
  }

  void _toggleSort(_DexSortKey key) {
    setState(() {
      // Name sorts A→Z first; stats sort high→low first.
      final defaultAsc = key == _DexSortKey.name;
      if (_sortKey != key) {
        _sortKey = key;
        _sortAsc = defaultAsc;
      } else if (_sortAsc == defaultAsc) {
        _sortAsc = !defaultAsc;
      } else {
        // Third tap → back to dex-number order.
        _sortKey = null;
        _sortAsc = true;
      }
      _DexBrowseStore.sortKey = _sortKey;
      _DexBrowseStore.sortAsc = _sortAsc;
    });
  }

  void _pickPokemon(Pokemon p, bool push) {
    // Drop the search-bar focus before navigating — otherwise the
    // soft keyboard pops back up the moment the user swipes back to
    // the list, which is jarring on mobile (the list itself never
    // needs the keyboard up). Same intent as MoveDex's _pickMove.
    _searchFocus.unfocus();
    if (push) {
      // Narrow: open the species in its own cross-link detail screen.
      // Tagged fromList=true so the detail page's PopScope lets the
      // user swipe back to the list (this route IS the previous one).
      Navigator.of(context).push(
        fadeRoute(
            (_) => DexScreen(initialPokemonName: p.name, fromList: true)),
      );
    } else {
      _onSelect(p);
    }
  }
}

// ────────────────────────────────────────────────────────────────────────
// Main tab — header, stats, abilities, type matchups
// ────────────────────────────────────────────────────────────────────────

// ────────────────────────────────────────────────────────────────────────
// Moves tab
// ────────────────────────────────────────────────────────────────────────

// _ChampionsOnlyToggle removed — the Champions-only filter is now a
// global setting accessible from AppSettingsMenu, shared across the
// calculator, dex, move dex, and team builder screens.
