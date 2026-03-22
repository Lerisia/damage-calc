import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/korean_search.dart';

class PokemonSelector extends StatefulWidget {
  final void Function(Pokemon pokemon) onSelected;
  final String initialPokemonName;

  const PokemonSelector({
    super.key,
    required this.onSelected,
    this.initialPokemonName = 'Bulbasaur',
  });

  @override
  State<PokemonSelector> createState() => _PokemonSelectorState();
}

class _PokemonSelectorState extends State<PokemonSelector> {
  List<Pokemon> _allPokemon = [];
  Pokemon? _selected;
  bool _hasFocusListenerAttached = false;


  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    final all = await loadPokedex();
    setState(() {
      _allPokemon = all;
      if (_selected == null && all.isNotEmpty) {
        _selected = all.firstWhere(
          (p) => p.name == widget.initialPokemonName,
          orElse: () => all.firstWhere((p) => p.dexNumber == 1, orElse: () => all.first),
        );
      }
    });
  }

  String _lastQuery = '';
  Pokemon? _lastSelected;
  List<Pokemon>? _lastResults;

  List<Pokemon> _sortedOptions(String query) {
    if (query == _lastQuery && _lastSelected == _selected && _lastResults != null) return _lastResults!;
    _lastQuery = query;
    _lastSelected = _selected;

    if (query.isEmpty) {
      final all = _selected != null
          ? [_selected!, ..._allPokemon.where((p) => p != _selected)]
          : List.of(_allPokemon);
      _lastResults = all.length > 30 ? all.sublist(0, 30) : all;
      return _lastResults!;
    }

    final scored = <(Pokemon, int)>[];
    for (final p in _allPokemon) {
      final koScore = koreanMatchScore(query, p.nameKo);
      final enScore = koreanMatchScore(query, p.name);
      final score = koScore > enScore ? koScore : enScore;
      if (score > 0) scored.add((p, score));
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
    return Autocomplete<Pokemon>(
      initialValue: TextEditingValue(text: _selected?.nameKo ?? ''),
      displayStringForOption: (p) => p.nameKo,
      optionsBuilder: (textEditingValue) {
        // Skip search while Korean IME is composing (native only)
        if (!kIsWeb && textEditingValue.composing != TextRange.empty) {
          return _lastResults ?? _sortedOptions('');
        }
        if (textEditingValue.text == _selected?.nameKo) {
          return _sortedOptions('');
        }
        return _sortedOptions(textEditingValue.text);
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        final displayCount = list.length > 30 ? 30 : list.length;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: displayCount,
                itemBuilder: (context, index) {
                  final p = list[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(p.nameKo, style: const TextStyle(fontSize: 14)),
                    onTap: () => onSelected(p),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (pokemon) {
        setState(() => _selected = pokemon);
        widget.onSelected(pokemon);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        if (!_hasFocusListenerAttached) {
          _hasFocusListenerAttached = true;
          focusNode.addListener(() {
            if (focusNode.hasFocus) {
              controller.clear();
            } else if (controller.text.isEmpty && _selected != null) {
              controller.text = _selected!.nameKo;
            }
          });
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: _selected?.nameKo ?? '포켓몬 이름',
            isDense: true,
          ),
        );
      },
    );
  }
}
