import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ability.dart';
import '../../models/move.dart';
import '../../models/pokemon.dart';
import '../../models/type.dart';
import '../../utils/ability_effects.dart';
import '../../utils/app_strings.dart';
import '../../utils/korean_search.dart';
import '../../utils/localization.dart';
import 'typeahead_helpers.dart';

/// Defensive-relation toggle used by the "약점/내성/면역" filter row.
/// `immunity` is strictly type-chart 0× (Normal vs Ghost, etc.) — it is
/// NOT a subset of `resistance` so users can filter for "immune" alone.
enum DexDefenseRelation { weakness, resistance, immunity }

/// One row of the "타입 약점 / 내성" filter — a (type, relation) pair.
/// Multiple entries on the same filter are ANDed.
@immutable
class DexDefenseEntry {
  final PokemonType type;
  final DexDefenseRelation relation;

  const DexDefenseEntry({required this.type, required this.relation});

  DexDefenseEntry copyWith({
    PokemonType? type,
    DexDefenseRelation? relation,
  }) =>
      DexDefenseEntry(
        type: type ?? this.type,
        relation: relation ?? this.relation,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DexDefenseEntry &&
          other.type == type &&
          other.relation == relation);

  @override
  int get hashCode => Object.hash(type, relation);
}

/// AND vs OR for the moves filter (up to 4 moves).
enum DexMovesMatch { and, or }

/// Which of the 6 base stats a stat constraint applies to.
enum DexStatKey { hp, attack, defense, spAttack, spDefense, speed }

/// One row of the "종족값 범위" filter — a stat with optional min/max.
/// Multiple entries are ANDed; the dialog hides stats already used in
/// other rows from each row's dropdown so the user can't add a
/// duplicate.
@immutable
class DexStatConstraint {
  final DexStatKey stat;
  final int? min;
  final int? max;

  const DexStatConstraint({required this.stat, this.min, this.max});

  /// True when the row has no effect (both bounds are null). The
  /// dialog keeps these so an empty placeholder row stays visible, but
  /// the matcher and activeCount ignore them.
  bool get hasBounds => min != null || max != null;

  DexStatConstraint copyWith({
    DexStatKey? stat,
    Object? min = _sentinel,
    Object? max = _sentinel,
  }) =>
      DexStatConstraint(
        stat: stat ?? this.stat,
        min: identical(min, _sentinel) ? this.min : min as int?,
        max: identical(max, _sentinel) ? this.max : max as int?,
      );

  static const _sentinel = Object();
}

/// All filter conditions the advanced dex search supports. Immutable —
/// the dialog mutates a draft and returns the final value via Navigator.
@immutable
class DexSearchFilter {
  /// Types the Pokémon must have.
  /// - 1 entry: Pokémon must include that type.
  /// - 2 entries: Pokémon's type set must equal exactly these two.
  final List<PokemonType> types;

  final int? bstMin, bstMax;

  /// Per-stat range filters. Multiple entries are ANDed; each entry's
  /// stat must be unique (enforced by the dialog UI).
  final List<DexStatConstraint> statConstraints;

  /// Defensive-type filter — list of (type, relation) constraints.
  /// All entries are ANDed; e.g. {fire weakness, grass resistance} →
  /// Pokémon weak to fire AND resistant to grass.
  final List<DexDefenseEntry> defenses;

  /// Internal ability key (English, as stored in Pokémon.abilities).
  final String? abilityKey;

  /// Up to 4 Showdown move IDs (e.g. "flamethrower").
  final List<String> moveIds;
  final DexMovesMatch movesMatch;

  const DexSearchFilter({
    this.types = const [],
    this.bstMin,
    this.bstMax,
    this.statConstraints = const [],
    this.defenses = const [],
    this.abilityKey,
    this.moveIds = const [],
    this.movesMatch = DexMovesMatch.and,
  });

  static const empty = DexSearchFilter();

  bool get isEmpty => activeCount == 0;

