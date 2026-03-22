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
    all.sort((a, b) => a.nameKo.compareTo(b.nameKo));
    setState(() {
      _allMoves = all;
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

    final scored = <(Move, int)>[];
    for (final m in _allMoves) {
      final koScore = koreanMatchScore(query, m.nameKo);
      final enScore = koreanMatchScore(query, m.name);
      final score = koScore > enScore ? koScore : enScore;
      if (score > 0) scored.add((m, score));
    }
    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$1.nameKo.compareTo(b.$1.nameKo);
    });
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
        if (!kIsWeb && textEditingValue.composing != TextRange.empty) {
          return _lastResults ?? _sortedOptions('');
        }
        var query = textEditingValue.text;
        if (query.isNotEmpty) {
          final lastCode = query.runes.last;
          if (lastCode >= 0x3131 && lastCode <= 0x314E && query.runes.length > 1) {
            query = String.fromCharCodes(query.runes.toList()..removeLast());
          }
        }
        return _sortedOptions(query);
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
                  return ListTile(
                    dense: true,
                    title: Text(m.nameKo),
                    subtitle: Text(
                      '${KoStrings.getTypeKo(m.type)} / ${KoStrings.getCategoryKo(m.category)} / 위력${m.power}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => onSelected(m),
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
              controller.clear();
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
          style: widget.displayNameOverride != null
              ? TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500)
              : null,
          decoration: InputDecoration(
            hintText: _selected?.nameKo ?? '기술 이름',
            isDense: true,
          ),
        );
      },
    );
  }
}
