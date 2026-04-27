import 'package:flutter/material.dart';
import '../data/champions_usage.dart';
import '../data/pokedex.dart';
import '../data/sample_storage.dart';
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

/// Process-lifetime team state — survives navigating away from the
/// screen so the user doesn't lose their picks the moment they pop
/// back to the calculator. Cleared only on app restart. (Persistent
/// disk storage will hook into the existing sample save/load slot.)
class _TeamCoverageStore {
  static const int maxTeamSize = 6;
  static final List<_TeamSlot> team =
      List.generate(maxTeamSize, (_) => _TeamSlot());
}

class TeamCoverageScreen extends StatefulWidget {
  final Map<String, String> abilityNames;
  final Map<String, String> itemNames;

  const TeamCoverageScreen({
    super.key,
    this.abilityNames = const {},
    this.itemNames = const {},
  });

  @override
  State<TeamCoverageScreen> createState() => _TeamCoverageScreenState();
}

class _TeamCoverageScreenState extends State<TeamCoverageScreen> {
  static const int _maxTeamSize = _TeamCoverageStore.maxTeamSize;
  // Backed by the singleton so the picks persist across pushes/pops.
  List<_TeamSlot> get _team => _TeamCoverageStore.team;

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

      // Seed ability from curated Champions Singles data; fall back
      // to the species' first listed ability.
      final curatedAbilities = championsUsageFor(p.name)?.abilities;
      String? pickedAbility;
      if (curatedAbilities != null && curatedAbilities.isNotEmpty) {
        final first = curatedAbilities.first.name;
        if (p.abilities.contains(first)) pickedAbility = first;
      }
      pickedAbility ??= p.abilities.isNotEmpty ? p.abilities.first : null;
      _team[index].ability = pickedAbility;

      // Seed item the same way the calculator's auto-load does — use
      // the curated top pick, but skip megastones for base forms so
      // dropping a Pokemon in doesn't silently mega-evolve it. Mega
      // forms get pinned to their requiredItem.
      String? pickedItem;
      if (p.requiredItem != null) {
        pickedItem = p.requiredItem;
      } else {
        final curatedItems = championsUsageFor(p.name)?.items;
        if (curatedItems != null && curatedItems.isNotEmpty) {
          final stones = megaStoneItemIds();
          for (final row in curatedItems) {
            if (!stones.contains(row.name)) {
              pickedItem = row.name;
              break;
            }
          }
        }
      }
      _team[index].heldItem = pickedItem;
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

  /// Item picker can clear back to "no item", so we accept null.
  void _setItem(int index, String? item) {
    setState(() => _team[index].heldItem = item);
  }