  /// How many filter sections are populated. Drives the badge on the
  /// dex-screen filter button. Each section (types, BST, per-stat,
  /// defense, ability, moves) counts at most once regardless of how
  /// many entries it has.
  int get activeCount {
    var n = 0;
    if (types.isNotEmpty) n++;
    if (bstMin != null || bstMax != null) n++;
    if (statConstraints.any((c) => c.hasBounds)) n++;
    if (defenses.isNotEmpty) n++;
    if (abilityKey != null) n++;
    if (moveIds.isNotEmpty) n++;
    return n;
  }

  DexSearchFilter copyWith({
    List<PokemonType>? types,
    Object? bstMin = _sentinel,
    Object? bstMax = _sentinel,
    List<DexStatConstraint>? statConstraints,
    List<DexDefenseEntry>? defenses,
    Object? abilityKey = _sentinel,
    List<String>? moveIds,
    DexMovesMatch? movesMatch,
  }) {
    return DexSearchFilter(
      types: types ?? this.types,
      bstMin: identical(bstMin, _sentinel) ? this.bstMin : bstMin as int?,
      bstMax: identical(bstMax, _sentinel) ? this.bstMax : bstMax as int?,
      statConstraints: statConstraints ?? this.statConstraints,
      defenses: defenses ?? this.defenses,
      abilityKey: identical(abilityKey, _sentinel)
          ? this.abilityKey
          : abilityKey as String?,
      moveIds: moveIds ?? this.moveIds,
      movesMatch: movesMatch ?? this.movesMatch,
    );
  }

  static const _sentinel = Object();
}

/// Returns true iff [p] matches every populated section of [filter].
/// [movesByPokemon] maps Pokémon.name → set of Showdown move IDs the
/// species can learn (passed in so the dex screen can precompute it
/// once instead of resolving regional/form IDs per filter call).
bool matchesDexFilter(
  Pokemon p,
  DexSearchFilter filter, {
  required Map<String, Set<String>> movesByPokemon,
}) {
  // Types — 1 selected: include the type; 2 selected: exact dual match.
  if (filter.types.length == 1) {
    final t = filter.types.first;
    if (p.type1 != t && p.type2 != t) return false;
  } else if (filter.types.length == 2) {
    final pSet = {p.type1, if (p.type2 != null) p.type2!};
    final fSet = filter.types.toSet();
    if (pSet.length != fSet.length) return false;
    if (!pSet.containsAll(fSet)) return false;
  }

  // Stats — BST + per-stat ranges. nulls = unbounded on that side.
  final s = p.baseStats;
  final bst = s.hp + s.attack + s.defense + s.spAttack + s.spDefense + s.speed;
  if (filter.bstMin != null && bst < filter.bstMin!) return false;
  if (filter.bstMax != null && bst > filter.bstMax!) return false;
  for (final c in filter.statConstraints) {
    if (!c.hasBounds) continue;
    final v = _statValue(s, c.stat);
    if (c.min != null && v < c.min!) return false;
    if (c.max != null && v > c.max!) return false;
  }

  // Defensive type — all entries are ANDed. Each relation is satisfied
  // if there's any candidate ability (including "no ability") whose
  // combined matchup against d.type makes it true. So Snorlax matches
  // "resists Fire" via Thick Fat, and a Pokémon with Fluffy matches
  // "weak to Fire" even when its pure type is neutral. "내성" still
  // includes 0× immunity matchups as a subset; "면역" stays strict 0×.
  for (final d in filter.defenses) {
    bool relationHolds(double mult) {
      switch (d.relation) {
        case DexDefenseRelation.weakness:
          return mult > 1.0;
        case DexDefenseRelation.resistance:
          return mult < 1.0;
        case DexDefenseRelation.immunity:
          return mult == 0.0;
      }
    }

    bool any = false;
    // Pure-type baseline (no ability).
    final baseMult = abilityAdjustedDefensiveMultiplier(
      d.type, p.type1, p.type2,
      ability: null,
    );
    if (relationHolds(baseMult)) {
      any = true;
    } else {
      for (final ab in p.abilities) {
        final m = abilityAdjustedDefensiveMultiplier(
          d.type, p.type1, p.type2,
          ability: ab,
        );
        if (relationHolds(m)) {
          any = true;
          break;
        }
      }
    }
    if (!any) return false;
  }

  // Ability — match if any potential ability (regular or hidden) equals.
  if (filter.abilityKey != null) {
    if (!p.abilities.contains(filter.abilityKey!)) return false;
  }

  // Moves — AND requires all 4; OR requires at least one.
  if (filter.moveIds.isNotEmpty) {
    final moves = movesByPokemon[p.name] ?? const <String>{};
    switch (filter.movesMatch) {
      case DexMovesMatch.and:
        for (final id in filter.moveIds) {
          if (!moves.contains(id)) return false;
        }
      case DexMovesMatch.or:
        var any = false;
        for (final id in filter.moveIds) {
          if (moves.contains(id)) {
            any = true;
            break;
          }
        }
        if (!any) return false;
    }
  }

  return true;
}

