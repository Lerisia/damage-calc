import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/movedex.dart';
import '../../models/move.dart';
import '../../utils/korean_search.dart';
import 'typeahead_helpers.dart';
import '../../utils/localization.dart';

class MoveSelector extends StatefulWidget {
  final void Function(Move move) onSelected;
  final VoidCallback? onTap;
  final String? initialMoveName;
  final String? displayNameOverride;

  const MoveSelector({super.key, required this.onSelected, this.onTap, this.initialMoveName, this.displayNameOverride});

  @override
  State<MoveSelector> createState() => _MoveSelectorState();
}

class _MoveSelectorState extends State<MoveSelector> {
  List<Move> _allMoves = [];
  List<SearchEntry<Move>> _searchEntries = [];
  Move? _selected;
  final _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _loadMoves();
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
      _searchEntries = all.map((m) => SearchEntry(m, m.nameKo, m.name)).toList();
      if (_selected == null && widget.initialMoveName != null) {
        final match = all.where((m) => m.name == widget.initialMoveName);
        if (match.isNotEmpty) {
          _selected = match.first;
          _controller.text = widget.displayNameOverride ?? _selected!.nameKo;
        }
      }
    });
  }

  List<Move> _sortedOptions(String query) {
    if (query.isEmpty) {
      return _selected != null
          ? [_selected!, ..._allMoves.where((m) => m != _selected)]
          : List.of(_allMoves);
    }

    final qLower = query.toLowerCase();
    final qRunes = qLower.runes.toList();
    final scored = <(Move, int)>[];
    for (final entry in _searchEntries) {
      final score = scoreEntry(qRunes, qLower, entry);
      if (score > 0) scored.add((entry.item, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final results = scored.map((e) => e.$1).toList();
    if (_selected != null && results.contains(_selected)) {
      results.remove(_selected);
      results.insert(0, _selected!);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Move>(
      controller: _controller,
      suggestionsCallback: (query) {
        if (_selected != null && query == _selected!.nameKo) return _sortedOptions('');
        return _sortedOptions(query);
      },
      builder: (context, controller, focusNode) {
        focusNode.addListener(() {
          if (focusNode.hasFocus) {
            _isFocused = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.value = TextEditingValue(
                text: controller.text,
                selection: TextSelection(baseOffset: 0, extentOffset: controller.text.length),
                composing: TextRange.empty,
              );
            });
          } else {
            _isFocused = false;
            if (controller.text.isEmpty && _selected != null) {
              controller.text = widget.displayNameOverride ?? _selected!.nameKo;
            }
            if (!_isFocused && widget.displayNameOverride != null && _selected != null) {
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
          onTap: () {
            selectAllOnTap(controller);
            widget.onTap?.call();
          },
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            final results = _sortedOptions(controller.text);
            if (results.isNotEmpty) {
              final pick = results.first;
              setState(() => _selected = pick);
              widget.onSelected(pick);
              controller.text = pick.nameKo;
              focusNode.unfocus();
            }
          },
          style: widget.displayNameOverride != null
              ? TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500, fontSize: 14)
              : const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: _selected?.nameKo ?? '기술 이름',
            hintStyle: const TextStyle(fontSize: 14),
            isDense: true,
          ),
        );
      },
      itemBuilder: (context, move) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(move.nameKo, style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text.rich(TextSpan(children: [
                TextSpan(text: KoStrings.getTypeKo(move.type),
                    style: TextStyle(fontSize: 12, color: KoStrings.getTypeColor(move.type))),
                TextSpan(text: ' ${KoStrings.getCategoryKo(move.category)} ${move.power}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ])),
            ],
          ),
        );
      },
      onSelected: (move) {
        setState(() => _selected = move);
        _controller.text = move.nameKo;
        widget.onSelected(move);
      },
      constraints: const BoxConstraints(maxHeight: 200),
      hideOnEmpty: false,
      hideOnSelect: typeaheadHideOnSelect,
      retainOnLoading: typeaheadRetainOnLoading,
      animationDuration: typeaheadAnimationDuration,
      debounceDuration: typeaheadDebounceDuration,
      autoFlipDirection: typeaheadAutoFlipDirection,
      hideOnUnfocus: typeaheadHideOnUnfocus,
    );
  }
}
