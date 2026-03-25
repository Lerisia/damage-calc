import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/movedex.dart';
import '../../data/learnsetdex.dart';
import '../../models/move.dart';
import '../../utils/korean_search.dart';
import 'typeahead_helpers.dart';
import '../../utils/app_strings.dart';
import '../../utils/localization.dart';

class MoveSelector extends StatefulWidget {
  final void Function(Move move) onSelected;
  final VoidCallback? onTap;
  final String? initialMoveName;
  final String? displayNameOverride;
  /// Pokemon name for learnset-based move highlighting/sorting.
  final String? pokemonName;
  final String? pokemonNameKo;
  final int? dexNumber;

  const MoveSelector({super.key, required this.onSelected, this.onTap, this.initialMoveName, this.displayNameOverride, this.pokemonName, this.pokemonNameKo, this.dexNumber});

  @override
  State<MoveSelector> createState() => _MoveSelectorState();
}

class _MoveSelectorState extends State<MoveSelector> {
  List<Move> _allMoves = [];
  List<SearchEntry<Move>> _searchEntries = [];
  Set<String> _learnableMoveIds = {};
  Move? _selected;
  final _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _loadMoves();
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMoves() async {
    final all = await loadAllMoves();
    all.removeWhere((m) =>
        m.category == MoveCategory.status ||
        m.moveClass != MoveClass.normal);
    setState(() {
      _allMoves = all;
      _searchEntries = all.map((m) => SearchEntry(m, m.nameKo, m.name, nameJa: m.nameJa)).toList();
      if (_selected == null && widget.initialMoveName != null) {
        final match = all.where((m) => m.name == widget.initialMoveName);
        if (match.isNotEmpty) {
          _selected = match.first;
          _controller.text = widget.displayNameOverride ?? _selected!.localizedName;
        }
      }
    });
    _updateLearnset();
  }

  Future<void> _updateLearnset() async {
    if (widget.pokemonName == null) {
      setState(() => _learnableMoveIds = {});
      return;
    }
    final moves = await getLearnableMoves(
      widget.pokemonName!,
      nameKo: widget.pokemonNameKo,
      dexNumber: widget.dexNumber,
    );
    if (mounted) setState(() => _learnableMoveIds = moves);
  }

  bool _canLearn(Move move) {
    if (_learnableMoveIds.isEmpty) return true; // no data → treat all as learnable
    final moveId = toShowdownMoveId(move.name);
    // Magnitude variants → check base "magnitude"
    if (move.name.startsWith('Magnitude ')) return _learnableMoveIds.contains('magnitude');
    return _learnableMoveIds.contains(moveId);
  }

  List<Move> _sortedOptions(String query) {
    List<Move> results;
    if (query.isEmpty) {
      results = _selected != null
          ? [_selected!, ..._allMoves.where((m) => m != _selected)]
          : List.of(_allMoves);
    } else {
      final qLower = query.toLowerCase();
      final qRunes = qLower.runes.toList();
      final scored = <(Move, int)>[];
      for (final entry in _searchEntries) {
        final score = scoreEntry(qRunes, qLower, entry);
        if (score > 0) scored.add((entry.item, score));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      results = scored.map((e) => e.$1).toList();
      if (_selected != null && results.contains(_selected)) {
        results.remove(_selected);
        results.insert(0, _selected!);
      }
    }

    // Sort learnable moves first (stable: preserves search score order within each group)
    if (_learnableMoveIds.isNotEmpty) {
      final learnable = <Move>[];
      final notLearnable = <Move>[];
      for (final m in results) {
        if (_canLearn(m)) {
          learnable.add(m);
        } else {
          notLearnable.add(m);
        }
      }
      results = [...learnable, ...notLearnable];
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return buildTypeAhead<Move>(
      controller: _controller,
      suggestionsCallback: (query) {
        if (_selected != null && query == _selected!.localizedName) return _sortedOptions('');
        return _sortedOptions(query);
      },
      decoration: InputDecoration(
        hintText: _selected?.localizedName ?? AppStrings.t('search.move'),
        hintStyle: const TextStyle(fontSize: 14),
        isDense: true,
      ),
      onTap: widget.onTap,
      builder: (context, controller, focusNode) {
        focusNode.addListener(() {
          if (focusNode.hasFocus) {
            _isFocused = true;
            controller.clear();
            widget.onTap?.call();
          } else {
            _isFocused = false;
            if (controller.text.isEmpty && _selected != null) {
              controller.text = widget.displayNameOverride ?? _selected!.localizedName;
            }
            if (widget.displayNameOverride != null && _selected != null) {
              controller.text = widget.displayNameOverride!;
            }
          }
        });
        if (!_isFocused && widget.displayNameOverride != null && _selected != null) {
          controller.text = widget.displayNameOverride!;
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            final results = _sortedOptions(controller.text);
            if (results.isNotEmpty) {
              final pick = results.first;
              setState(() => _selected = pick);
              widget.onSelected(pick);
              controller.text = pick.localizedName;
              focusNode.unfocus();
            }
          },
          style: widget.displayNameOverride != null
              ? TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500, fontSize: 14)
              : const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: _selected?.localizedName ?? AppStrings.t('search.move'),
            hintStyle: const TextStyle(fontSize: 14),
            isDense: true,
          ),
        );
      },
      itemBuilder: (context, move) {
        final learnable = _canLearn(move);
        final nameColor = learnable ? null : Colors.grey;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(move.localizedName, style: TextStyle(fontSize: 14, color: nameColor),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text.rich(TextSpan(children: [
                TextSpan(text: KoStrings.getTypeName(move.type),
                    style: TextStyle(fontSize: 12, color: learnable ? KoStrings.getTypeColor(move.type) : Colors.grey[400])),
                TextSpan(text: ' ${KoStrings.getCategoryName(move.category)} ${move.power}',
                    style: TextStyle(fontSize: 12, color: learnable ? Colors.grey[600] : Colors.grey[400])),
              ])),
            ],
          ),
        );
      },
      onSelected: (move) {
        setState(() => _selected = move);
        _controller.text = move.localizedName;
        widget.onSelected(move);
      },
      maxHeight: 200,
    );
  }
}
