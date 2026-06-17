import 'package:flutter/material.dart';

import '../data/abilitydex.dart';
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
import '../utils/app_strings.dart';
import '../utils/battle_facade.dart';
import '../utils/champions_filter_controller.dart';
import '../utils/korean_search.dart';
import '../utils/page_routes.dart';
import '../utils/localization.dart';
import '../utils/stacking_moves.dart';
import '../utils/terrain_effects.dart' show abilityTerrainMap;
import '../utils/ability_effects.dart';
import '../utils/weather_effects.dart' show abilityWeatherMap;
import 'root_shell.dart';
import 'widgets/app_bottom_nav.dart' show AppNavTab;
import 'widgets/app_settings_menu.dart';
import 'widgets/dex_search_filter_dialog.dart';
import 'widgets/move_selector.dart';
import 'widgets/pokemon_sprite.dart';
import 'widgets/type_filter_dialog.dart';

/// Result produced when the user taps "공격측으로" / "방어측으로" in
/// the dex header — the dex pops with this payload so the calculator
/// can apply the Pokemon to the chosen side.
///
/// `side`: 0 = attacker, 1 = defender.
typedef DexPickResult = ({int side, Pokemon pokemon});

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

  /// Pop the dex returning the current species for a calc side
  /// (0 = attacker, 1 = defender). Shared by the app bar's send
  /// buttons and (in browse mode) the future header tap target.
  void _sendToSide(int side) {
    final p = _selected;
    if (p == null) return;
    Navigator.of(context).pop<DexPickResult>((side: side, pokemon: p));
  }

  /// Attacker / defender send buttons for the app bar. Empty list
  /// when nothing's selected yet — keeps the bar uncluttered before
  /// the user picks a species. Moved out of the species-info card
  /// because that card now hosts the 80×80 sprite and the buttons
  /// were squeezing the name into a 1-char-wide stub on small
  /// screens.
  List<Widget> _appBarSendButtons() {
    if (_selected == null) return const [];
    return [
      _dexSendButton(
        label: AppStrings.t('dex.sendToAttacker'),
        color: Colors.red.shade600,
        onPressed: () => _sendToSide(0),
      ),
      const SizedBox(width: 6),
      _dexSendButton(
        label: AppStrings.t('dex.sendToDefender'),
        color: Colors.blue.shade600,
        onPressed: () => _sendToSide(1),
      ),
      const SizedBox(width: 4),
    ];
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
              ..._appBarSendButtons(),
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
              ..._appBarSendButtons(),
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
      final active = _sortKey == key;
      final searching = _searchCtl.text.isNotEmpty;
      final arrow = (active && !searching) ? (_sortAsc ? ' ↑' : ' ↓') : '';
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
              color: (active && !searching)
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

  /// Filters by the advanced-search [DexSearchFilter] + Champions toggle;
  /// with a query, results are relevance-scored (column sort ignored);
  /// otherwise sorted by the active column, defaulting to dex-number
  /// order.
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
      return [for (final e in scored) e.$1];
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

class _MainTab extends StatefulWidget {
  final Pokemon? pokemon;
  final Map<String, Ability> abilityDex;
  final Map<String, Move> moveDex;

  const _MainTab({
    required this.pokemon,
    required this.abilityDex,
    required this.moveDex,
  });

  @override
  State<_MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<_MainTab> {
  /// Ability the user has selected for the bulk / decisive power
  /// tables. Defaulted from curated usage data (or species' first
  /// ability) when the species changes.
  String? _selectedAbility;

  /// Show shiny art for the header sprite. Session-only — resets to
  /// false whenever the user lands on a new species. The dex is a
  /// browse / inspect surface; users who want a persistent shiny
  /// pick should save the Pokémon as a sample (carries `shiny`).
  bool _shiny = false;

  @override
  void initState() {
    super.initState();
    _seedAbility();
  }

  @override
  void didUpdateWidget(_MainTab old) {
    super.didUpdateWidget(old);
    if (old.pokemon?.name != widget.pokemon?.name) {
      _seedAbility();
      // Different species → wipe the shiny toggle so the new entry
      // starts at its default art.
      _shiny = false;
    }
  }

  /// Pick a default ability for calc tables — curated top pick wins
  /// when the species has usage data; otherwise falls back to the
  /// species' first listed ability.
  void _seedAbility() {
    final p = widget.pokemon;
    if (p == null) {
      _selectedAbility = null;
      return;
    }
    final curated = championsUsageFor(p.name)?.abilities;
    String? picked;
    if (curated != null && curated.isNotEmpty) {
      final first = curated.first.name;
      if (p.abilities.contains(first)) picked = first;
    }
    picked ??= p.abilities.isNotEmpty ? p.abilities.first : null;
    _selectedAbility = picked;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pokemon;
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AppStrings.t('dex.title'),
              style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }
    return SingleChildScrollView(
      // Generous bottom inset matches the calculator tabs (120 px) so
      // the last decisive-power row never butts against the system
      // gesture bar / keyboard, and gives the eye some breathing room.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            pokemon: p,
            shiny: _shiny,
            onShinyChanged: (v) => setState(() => _shiny = v),
          ),
          const SizedBox(height: 12),
          _StatRow(pokemon: p),
          const SizedBox(height: 16),
          _AbilitiesSection(pokemon: p, abilityDex: widget.abilityDex),
          const SizedBox(height: 16),
          // Picker comes BEFORE the type matchup chart so the user
          // can see the chart change as they switch abilities
          // (Snorlax + Thick Fat shifts Fire/Ice into the resist
          // bucket, Levitate moves Ground into the immunity bucket,
          // Wonder Guard collapses everything that isn't SE to 0×,
          // etc.). "특성 없음" reverts to the pure-type chart.
          if (p.abilities.isNotEmpty) ...[
            _CalcAbilityPicker(
              pokemon: p,
              abilityDex: widget.abilityDex,
              selected: _selectedAbility,
              onChanged: (ab) => setState(() => _selectedAbility = ab),
            ),
            const SizedBox(height: 12),
          ],
          _TypeMatchupsSection(pokemon: p, ability: _selectedAbility),
          const SizedBox(height: 16),
          _BulkSection(pokemon: p, ability: _selectedAbility),
          const SizedBox(height: 16),
          _DecisivePowerSection(
            pokemon: p,
            moveDex: widget.moveDex,
            ability: _selectedAbility,
          ),
        ],
      ),
    );
  }
}

