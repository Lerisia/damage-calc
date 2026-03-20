import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  ) onSelected;

  const PokemonSelector({super.key, required this.onSelected});

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
    final List<Pokemon> all = [];
    const genFiles = [
      'assets/pokemon/gen1.json', 'assets/pokemon/gen2.json',
      'assets/pokemon/gen3.json', 'assets/pokemon/gen4.json',
      'assets/pokemon/gen5.json', 'assets/pokemon/gen6.json',
      'assets/pokemon/gen7.json', 'assets/pokemon/gen8.json',
      'assets/pokemon/gen9.json',
      'assets/pokemon/mega.json', 'assets/pokemon/alola.json',
      'assets/pokemon/galar.json', 'assets/pokemon/hisui.json',
      'assets/pokemon/paldea.json',
    ];

    for (final file in genFiles) {
      try {
        final jsonString = await rootBundle.loadString(file);
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        for (final entry in jsonList) {
          all.add(Pokemon.fromJson(entry as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    setState(() {
      _allPokemon = all;
      // Default to Bulbasaur
      if (_selected == null && all.isNotEmpty) {
        _selected = all.firstWhere((p) => p.dexNumber == 1, orElse: () => all.first);
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
          p.name.toLowerCase().contains(q) ||
          p.dexNumber.toString() == q).toList();
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
          pokemon.baseStats, pokemon.abilities,
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
            hintText: _selected?.nameKo ?? '포켓몬 이름 또는 도감번호',
            isDense: true,
          ),
        );
      },
    );
  }
}