  /// Pull a saved sample (from the calculator's attacker/defender
  /// sample storage) and copy just the bits the team builder cares
  /// about into [index].
  Future<void> _loadSampleInto(int index) async {
    final samples = await SampleStorage.loadSamples();
    if (!mounted) return;
    if (samples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.sample.empty')),
      ));
      return;
    }
    final pokedex = await loadPokedex();
    if (!mounted) return;
    // Build a map name → Pokemon once so we can rehydrate samples
    // whose persisted state only kept the `pokemonName` string.
    final byName = {for (final p in pokedex) p.name: p};
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (int i = 0; i < samples.length; i++)
              ListTile(
                title: Text(samples[i].name),
                subtitle: Text(samples[i].state.localizedPokemonName,
                    style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final s = samples[picked].state;
    final p = byName[s.pokemonName];
    if (p == null) return;
    setState(() {
      _team[index].pokemon = p;
      _team[index].ability = s.selectedAbility;
      _team[index].heldItem = s.selectedItem;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wide layout splits into two columns: slot list on the left,
    // matrix on the right. Threshold matches the calculator's wide
    // breakpoint feel.
    final isWide = MediaQuery.of(context).size.width >= 900;

    final slotList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _maxTeamSize; i++) ...[
          _SlotCard(
            index: i,
            slot: _team[i],
            abilityNames: widget.abilityNames,
            itemNames: widget.itemNames,
            onPokemonSelected: (p) => _setPokemon(i, p),
            onAbilitySelected: (a) => _setAbility(i, a),
            onItemSelected: (it) => _setItem(i, it),
            onLoadSample: () => _loadSampleInto(i),
            onClear: () => _clearSlot(i),
          ),
          if (i < _maxTeamSize - 1) const SizedBox(height: 4),
        ],
      ],
    );

    // Pass ALL 6 slots — including empty ones — so the matrix grid
    // is dimensionally stable. Empty slots render blank cells; the
    // summary only counts filled ones.
    final matrix = _CoverageMatrix(
      team: _team,
      abilityNames: widget.abilityNames,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('team.title')),
      ),
      body: isWide
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(child: slotList),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(child: matrix),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  slotList,
                  const SizedBox(height: 20),
                  matrix,
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
  final Map<String, String> itemNames;
  final ValueChanged<Pokemon> onPokemonSelected;
  final ValueChanged<String> onAbilitySelected;
  final ValueChanged<String?> onItemSelected;
  final VoidCallback onLoadSample;
  final VoidCallback onClear;

  const _SlotCard({
    required this.index,
    required this.slot,
    required this.abilityNames,
    required this.itemNames,
    required this.onPokemonSelected,
    required this.onAbilitySelected,
    required this.onItemSelected,
    required this.onLoadSample,
    required this.onClear,
  });

  String _abilityLabel(String key) => abilityNames[key] ?? key;
  String _itemLabel(String? key) =>
      key == null ? AppStrings.t('team.item.none') : (itemNames[key] ?? key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = slot.pokemon;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Row 1: index | name selector | type chips | load | clear
          Row(
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
                  initialPokemonName: p?.name,
                  onSelected: onPokemonSelected,
                ),
              ),
              if (p != null) ...[
                const SizedBox(width: 6),
                _typeChip(p.type1),
                if (p.type2 != null) ...[
                  const SizedBox(width: 2),
                  _typeChip(p.type2!),
                ],
              ],
              const SizedBox(width: 4),
              IconButton(
                tooltip: AppStrings.t('team.sample.load'),
                icon: const Icon(Icons.folder_open, size: 18),
                onPressed: onLoadSample,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
              if (p != null)
                IconButton(
                  tooltip: '',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
            ],
          ),
          // ─── Row 2: ability + item dropdowns — always present so
          // the row height stays constant whether or not a Pokemon is
          // picked. Disabled when empty.
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: _abilityDropdown(scheme, p),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _itemDropdown(scheme, p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(PokemonType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(type),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        KoStrings.getTypeName(type),
        style: const TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _abilityDropdown(ColorScheme scheme, Pokemon? p) {
    if (p == null) {
      return _dropdownBody(scheme, '-', hasValue: false, disabled: true);
    }
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      // Mid-battle calc — match the rest of the app's snappy ≤100 ms
      // popup style instead of the default ~250 ms slide.
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      itemBuilder: (_) => [
        for (final ab in p.abilities)
          PopupMenuItem(
            value: ab,
            child: Text(_abilityLabel(ab),
                style: const TextStyle(fontSize: 13)),
          ),
      ],
      onSelected: onAbilitySelected,
      child: _dropdownBody(
        scheme,
        slot.ability != null ? _abilityLabel(slot.ability!) : '-',
        hasValue: slot.ability != null,
      ),
    );
  }

  /// Item picker. We surface the curated top items for the species
  /// (champions_usage data) plus a "none" option — full item search
  /// stays in the calculator. The item field mostly matters here for
  /// Air Balloon / Iron Ball, which are common enough to show up in
  /// curated lists. Renders as a disabled row when no Pokemon yet.
  Widget _itemDropdown(ColorScheme scheme, Pokemon? p) {
    if (p == null) {
      return _dropdownBody(
        scheme,
        AppStrings.t('team.item.none'),
        hasValue: false,
        disabled: true,
      );
    }
    final usage = championsUsageFor(p.name);
    final curated = usage?.items.map((row) => row.name).toList() ?? const [];
    return PopupMenuButton<String?>(
      tooltip: '',
      position: PopupMenuPosition.under,
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 100)),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(AppStrings.t('team.item.none'),
              style: const TextStyle(fontSize: 13)),
        ),
        for (final item in curated)
          PopupMenuItem<String?>(
            value: item,
            child: Text(_itemLabel(item),
                style: const TextStyle(fontSize: 13)),
          ),
      ],
      onSelected: onItemSelected,
      child: _dropdownBody(
        scheme,
        _itemLabel(slot.heldItem),
        hasValue: slot.heldItem != null,
      ),
    );
  }

  /// Shared dropdown body. [disabled] dims the border, label, and
  /// arrow so an empty slot's controls read as inert without removing
  /// them from the layout.
  Widget _dropdownBody(ColorScheme scheme, String label,
      {required bool hasValue, bool disabled = false}) {
    final borderAlpha = disabled ? 0.4 : 1.0;
    final labelAlpha = disabled ? 0.3 : (hasValue ? 1.0 : 0.4);
    final iconAlpha = disabled ? 0.25 : 0.6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: borderAlpha)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: labelAlpha),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.arrow_drop_down,
              size: 18, color: scheme.onSurface.withValues(alpha: iconAlpha)),
        ],
      ),
    );
  }
}

