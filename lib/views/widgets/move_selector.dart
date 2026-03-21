import 'package:flutter/material.dart';
import '../../data/movedex.dart';
import '../../models/move.dart';
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

    final Iterable<Move> filtered;
    if (query.isEmpty) {
      filtered = _allMoves;
    } else {
      final q = query.toLowerCase();
      filtered = _allMoves.where((m) =>
          m.nameKo.contains(q) ||
          m.name.toLowerCase().contains(q));
    }
    if (_selected != null) {
      _lastResults = [
        if (filtered.contains(_selected)) _selected!,
        ...filtered.where((m) => m != _selected),
      ];
    } else {
      _lastResults = filtered.toList();
    }
    return _lastResults!;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Move>(
      displayStringForOption: (m) => m.nameKo,
      optionsBuilder: (textEditingValue) {
        // Skip search while Korean IME is composing to prevent garbled input
        if (textEditingValue.composing != TextRange.empty) {
          return _lastResults ?? _sortedOptions('');
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
