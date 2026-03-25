import 'package:flutter/material.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/app_strings.dart';
import '../../utils/korean_search.dart';
import 'typeahead_helpers.dart';

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
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPokemon() async {
    final all = await loadPokedex();
    final visible = all.where((p) => !p.hidden).toList();
    setState(() {
      _allPokemon = visible;
      _searchEntries = visible.map((p) => SearchEntry(p, p.nameKo, p.name, nameJa: p.nameJa, aliases: p.aliases)).toList();
      if (_selected == null && all.isNotEmpty) {
        _selected = all.firstWhere(
          (p) => p.name == widget.initialPokemonName,
          orElse: () => all.firstWhere((p) => p.dexNumber == 1, orElse: () => all.first),
        );
        _controller.text = _selected?.localizedName ?? '';
      }
    });
  }

  List<Pokemon> _sortedOptions(String query) {
    if (query.isEmpty) {
      return _selected != null
          ? [_selected!, ..._allPokemon.where((p) => p != _selected)]
          : List.of(_allPokemon);
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
      return a.$1.localizedName.compareTo(b.$1.localizedName);
    });
    final results = scored.map((e) => e.$1).toList();
    if (_selected != null && results.contains(_selected)) {
      results.remove(_selected);
      results.insert(0, _selected!);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return buildTypeAhead<Pokemon>(
      controller: _controller,
      suggestionsCallback: (query) {
        if (query == _selected?.localizedName) return _sortedOptions('');
        return _sortedOptions(query);
      },
      decoration: InputDecoration(
        hintText: _selected?.localizedName ?? AppStrings.t('search.pokemon'),
        isDense: true,
      ),
      itemBuilder: (context, pokemon) {
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(pokemon.localizedName, style: const TextStyle(fontSize: 14)),
        );
      },
      onSelected: (pokemon) {
        setState(() => _selected = pokemon);
        _controller.text = pokemon.localizedName;
        widget.onSelected(pokemon);
      },
      onSubmittedPick: (text) {
        final results = _sortedOptions(text);
        return results.isNotEmpty ? results.first : null;
      },
      maxHeight: 250,
    );
  }
}
