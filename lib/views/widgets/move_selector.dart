import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/champions_moves.dart';
import '../../data/champions_usage.dart';
import '../../controllers/champions_filter_controller.dart';
import '../../data/movedex.dart';
import '../../data/learnsetdex.dart';
import '../../models/move.dart';
import '../../models/move_tags.dart';
import '../../search/korean_search.dart';
import '../../controllers/move_options_controller.dart';
import 'search_picker/search_picker.dart';
import '../../i18n/app_strings.dart';
import '../../i18n/localization.dart';

/// A move slot: shows the current move and opens the search modal on
/// tap. The list is the same one the old dropdown showed — current
/// move, the Pokémon's configured slots, its Champions top moves, then
/// the rest, learnable moves first — with type / category / power at
/// the end of each row and unlearnable moves greyed.
class MoveSelector extends StatefulWidget {
  final void Function(Move move) onSelected;
  final String? initialMoveName;

  /// Shown instead of the move's own name (Max / Z-Move names), in the
  /// accent colour.
  final String? displayNameOverride;
  /// Pokemon name for learnset-based move highlighting/sorting.
  final String? pokemonName;
  final String? pokemonNameKo;
  final int? dexNumber;
  /// When `false`, status-category moves are always hidden from the
  /// search list regardless of the global "변화기 보기" toggle. Simple
  /// Mode forces this off — its compact UI doesn't need them. Extended
  /// Mode and the party-coverage grid leave this `true` so the user's
  /// global preference applies.
  final bool allowStatus;
  /// When true, status moves are always shown regardless of the
  /// [MoveOptionsController.showStatusMoves] preference. Used by the
  /// team-builder slot card where the user shouldn't have to flip a
  /// toggle to pick a status move (per UX direction: "파티창에선
  /// 무조건 보는 겁니다").
  final bool forceShowStatus;
  /// Optional floating label rendered on the field. Used by Simple
  /// Mode to surface "기술" the same way ability/item/상태이상 carry
  /// their own labels. Most other call sites omit this and rely on
  /// context (no label).
  final String? labelText;

  /// The Pokémon's configured move slots, hoisted to the top of the
  /// empty-query suggestion list in slot order. Simple Mode passes
  /// the attacker's 4-slot `moves` list here — since Extended and
  /// Simple share one BattlePokemonState, whatever set the user built
  /// in Extended Mode (or the auto-seeded champions defaults) surfaces
  /// first without scrolling. Status moves and empty slots are
  /// skipped; the currently-selected move isn't duplicated. Null →
  /// no pinning (all other call sites).
  final List<Move?>? pinnedMoves;

  const MoveSelector({super.key, required this.onSelected, this.initialMoveName, this.displayNameOverride, this.pokemonName, this.pokemonNameKo, this.dexNumber, this.allowStatus = true, this.forceShowStatus = false, this.labelText, this.pinnedMoves});

  @override
  State<MoveSelector> createState() => _MoveSelectorState();
}

class _MoveSelectorState extends State<MoveSelector> {
  static Map<String, Set<String>> _learnsetCache = {};

  /// All selectable moves (non-G-Max etc. already stripped). The
  /// status-move filter is applied dynamically on top of this so
  /// toggling [MoveOptionsController.showStatusMoves] doesn't require
  /// reloading from disk.
  List<Move> _baseMoves = [];
  List<Move> _allMoves = [];
  SearchIndex<Move>? _moveIndex;
  Set<String> _learnableMoveIds = {};
  Move? _selected;

  @override
  void initState() {
    super.initState();
    _loadMoves();
    if (widget.allowStatus) {
      MoveOptionsController.instance.showStatusMoves
          .addListener(_rebuildEntries);
    }
    // Rebuild the pool when the global Champions filter flips so
    // non-Champions moves drop out (or reappear) live, same as the
    // status-move toggle above.
    ChampionsFilterController.instance.championsOnly
        .addListener(_rebuildEntries);
  }

  @override
  void didUpdateWidget(MoveSelector old) {
    super.didUpdateWidget(old);
    if (old.pokemonName != widget.pokemonName) {
      _updateLearnset();
    }
  }

  @override
  void dispose() {
    if (widget.allowStatus) {
      MoveOptionsController.instance.showStatusMoves
          .removeListener(_rebuildEntries);
    }
    ChampionsFilterController.instance.championsOnly
        .removeListener(_rebuildEntries);
    super.dispose();
  }

  bool _showStatus() =>
      widget.forceShowStatus ||
      (widget.allowStatus &&
          MoveOptionsController.instance.showStatusMoves.value);

  Future<void> _loadMoves() async {
    final all = await loadAllMoves();
    // Strip non-selectable kinds (G-Max moves, Z-moves, …) up-front.
    // Status moves are filtered dynamically by [_rebuildEntries].
    all.removeWhere((m) => m.moveClass != MoveClass.normal);
    // `dex_only` synthetic entries (the canonical Magnitude row in
    // the Move Dex, etc.) are display-only — the calc keeps the
    // numeric variants for actual power picking.
    all.removeWhere((m) => m.hasTag(MoveTags.dexOnly));
    _baseMoves = all;
    _rebuildEntries();
    _updateLearnset();
  }

