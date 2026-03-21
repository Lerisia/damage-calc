import 'package:flutter/material.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';

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
  List<Pokemon>? _lastResults;

  List<Pokemon> _sortedOptions(String query) {
    if (query == _lastQuery && _lastResults != null) return _lastResults!;
    _lastQuery = query;

    final Iterable<Pokemon> filtered;
    if (query.isEmpty) {
      filtered = _allPokemon;
    } else {
      final q = query.toLowerCase();
      filtered = _allPokemon.where((p) =>
          p.nameKo.contains(q) ||
          p.name.toLowerCase().contains(q));
    }
    if (_selected != null) {
      _lastResults = [
        if (filtered.contains(_selected)) _selected!,
        ...filtered.where((p) => p != _selected),
      ];
    } else {
      _lastResults = filtered.toList();
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
