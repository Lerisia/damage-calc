import 'package:flutter/material.dart';
import '../data/champions_usage.dart';
import '../models/pokemon.dart';
import '../models/type.dart';
import '../utils/app_strings.dart';
import '../utils/localization.dart';
import '../utils/team_coverage.dart';
import 'widgets/pokemon_selector.dart';

/// One slot in the team-builder. We keep just the bits that affect
/// type matchups — full BattlePokemonState is overkill here and would
/// drag along EV/level/move state nobody fills out.
class _TeamSlot {
  Pokemon? pokemon;
  String? ability;
  String? heldItem; // currently only used to honour Air Balloon / Iron Ball
}

class TeamCoverageScreen extends StatefulWidget {
  final Map<String, String> abilityNames;

  const TeamCoverageScreen({super.key, this.abilityNames = const {}});

  @override
  State<TeamCoverageScreen> createState() => _TeamCoverageScreenState();
}

class _TeamCoverageScreenState extends State<TeamCoverageScreen> {
  static const int _maxTeamSize = 6;
  final List<_TeamSlot> _team = List.generate(_maxTeamSize, (_) => _TeamSlot());

  /// Filled slots only — used to feed coverage logic and to render
  /// the matrix without empty rows.
  List<_TeamSlot> get _filled =>
      _team.where((s) => s.pokemon != null).toList(growable: false);

  /// Resolves a slot to a [CoverageSlot]. Pokemon's natural type1/2
  /// is used; Forest's Curse / type-picker overrides aren't supported
  /// in the team builder yet.
  CoverageSlot _toCoverageSlot(_TeamSlot s) {
    final p = s.pokemon!;
    return CoverageSlot(
      type1: p.type1,
      type2: p.type2,
      ability: s.ability,
      heldItem: s.heldItem,
    );
  }

  void _setPokemon(int index, Pokemon p) {
    setState(() {
      _team[index].pokemon = p;
      // Seed ability from curated Champions Singles data when the
      // species has it; fall back to species' first listed ability.
      final curated = championsUsageFor(p.name)?.abilities;
      String? picked;
      if (curated != null && curated.isNotEmpty) {
        final first = curated.first.name;
        if (p.abilities.contains(first)) picked = first;
      }
      picked ??= p.abilities.isNotEmpty ? p.abilities.first : null;
      _team[index].ability = picked;
      _team[index].heldItem = null;
    });
  }

  void _clearSlot(int index) {
    setState(() {
      _team[index] = _TeamSlot();
    });
  }