int _statValue(dynamic stats, DexStatKey k) {
  // `dynamic` because Stats lives in another file but its fields are
  // typed plain int — switch returns the right one without importing.
  switch (k) {
    case DexStatKey.hp:
      return stats.hp as int;
    case DexStatKey.attack:
      return stats.attack as int;
    case DexStatKey.defense:
      return stats.defense as int;
    case DexStatKey.spAttack:
      return stats.spAttack as int;
    case DexStatKey.spDefense:
      return stats.spDefense as int;
    case DexStatKey.speed:
      return stats.speed as int;
  }
}

String _statLabel(DexStatKey k) {
  switch (k) {
    case DexStatKey.hp:
      return AppStrings.t('stat.hp');
    case DexStatKey.attack:
      return AppStrings.t('stat.attack');
    case DexStatKey.defense:
      return AppStrings.t('stat.defense');
    case DexStatKey.spAttack:
      return AppStrings.t('stat.spAttack');
    case DexStatKey.spDefense:
      return AppStrings.t('stat.spDefense');
    case DexStatKey.speed:
      return AppStrings.t('stat.speed');
  }
}

/// Sentinel returned when the dialog is dismissed without applying —
/// callers should leave the existing filter untouched.
const Object kDexFilterDismissed = Object();

/// Opens the advanced dex search dialog. Returns the new
/// [DexSearchFilter] if applied, or [kDexFilterDismissed] on dismiss.
Future<Object?> showDexSearchFilterDialog({
  required BuildContext context,
  required DexSearchFilter current,
  required Map<String, Ability> abilityDex,
  required List<Move> allMoves,
}) {
  return showDialog<Object?>(
    context: context,
    builder: (ctx) => _DexSearchFilterDialog(
      initial: current,
      abilityDex: abilityDex,
      allMoves: allMoves,
    ),
  );
}

class _DexSearchFilterDialog extends StatefulWidget {
  final DexSearchFilter initial;
  final Map<String, Ability> abilityDex;
  final List<Move> allMoves;

  const _DexSearchFilterDialog({
    required this.initial,
    required this.abilityDex,
    required this.allMoves,
  });

  @override
  State<_DexSearchFilterDialog> createState() => _DexSearchFilterDialogState();
}

class _DexSearchFilterDialogState extends State<_DexSearchFilterDialog> {
  late DexSearchFilter _draft;

  // Text controllers for BST + 1 ability slot + 4 move slots. Per-stat
  // range controllers are dynamic (in _statMinCtls / _statMaxCtls),
  // index-aligned with _draft.statConstraints.
  late final TextEditingController _bstMin, _bstMax;
  // Index-aligned with _draft.statConstraints. Append on add, remove
  // on row delete, never reordered while the dialog is open.
  late List<TextEditingController> _statMinCtls;
  late List<TextEditingController> _statMaxCtls;
  late final TextEditingController _abilityCtl;
  late final List<TextEditingController> _moveCtls;

