import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/champions_usage.dart';
import '../../data/pokedex.dart';
import '../../models/pokemon.dart';
import '../../i18n/app_strings.dart';
import '../../controllers/champions_filter_controller.dart';
import '../../platform/sprite_pack_manager.dart';
import '../../search/korean_search.dart';
import 'pokemon_sprite.dart';
import 'search_picker/search_picker.dart';

/// The species field: shows the current Pokémon and opens the search
/// modal on tap (grid of sprites by default, list on request).
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

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    final all = await loadPokedex();
    if (!mounted) return;
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
      }
    });
  }

  bool _passesFilter(Pokemon p) {
    // Global champions-only filter — controlled from AppSettingsMenu.
    // Read when the modal opens. The selected species always passes
    // (hoisted in _sortedOptions) so toggling the filter never strands
    // the field on a hidden value.
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
    // ties fall back to dex order (SearchIndex default).
    return pickerSuggestions(
      index,
      query,
      hoist: _selected,
      allow: _passesFilter,
    );
  }

  Future<void> _open() async {
    final picked = await showSearchPicker<Pokemon>(
      context,
      SearchPickerConfig<Pokemon>(
        kind: 'pokemon',
        hintText: AppStrings.t('search.pokemon'),
        selected: _selected,
        suggestions: _sortedOptions,
        labelOf: (p) => p.localizedName,
        idOf: (p) => p.name,
        fromId: (id) {
          final p = pokedexByName(id);
          return p != null && !p.hidden && _passesFilter(p) ? p : null;
        },
        // The sprite's placeholder has its own tap handler (opens the
        // sprite settings); inside a picker tile the tap must pick.
        imageOf: (context, p, size) => IgnorePointer(
          child: PokemonSprite(
              pokemonName: p.name, size: size, useBoxIcon: size <= 32),
        ),
        imagesAvailable: kIsWeb || SpritePackManager.instance.hasAnyInstalled,
        defaultView: PickerViewMode.grid,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selected = picked);
    widget.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SearchPickerField(
      text: _selected?.localizedName ?? '',
      hintText: AppStrings.t('search.pokemon'),
      onTap: _index == null ? null : _open,
    );
  }
}
