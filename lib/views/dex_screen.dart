import 'package:flutter/material.dart';

import '../data/abilitydex.dart';
import '../data/learnsetdex.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../models/ability.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../models/type.dart';
import '../utils/app_strings.dart';
import '../utils/localization.dart';
import '../utils/type_effectiveness.dart';
import 'widgets/pokemon_selector.dart';

/// Result produced when the user taps "공격측으로" / "방어측으로" in
/// the dex header — the dex pops with this payload so the calculator
/// can apply the Pokemon to the chosen side.
///
/// `side`: 0 = attacker, 1 = defender.
typedef DexPickResult = ({int side, Pokemon pokemon});

/// Pokédex screen — search a Pokemon and see species info, abilities,
/// type matchups, and learnable moves. Reuses the calculator's
/// PokemonSelector for search and KoStrings for type colors / names so
/// the visual language matches.
class DexScreen extends StatefulWidget {
  /// If non-null, opens directly on this Pokemon's page (used by the
  /// "open in dex" button on the calculator panels).
  final String? initialPokemonName;

  const DexScreen({super.key, this.initialPokemonName});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  Pokemon? _selected;

  Map<String, Ability> _abilityDex = const {};
  Map<String, Move> _moveDex = const {};
  Set<String> _learnable = const {};
  bool _loadingMoves = false;

  @override
  void initState() {
    super.initState();
    _loadDexes();
  }

  Future<void> _loadDexes() async {
    final results = await Future.wait([
      loadAbilitydex(),
      loadMovedex(),
      loadPokedex(),
    ]);
    if (!mounted) return;
    final allPokemon = results[2] as List<Pokemon>;
    // Auto-select the initial pokemon so the dex opens with data
    // populated — PokemonSelector shows the initial name in the
    // text field but doesn't fire onSelected, so the parent stays
    // uninitialized without this nudge.
    final initialName = widget.initialPokemonName ?? 'Bulbasaur';
    final initial = allPokemon.firstWhere(
      (p) => p.name == initialName,
      orElse: () => allPokemon.firstWhere(
        (p) => p.dexNumber == 1,
        orElse: () => allPokemon.first,
      ),
    );
    setState(() {
      _abilityDex = results[0] as Map<String, Ability>;
      _moveDex = results[1] as Map<String, Move>;
      _selected = initial;
    });
    _loadLearnsetFor(initial);
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
    // Wide viewports: show Main + Moves side by side so users don't
    // need to swap tabs. Threshold chosen to roughly match the calc's
    // wide layout switch (1050) — anything narrower is phone/tablet
    // portrait where the tab UI works better.
    final wide = MediaQuery.of(context).size.width >= 1050;
    final mainTab = _MainTab(
      pokemon: _selected,
      abilityDex: _abilityDex,
    );
    final movesTab = _MovesTab(
      pokemon: _selected,
      learnable: _learnable,
      moveDex: _moveDex,
      loading: _loadingMoves,
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          // Dex is an immersive screen — the title is redundant, so
          // give the full width to the search field. `titleSpacing: 0`
          // removes the default gap between the back button and title
          // so the typeahead gets all available width.
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PokemonSelector(
              // PokemonSelector holds its own _selected state, so
              // don't key it by _selected.name — that would remount
              // the widget (and flash the typeahead overlay) every
              // time auto-selection or a user pick updates state.
              initialPokemonName:
                  widget.initialPokemonName ?? 'Bulbasaur',
              onSelected: _onSelect,
            ),
          ),
          bottom: wide
              ? null
              : TabBar(
                  tabs: [
                    Tab(text: AppStrings.t('dex.tabMain')),
                    Tab(text: AppStrings.t('dex.tabMoves')),
                  ],
                ),
        ),
        body: GestureDetector(
          // Tap outside the typeahead → blur it. Without this the
          // suggestion box stays mounted because flutter_typeahead's
          // hideOnUnfocus needs an actual focus change.
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
          children: [
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: mainTab),
                        const VerticalDivider(width: 1),
                        Expanded(child: movesTab),
                      ],
                    )
                  : TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  mainTab,
                  movesTab,
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Main tab — header, stats, abilities, type matchups
// ────────────────────────────────────────────────────────────────────────

