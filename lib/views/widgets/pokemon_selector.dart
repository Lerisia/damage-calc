import 'package:flutter/material.dart';
import '../../data/champions_usage.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../utils/app_strings.dart';
import '../../utils/champions_filter_controller.dart';
import '../../utils/korean_search.dart';
import 'typeahead_helpers.dart';

class PokemonSelector extends StatefulWidget {
  final void Function(Pokemon pokemon) onSelected;
  /// Pokemon name to seed the field with, or `null` for an empty
  /// "pick a Pokemon" state. Empty string is treated the same as
  /// `null` so callers passing `state.pokemonName ?? ''` work.
  final String? initialPokemonName;
  /// When true, narrow the search list to species curated in
  /// [championsUsageFor] (Pokémon Champions roster). The selector still
  /// respects the user's last pick — selected species always shows up
  /// at the top regardless of filter — so toggling won't strand the
  /// field on a hidden value.
  final bool filterChampionsOnly;

  const PokemonSelector({
    super.key,
    required this.onSelected,
    this.initialPokemonName = 'Bulbasaur',
    this.filterChampionsOnly = false,
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
    // The global "Champions only" toggle can flip between dex visits;
    // listen so the suggestions list refilters on the fly.
    ChampionsFilterController.instance.championsOnly.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    ChampionsFilterController.instance.championsOnly.removeListener(_onFilterChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPokemon() async {
    final all = await loadPokedex();
    final visible = all.where((p) => !p.hidden).toList();
    setState(() {
      _allPokemon = visible;
      _searchEntries = visible.map((p) => SearchEntry(p, p.nameKo, p.name, nameJa: p.nameJa, aliases: p.aliases)).toList();
      // Empty / null initial name → leave the field blank so callers
      // (e.g. team builder slots) can render a true "no Pokemon" state
      // instead of forcing a Bulbasaur fallback.
      final seed = widget.initialPokemonName;
      if (_selected == null && all.isNotEmpty &&
          seed != null && seed.isNotEmpty) {
        _selected = all.firstWhere(
          (p) => p.name == seed,
          orElse: () => all.firstWhere((p) => p.dexNumber == 1, orElse: () => all.first),
        );
        _controller.text = _selected?.localizedName ?? '';
      }
    });
  }

  bool _passesFilter(Pokemon p) {
    if (!widget.filterChampionsOnly) return true;
    if (!ChampionsFilterController.instance.championsOnly.value) return true;
    return isInChampions(p.name);
  }

  List<Pokemon> _sortedOptions(String query) {
    if (query.isEmpty) {
      final base = _allPokemon.where(_passesFilter).toList();
      return _selected != null
          ? [_selected!, ...base.where((p) => p != _selected)]
          : base;
    }

    final qLower = query.toLowerCase();
    final qRunes = qLower.runes.toList();
    final scored = <(Pokemon, int)>[];
    for (final entry in _searchEntries) {
      if (!_passesFilter(entry.item)) continue;
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
        // Move caret to the end so the field doesn't stay in a
        // "select all" state after picking.
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        // Dismiss the on-screen keyboard — users expect mobile to
        // collapse the keyboard after a typeahead pick.
        FocusManager.instance.primaryFocus?.unfocus();
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