  void _rebuildEntries() {
    if (!mounted) return;
    final champOnly =
        ChampionsFilterController.instance.championsOnly.value;
    final filtered = _baseMoves.where((m) {
      if (!_showStatus() && m.category == MoveCategory.status) return false;
      // Champions-only: drop moves the game doesn't include. The
      // currently-selected move is exempt so a legal pick loaded
      // from a sample / handoff never vanishes from its own field.
      if (champOnly && m != _selected && !isChampionsMove(m.name)) {
        return false;
      }
      return true;
    }).toList();
    setState(() {
      _allMoves = filtered;
      // Champions/status filtering is baked into this corpus, so the
      // index needs no `allow` — it's rebuilt whenever the pool changes.
      _moveIndex = SearchIndex<Move>(filtered.map((m) =>
          SearchEntry(m, m.nameKo, m.name, nameJa: m.nameJa, aliases: m.aliases)));
      if (_selected == null && widget.initialMoveName != null) {
        final match = _baseMoves.where((m) => m.name == widget.initialMoveName);
        if (match.isNotEmpty) {
          _selected = match.first;
        }
      }
    });
  }

  Future<void> _updateLearnset() async {
    if (widget.pokemonName == null) {
      setState(() => _learnableMoveIds = {});
      return;
    }
    // Use cache if available for instant display
    final cacheKey = widget.pokemonName!;
    if (_learnsetCache.containsKey(cacheKey)) {
      setState(() => _learnableMoveIds = _learnsetCache[cacheKey]!);
      return;
    }
    final moves = await getLearnableMoves(
      widget.pokemonName!,
      nameKo: widget.pokemonNameKo,
      dexNumber: widget.dexNumber,
    );
    _learnsetCache[cacheKey] = moves;
    if (mounted) setState(() => _learnableMoveIds = moves);
  }

  bool _canLearn(Move move) {
    if (_learnableMoveIds.isEmpty) return true; // no data → treat all as learnable
    final moveId = toShowdownMoveId(move.name);
    // Magnitude variants → check base "magnitude"
    if (move.name.startsWith('Magnitude ')) return _learnableMoveIds.contains('magnitude');
    return _learnableMoveIds.contains(moveId);
  }

  /// Top-N Champions Singles moves for this species, in usage order,
  /// restricted to moves visible in the current `_allMoves` pool
  /// (so the status-move toggle is respected) and excluding the
  /// already-selected move (which is hoisted separately). Returns an
  /// empty list for uncurated species.
  List<Move> _championsPriorityMoves({required int topN}) {
    final name = widget.pokemonName;
    if (name == null) return const [];
    final usage = championsUsageFor(name);
    if (usage == null || usage.moves.isEmpty) return const [];
    final byName = {for (final m in _allMoves) m.name: m};
    final out = <Move>[];
    for (final row in usage.moves) {
      if (out.length >= topN) break;
      final m = byName[row.name];
      if (m == null) continue;
      if (m == _selected) continue;
      out.add(m);
    }
    return out;
  }

  /// The caller-provided slot moves resolved against the current
  /// `_allMoves` pool: canonical instances, slot order preserved,
  /// nulls/status/dupes-of-selected dropped. Matching by name (not
  /// identity) because the slots' Move objects may predate this
  /// selector's own movedex load.
  List<Move> _resolvedPinnedMoves() {
    final slots = widget.pinnedMoves;
    if (slots == null) return const [];
    final byName = {for (final m in _allMoves) m.name: m};
    final out = <Move>[];
    for (final slot in slots) {
      if (slot == null) continue;
      if (slot.category == MoveCategory.status) continue; // 변화기 제외
      final m = byName[slot.name];
      if (m == null || m == _selected) continue;
      if (out.contains(m)) continue;
      out.add(m);
    }
    return out;
  }

  List<Move> _sortedOptions(String query) {
    final index = _moveIndex;
    if (index == null) return const [];
    // Empty query pins (after the selected move, which is hoisted):
    //   configured slot moves → champions top-10. On a real query
    //   these don't force to the top — relevance wins. Champions/status
    //   filtering is already baked into the index corpus.
    final pinned = _resolvedPinnedMoves();
    final pinnedSet = pinned.toSet();
    final priority = _championsPriorityMoves(topN: 10)
        .where((m) => !pinnedSet.contains(m))
        .toList();
    return pickerSuggestions(
      index,
      query,
      hoist: _selected,
      pins: [...pinned, ...priority],
      // Learnable moves first, applied last as a stable partition so
      // search/pin order is preserved within each group. No-op when
      // we have no learnset data (treats everything as learnable).
      groupFirst:
          _learnableMoveIds.isEmpty ? null : _canLearn,
    );
  }

  Future<void> _open() async {
    final byName = {for (final m in _allMoves) m.name: m};
    final picked = await showSearchPicker<Move>(
      context,
      SearchPickerConfig<Move>(
        kind: 'move',
        hintText: AppStrings.t('search.moveQuery'),
        selected: _selected,
        suggestions: _sortedOptions,
        labelOf: (m) => m.localizedName,
        idOf: (m) => m.name,
        fromId: (id) => byName[id],
        dimmed: (m) => !_canLearn(m),
        trailingOf: (context, m) {
          final learnable = _canLearn(m);
          return Text.rich(TextSpan(children: [
            TextSpan(
                text: KoStrings.getTypeName(m.type),
                style: TextStyle(
                    fontSize: 12,
                    color: learnable
                        ? KoStrings.getTypeColor(m.type)
                        : Colors.grey[400])),
            TextSpan(
                text: ' ${KoStrings.getCategoryName(m.category)} ${m.power}',
                style: TextStyle(
                    fontSize: 12,
                    color: learnable ? Colors.grey[600] : Colors.grey[400])),
          ]));
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selected = picked);
    widget.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final override = widget.displayNameOverride;
    return SearchPickerField(
      text: override ?? _selected?.localizedName ?? '',
      labelText: widget.labelText,
      hintText: AppStrings.t('search.move'),
      textStyle: override != null
          ? TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 14)
          : const TextStyle(fontSize: 14),
      onTap: _moveIndex == null ? null : _open,
    );
  }
}
