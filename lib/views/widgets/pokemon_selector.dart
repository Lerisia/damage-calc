import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/korean_search.dart';
import 'adaptive_dropdown.dart';

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
  List<SearchEntry<Pokemon>> _searchEntries = [];
  Pokemon? _selected;
  bool _hasFocusListenerAttached = false;
  BuildContext? _fieldContext;


  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    final all = await loadPokedex();
    final visible = all.where((p) => !p.hidden).toList();
    setState(() {
      _allPokemon = visible;
      _searchEntries = visible.map((p) => SearchEntry(p, p.nameKo, p.name, aliases: p.aliases)).toList();
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
      _lastResults = _selected != null
          ? [_selected!, ..._allPokemon.where((p) => p != _selected)]
          : List.of(_allPokemon);
      return _lastResults!;
    }

    final qLower = query.toLowerCase();
    final qRunes = qLower.runes.toList();
    final scored = <(Pokemon, int)>[];
    for (final entry in _searchEntries) {
      final score = scoreEntry(qRunes, qLower, entry);
      if (score > 0) scored.add((entry.item, score));
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
        if (textEditingValue.text == _selected?.nameKo) {
          return _sortedOptions('');
        }
        return _sortedOptions(textEditingValue.text);
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        final align = _fieldContext != null
            ? dropdownAlignment(_fieldContext!)
            : Alignment.topLeft;
        return dismissibleOptionsWrapper(
          alignment: align,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
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
        FocusManager.instance.primaryFocus?.unfocus();
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
              controller.text = _selected!.nameKo;
            }
          });
        }
        _fieldContext = context;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.done,
          onTap: () {
            // Dismiss any other focused field before opening autocomplete
            FocusScope.of(context).requestFocus(focusNode);
          },
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
          decoration: InputDecoration(
            hintText: _selected?.nameKo ?? '이름 검색',
            isDense: true,
          ),
        );
      },
    );
  }
}
