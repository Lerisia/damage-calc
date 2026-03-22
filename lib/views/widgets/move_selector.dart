import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../data/movedex.dart';
import '../../models/move.dart';
import '../../utils/korean_search.dart';
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
  bool _hasFocusListenerAttached = false;


  @override
  void initState() {
    super.initState();
    _loadMoves();
  }

  Future<void> _loadMoves() async {
    final all = await loadAllMoves();
    // Filter: only normal-class physical/special moves
    all.removeWhere((m) =>
        m.category == MoveCategory.status ||
        m.moveClass != MoveClass.normal);
    // Keep original order (gen1 → gen9, registration order)
    setState(() {
      _allMoves = all;
      _searchEntries = all.map((m) => SearchEntry(m, m.nameKo, m.name)).toList();
      if (_selected == null && widget.initialMoveName != null) {
        final match = all.where((m) => m.name == widget.initialMoveName);
        if (match.isNotEmpty) _selected = match.first;
      }
    });
  }

  String _moveDisplay(Move m) =>
      '${m.nameKo} (${KoStrings.getTypeKo(m.type)} / ${KoStrings.getCategoryKo(m.category)} / 위력${m.power})';

  String _lastQuery = '';
  List<Move>? _lastResults;

  List<Move> _sortedOptions(String query) {
    if (query == _lastQuery && _lastResults != null) return _lastResults!;
    _lastQuery = query;

    if (query.isEmpty) {
      _lastResults = _selected != null
          ? [_selected!, ..._allMoves.where((m) => m != _selected)]
          : List.of(_allMoves);
      return _lastResults!;
    }

    final qLower = query.toLowerCase();
    final qRunes = qLower.runes.toList();
    final scored = <(Move, int)>[];
    for (final entry in _searchEntries) {
      final score = scoreEntry(qRunes, qLower, entry);
      if (score > 0) scored.add((entry.item, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    _lastResults = scored.map((e) => e.$1).toList();
    if (_selected != null && _lastResults!.contains(_selected)) {
      _lastResults!.remove(_selected);
      _lastResults!.insert(0, _selected!);
    }
    return _lastResults!;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Move>(
      displayStringForOption: (m) => m.nameKo,
      optionsBuilder: (textEditingValue) {
        if (_selected != null && textEditingValue.text == _selected!.nameKo) {
          return _sortedOptions('');
        }
        return _sortedOptions(textEditingValue.text);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final m = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(m.nameKo, style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text.rich(TextSpan(children: [
                            TextSpan(text: KoStrings.getTypeKo(m.type),
                                style: TextStyle(fontSize: 12, color: KoStrings.getTypeColor(m.type))),
                            TextSpan(text: ' ${KoStrings.getCategoryKo(m.category)} ${m.power}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ])),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (move) {
        setState(() => _selected = move);
        widget.onSelected(move);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (!_hasFocusListenerAttached) {
          _hasFocusListenerAttached = true;
          focusNode.addListener(() {
            if (focusNode.hasFocus) {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            } else if (controller.text.isEmpty && _selected != null) {
              final display = widget.displayNameOverride ?? _selected!.nameKo;
              controller.text = display;
            }
          });
        }
        // Show override name when not focused
        if (!focusNode.hasFocus && widget.displayNameOverride != null && _selected != null) {
          controller.text = widget.displayNameOverride!;
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onTap: widget.onTap,
          textInputAction: TextInputAction.done,
          onChanged: kIsWeb ? (_) => setState(() {}) : null,
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
    );
  }
}