class _CoverageMatrix extends StatelessWidget {
  final List<_TeamSlot> team;
  final Map<String, String> abilityNames;

  const _CoverageMatrix({
    required this.team,
    required this.abilityNames,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The matrix grid is dimensionally stable: always [team.length]
    // Pokemon columns (typically 6, even when slots are empty). Empty
    // slots produce a `null` row internally, which the renderer paints
    // as a blank cell. The summary on the right only counts filled
    // slots, so 0/0 reads cleanly when the team is empty.
    final filledCells = <CoverageSlot>[];
    final filledIndices = <int>[];
    for (int i = 0; i < team.length; i++) {
      final slot = team[i];
      final p = slot.pokemon;
      if (p == null) continue;
      filledCells.add(CoverageSlot(
        type1: p.type1,
        type2: p.type2,
        ability: slot.ability,
        heldItem: slot.heldItem,
      ));
      filledIndices.add(i);
    }
    final filledMatrix = defensiveCoverageMatrix(filledCells);
    final summary = summarize(filledMatrix);

    // Re-expand into a [team.length × 18] grid where empty slots get
    // null rows. Renderer keys off this for blank cells.
    final List<List<CoverageCell>?> displayMatrix =
        List<List<CoverageCell>?>.filled(team.length, null);
    for (int j = 0; j < filledIndices.length; j++) {
      displayMatrix[filledIndices[j]] = filledMatrix[j];
    }

    // Type-label column is sized to a snug 3-char chip (Korean type
    // names cap at 3 chars: 에스퍼, 고스트, 드래곤, 페어리) — no
    // wasted whitespace around it. The remaining width is split
    // between the 6 Pokemon columns and the summary block via flex.
    return Table(
      defaultColumnWidth: const FlexColumnWidth(1.0),
      columnWidths: {
        0: const FixedColumnWidth(48),
        for (int i = 0; i < team.length; i++)
          i + 1: const FlexColumnWidth(1.0),
        team.length + 1: const FlexColumnWidth(1.8),
      },
      border: TableBorder.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6), width: 0.6),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(scheme),
        for (int t = 0; t < teamCoverageAttackTypes.length; t++)
          _typeRow(t, displayMatrix, summary[t], scheme),
      ],
    );
  }

  TableRow _headerRow(ColorScheme scheme) {
    return TableRow(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      children: [
        const SizedBox.shrink(),
        for (final slot in team)
          slot.pokemon != null
              ? _vertNameCell(slot.pokemon!.localizedName)
              : const SizedBox(height: 84),
        // Color-coded labels side-by-side, with the same thicker
        // left divider that the data rows carry below.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                AppStrings.t('team.matrix.weak'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                ),
              ),
              Text(
                AppStrings.t('team.matrix.resist'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Vertical Pokemon name cell — RotatedBox flips a normal Text 90°
  /// so a 6-column header stays narrow even with longer names like
  /// "메가샹델라". Tall enough to fit ~6 Korean characters.
  Widget _vertNameCell(String name) {
    return SizedBox(
      height: 84,
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  TableRow _typeRow(
      int t,
      List<List<CoverageCell>?> matrix,
      CoverageColumnSummary summary,
      ColorScheme scheme) {
    final attackType = teamCoverageAttackTypes[t];
    return TableRow(
      // Zebra-stripe data rows so the eye can track a single type
      // across the 6 Pokemon columns without losing its place. The
      // stripe sits behind everything (cell content paints on top),
      // so the summary's colored backgrounds still read at full
      // saturation.
      decoration: BoxDecoration(
        color: t.isOdd
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : null,
      ),
      children: [
        // No horizontal padding — the type chip fills the 48 px
        // column flush, no whitespace either side. Vertical pad is
        // just enough to keep the chip from touching the row borders.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _attackTypeChip(attackType),
        ),
        for (int p = 0; p < team.length; p++)
          // Empty slot → blank cell so the column stays in place
          // without inviting the eye to read anything into it.
          matrix[p] == null
              ? const SizedBox(height: 22)
              : _multCell(matrix[p]![t], scheme),
        _summaryCell(summary, scheme),
      ],
    );
  }

  /// Solid colored chip — same style as the team-builder slot's type
  /// chips and the attacker/defender panel badges. The chip fills the
  /// fixed-width type column edge-to-edge; the 3-char Korean name sits
  /// centered with the colored bg picking up any slack.
  Widget _attackTypeChip(PokemonType type) {
    return ClipRect(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: KoStrings.getTypeColor(type),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          KoStrings.getTypeName(type),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: const TextStyle(
              fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Background tint for the weak/resist halves of the summary cell —
  /// gets denser the more team members fall into that bucket. 0 is
  /// transparent so it blends with the row's zebra stripe; 6 (full
  /// team) is the most saturated shade we'll show.
  Color _summaryBg(int count, MaterialColor base) {
    return switch (count) {
      0 => Colors.transparent,
      1 => base.shade50,
      2 => base.shade100,
      3 => base.shade200,
      4 => base.shade300,
      _ => base.shade400, // 5 or 6
    };
  }

  /// Side-by-side numbers — weak (red) on the left, resist+immune
  /// (blue) on the right. Each half carries a tint that grows with
  /// the count, so the eye can scan the column and spot the worst
  /// (densest red) and best (densest blue) types at a glance without
  /// reading the digits. Fenced off from the matrix by a thicker
  /// left border.
  Widget _summaryCell(CoverageColumnSummary summary, ColorScheme scheme) {
    final resistOrImmune = summary.resist + summary.immune;
    final weakBg = _summaryBg(summary.weak, Colors.red);
    final resistBg = _summaryBg(resistOrImmune, Colors.blue);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: weakBg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${summary.weak}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: summary.weak > 0
                      ? Colors.red.shade900
                      : scheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: resistBg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '$resistOrImmune',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: resistOrImmune > 0
                      ? Colors.blue.shade900
                      : scheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One matrix cell. We rely on text + color alone (no background
  /// tint) so a column scan reads clean — each cell is just one short
  /// glyph in one of four colors:
  ///   - dark red   "4×"  — quad weakness
  ///   - red        "2×"  — weakness
  ///   - (blank)          — neutral
  ///   - blue       "½"   — resist
  ///   - dark blue  "¼"   — quad resist
  ///   - grey       "무"  — immune
  Widget _multCell(CoverageCell cell, ColorScheme scheme) {
    String label;
    Color fg;
    FontWeight weight = FontWeight.w800;
    if (cell.isImmune) {
      label = AppStrings.t('team.matrix.immune');
      fg = scheme.onSurface.withValues(alpha: 0.45);
      weight = FontWeight.w700;
    } else {
      final m = cell.multiplier;
      if (m == 4) {
        label = '4×';
        fg = Colors.red.shade900;
      } else if (m == 2) {
        label = '2×';
        fg = Colors.red.shade600;
      } else if (m == 0.5) {
        label = '½';
        fg = Colors.blue.shade600;
      } else if (m == 0.25) {
        label = '¼';
        fg = Colors.blue.shade900;
      } else {
        label = '';
        fg = scheme.onSurface;
      }
    }
    return Container(
      height: 22,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: weight, color: fg),
      ),
    );
  }

}