  void _setAbility(int index, String ability) {
    setState(() => _team[index].ability = ability);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('team.title')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _maxTeamSize; i++) ...[
              _SlotCard(
                index: i,
                slot: _team[i],
                abilityNames: widget.abilityNames,
                onPokemonSelected: (p) => _setPokemon(i, p),
                onAbilitySelected: (a) => _setAbility(i, a),
                onClear: () => _clearSlot(i),
              ),
              if (i < _maxTeamSize - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 20),
            _CoverageMatrix(
              team: _filled,
              cells: _filled.map(_toCoverageSlot).toList(),
              abilityNames: widget.abilityNames,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final int index;
  final _TeamSlot slot;
  final Map<String, String> abilityNames;
  final ValueChanged<Pokemon> onPokemonSelected;
  final ValueChanged<String> onAbilitySelected;
  final VoidCallback onClear;

  const _SlotCard({
    required this.index,
    required this.slot,
    required this.abilityNames,
    required this.onPokemonSelected,
    required this.onAbilitySelected,
    required this.onClear,
  });

  String _abilityLabel(String key) => abilityNames[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = slot.pokemon;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: PokemonSelector(
              key: ValueKey('team_slot_${index}_${p?.name ?? "empty"}'),
              initialPokemonName: p?.name ?? '',
              onSelected: onPokemonSelected,
            ),
          ),
          const SizedBox(width: 8),
          if (p != null && p.abilities.isNotEmpty) ...[
            SizedBox(
              width: 140,
              child: PopupMenuButton<String>(
                tooltip: '',
                position: PopupMenuPosition.under,
                itemBuilder: (_) => [
                  for (final ab in p.abilities)
                    PopupMenuItem(
                      value: ab,
                      child: Text(_abilityLabel(ab),
                          style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onSelected: onAbilitySelected,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          slot.ability != null
                              ? _abilityLabel(slot.ability!)
                              : '-',
                          style: TextStyle(
                            fontSize: 13,
                            color: slot.ability != null
                                ? scheme.onSurface
                                : scheme.onSurface.withValues(alpha: 0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '',
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverageMatrix extends StatelessWidget {
  final List<_TeamSlot> team;
  final List<CoverageSlot> cells;
  final Map<String, String> abilityNames;

  const _CoverageMatrix({
    required this.team,
    required this.cells,
    required this.abilityNames,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (cells.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          AppStrings.t('team.matrix.empty'),
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    final matrix = defensiveCoverageMatrix(cells);
    final summary = summarize(matrix);

    // Horizontal scroll for the matrix on narrow screens — 18 attack
    // type columns + the per-row summary column never fit comfortably
    // on mobile portrait.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(44),
        columnWidths: const {0: FixedColumnWidth(120)},
        border: TableBorder.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6), width: 0.6),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _headerRow(scheme),
          for (int row = 0; row < team.length; row++)
            _pokemonRow(team[row], matrix[row], scheme),
          _summaryRow(summary, scheme),
        ],
      ),
    );
  }

  TableRow _headerRow(ColorScheme scheme) {
    return TableRow(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      children: [
        const SizedBox.shrink(),
        for (final t in teamCoverageAttackTypes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              KoStrings.getTypeName(t),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: KoStrings.getTypeColor(t),
              ),
            ),
          ),
      ],
    );
  }

  TableRow _pokemonRow(
      _TeamSlot slot, List<CoverageCell> row, ColorScheme scheme) {
    final p = slot.pokemon!;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            p.localizedName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final cell in row) _multCell(cell, scheme),
      ],
    );
  }

  /// One matrix cell. Color/text encodes the bucket so the eye can
  /// scan a column without reading every number:
  ///   - red shades: weakness (2× / 4×)
  ///   - blue shades: resist (½ / ¼)
  ///   - grey: neutral (1×, blank)
  ///   - dim outlined "무": immune (0×)
  Widget _multCell(CoverageCell cell, ColorScheme scheme) {
    if (cell.isImmune) {
      return Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.08),
        ),
        child: Text(
          AppStrings.t('team.matrix.immune'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    final m = cell.multiplier;
    String label;
    Color bg;
    Color fg;
    if (m == 4) {
      label = '4×';
      bg = Colors.red.withValues(alpha: 0.55);
      fg = Colors.white;
    } else if (m == 2) {
      label = '2×';
      bg = Colors.red.withValues(alpha: 0.28);
      fg = Colors.red.shade900;
    } else if (m == 0.5) {
      label = '½';
      bg = Colors.blue.withValues(alpha: 0.22);
      fg = Colors.blue.shade900;
    } else if (m == 0.25) {
      label = '¼';
      bg = Colors.blue.withValues(alpha: 0.45);
      fg = Colors.white;
    } else {
      // Neutral: blank cell so the colored ones stand out.
      label = '';
      bg = Colors.transparent;
      fg = scheme.onSurface;
    }
    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  TableRow _summaryRow(
      List<CoverageColumnSummary> summary, ColorScheme scheme) {
    return TableRow(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '${AppStrings.t('team.matrix.weak')} / ${AppStrings.t('team.matrix.resist')}',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        for (final col in summary)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${col.weak}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: col.weak > 0
                        ? Colors.red.shade700
                        : scheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                Text(
                  '${col.resist + col.immune}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: (col.resist + col.immune) > 0
                        ? Colors.blue.shade700
                        : scheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