class _MainTab extends StatelessWidget {
  final Pokemon? pokemon;
  final Map<String, Ability> abilityDex;

  const _MainTab({required this.pokemon, required this.abilityDex});

  @override
  Widget build(BuildContext context) {
    final p = pokemon;
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(pokemon: p),
          const SizedBox(height: 12),
          _StatRow(pokemon: p),
          const SizedBox(height: 16),
          _AbilitiesSection(pokemon: p, abilityDex: abilityDex),
          const SizedBox(height: 16),
          _TypeMatchupsSection(pokemon: p),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Pokemon pokemon;
  const _Header({required this.pokemon});

  void _send(BuildContext context, int side) {
    Navigator.of(context).pop<DexPickResult>((side: side, pokemon: pokemon));
  }

  @override
  Widget build(BuildContext context) {
    final dexId = pokemon.dexNumber.toString().padLeft(3, '0');
    final altName = AppStrings.current == AppLanguage.ko
        ? '${pokemon.nameEn ?? pokemon.name} · ${pokemon.nameJa}'
        : (AppStrings.current == AppLanguage.ja
            ? '${pokemon.nameEn ?? pokemon.name} · ${pokemon.nameKo}'
            : '${pokemon.nameKo} · ${pokemon.nameJa}');
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
            children: [
              Text('#$dexId',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pokemon.localizedName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._formBadges(context, pokemon),
              const SizedBox(width: 4),
              _sendButton(
                context,
                label: AppStrings.t('dex.sendToAttacker'),
                color: Colors.red.shade600,
                onPressed: () => _send(context, 0),
              ),
              const SizedBox(width: 4),
              _sendButton(
                context,
                label: AppStrings.t('dex.sendToDefender'),
                color: Colors.blue.shade600,
                onPressed: () => _send(context, 1),
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

  static Widget _sendButton(
    BuildContext context, {
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
          style:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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

  static List<Widget> _formBadges(BuildContext context, Pokemon p) {
    final badges = <Widget>[];
    if (p.isMega) {
      badges.add(Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('MEGA',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
        ),
      ));
    }
    return badges;
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

  @override
  Widget build(BuildContext context) {
    final abs = pokemon.abilities;
    if (abs.isEmpty) return const SizedBox.shrink();
    // Convention: last ability in the list is the hidden one when 3
    // are listed (PokeAPI convention is preserved in our data). We
    // tag with '*' when this looks like a HA pattern.
    final hiddenIndex = abs.length >= 2 ? abs.length - 1 : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(AppStrings.t('dex.abilities')),
        const SizedBox(height: 6),
        for (int i = 0; i < abs.length; i++)
          _abilityRow(abs[i], isHidden: i == hiddenIndex && abs.length >= 2),
      ],
    );
  }

  Widget _abilityRow(String key, {required bool isHidden}) {
    final ab = abilityDex[key];
    final name = ab?.localizedName ?? key;
    final desc = ab?.localizedDescription;
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
  const _TypeMatchupsSection({required this.pokemon});

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
      final mult = getCombinedEffectiveness(atkType, pokemon.type1, pokemon.type2);
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
    // PopupMenuButton can't distinguish a selected null-valued item
    // from dismissal, so we encode "all" as -1 and every real type as
    // its enum index.
    const allSentinel = -1;
    final avail = _availableTypes();
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
      itemBuilder: (_) => [
        PopupMenuItem(
          value: allSentinel,
          child: Text(AppStrings.t('dex.allTypes'),
              style: const TextStyle(fontSize: 13)),
        ),
        for (final t in PokemonType.values)
          if (t != PokemonType.typeless && avail.contains(t))
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
          AnimationStyle(duration: const Duration(milliseconds: 100)),
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
    return Padding(
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
    );
  }
}
