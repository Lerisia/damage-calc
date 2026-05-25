import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ability.dart';
import '../../models/move.dart';
import '../../models/pokemon.dart';
import '../../models/type.dart';
import '../../utils/app_strings.dart';
import '../../utils/korean_search.dart';
import '../../utils/localization.dart';
import '../../utils/type_effectiveness.dart';
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

/// All filter conditions the advanced dex search supports. Immutable —
/// the dialog mutates a draft and returns the final value via Navigator.
@immutable
class DexSearchFilter {
  /// Types the Pokémon must have.
  /// - 1 entry: Pokémon must include that type.
  /// - 2 entries: Pokémon's type set must equal exactly these two.
  final List<PokemonType> types;

  final int? bstMin, bstMax;
  final int? hpMin, hpMax;
  final int? atkMin, atkMax;
  final int? defMin, defMax;
  final int? spaMin, spaMax;
  final int? spdMin, spdMax;
  final int? speMin, speMax;

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
    this.hpMin,
    this.hpMax,
    this.atkMin,
    this.atkMax,
    this.defMin,
    this.defMax,
    this.spaMin,
    this.spaMax,
    this.spdMin,
    this.spdMax,
    this.speMin,
    this.speMax,
    this.defenses = const [],
    this.abilityKey,
    this.moveIds = const [],
    this.movesMatch = DexMovesMatch.and,
  });

  static const empty = DexSearchFilter();

  bool get isEmpty => activeCount == 0;

  /// How many filter sections are populated. Drives the badge on the
  /// dex-screen filter button.
  int get activeCount {
    var n = 0;
    if (types.isNotEmpty) n++;
    if (bstMin != null || bstMax != null) n++;
    if (hpMin != null || hpMax != null) n++;
    if (atkMin != null || atkMax != null) n++;
    if (defMin != null || defMax != null) n++;
    if (spaMin != null || spaMax != null) n++;
    if (spdMin != null || spdMax != null) n++;
    if (speMin != null || speMax != null) n++;
    if (defenses.isNotEmpty) n++;
    if (abilityKey != null) n++;
    if (moveIds.isNotEmpty) n++;
    return n;
  }

  DexSearchFilter copyWith({
    List<PokemonType>? types,
    Object? bstMin = _sentinel,
    Object? bstMax = _sentinel,
    Object? hpMin = _sentinel,
    Object? hpMax = _sentinel,
    Object? atkMin = _sentinel,
    Object? atkMax = _sentinel,
    Object? defMin = _sentinel,
    Object? defMax = _sentinel,
    Object? spaMin = _sentinel,
    Object? spaMax = _sentinel,
    Object? spdMin = _sentinel,
    Object? spdMax = _sentinel,
    Object? speMin = _sentinel,
    Object? speMax = _sentinel,
    List<DexDefenseEntry>? defenses,
    Object? abilityKey = _sentinel,
    List<String>? moveIds,
    DexMovesMatch? movesMatch,
  }) {
    return DexSearchFilter(
      types: types ?? this.types,
      bstMin: identical(bstMin, _sentinel) ? this.bstMin : bstMin as int?,
      bstMax: identical(bstMax, _sentinel) ? this.bstMax : bstMax as int?,
      hpMin: identical(hpMin, _sentinel) ? this.hpMin : hpMin as int?,
      hpMax: identical(hpMax, _sentinel) ? this.hpMax : hpMax as int?,
      atkMin: identical(atkMin, _sentinel) ? this.atkMin : atkMin as int?,
      atkMax: identical(atkMax, _sentinel) ? this.atkMax : atkMax as int?,
      defMin: identical(defMin, _sentinel) ? this.defMin : defMin as int?,
      defMax: identical(defMax, _sentinel) ? this.defMax : defMax as int?,
      spaMin: identical(spaMin, _sentinel) ? this.spaMin : spaMin as int?,
      spaMax: identical(spaMax, _sentinel) ? this.spaMax : spaMax as int?,
      spdMin: identical(spdMin, _sentinel) ? this.spdMin : spdMin as int?,
      spdMax: identical(spdMax, _sentinel) ? this.spdMax : spdMax as int?,
      speMin: identical(speMin, _sentinel) ? this.speMin : speMin as int?,
      speMax: identical(speMax, _sentinel) ? this.speMax : speMax as int?,
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
  if (filter.hpMin != null && s.hp < filter.hpMin!) return false;
  if (filter.hpMax != null && s.hp > filter.hpMax!) return false;
  if (filter.atkMin != null && s.attack < filter.atkMin!) return false;
  if (filter.atkMax != null && s.attack > filter.atkMax!) return false;
  if (filter.defMin != null && s.defense < filter.defMin!) return false;
  if (filter.defMax != null && s.defense > filter.defMax!) return false;
  if (filter.spaMin != null && s.spAttack < filter.spaMin!) return false;
  if (filter.spaMax != null && s.spAttack > filter.spaMax!) return false;
  if (filter.spdMin != null && s.spDefense < filter.spdMin!) return false;
  if (filter.spdMax != null && s.spDefense > filter.spdMax!) return false;
  if (filter.speMin != null && s.speed < filter.speMin!) return false;
  if (filter.speMax != null && s.speed > filter.speMax!) return false;

  // Defensive type — all entries are ANDed. Ability effects ignored
  // per spec. Immunity is a separate bucket from resistance — picking
  // "내성" excludes 0× matchups; pick "면역" to find those.
  for (final d in filter.defenses) {
    final immune = hasTypeImmunity(d.type, p.type1, p.type2);
    final double mult = immune
        ? 0.0
        : getCombinedEffectiveness(d.type, p.type1, p.type2);
    switch (d.relation) {
      case DexDefenseRelation.weakness:
        if (mult <= 1.0) return false;
      case DexDefenseRelation.resistance:
        if (mult >= 1.0 || mult == 0.0) return false;
      case DexDefenseRelation.immunity:
        if (mult != 0.0) return false;
    }
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

  // Text controllers for the 14 range inputs + 1 ability slot + 4 move
  // slots. Kept on the state object so they survive rebuilds while the
  // user is typing.
  late final TextEditingController _bstMin, _bstMax;
  late final TextEditingController _hpMin, _hpMax;
  late final TextEditingController _atkMin, _atkMax;
  late final TextEditingController _defMin, _defMax;
  late final TextEditingController _spaMin, _spaMax;
  late final TextEditingController _spdMin, _spdMax;
  late final TextEditingController _speMin, _speMax;
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
    _hpMin = TextEditingController(text: s(_draft.hpMin));
    _hpMax = TextEditingController(text: s(_draft.hpMax));
    _atkMin = TextEditingController(text: s(_draft.atkMin));
    _atkMax = TextEditingController(text: s(_draft.atkMax));
    _defMin = TextEditingController(text: s(_draft.defMin));
    _defMax = TextEditingController(text: s(_draft.defMax));
    _spaMin = TextEditingController(text: s(_draft.spaMin));
    _spaMax = TextEditingController(text: s(_draft.spaMax));
    _spdMin = TextEditingController(text: s(_draft.spdMin));
    _spdMax = TextEditingController(text: s(_draft.spdMax));
    _speMin = TextEditingController(text: s(_draft.speMin));
    _speMax = TextEditingController(text: s(_draft.speMax));
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
      _hpMin, _hpMax, _atkMin, _atkMax, _defMin, _defMax,
      _spaMin, _spaMax, _spdMin, _spdMax, _speMin, _speMax,
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
      _draft = DexSearchFilter.empty;
      for (final c in [
        _bstMin, _bstMax,
        _hpMin, _hpMax, _atkMin, _atkMax, _defMin, _defMax,
        _spaMin, _spaMax, _spdMin, _spdMax, _speMin, _speMax,
        _abilityCtl,
        ..._moveCtls,
      ]) {
        c.clear();
      }
    });
  }

  /// Snapshot the live text-field values into [_draft] before returning.
  /// We don't run an onChanged per keystroke (cheaper and less janky on
  /// number pads), so this is the single sync point.
  DexSearchFilter _commitDraft() {
    return _draft.copyWith(
      bstMin: _parseInt(_bstMin.text),
      bstMax: _parseInt(_bstMax.text),
      hpMin: _parseInt(_hpMin.text),
      hpMax: _parseInt(_hpMax.text),
      atkMin: _parseInt(_atkMin.text),
      atkMax: _parseInt(_atkMax.text),
      defMin: _parseInt(_defMin.text),
      defMax: _parseInt(_defMax.text),
      spaMin: _parseInt(_spaMin.text),
      spaMax: _parseInt(_spaMax.text),
      spdMin: _parseInt(_spdMin.text),
      spdMax: _parseInt(_spdMax.text),
      speMin: _parseInt(_speMin.text),
      speMax: _parseInt(_speMax.text),
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
                _rangeRow(AppStrings.t('stat.hp'), _hpMin, _hpMax),
                _rangeRow(AppStrings.t('stat.attack'), _atkMin, _atkMax),
                _rangeRow(AppStrings.t('stat.defense'), _defMin, _defMax),
                _rangeRow(AppStrings.t('stat.spAttack'), _spaMin, _spaMax),
                _rangeRow(AppStrings.t('stat.spDefense'), _spdMin, _spdMax),
                _rangeRow(AppStrings.t('stat.speed'), _speMin, _speMax),
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
            onPressed: _addDefenseEntry,
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
              final picked = await _pickDefenseType();
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

  Future<PokemonType?> _pickDefenseType() {
    return showDialog<PokemonType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppStrings.t('dex.advDefenseTypePick')),
        children: [
          for (final t in _TypeChipGrid._options)
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
    final picked = await _pickDefenseType();
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
