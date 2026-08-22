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

  const PokemonSelector({
    super.key,
    required this.onSelected,
    this.initialPokemonName = 'Bulbasaur',
  });

  @override
  State<PokemonSelector> createState() => _PokemonSelectorState();
}

class _PokemonSelectorState extends State<PokemonSelector> {
  SearchIndex<Pokemon>? _index;
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
      _index = SearchIndex<Pokemon>(visible.map((p) =>
          SearchEntry(p, p.nameKo, p.name, nameJa: p.nameJa, aliases: p.aliases)));
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
    // Global champions-only filter — controlled from AppSettingsMenu.
    // Selected species always passes (handled by _sortedOptions' pinning
    // of the current pick at the top) so toggling the filter never
    // strands the field on a hidden value.
    if (!ChampionsFilterController.instance.championsOnly.value) return true;
    return isInChampions(p.name);
  }

  List<Pokemon> _sortedOptions(String query) {
    final index = _index;
    if (index == null) return const [];
    // Selected species pinned first (both modes); champions-only
    // filter applied to the rest via `allow` — the pinned selection
    // bypasses it so toggling the filter never strands the field.
    // Empty-mode rest keeps dex order (no restSort). Equal-relevance
    // ties fall back to dex order (SearchIndex default) — was
    // localized-name before; unified with the other pickers.
    return pickerSuggestions(
      index,
      query,
      hoist: _selected,
      allow: _passesFilter,
    );
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
