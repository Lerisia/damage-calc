import 'package:flutter/material.dart';

import '../data/abilitydex.dart';
import '../data/learnsetdex.dart';
import '../data/movedex.dart';
import '../models/ability.dart';
import '../models/dynamax.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../models/type.dart';
import '../utils/app_strings.dart';
import '../utils/localization.dart';
import '../utils/type_effectiveness.dart';
import 'widgets/pokemon_panel.dart' show DynamaxPainter;
import 'widgets/pokemon_selector.dart';

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
    ]);
    if (!mounted) return;
    setState(() {
      _abilityDex = results[0] as Map<String, Ability>;
      _moveDex = results[1] as Map<String, Move>;
    });
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.t('dex.title')),
          bottom: TabBar(
            tabs: [
              Tab(text: AppStrings.t('dex.tabMain')),
              Tab(text: AppStrings.t('dex.tabMoves')),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: PokemonSelector(
                key: ValueKey('dex_search_${_selected?.name ?? "init"}'),
                initialPokemonName:
                    widget.initialPokemonName ?? _selected?.name ?? 'Bulbasaur',
                onSelected: _onSelect,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MainTab(
                    pokemon: _selected,
                    abilityDex: _abilityDex,
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
                ),
              ),
              ..._formBadges(context, pokemon),
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
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('${AppStrings.t('dex.height')} ${pokemon.height} m'),
                Text('${AppStrings.t('dex.weight')} ${pokemon.weight} kg'),
                Text(_genderLabel(pokemon)),
              ],
            ),
          ),
        ],
      ),
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

  static String _genderLabel(Pokemon p) {
    if (p.genderRate == -1) return AppStrings.t('dex.genderless');
    if (p.genderRate == 0) return '${AppStrings.t('dex.gender')} ♂';
    if (p.genderRate == 8) return '${AppStrings.t('dex.gender')} ♀';
    final female = p.genderRate / 8 * 100;
    final male = 100 - female;
    return '♂ ${male.toStringAsFixed(male % 1 == 0 ? 0 : 1)}% / '
        '♀ ${female.toStringAsFixed(female % 1 == 0 ? 0 : 1)}%';
  }

  static List<Widget> _formBadges(BuildContext context, Pokemon p) {
    final badges = <Widget>[];
    if (p.canGmax) {
      badges.add(Padding(
        padding: const EdgeInsets.only(left: 4),
        child: SizedBox(
          width: 22, height: 22,
          child: CustomPaint(
            painter: DynamaxPainter(
              state: DynamaxState.gigantamax,
              isGmax: true,
            ),
          ),
        ),
      ));
    } else if (p.canDynamax) {
      badges.add(Padding(
        padding: const EdgeInsets.only(left: 4),
        child: SizedBox(
          width: 22, height: 22,
          child: CustomPaint(
            painter: DynamaxPainter(
              state: DynamaxState.dynamax,
              isGmax: false,
            ),
          ),
        ),
      ));
    }
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
      0.5: [],
      0.25: [],
      0.0: [],
    };
    for (final atkType in PokemonType.values) {
      if (atkType == PokemonType.typeless) continue;
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

class _MovesTabState extends State<_MovesTab> {
  String _query = '';
  PokemonType? _typeFilter;
  MoveCategory? _categoryFilter;

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
    out.sort((a, b) =>
        a.localizedName.compareTo(b.localizedName));
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
    return Column(
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
        if (moves.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppStrings.t('dex.noMovesMatch'),
                style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: moves.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _moveRow(moves[i]),
            ),
          ),
      ],
    );
  }

  Widget _typeDropdown() {
    return PopupMenuButton<PokemonType?>(
      tooltip: AppStrings.t('dex.allTypes'),
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
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
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text(AppStrings.t('dex.allTypes'),
              style: const TextStyle(fontSize: 13)),
        ),
        for (final t in PokemonType.values)
          if (t != PokemonType.typeless)
            PopupMenuItem(
              value: t,
              child: Text(KoStrings.getTypeName(t),
                  style: TextStyle(
                      fontSize: 13, color: KoStrings.getTypeColor(t))),
            ),
      ],
      onSelected: (v) => setState(() => _typeFilter = v),
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

    return PopupMenuButton<MoveCategory?>(
      tooltip: AppStrings.t('dex.allCategories'),
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label(_categoryFilter),
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem<MoveCategory?>(value: null, child: Text('—')),
        for (final c in MoveCategory.values)
          PopupMenuItem(value: c, child: Text(label(c))),
      ],
      onSelected: (v) => setState(() => _categoryFilter = v),
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