/// Flat chip used by the calc-ability picker. Deliberately not
/// [ChoiceChip] — Material's chip animates a checkmark in/out on
/// selection which jiggles the row's metrics. Here we only flip the
/// fill color so tapping is visually instant.
class _AbilityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AbilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary.withValues(alpha: 0.18) : Colors.transparent;
    final fg = selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.8);
    final border = selected ? scheme.primary : scheme.outlineVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Compact picker that drives the bulk + decisive-power tables. Shows
/// the species' ability list (one row) and lets the user tap to switch.
/// Auto-applied weather/terrain (Drought → Sun, etc.) is handled by the
/// table sections themselves.
class _CalcAbilityPicker extends StatelessWidget {
  final Pokemon pokemon;
  final Map<String, Ability> abilityDex;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CalcAbilityPicker({
    required this.pokemon,
    required this.abilityDex,
    required this.selected,
    required this.onChanged,
  });

  String _label(String key) => abilityDex[key]?.localizedName ?? key;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            AppStrings.t('dex.calcAbility'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                // Stateful ability bases (Supreme Overlord, Rivalry)
                // get mapped to a default variant ("Supreme Overlord
                // 0", "Rivalry Same") so the chip carries a key the
                // damage calc actually understands. Mirrors what
                // applyPokemon does on the calc side.
                for (final raw in pokemon.abilities)
                  _AbilityChip(
                    label: _label(
                        BattlePokemonState.expandAbilityKey(raw) ?? raw),
                    selected: selected ==
                        (BattlePokemonState.expandAbilityKey(raw) ?? raw),
                    onTap: () => onChanged(
                        BattlePokemonState.expandAbilityKey(raw) ?? raw),
                  ),
                // "특성 없음" — lets the user remove the ability so
                // the type matchup chart and downstream calc tables
                // recompute as if no ability were active.
                _AbilityChip(
                  label: AppStrings.t('dex.calcAbility.none'),
                  selected: selected == null,
                  onTap: () => onChanged(null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tonal pill button for the dex's attacker / defender send actions.
/// Top-level so both app bars (browse + cross-link) can share it
/// without each pulling in the entire _Header class.
Widget _dexSendButton({
  required String label,
  required Color color,
  required VoidCallback onPressed,
}) {
  return FilledButton.tonal(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
    ),
    child: Text(label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _Header extends StatelessWidget {
  final Pokemon pokemon;
  final bool shiny;
  final ValueChanged<bool> onShinyChanged;
  const _Header({
    required this.pokemon,
    required this.shiny,
    required this.onShinyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final altName = AppStrings.current == AppLanguage.ko
        ? '${pokemon.nameEn ?? pokemon.name} · ${pokemon.nameJa}'
        : (AppStrings.current == AppLanguage.ja
            ? '${pokemon.nameEn ?? pokemon.name} · ${pokemon.nameKo}'
            : '${pokemon.nameKo} · ${pokemon.nameJa}');
    // The header gets a sprite slot down the left — the slot is always
    // reserved (pokéball placeholder when no sprite is available) so
    // the layout stays the same shape regardless of platform / cache /
    // Champions-original coverage. The send buttons used to share the
    // name row here but they squeezed the name into a stub on narrow
    // screens; they now live in the app bar instead.
    //
    // Dex number used to live to the left of the name as `#0042`
    // but that's redundant — list rows already surface it and the
    // detail page benefits more from giving the name (and the new
    // shiny toggle) the full row width.
    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                pokemon.localizedName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Shiny toggle anchored to the right of the species name
            // (per UX direction — easier to spot at the natural end
            // of the title row). Session-only — `_MainTabState`
            // resets it whenever the user navigates to a different
            // species. Persisting a shiny pick is what saved samples
            // are for.
            InkWell(
              onTap: () => onShinyChanged(!shiny),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      shiny
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: shiny
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.t('dex.shinyToggle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(altName,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _typeChip(pokemon.type1),
            if (pokemon.type2 != null) _typeChip(pokemon.type2!),
          ],
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PokemonSprite(
                  pokemonName: pokemon.name, size: 80, shiny: shiny),
              const SizedBox(width: 12),
              Expanded(child: infoColumn),
            ],
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: _metaCell(
                          AppStrings.t('dex.height'), '${pokemon.height} m'),
                    ),
                    Expanded(
                      child: _metaCell(
                          AppStrings.t('dex.weight'), '${pokemon.weight} kg'),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _metaCell(AppStrings.t('dex.gender'), _genderValue(pokemon)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _metaCell(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Flexible(child: Text(value)),
      ],
    );
  }

  static Widget _typeChip(PokemonType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(type),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(KoStrings.getTypeName(type),
          style: const TextStyle(
              fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  static String _genderValue(Pokemon p) {
    if (p.genderRate == -1) return AppStrings.t('dex.genderless');
    if (p.genderRate == 0) return '♂';
    if (p.genderRate == 8) return '♀';
    final female = p.genderRate / 8 * 100;
    final male = 100 - female;
    return '♂ ${male.toStringAsFixed(male % 1 == 0 ? 0 : 1)}% / '
        '♀ ${female.toStringAsFixed(female % 1 == 0 ? 0 : 1)}%';
  }

}

class _StatRow extends StatelessWidget {
  final Pokemon pokemon;
  const _StatRow({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final s = pokemon.baseStats;
    final values = [s.hp, s.attack, s.defense, s.spAttack, s.spDefense, s.speed];
    final labels = [
      AppStrings.t('stat.hp'),
      AppStrings.t('stat.attack'),
      AppStrings.t('stat.defense'),
      AppStrings.t('stat.spAttack'),
      AppStrings.t('stat.spDefense'),
      AppStrings.t('stat.speed'),
    ];
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final total = values.reduce((a, b) => a + b);

    Widget cell(String label, int v, {bool isTotal = false}) {
      Color? color;
      FontWeight weight = FontWeight.w600;
      if (!isTotal) {
        if (v == maxValue) {
          color = Colors.red;
          weight = FontWeight.w700;
        } else if (v == minValue) {
          color = Colors.grey;
        }
      }
      return Expanded(
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$v',
                style: TextStyle(fontSize: 15, color: color, fontWeight: weight)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (int i = 0; i < 6; i++) cell(labels[i], values[i]),
          Container(
            width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.4),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          cell(AppStrings.t('dex.statTotal'), total, isTotal: true),
        ],
      ),
    );
  }
}

class _AbilitiesSection extends StatelessWidget {
  final Pokemon pokemon;
  final Map<String, Ability> abilityDex;

  const _AbilitiesSection({required this.pokemon, required this.abilityDex});

  /// Map a variant key (Supreme Overlord 0, Disguise Busted, Rivalry
  /// Same, …) back to its base entry name. Returns null when the key
  /// is already a base or doesn't have a base counterpart.
  static String? _baseAbilityFor(String key) {
    if (key.startsWith('Supreme Overlord ')) return 'Supreme Overlord';
    if (key.startsWith('Disguise ')) return 'Disguise';
    if (key.startsWith('Rivalry ')) return 'Rivalry';
    if (key.startsWith('Slow Start ')) return 'Slow Start';
    if (key.startsWith('Stakeout ')) return 'Stakeout';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final abs = pokemon.abilities;
    // Convention: last ability in the list is the hidden one when 3
    // are listed (PokeAPI convention is preserved in our data). We
    // tag with '*' when this looks like a HA pattern.
    final hiddenIndex = abs.length >= 2 ? abs.length - 1 : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.abilities')),
        const SizedBox(height: 6),
        if (abs.isEmpty)
          // Placeholder for fan/unreleased mega forms whose abilities
          // haven't been officially revealed — show "미공개" with a
          // short note that it'll be updated once official info drops.
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t('dex.abilityUnrevealed'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Text(
                    AppStrings.t('dex.abilityUnrevealedDesc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < abs.length; i++)
            _abilityRow(abs[i], isHidden: i == hiddenIndex && abs.length >= 2),
      ],
    );
  }

  Widget _abilityRow(String key, {required bool isHidden}) {
    final ab = abilityDex[key];
    // Stateful abilities ship as numbered / state-suffixed variants
    // ("Supreme Overlord 0", "Disguise Busted") with no descriptions
    // of their own. Fall back to the base entry — added with
    // descriptionOnly: true — so the dex shows the canonical name +
    // explanation instead of "총대장 ×0" + nothing.
    final base = _baseAbilityFor(key);
    final baseAb = base != null ? abilityDex[base] : null;
    final name = baseAb?.localizedName ?? ab?.localizedName ?? key;
    final desc =
        baseAb?.localizedDescription ?? ab?.localizedDescription;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(name,
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (isHidden)
                Text(' *',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(desc,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(AppStrings.t('dex.noDescription'),
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

class _TypeMatchupsSection extends StatelessWidget {
  final Pokemon pokemon;
  final String? ability;
  const _TypeMatchupsSection({required this.pokemon, this.ability});

  @override
  Widget build(BuildContext context) {
    // Build buckets keyed by multiplier. Hide buckets that end up empty.
    final buckets = <double, List<PokemonType>>{
      4.0: [],
      2.0: [],
      1.0: [],
      0.5: [],
      0.25: [],
      0.0: [],
    };
    for (final atkType in PokemonType.values) {
      if (atkType == PokemonType.typeless) continue;
      // Stellar is a Terastal-only attacker type with a fixed 1×/2× rule
      // against Terastallized targets; hiding it from the dex chart
      // matches user expectation for "normal" matchups.
      if (atkType == PokemonType.stellar) continue;
      // abilityAdjustedDefensiveMultiplier folds the pure type chart,
      // the type immunity table (Ground vs Flying, Poison vs Steel,
      // etc.), and any ability-driven changes (Levitate / Thick Fat /
      // Wonder Guard / Fluffy / …) into one number that lines up with
      // the chart's bucket keys. Pass ability=null for the pure-type
      // view.
      final mult = abilityAdjustedDefensiveMultiplier(
        atkType,
        pokemon.type1,
        pokemon.type2,
        ability: ability,
      );
      if (buckets.containsKey(mult)) buckets[mult]!.add(atkType);
    }
    final activeKeys = buckets.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();
    if (activeKeys.isEmpty) return const SizedBox.shrink();

    // Responsive chip font: shrink as more columns are visible / on
    // narrow phones.
    final width = MediaQuery.of(context).size.width;
    final colCount = activeKeys.length;
    final tightFactor = (width / (colCount * 70)).clamp(0.7, 1.0);
    final fontSize = 11.0 * tightFactor;
    final padH = (6 * tightFactor).clamp(3.0, 6.0);
    final padV = (2 * tightFactor).clamp(1.5, 2.0);

    Widget chip(PokemonType t) => Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: KoStrings.getTypeColor(t),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(KoStrings.getTypeName(t),
              style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        );

    Widget column(double key) {
      final types = buckets[key]!;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(_multLabel(key),
                style: TextStyle(
                    fontSize: 12,
                    color: _multColor(key),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final t in types) ...[
              chip(t),
              const SizedBox(height: 4),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.typeMatchups')),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final k in activeKeys) column(k)],
        ),
      ],
    );
  }

  static String _multLabel(double mult) {
    if (mult == 4.0) return '×4';
    if (mult == 2.0) return '×2';
    if (mult == 1.0) return '×1';
    if (mult == 0.5) return '×½';
    if (mult == 0.25) return '×¼';
    if (mult == 0.0) return '×0';
    return '×$mult';
  }

  static Color _multColor(double mult) {
    if (mult >= 2.0) return Colors.red;
    if (mult > 0 && mult < 1) return Colors.green;
    if (mult == 0) return Colors.grey;
    return Colors.black;
  }
}

/// Build a stripped-down [BattlePokemonState] the dex can feed into
/// [BattleFacade]. All defender-specific battle toggles (status, rank,
/// allies, rooms, etc.) stay at their defaults — the dex is a raw
/// species baseline, not an in-battle snapshot.
BattlePokemonState _dexState({
  required Pokemon pokemon,
  required String? ability,
  required Stats ev,
  required NatureProfile nature,
  required Stats iv,
  required int level,
  Move? move,
  int? hits,
  int? powerOverride,
}) {
  return BattlePokemonState(
    pokemonName: pokemon.name,
    pokemonNameKo: pokemon.nameKo,
    pokemonNameJa: pokemon.nameJa,
    pokemonNameEn: pokemon.nameEn,
    dexNumber: pokemon.dexNumber,
    finalEvo: pokemon.finalEvo,
    genderRate: pokemon.genderRate,
    type1: pokemon.type1,
    type2: pokemon.type2,
    weight: pokemon.weight,
    baseStats: pokemon.baseStats,
    pokemonAbilities: pokemon.abilities,
    selectedAbility: BattlePokemonState.expandAbilityKey(ability),
    level: level,
    nature: nature,
    iv: iv,
    ev: ev,
    moves: [move, null, null, null],
    hitOverrides: [hits, null, null, null],
    powerOverrides: [powerOverride, null, null, null],
    isMega: pokemon.isMega,
    canDynamax: pokemon.canDynamax,
    canGmax: pokemon.canGmax,
    selectedItem: pokemon.requiredItem,
  );
}

class _BulkSection extends StatelessWidget {
  final Pokemon pokemon;
  /// Ability used by the bulk calc. Unconditional Def/SpD modifiers
  /// (Fur Coat, Ice Scales-adjacent, Grass Pelt under terrain, etc.)
  /// flow into the numbers; weather/terrain that the ability implies
  /// (Drought → Sun, Grassy Surge → Grassy terrain) is auto-activated
  /// so bulk reflects the on-field reality of that species.
  final String? ability;
  const _BulkSection({required this.pokemon, this.ability});

  static const _level = 50;
  static const _fullIv = Stats(
      hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);

  @override
  Widget build(BuildContext context) {
    // Three investment tiers — "준보정" is rare in practice so we skip
    // it. Bulk routes through [BattleFacade.calcBulk] so the numbers
    // match what the calculator's defender panel shows (HP × Def /
    // 0.411, with the full ability chain applied).
    const baseEv = Stats(
        hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);

    final weather =
        ability != null ? (abilityWeatherMap[ability!] ?? Weather.none) : Weather.none;
    final terrain =
        ability != null ? (abilityTerrainMap[ability!] ?? Terrain.none) : Terrain.none;

    ({int physical, int special}) bulk(Stats ev, NatureProfile nat) =>
        BattleFacade.calcBulk(
          state: _dexState(
            pokemon: pokemon,
            ability: ability,
            ev: ev,
            nature: nat,
            iv: _fullIv,
            level: _level,
          ),
          weather: weather,
          terrain: terrain,
          room: const RoomConditions(),
        );

    final none = bulk(baseEv, const NatureProfile());
    final hpOnly = bulk(baseEv.copyWith(hp: 252), const NatureProfile());
    final hb = bulk(baseEv.copyWith(hp: 252, defense: 252),
        const NatureProfile(up: NatureStat.def));
    final hd = bulk(baseEv.copyWith(hp: 252, spDefense: 252),
        const NatureProfile(up: NatureStat.spd));

    // 4-row layout. For HB/HD rows the "off-axis" column (SpD on HB,
    // Def on HD) is mathematically identical to the H32 value — no
    // EV or nature changes that stat — so we surface that value
    // rather than leaving it blank. The user still gets a complete
    // picture of the spread's total bulk footprint.
    final rows = <(String, int, int)>[
      (AppStrings.t('dex.bulkNone'), none.physical, none.special),
      (AppStrings.t('dex.bulkH'), hpOnly.physical, hpOnly.special),
      (AppStrings.t('dex.bulkHB'), hb.physical, hpOnly.special),
      (AppStrings.t('dex.bulkHD'), hpOnly.physical, hd.special),
    ];

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.bulk')),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(3),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              children: [
                const SizedBox.shrink(),
                _DexTableCell(AppStrings.t('dex.bulkPhysical'),
                    bold: true, dim: true),
                _DexTableCell(AppStrings.t('dex.bulkSpecial'),
                    bold: true, dim: true),
              ],
            ),
            for (final r in rows)
              TableRow(children: [
                _DexTableCell(r.$1, align: TextAlign.left, bold: true),
                _DexTableCell(_fmt(r.$2), bold: true),
                _DexTableCell(_fmt(r.$3), bold: true),
              ]),
          ],
        ),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// 결정력 table — shows raw offensive output for each of the
/// species' curated key moves at three investment tiers (none /
/// half / full). STAB is applied when the move's type matches the
/// species's type; no item, rank or ability modifiers are included.
class _DecisivePowerSection extends StatefulWidget {
  final Pokemon pokemon;
  final Map<String, Move> moveDex;
  /// Ability for decisive power. Offensive modifiers (Adaptability,
  /// Huge Power, Sheer Force, …) flow through OffensiveCalculator via
  /// `attackerAbility`; weather/terrain this ability would set on
  /// switch-in (Drought, Grassy Surge, …) is auto-activated for the
  /// duration of the calc.
  final String? ability;

  const _DecisivePowerSection({
    required this.pokemon,
    required this.moveDex,
    this.ability,
  });

  @override
  State<_DecisivePowerSection> createState() => _DecisivePowerSectionState();
}

class _DecisivePowerSectionState extends State<_DecisivePowerSection> {
  static const _level = 50;
  static const _fullIv = Stats(
      hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31);
  static const _baseEv = Stats(
      hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0);

  // Per-row hit count for multi-hit moves, keyed by move English name.
  final Map<String, int> _hits = {};

  // Scratch-row move picked by the user for ad-hoc damage lookups.
  Move? _customMove;
  int _customHits = 1;

  /// True while the scratch selector has focus. Drives the layout
  /// swap — picking widens the selector back to full row, collapsing
  /// to the fused 4-column layout on blur.
  bool _scratchFocused = false;

  @override
  void initState() {
    super.initState();
    _seedHits();
  }

  @override
  void didUpdateWidget(_DecisivePowerSection old) {
    super.didUpdateWidget(old);
    if (old.pokemon != widget.pokemon || old.moveDex != widget.moveDex) {
      _hits.clear();
      _customMove = null;
      _customHits = 1;
      _seedHits();
    }
  }

  /// Curated damage-move pool from the Champions Singles usage data.
  /// Falls back to the legacy `pokemon.keyMoves` list (unsuffixed names
  /// only) for species that haven't been curated yet. Filters out moves
  /// whose output doesn't reflect the user's own offensive stats —
  /// status moves (power 0), fixed-damage / OHKO moves, and Foul Play
  /// (which scales off the target's Attack).
  List<Move> _decisiveMoves() {
    final usage = championsUsageFor(widget.pokemon.name);
    final rawNames = <String>[];
    if (usage != null && usage.moves.isNotEmpty) {
      rawNames.addAll(usage.moves.map((row) => row.name));
    } else {
      // Legacy fallback: strip the ":N" hit-count suffix if present.
      rawNames.addAll(widget.pokemon.keyMoves.map((s) => s.split(':').first));
    }
    final out = <Move>[];
    for (final name in rawNames) {
      final m = widget.moveDex[name];
      if (m == null) continue;
      if (m.power <= 0) continue;
      if (_doesntScaleWithUserOffense(m)) continue;
      out.add(m);
    }
    return out;
  }

  bool _doesntScaleWithUserOffense(Move m) =>
      m.hasTag(MoveTags.ohko) ||
      m.hasTag(MoveTags.fixedLevel) ||
      m.hasTag(MoveTags.fixedHalfHp) ||
      m.hasTag(MoveTags.fixedThreeQuarterHp) ||
      m.hasTag(MoveTags.fixed20) ||
      m.hasTag(MoveTags.fixed40) ||
      m.hasTag(MoveTags.useOpponentAtk);

  void _seedHits() {
    for (final m in _decisiveMoves()) {
      if (m.isMultiHit) {
        _hits[m.name] = m.maxHits;
      } else if (isStackingPower(m)) {
        _hits[m.name] = stackingDefaultTier(m);
      }
    }
  }

  /// Run a decisive-power calc for [m] under the given EV/nature. We
  /// route the call through [BattleFacade.getMoveSlotInfo] so every
  /// ability-driven transform (Pixilate, Liquid Voice, Sheer Force,
  /// Adaptability, Huge Power, …) is applied the same way the
  /// calculator does. Multi-hit `hits` feeds into the move slot's
  /// hit-count override; for stacking-power moves (Last Respects)
  /// `hits` is reinterpreted as a power override.
  int _outputFor(Move m, Stats ev, NatureProfile nat, int hits) {
    final ab = widget.ability;
    final weather =
        ab != null ? (abilityWeatherMap[ab] ?? Weather.none) : Weather.none;
    final terrain =
        ab != null ? (abilityTerrainMap[ab] ?? Terrain.none) : Terrain.none;
    final state = _dexState(
      pokemon: widget.pokemon,
      ability: ab,
      ev: ev,
      nature: nat,
      iv: _fullIv,
      level: _level,
      move: m,
      hits: m.isMultiHit ? hits : null,
      powerOverride:
          isStackingPower(m) ? stackingPower(m, hits) : null,
    );
    final info = BattleFacade.getMoveSlotInfo(
      state: state,
      moveIndex: 0,
      weather: weather,
      terrain: terrain,
      room: const RoomConditions(),
    );
    return info.offensivePower ?? 0;
  }

  /// Whether [m] should expose an ×N picker — either it's a
  /// variable multi-hit or a stacking-power move.
  bool _hasTierPicker(Move m) =>
      (m.isMultiHit && m.minHits != m.maxHits) || isStackingPower(m);

  /// Which stat the move scales off (Body Press → Def, etc.). Kept
  /// here only to pick the right EV/nature column; actual stat
  /// selection inside the calc happens in [transformMove].
  NatureStat _investStat(Move m) {
    if (m.hasTag(MoveTags.useDefense)) return NatureStat.def;
    return m.category == MoveCategory.physical
        ? NatureStat.atk
        : NatureStat.spa;
  }

  NatureProfile _fullNature(Move m) => NatureProfile(up: _investStat(m));

  Stats _halfEv(Move m) {
    switch (_investStat(m)) {
      case NatureStat.atk:
        return _baseEv.copyWith(attack: 252);
      case NatureStat.spa:
        return _baseEv.copyWith(spAttack: 252);
      case NatureStat.def:
        return _baseEv.copyWith(defense: 252);
      case NatureStat.spd:
        return _baseEv.copyWith(spDefense: 252);
      case NatureStat.spe:
        return _baseEv.copyWith(speed: 252);
    }
  }

  Future<int?> _showHitPicker(Move m) async {
    if (!_hasTierPicker(m)) return null;
    final stackMaxVal = stackingMax(m);
    final (lo, hi) = stackMaxVal != null
        ? (1, stackMaxVal)
        : (m.minHits, m.maxHits);
    return showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int n = lo; n <= hi; n++)
                InkWell(
                  onTap: () => Navigator.pop(ctx, n),
                  child: Container(
                    width: 44,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('×$n',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickKeyMoveHits(String rawKey, Move m) async {
    final picked = await _showHitPicker(m);
    if (picked != null && mounted) {
      setState(() => _hits[rawKey] = picked);
    }
  }

  Future<void> _pickCustomHits(Move m) async {
    final picked = await _showHitPicker(m);
    if (picked != null && mounted) {
      setState(() => _customHits = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String tierLabel(String k) => k == 'dex.bulkHp'
        ? AppStrings.t('dex.decisiveHalf')
        : AppStrings.t(k);

    final curatedRows = <TableRow>[];
    for (final m in _decisiveMoves()) {
      final hits = _hits[m.name] ?? 1;
      final v1 = _outputFor(m, _baseEv, const NatureProfile(), hits);
      final v2 = _outputFor(m, _halfEv(m), const NatureProfile(), hits);
      final v3 = _outputFor(m, _halfEv(m), _fullNature(m), hits);
      curatedRows.add(TableRow(children: [
        _moveLabel(m, hits: hits, onTap: () => _pickKeyMoveHits(m.name, m)),
        _DexTableCell(_BulkSection._fmt(v1), bold: true),
        _DexTableCell(_BulkSection._fmt(v2), bold: true),
        _DexTableCell(_BulkSection._fmt(v3), bold: true),
      ]));
    }

    // Scratch area below the table. The MoveSelector claims the full
    // section width (no column-1 squeeze) so search is roomy; once a
    // move is picked, a compact 4-column row beneath shows its values
    // aligned with the main table's columns.
    final custom = _customMove;
    int? c1, c2, c3;
    int customHits = _customHits;
    if (custom != null && custom.power > 0) {
      customHits = custom.isMultiHit && _customHits < custom.minHits
          ? custom.minHits
          : _customHits;
      c1 = _outputFor(custom, _baseEv, const NatureProfile(), customHits);
      c2 = _outputFor(
          custom, _halfEv(custom), const NatureProfile(), customHits);
      c3 = _outputFor(
          custom, _halfEv(custom), _fullNature(custom), customHits);
    }

    final customHasTierPicker = custom != null && _hasTierPicker(custom);

    // Single Row layout — flex values change instead of the widget
    // tree, so tapping the compact selector doesn't unmount it (which
    // was losing focus and forcing a second tap). Expand to flex 9
    // (the full 3+2+2+2 table width) while focused or empty; collapse
    // to flex 3 (matching the column-1 width) once a move is set and
    // focus is lost so the results line up with the main table.
    final fuseWithValues =
        !_scratchFocused && custom != null && custom.power > 0;
    final scratchArea = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border.all(color: scheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: fuseWithValues ? 3 : 9,
            child: Row(
              children: [
                Expanded(
                  child: MoveSelector(
                    key: ValueKey(
                        'dex_decisive_custom_${widget.pokemon.name}'),
                    initialMoveName: custom?.name,
                    pokemonName: widget.pokemon.name,
                    pokemonNameKo: widget.pokemon.nameKo,
                    dexNumber: widget.pokemon.dexNumber,
                    onFocusChanged: (f) {
                      if (_scratchFocused != f) {
                        setState(() => _scratchFocused = f);
                      }
                    },
                    onSelected: (m) => setState(() {
                      _customMove = m;
                      _customHits = m.isMultiHit ? m.maxHits : 1;
                    }),
                  ),
                ),
                if (customHasTierPicker) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _pickCustomHits(custom),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.onSurface.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '×$customHits',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (fuseWithValues) ...[
            Expanded(
              flex: 2,
              child: _DexTableCell(_BulkSection._fmt(c1!), bold: true),
            ),
            Expanded(
              flex: 2,
              child: _DexTableCell(_BulkSection._fmt(c2!), bold: true),
            ),
            Expanded(
              flex: 2,
              child: _DexTableCell(_BulkSection._fmt(c3!), bold: true),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.decisive')),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(
            color: scheme.outlineVariant,
            width: 1,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              children: [
                const SizedBox.shrink(),
                for (final k in const [
                  'dex.bulkNone',
                  'dex.bulkHp',
                  'dex.bulkFull',
                ])
                  _DexTableCell(tierLabel(k), bold: true, dim: true),
              ],
            ),
            ...curatedRows,
          ],
        ),
        const SizedBox(height: 6),
        scratchArea,
      ],
    );
  }

  Widget _moveLabel(Move m,
      {required int hits, required VoidCallback onTap}) {
    final canPick = _hasTierPicker(m);
    final isStacking = isStackingPower(m);
    final name = m.localizedName;
    // Stacking moves (Last Respects) always keep the chip so the
    // picker is discoverable even at the x1 baseline. Multi-hit moves
    // collapse to a plain row when the user's picked x1.
    if (!canPick || (!isStacking && hits <= 1)) {
      return _DexTableCell(name, align: TextAlign.left, bold: true);
    }
    // Multi-hit: name + tappable (×N) chip. Inside the same cell so
    // table column sizing is still driven by label column flex.
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: canPick ? onTap : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '×$hits',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared cell widget for the dex tables — gives consistent padding,
/// alignment, font sizing across the bulk and decisive-power tables.
class _DexTableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool dim;
  final TextAlign align;

  const _DexTableCell(
    this.text, {
    this.bold = false,
    this.dim = false,
    this.align = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: dim ? fg.withValues(alpha: 0.7) : fg,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800));
  }
}

// ────────────────────────────────────────────────────────────────────────
// Moves tab
// ────────────────────────────────────────────────────────────────────────

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

enum _MoveSortKey { name, type, category, power, accuracy }

class _MovesTabState extends State<_MovesTab> {
  String _query = '';
  PokemonType? _typeFilter;
  MoveCategory? _categoryFilter;
  _MoveSortKey _sortKey = _MoveSortKey.name;
  bool _sortAsc = true;

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

  Set<PokemonType> _availableTypes() {
    final out = <PokemonType>{};
    for (final m in widget.moveDex.values) {
      if (widget.learnable.contains(toShowdownMoveId(m.name))) {
        out.add(m.type);
      }
    }
    return out;
  }

  Set<MoveCategory> _availableCategories() {
    final out = <MoveCategory>{};
    for (final m in widget.moveDex.values) {
      if (widget.learnable.contains(toShowdownMoveId(m.name))) {
        out.add(m.category);
      }
    }
    return out;
  }

  void _toggleSort(_MoveSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        // Power/accuracy default to descending (big → small) since
        // that's almost always what you want when ranking moves.
        _sortAsc = !(key == _MoveSortKey.power || key == _MoveSortKey.accuracy);
      }
    });
  }

  int _compare(Move a, Move b) {
    int cmp;
    switch (_sortKey) {
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
        // Treat 0 (—) as "no miss" → highest when sorting descending,
        // lowest when sorting ascending. Simplest: leave as-is.
        cmp = a.accuracy.compareTo(b.accuracy);
    }
    if (cmp == 0 && _sortKey != _MoveSortKey.name) {
      cmp = a.localizedName.compareTo(b.localizedName);
    }
    return _sortAsc ? cmp : -cmp;
  }

  List<Move> _filtered() {
    if (widget.pokemon == null) return [];
    final ids = widget.learnable;
    final out = <Move>[];
    for (final m in widget.moveDex.values) {
      // Skip calc-only variants (Magnitude 4-10 etc.) — the canonical
      // synthetic entry shows up via its own row instead.
      if (m.hasTag(MoveTags.dexHidden)) continue;
      final mid = toShowdownMoveId(m.name);
      if (!ids.contains(mid)) continue;
      if (_typeFilter != null && m.type != _typeFilter) continue;
      if (_categoryFilter != null && m.category != _categoryFilter) continue;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matches = m.name.toLowerCase().contains(q) ||
            m.nameKo.toLowerCase().contains(q) ||
            m.nameJa.toLowerCase().contains(q);
        if (!matches) continue;
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

  Widget _typeDropdown() {
    final avail = _availableTypes();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showTypeFilterDialog(
          context: context,
          current: _typeFilter,
          available: avail,
        );
        if (!mounted || identical(picked, kTypeFilterDismissed)) return;
        setState(() => _typeFilter = picked as PokemonType?);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        // Stack with an invisible "all" label so the chip width stays
        // constant regardless of which type is picked — otherwise the
        // chip jumps around between long ("전기"/"격투") and short
        // ("물"/"불") selections.
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
    );
  }

  Widget _categoryDropdown() {
    String label(MoveCategory? c) {
      if (c == null) return AppStrings.t('dex.allCategories');
      switch (c) {
        case MoveCategory.physical: return AppStrings.t('damage.physical');
        case MoveCategory.special: return AppStrings.t('damage.special');
        case MoveCategory.status: return AppStrings.t('damage.status');
      }
    }

    // Same sentinel trick as _typeDropdown — PopupMenuButton swallows
    // null selections, so encode "all" as -1.
    const allSentinel = -1;
    final avail = _availableCategories();
    return PopupMenuButton<int>(
      tooltip: AppStrings.t('dex.allCategories'),
      popUpAnimationStyle:
          const AnimationStyle(duration: Duration(milliseconds: 100)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        // Stack with invisible "all categories" placeholder keeps the
        // chip width constant across selections.
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
          if (avail.contains(c))
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
      final arrow = active ? (_sortAsc ? ' ↑' : ' ↓') : '';
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
                color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
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

// _ChampionsOnlyToggle removed — the Champions-only filter is now a
// global setting accessible from AppSettingsMenu, shared across the
// calculator, dex, move dex, and team builder screens.