  // Cached search index for ability typeahead — built once per dialog
  // open from the (filtered) ability list so we don't reallocate every
  // suggestion-callback invocation while the user types.
  late final List<Ability> _selectableAbilities;
  late final List<SearchEntry<Ability>> _abilityEntries;
  late final List<SearchEntry<Move>> _moveEntries;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    String s(int? v) => v?.toString() ?? '';
    _bstMin = TextEditingController(text: s(_draft.bstMin));
    _bstMax = TextEditingController(text: s(_draft.bstMax));
    // The "Stats" section always shows at least one row so the
    // dropdown + range fields are discoverable — if the incoming
    // filter has none, seed an empty HP placeholder. Placeholders
    // with no bounds get dropped on commit.
    if (_draft.statConstraints.isEmpty) {
      _draft = _draft.copyWith(statConstraints: const [
        DexStatConstraint(stat: DexStatKey.hp),
      ]);
    }
    _statMinCtls = [
      for (final c in _draft.statConstraints)
        TextEditingController(text: s(c.min)),
    ];
    _statMaxCtls = [
      for (final c in _draft.statConstraints)
        TextEditingController(text: s(c.max)),
    ];
    _abilityCtl = TextEditingController(
      text: _draft.abilityKey != null
          ? (widget.abilityDex[_draft.abilityKey!]?.localizedName ??
              _draft.abilityKey!)
          : '',
    );
    // 4 move slots, prefilled with any existing IDs translated to display names.
    _moveCtls = List.generate(4, (i) {
      if (i >= _draft.moveIds.length) return TextEditingController();
      final id = _draft.moveIds[i];
      final move = widget.allMoves.firstWhere(
        (m) => _toShowdownId(m.name) == id,
        orElse: () => widget.allMoves.first,
      );
      final label = _toShowdownId(move.name) == id ? move.localizedName : id;
      return TextEditingController(text: label);
    });

