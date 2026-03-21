import 'package:flutter/material.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../models/stats.dart';
import '../../models/type.dart';

class PokemonSelector extends StatefulWidget {
  final void Function(
    String name,
    PokemonType type1,
    PokemonType? type2,
    Stats baseStats,
    List<String> abilities,
    bool finalEvo,
    String? requiredItem,
    int genderRate,
  ) onSelected;
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

  List<Pokemon> _sortedOptions(String query) {
    List<Pokemon> results;
    if (query.isEmpty) {
      results = List.of(_allPokemon);
    } else {
      final q = query.toLowerCase();
      results = _allPokemon.where((p) =>
          p.nameKo.contains(q) ||
          p.name.toLowerCase().contains(q)).toList();
    }
    // Selected at top
    if (_selected != null && results.contains(_selected)) {
      results.remove(_selected);
      results.insert(0, _selected!);
    }
    return results;
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
        widget.onSelected(
          pokemon.name, pokemon.type1, pokemon.type2,
          pokemon.baseStats, pokemon.abilities, pokemon.finalEvo,
          pokemon.requiredItem,
          pokemon.genderRate,
        );
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