    _selectableAbilities = widget.abilityDex.values
        .where((a) => !a.nonMainline && !a.descriptionOnly)
        .toList()
      ..sort((a, b) => a.localizedName.compareTo(b.localizedName));
    _abilityEntries = [
      for (final a in _selectableAbilities)
        SearchEntry(a, a.nameKo, a.name, nameJa: a.nameJa),
    ];
    _moveEntries = [
      for (final m in widget.allMoves)
        SearchEntry(m, m.nameKo, m.name, nameJa: m.nameJa, aliases: m.aliases),
    ];
  }

  @override
  void dispose() {
    for (final c in [
      _bstMin, _bstMax,
      ..._statMinCtls, ..._statMaxCtls,
      _abilityCtl,
      ..._moveCtls,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _toShowdownId(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  void _toggleType(PokemonType t) {
    setState(() {
      final list = List<PokemonType>.from(_draft.types);
      if (list.contains(t)) {
        list.remove(t);
      } else {
        if (list.length >= 2) return;
        list.add(t);
      }
      _draft = _draft.copyWith(types: list);
    });
  }

  void _resetDraft() {
    setState(() {
      // Keep the same 1-row HP placeholder as a fresh dialog open.
      _draft = const DexSearchFilter(statConstraints: [
        DexStatConstraint(stat: DexStatKey.hp),
      ]);
      for (final c in [
        _bstMin, _bstMax,
        _abilityCtl,
        ..._moveCtls,
      ]) {
        c.clear();
      }
      // Drop all but one stat row, clear that one.
      for (var i = _statMinCtls.length - 1; i > 0; i--) {
        _statMinCtls.removeAt(i).dispose();
        _statMaxCtls.removeAt(i).dispose();
      }
      _statMinCtls[0].clear();
      _statMaxCtls[0].clear();
    });
  }

  /// Snapshot the live text-field values into [_draft] before returning.
  /// We don't run an onChanged per keystroke (cheaper and less janky on
  /// number pads), so this is the single sync point. Empty stat rows
  /// (no min and no max) are dropped here so they don't show up as
  /// active filters.
  DexSearchFilter _commitDraft() {
    final stats = <DexStatConstraint>[];
    for (var i = 0; i < _draft.statConstraints.length; i++) {
      final min = _parseInt(_statMinCtls[i].text);
      final max = _parseInt(_statMaxCtls[i].text);
      if (min == null && max == null) continue;
      stats.add(_draft.statConstraints[i].copyWith(min: min, max: max));
    }
    return _draft.copyWith(
      bstMin: _parseInt(_bstMin.text),
      bstMax: _parseInt(_bstMax.text),
      statConstraints: stats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Cap height so the dialog never grows past the screen — long
    // content scrolls internally.
    final maxHeight = screen.height * 0.85;
    final width = screen.width < 420 ? screen.width - 32 : 380.0;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.t('dex.advancedSearch'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: AppStrings.t('action.close'),
            onPressed: () => Navigator.pop(context, kDexFilterDismissed),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          // Tapping any non-input area inside the dialog dismisses the
          // on-screen keyboard. Without this, numeric range inputs trap
          // focus and the user has no way out short of closing the
          // dialog. translucent so the underlying scroll/tap targets
          // still receive the event.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel(AppStrings.t('dex.advTypes')),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.t('dex.advTypesHint'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  _TypeChipGrid(
                    selected: _draft.types,
                    onTap: _toggleType,
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel(AppStrings.t('dex.advStats')),
                  const SizedBox(height: 6),
                  _rangeRow(AppStrings.t('dex.colBst'), _bstMin, _bstMax),
                  const SizedBox(height: 6),
                  _statSection(),
                  const SizedBox(height: 16),
                  _sectionLabel(AppStrings.t('dex.advDefenseType')),
                  const SizedBox(height: 6),
                  _defenseSection(),
                  const SizedBox(height: 16),
                  _sectionLabel(AppStrings.t('dex.advAbility')),
                  const SizedBox(height: 6),
                  _abilityField(),
                  const SizedBox(height: 16),
                  _sectionLabel(AppStrings.t('dex.advMoves')),
                  const SizedBox(height: 6),
                  _movesMatchToggle(),
                  const SizedBox(height: 6),
                  for (int i = 0; i < 4; i++) ...[
                    _moveField(i),
                    if (i < 3) const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      actions: [
        TextButton(
          onPressed: _resetDraft,
          child: Text(AppStrings.t('action.reset')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _commitDraft()),
          child: Text(AppStrings.t('action.apply')),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
  }

  Widget _statSection() {
    final rows = _draft.statConstraints;
    final canAdd = rows.length < DexStatKey.values.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _statRow(i, rows[i]),
          if (i < rows.length - 1) const SizedBox(height: 4),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            // Cap at 6 (one per base stat) since the dropdown hides
            // already-used stats — picking a 7th would have nothing
            // left to offer.
            onPressed: canAdd ? _addStatRow : null,
            icon: const Icon(Icons.add, size: 16),
            label: Text(AppStrings.t('dex.advAddStat')),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statRow(int index, DexStatConstraint c) {
    final used = <DexStatKey>{
      for (var i = 0; i < _draft.statConstraints.length; i++)
        if (i != index) _draft.statConstraints[i].stat,
    };
    final selectable =
        DexStatKey.values.where((k) => !used.contains(k)).toList();
    final removable = _draft.statConstraints.length > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: _StatDropdown(
              value: c.stat,
              options: selectable,
              onChanged: (k) => _changeStatType(index, k),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: _numberField(_statMinCtls[index])),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('~', style: TextStyle(fontSize: 13)),
          ),
          Expanded(child: _numberField(_statMaxCtls[index])),
          // First row can't be removed — the section always shows at
          // least one stat slot per spec.
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: AppStrings.t('action.clear'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: removable ? () => _removeStatRow(index) : null,
          ),
        ],
      ),
    );
  }

  void _addStatRow() {
    final used = _draft.statConstraints.map((c) => c.stat).toSet();
    final next = DexStatKey.values.firstWhere((k) => !used.contains(k));
    setState(() {
      _draft = _draft.copyWith(statConstraints: [
        ..._draft.statConstraints,
        DexStatConstraint(stat: next),
      ]);
      _statMinCtls.add(TextEditingController());
      _statMaxCtls.add(TextEditingController());
    });
  }

  void _removeStatRow(int index) {
    setState(() {
      final list = List<DexStatConstraint>.from(_draft.statConstraints);
      list.removeAt(index);
      _draft = _draft.copyWith(statConstraints: list);
      _statMinCtls.removeAt(index).dispose();
      _statMaxCtls.removeAt(index).dispose();
    });
  }

  void _changeStatType(int index, DexStatKey k) {
    setState(() {
      final list = List<DexStatConstraint>.from(_draft.statConstraints);
      list[index] = list[index].copyWith(stat: k);
      _draft = _draft.copyWith(statConstraints: list);
    });
  }

  Widget _rangeRow(
      String label, TextEditingController minCtl, TextEditingController maxCtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: _numberField(minCtl)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('~', style: TextStyle(fontSize: 13)),
          ),
          Expanded(child: _numberField(maxCtl)),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _defenseSection() {
    final entries = _draft.defenses;
    // Cap at 18 since each defending-type row must be a unique type
    // (no Pokémon is simultaneously weak to AND immune to the same
    // attacking type, etc.) — disable Add once every type is used.
    final canAdd = entries.length < _TypeChipGrid._options.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _defenseRow(i, entries[i]),
          if (i < entries.length - 1) const SizedBox(height: 6),
        ],
        if (entries.isNotEmpty) const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: canAdd ? _addDefenseEntry : null,
            icon: const Icon(Icons.add, size: 16),
            label: Text(AppStrings.t('dex.advAddDefense')),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defenseRow(int index, DexDefenseEntry entry) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final exclude = <PokemonType>{
                for (var i = 0; i < _draft.defenses.length; i++)
                  if (i != index) _draft.defenses[i].type,
              };
              final picked = await _pickDefenseType(exclude: exclude);
              if (picked == null || picked == entry.type) return;
              _updateDefenseEntry(index, entry.copyWith(type: picked));
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: KoStrings.getTypeColor(entry.type)
                    .withValues(alpha: 0.12),
                border: Border.all(
                  color: KoStrings.getTypeColor(entry.type)
                      .withValues(alpha: 0.6),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      KoStrings.getTypeName(entry.type),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: KoStrings.getTypeColor(entry.type),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _SegmentedToggle(
          selected: DexDefenseRelation.values.indexOf(entry.relation),
          labels: [
            AppStrings.t('dex.advWeakness'),
            AppStrings.t('dex.advResistance'),
            AppStrings.t('dex.advImmunity'),
          ],
          onChanged: (i) => _updateDefenseEntry(
            index,
            entry.copyWith(relation: DexDefenseRelation.values[i]),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          tooltip: AppStrings.t('action.clear'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => _removeDefenseEntry(index),
        ),
      ],
    );
  }

  Future<PokemonType?> _pickDefenseType({
    Set<PokemonType> exclude = const {},
  }) {
    final options =
        _TypeChipGrid._options.where((t) => !exclude.contains(t)).toList();
    if (options.isEmpty) return Future.value(null);
    return showDialog<PokemonType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppStrings.t('dex.advDefenseTypePick')),
        children: [
          for (final t in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: KoStrings.getTypeColor(t),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(KoStrings.getTypeName(t)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addDefenseEntry() async {
    final used = _draft.defenses.map((d) => d.type).toSet();
    final picked = await _pickDefenseType(exclude: used);
    if (picked == null) return;
    setState(() {
      _draft = _draft.copyWith(
        defenses: [
          ..._draft.defenses,
          DexDefenseEntry(
              type: picked, relation: DexDefenseRelation.weakness),
        ],
      );
    });
  }

  void _updateDefenseEntry(int index, DexDefenseEntry next) {
    setState(() {
      final list = List<DexDefenseEntry>.from(_draft.defenses);
      list[index] = next;
      _draft = _draft.copyWith(defenses: list);
    });
  }

  void _removeDefenseEntry(int index) {
    setState(() {
      final list = List<DexDefenseEntry>.from(_draft.defenses);
      list.removeAt(index);
      _draft = _draft.copyWith(defenses: list);
    });
  }

  Widget _abilityField() {
    return buildTypeAhead<Ability>(
      controller: _abilityCtl,
      hideOnEmpty: true,
      maxHeight: 220,
      decoration: InputDecoration(
        hintText: AppStrings.t('dex.advAbilityHint'),
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        suffixIcon: _draft.abilityKey != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: AppStrings.t('action.clear'),
                onPressed: () => setState(() {
                  _draft = _draft.copyWith(abilityKey: null);
                  _abilityCtl.clear();
                }),
              )
            : null,
      ),
      suggestionsCallback: (q) => _searchAbilities(q),
      itemBuilder: (context, ab) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(ab.localizedName, style: const TextStyle(fontSize: 14)),
      ),
      onSelected: (ab) {
        setState(() {
          _draft = _draft.copyWith(abilityKey: ab.name);
          _abilityCtl.text = ab.localizedName;
          _abilityCtl.selection =
              TextSelection.collapsed(offset: _abilityCtl.text.length);
        });
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  }

  List<Ability> _searchAbilities(String q) {
    if (q.trim().isEmpty) {
      return _selectableAbilities.take(50).toList();
    }
    final qLower = q.toLowerCase();
    final qRunes = qLower.runes.toList();
    final scored = <(Ability, int)>[];
    for (final e in _abilityEntries) {
      final s = scoreEntry(qRunes, qLower, e);
      if (s > 0) scored.add((e.item, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in scored) e.$1];
  }

  Widget _movesMatchToggle() {
    return Row(
      children: [
        Text(AppStrings.t('dex.advMovesMatch'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        _SegmentedToggle(
          selected: _draft.movesMatch == DexMovesMatch.and ? 0 : 1,
          labels: [
            AppStrings.t('dex.advMovesAnd'),
            AppStrings.t('dex.advMovesOr'),
          ],
          onChanged: (i) => setState(() {
            _draft = _draft.copyWith(
              movesMatch: i == 0 ? DexMovesMatch.and : DexMovesMatch.or,
            );
          }),
        ),
      ],
    );
  }

  Widget _moveField(int slot) {
    final c = _moveCtls[slot];
    return buildTypeAhead<Move>(
      controller: c,
      hideOnEmpty: true,
      maxHeight: 220,
      decoration: InputDecoration(
        hintText: AppStrings.t('dex.advMoveSlot'),
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        suffixIcon: slot < _draft.moveIds.length
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: AppStrings.t('action.clear'),
                onPressed: () => _clearMoveSlot(slot),
              )
            : null,
      ),
      suggestionsCallback: (q) => _searchMoves(q),
      itemBuilder: (context, m) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(m.localizedName, style: const TextStyle(fontSize: 14)),
      ),
      onSelected: (m) {
        setState(() {
          final id = _toShowdownId(m.name);
          final ids = List<String>.from(_draft.moveIds);
          if (slot < ids.length) {
            ids[slot] = id;
          } else {
            // Fill any earlier empty slots with this slot's index so the
            // list stays compact (no nulls between selections).
            while (ids.length < slot) {
              ids.add('');
            }
            if (ids.length == slot) {
              ids.add(id);
            } else {
              ids[slot] = id;
            }
          }
          // Drop trailing empties.
          while (ids.isNotEmpty && ids.last.isEmpty) {
            ids.removeLast();
          }
          _draft = _draft.copyWith(moveIds: ids);
          c.text = m.localizedName;
          c.selection = TextSelection.collapsed(offset: c.text.length);
        });
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  }

  void _clearMoveSlot(int slot) {
    setState(() {
      _moveCtls[slot].clear();
      if (slot >= _draft.moveIds.length) return;
      final ids = List<String>.from(_draft.moveIds);
      ids.removeAt(slot);
      // Move text controllers up so the empty row sits at the bottom.
      for (var i = slot; i < _moveCtls.length - 1; i++) {
        _moveCtls[i].text = _moveCtls[i + 1].text;
      }
      _moveCtls.last.clear();
      _draft = _draft.copyWith(moveIds: ids);
    });
  }

  List<Move> _searchMoves(String q) {
    if (q.trim().isEmpty) {
      return widget.allMoves.take(50).toList();
    }
    final qLower = q.toLowerCase();
    final qRunes = qLower.runes.toList();
    final scored = <(Move, int)>[];
    for (final e in _moveEntries) {
      final s = scoreEntry(qRunes, qLower, e);
      if (s > 0) scored.add((e.item, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in scored) e.$1];
  }
}

class _TypeChipGrid extends StatelessWidget {
  static const _options = <PokemonType>[
    PokemonType.normal,
    PokemonType.fire,
    PokemonType.water,
    PokemonType.electric,
    PokemonType.grass,
    PokemonType.ice,
    PokemonType.fighting,
    PokemonType.poison,
    PokemonType.ground,
    PokemonType.flying,
    PokemonType.psychic,
    PokemonType.bug,
    PokemonType.rock,
    PokemonType.ghost,
    PokemonType.dragon,
    PokemonType.dark,
    PokemonType.steel,
    PokemonType.fairy,
  ];

  final List<PokemonType> selected;
  final ValueChanged<PokemonType> onTap;

  const _TypeChipGrid({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final atCap = selected.length >= 2;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in _options)
          _TypeChip(
            type: t,
            selected: selected.contains(t),
            // At the 2-type cap, only the already-selected chips stay
            // tappable (to deselect). Newly-tapping a third type is a
            // silent no-op — the controller refuses the change.
            dimmed: atCap && !selected.contains(t),
            onTap: () => onTap(t),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final PokemonType type;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = KoStrings.getTypeColor(type);
    final fillAlpha = selected ? 1.0 : (dimmed ? 0.04 : 0.08);
    final borderAlpha = selected ? 1.0 : (dimmed ? 0.25 : 0.55);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: fillAlpha),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: borderAlpha),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          KoStrings.getTypeName(type),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : color.withValues(alpha: dimmed ? 0.55 : 1.0),
          ),
        ),
      ),
    );
  }
}

/// Compact stat picker — opens a popup with only the stats not yet
/// used in other rows (so each base stat appears in at most one row).
class _StatDropdown extends StatelessWidget {
  final DexStatKey value;
  final List<DexStatKey> options;
  final ValueChanged<DexStatKey> onChanged;

  const _StatDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showDialog<DexStatKey>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(AppStrings.t('dex.advPickStat')),
            children: [
              for (final k in options)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, k),
                  child: Text(_statLabel(k)),
                ),
            ],
          ),
        );
        if (picked != null && picked != value) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _statLabel(value),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}

/// 2-option segmented control sized to fit inside a filter row.
class _SegmentedToggle extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget seg(int i) {
      final on = i == selected;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on
                ? scheme.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: on ? scheme.primary : scheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.only(
              topLeft: i == 0 ? const Radius.circular(4) : Radius.zero,
              bottomLeft: i == 0 ? const Radius.circular(4) : Radius.zero,
              topRight: i == labels.length - 1
                  ? const Radius.circular(4)
                  : Radius.zero,
              bottomRight: i == labels.length - 1
                  ? const Radius.circular(4)
                  : Radius.zero,
            ),
          ),
          child: Text(
            labels[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: on ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < labels.length; i++) seg(i),
      ],
    );
  }
}
