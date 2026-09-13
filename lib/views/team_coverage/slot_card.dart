part of '../team_coverage_screen.dart';

class _SlotCard extends StatefulWidget {
  final int index;
  final _TeamSlot slot;
  final Map<String, Ability> abilityDex;
  final Map<String, String> abilityNames;
  final Map<String, Item> itemDex;
  final Map<String, String> itemNames;
  final ValueChanged<Pokemon> onPokemonSelected;
  final ValueChanged<String> onAbilitySelected;
  final ValueChanged<String?> onItemSelected;
  /// When true, a 3rd row of 4 move pickers is added so the user can
  /// fill in the moves used for the offensive coverage matrix.
  final bool showMoves;
  final void Function(int moveIndex, Move? move) onMoveChanged;
  /// Tap handler for the type chips — opens the type-picker dialog
  /// and reports the user's pick (or null to clear back to natural).
  final void Function(
      ({PokemonType type1, PokemonType? type2, PokemonType? type3})?
          override) onTypeOverrideChanged;
  final ValueChanged<Stats> onEvChanged;
  final ValueChanged<NatureProfile> onNatureChanged;
  /// Fires when the user flips the shiny toggle. The slot's storage
  /// is mutated by the host (so save/load round-trips through the
  /// same `_TeamSlot.shiny` field); _SlotCard rebuilds via its own
  /// setState since it lives on the dialog overlay.
  final ValueChanged<bool> onShinyChanged;
  /// Fires when the user taps one of the send-to-calc buttons in
  /// the popup's sprite rail. 0 = attacker, 1 = defender. Host
  /// stages the payload via [CalcHandoff] and pops the route stack
  /// back to the calculator.
  final ValueChanged<int> onSendToCalc;

  const _SlotCard({
    required this.index,
    required this.slot,
    required this.abilityDex,
    required this.abilityNames,
    required this.itemDex,
    required this.itemNames,
    required this.onPokemonSelected,
    required this.onAbilitySelected,
    required this.onItemSelected,
    required this.showMoves,
    required this.onMoveChanged,
    required this.onTypeOverrideChanged,
    required this.onEvChanged,
    required this.onNatureChanged,
    required this.onShinyChanged,
    required this.onSendToCalc,
  });

  @override
  State<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<_SlotCard>
    with ChampionsScopeListener {
  final _abilityController = TextEditingController();
  final _itemController = TextEditingController();
  final _abilityFocus = FocusNode();
  final _itemFocus = FocusNode();

  // Cached sorted ability list. Same approach as StatInput — own
  // abilities first (sorted by their declaration order), then the
  // rest A→Z by Korean name. Recomputed only when the species'
  // ability list changes.
  // App-wide search engine over the ability keys; built lazily and
  // rebuilt only when the ability map reference changes. Replaces the
  // old own-first sort + cache + _listEquals (now shared).
  SearchIndex<String>? _abilityIndex;
  Map<String, String>? _abilityIndexFor;
  SearchIndex<String>? _itemIndex;
  Map<String, String>? _itemIndexFor;

  @override
  void dispose() {
    _abilityController.dispose();
    _itemController.dispose();
    _abilityFocus.dispose();
    _itemFocus.dispose();
    super.dispose();
  }

  String _abilityLabel(String key) => widget.abilityNames[key] ?? key;
  String _itemLabel(String? key) =>
      key == null ? AppStrings.t('team.item.none') : (widget.itemNames[key] ?? key);

  /// Ability suggestions via the shared engine: the mon's own abilities
  /// (Supreme Overlord expanded) pinned first, the rest A→Z by label,
  /// relevance-ranked on a real query.
  List<String> _abilitySuggestions(String query, List<String> pokemonAbilities) {
    if (!identical(_abilityIndexFor, widget.abilityNames)) {
      _abilityIndex = buildAbilityIndex(
        widget.abilityNames.keys,
        koOf: _abilityLabel,
        enOf: (k) => widget.abilityDex[k]?.nameEn ?? k,
        jaOf: (k) => widget.abilityDex[k]?.nameJa ?? '',
      );
      _abilityIndexFor = widget.abilityNames;
    }
    final own = expandAbilities(pokemonAbilities, widget.abilityNames);
    return pickerSuggestions(
      _abilityIndex!,
      query,
      pins: own,
      restSort: (a, b) => _abilityLabel(a).compareTo(_abilityLabel(b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.slot.pokemon;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left rail: sprite + shiny toggle + send-to-calc
              // buttons. Width locked at 108 — the right column
              // (ability / item / EV / nature inputs) is much
              // more important than the sprite, so the rail must
              // not eat into the form area. The chunkier buttons
              // grow vertically (into the previously-empty space
              // below the sprite), never horizontally.
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 6),
                child: SizedBox(
                  width: 108,
                  child: _spriteRail(context, p),
                ),
              ),
              Expanded(child: _slotCardBody(context, p)),
            ],
          ),
          // Move grid sits BELOW the sprite-rail / form row so each
          // move picker can use the full popup width instead of
          // being squeezed into the form column. With a 4 × 1
          // vertical layout each picker stretches edge-to-edge,
          // leaving plenty of room for the type/category/power
          // suffix.
          if (widget.showMoves) ...[
            const SizedBox(height: 10),
            _moveGrid(scheme, p),
          ],
        ],
      ),
    );
  }

  /// Left column of the popup: sprite + shiny toggle + send-to-calc
  /// buttons. The buttons disable themselves on an empty slot so the
  /// user can't accidentally ship a blank pokemon into the calc.
  Widget _spriteRail(BuildContext context, Pokemon? p) {
    final scheme = Theme.of(context).colorScheme;
    final hasPokemon = p != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          // Sprite stays at 80 — the slot summary card behind the
          // popup already shows the species clearly, so the popup
          // sprite is just confirmation. Reserving the visual
          // weight (and the rail width budget) for the inputs.
          child: PokemonSprite(
            pokemonName: p?.name ?? '',
            size: 80,
            shiny: widget.slot.shiny,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: OutlinedButton(
            onPressed: hasPokemon
                ? () {
                    widget.onShinyChanged(!widget.slot.shiny);
                    // Host setState updates the slot; we also have to
                    // rebuild ourselves because we live in the dialog
                    // overlay.
                    if (mounted) setState(() {});
                  }
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              side: BorderSide(
                color: !hasPokemon
                    ? Colors.grey
                    : (widget.slot.shiny
                        ? scheme.primary
                        : Colors.grey.shade500),
              ),
              foregroundColor: !hasPokemon
                  ? Colors.grey
                  : (widget.slot.shiny
                      ? scheme.primary
                      : scheme.onSurface),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.slot.shiny
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    AppStrings.t('dex.shinyToggle'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Wider gap before the destructive(-ish) handoff buttons —
        // tapping them yanks the user out of the team builder into
        // the calc, so we want a clear separation from the shiny
        // toggle above (which is a no-op visual flip).
        const SizedBox(height: 16),
        _handoffButton(
          label: AppStrings.t('team.slot.toAttacker'),
          color: Colors.red.shade600,
          enabled: hasPokemon,
          onPressed: () => widget.onSendToCalc(0),
        ),
        const SizedBox(height: 10),
        _handoffButton(
          label: AppStrings.t('team.slot.toDefender'),
          color: Colors.blue.shade600,
          enabled: hasPokemon,
          onPressed: () => widget.onSendToCalc(1),
        ),
      ],
    );
  }

  Widget _handoffButton({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          side: BorderSide(
              color:
                  enabled ? color.withValues(alpha: 0.6) : Colors.grey,
              width: 1.5),
          foregroundColor: enabled ? color : Colors.grey,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _slotCardBody(BuildContext context, Pokemon? p) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Row 1: name selector (full width) | type chips.
        // Index, load, delete, close all moved out of the row.
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Expanded(
                child: PokemonSelector(
                  key: ValueKey(
                      'team_slot_${widget.index}_${p?.name ?? "empty"}'),
                  initialPokemonName: p?.name,
                  // Host setState fires inside onPokemonSelected, but
                  // _SlotCard lives in the dialog overlay and doesn't
                  // see that rebuild — call our own setState so the
                  // sprite / ability / item / EV / move fields all
                  // refresh immediately with the new species' defaults.
                  onSelected: (picked) {
                    widget.onPokemonSelected(picked);
                    if (mounted) setState(() {});
                  },
                ),
              ),
              if (p != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _openTypePicker(p),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.slot.effectiveType1 != null)
                        TypeChip(widget.slot.effectiveType1!, dense: true),
                      if (widget.slot.effectiveType2 != null) ...[
                        const SizedBox(width: 2),
                        TypeChip(widget.slot.effectiveType2!, dense: true),
                      ],
                      if (widget.slot.effectiveType3 != null) ...[
                        const SizedBox(width: 2),
                        TypeChip(widget.slot.effectiveType3!, dense: true),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // ─── Row 2: ability + item.
        const SizedBox(height: 4),
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(child: _abilityField(scheme, p)),
              const SizedBox(width: 6),
              Expanded(child: _itemField(scheme, p)),
            ],
          ),
        ),
        // ─── Row 3: 6 EV inputs + 2 nature pickers. Placed above
        // the move grid per UX direction so the stat block sits next
        // to the ability/item field it belongs with. Always rendered
        // (even on an empty slot) so the popup's full footprint shows
        // before selection — picking a species fills the cells with
        // curated Champions defaults via _applyPokemonToSlot.
        const SizedBox(height: 8),
        _evInputsRow(scheme),
        const SizedBox(height: 6),
        _naturePickersRow(scheme),
        // Move grid intentionally NOT here — it's rendered below the
        // whole sprite-rail / form row so it can span the full popup
        // width. See build().
      ],
    );
  }

  Widget _evInputsRow(ColorScheme scheme) {
    // Slot stores EVs internally (so the calc handoff stays in EV
    // units), but the team-builder UI works in Champions SP — convert
    // once for display, convert back inside the onChanged handler.
    final evs = widget.slot.evs ?? const Stats(
      hp: 0, attack: 0, defense: 0,
      spAttack: 0, spDefense: 0, speed: 0,
    );
    final sp = ChampionsMode.evToSpStats(evs);
    const keys = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
    final labels = {
      'hp': AppStrings.t('stat.hp'),
      'atk': AppStrings.t('stat.attack'),
      'def': AppStrings.t('stat.defense'),
      'spa': AppStrings.t('stat.spAttack'),
      'spd': AppStrings.t('stat.spDefense'),
      // Slot popup uses the shortened Speed label so the 6-cell
      // EV row stays balanced (see stat.speedShort comment in
      // app_strings.dart).
      'spe': AppStrings.t('stat.speedShort'),
    };

    int valueOf(String k) {
      switch (k) {
        case 'hp':
          return sp.hp;
        case 'atk':
          return sp.attack;
        case 'def':
          return sp.defense;
        case 'spa':
          return sp.spAttack;
        case 'spd':
          return sp.spDefense;
        case 'spe':
          return sp.speed;
      }
      return 0;
    }

    Stats spWithUpdated(String k, int v) {
      v = v.clamp(0, ChampionsMode.maxPerStat);
      switch (k) {
        case 'hp':
          return Stats(
              hp: v,
              attack: sp.attack,
              defense: sp.defense,
              spAttack: sp.spAttack,
              spDefense: sp.spDefense,
              speed: sp.speed);
        case 'atk':
          return Stats(
              hp: sp.hp,
              attack: v,
              defense: sp.defense,
              spAttack: sp.spAttack,
              spDefense: sp.spDefense,
              speed: sp.speed);
        case 'def':
          return Stats(
              hp: sp.hp,
              attack: sp.attack,
              defense: v,
              spAttack: sp.spAttack,
              spDefense: sp.spDefense,
              speed: sp.speed);
        case 'spa':
          return Stats(
              hp: sp.hp,
              attack: sp.attack,
              defense: sp.defense,
              spAttack: v,
              spDefense: sp.spDefense,
              speed: sp.speed);
        case 'spd':
          return Stats(
              hp: sp.hp,
              attack: sp.attack,
              defense: sp.defense,
              spAttack: sp.spAttack,
              spDefense: v,
              speed: sp.speed);
        case 'spe':
          return Stats(
              hp: sp.hp,
              attack: sp.attack,
              defense: sp.defense,
              spAttack: sp.spAttack,
              spDefense: sp.spDefense,
              speed: v);
      }
      return sp;
    }

    return Row(
      children: [
        for (final k in keys) ...[
          Expanded(
            child: EvSpCell(
              label: labels[k]!,
              value: valueOf(k),
              max: ChampionsMode.maxPerStat,
              onChanged: (v) {
                final newSp = spWithUpdated(k, v);
                widget.onEvChanged(ChampionsMode.spToEvStats(newSp));
                setState(() {});
              },
            ),
          ),
          if (k != keys.last) const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget _naturePickersRow(ColorScheme scheme) {
    final nature = widget.slot.nature ?? NatureProfile.neutral;
    return Row(
      children: [
        Expanded(child: _naturePicker(nature, isUp: true)),
        const SizedBox(width: 6),
        Expanded(child: _naturePicker(nature, isUp: false)),
      ],
    );
  }

  Widget _naturePicker(NatureProfile nature, {required bool isUp}) =>
      NaturePickMenu(
        nature: nature,
        isUp: isUp,
        labelFontSize: 14,
        onNatureChanged: (n) {
          widget.onNatureChanged(n);
          // Parent's setState rebuilds the host screen, but the dialog
          // we're inside lives on the Navigator overlay and doesn't
          // see that — trigger our own rebuild so the picker label
          // updates immediately.
          setState(() {});
        },
      );

  Widget _moveGrid(ColorScheme scheme, Pokemon? p) {
    // 2 × 2 grid that now spans the full popup width (the grid
    // sits below the sprite-rail/form Row, not inside the form
    // column). Each cell gets ~popupWidth/2 — much wider than the
    // pre-restructure layout where cells competed with the form
    // column for half of that.
    Widget cell(int i) {
      return Expanded(
        child: SizedBox(
          height: 50,
          child: _moveField(scheme, p, i),
        ),
      );
    }
    return Column(
      children: [
        Row(children: [cell(0), const SizedBox(width: 8), cell(1)]),
        const SizedBox(height: 6),
        Row(children: [cell(2), const SizedBox(width: 8), cell(3)]),
      ],
    );
  }

  Widget _moveField(ColorScheme scheme, Pokemon? p, int moveIndex) {
    if (p == null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: '${AppStrings.t('label.move')} ${moveIndex + 1}',
          isDense: true,
        ),
        child: Text(
          '-',
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    final current = widget.slot.moves[moveIndex];
    return MoveSelector(
      // Key by pokemon + move so swapping pokemon resets the
      // selector's internal cached pick.
      key: ValueKey(
          'team_slot_${widget.index}_move${moveIndex}_${p.name}_${current?.name ?? ''}'),
      pokemonName: p.name,
      pokemonNameKo: p.nameKo,
      dexNumber: p.dexNumber,
      initialMoveName: current?.name,
      onSelected: (m) => widget.onMoveChanged(moveIndex, m),
      // 4×1 vertical layout → each picker spans the full popup
      // width, so we can show the type/category/power suffix in
      // the suggestion rows (compact: false).
      compact: false,
      // Team builder always surfaces status moves (no toggle UI on
      // this screen) so users don't need to flip the global show-
      // status preference to pick e.g. 자기재생.
      forceShowStatus: true,
    );
  }

  Future<void> _openTypePicker(Pokemon p) async {
    final result = await showTypePickerDialog(
      context: context,
      currentType1: widget.slot.effectiveType1 ?? p.type1,
      currentType2: widget.slot.effectiveType2,
      currentType3: widget.slot.effectiveType3,
      pokemonName: p.name,
    );
    if (result == null) return;
    // The dialog's "초기화" returns the species' natural types — if
    // the result matches the natural pair, drop the override so the
    // slot tracks any future species change cleanly.
    final isNatural = result.type1 == p.type1 &&
        result.type2 == p.type2 &&
        result.type3 == null;
    widget.onTypeOverrideChanged(
      isNatural
          ? null
          : (type1: result.type1, type2: result.type2, type3: result.type3),
    );
  }

  // ─── Ability typeahead — same pattern as StatInput._abilityAutocomplete:
  // own abilities sorted to the top, others gray, tri-language search.
  Widget _abilityField(ColorScheme scheme, Pokemon? p) {
    if (p == null || widget.abilityNames.isEmpty) {
      return _disabledField(scheme, AppStrings.t('label.ability'));
    }
    final initialText = widget.slot.ability != null
        ? _abilityLabel(widget.slot.ability!)
        : '';
    if (!_abilityFocus.hasFocus) {
      _abilityController.text = initialText;
    }

    final ownSet = <String>{
      for (final a in p.abilities) ...expandAbilityStates(a),
    };

    return buildTypeAhead<String>(
      controller: _abilityController,
      focusNode: _abilityFocus,
      suggestionsCallback: (query) {
        if (query == initialText) return _abilitySuggestions('', p.abilities);
        return _abilitySuggestions(query, p.abilities);
      },
      decoration: InputDecoration(
        labelText: AppStrings.t('label.ability'),
        isDense: true,
      ),
      itemBuilder: (context, ability) {
        final isOwn = ownSet.contains(ability);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            _abilityLabel(ability),
            style: TextStyle(
              fontSize: 14,
              color: isOwn ? null : Colors.grey,
            ),
          ),
        );
      },
      onSelected: (v) {
        _abilityController.text = _abilityLabel(v);
        _abilityFocus.unfocus();
        widget.onAbilitySelected(v);
      },
    );
  }

  // ─── Item typeahead — same pattern as StatInput._itemAutocomplete:
  // empty key '' represents "no item" and sits at the top, currently
  // selected item bubbles to the front, tri-language search.
  Widget _itemField(ColorScheme scheme, Pokemon? p) {
    if (p == null || widget.itemNames.isEmpty) {
      return _disabledField(scheme, AppStrings.t('label.item'));
    }
    // Shared item engine (same as the calculator's pickers).
    if (!identical(_itemIndexFor, widget.itemNames)) {
      _itemIndex = buildItemIndex(widget.itemNames,
          itemDex: widget.itemDex, noneLabel: AppStrings.t('team.item.none'));
      _itemIndexFor = widget.itemNames;
    }
    final initialText = _itemLabel(widget.slot.heldItem);
    if (!_itemFocus.hasFocus) {
      _itemController.text = initialText;
    }

    return buildTypeAhead<String>(
      controller: _itemController,
      focusNode: _itemFocus,
      suggestionsCallback: (text) => itemSuggestions(
        _itemIndex!,
        text == initialText ? '' : text,
        selected: widget.slot.heldItem,
        championsOnly: ChampionsFilterController.instance.championsOnly.value,
        labelOf: (k) => _itemLabel(k.isEmpty ? null : k),
      ),
      decoration: InputDecoration(
        labelText: AppStrings.t('label.item'),
        isDense: true,
      ),
      itemBuilder: (context, key) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            _itemLabel(key.isEmpty ? null : key),
            style: const TextStyle(fontSize: 14),
          ),
        );
      },
      onSelected: (v) {
        _itemController.text = _itemLabel(v.isEmpty ? null : v);
        _itemFocus.unfocus();
        widget.onItemSelected(v.isEmpty ? null : v);
      },
    );
  }

  /// Disabled-looking InputDecorator for the empty-slot state — mirrors
  /// the active typeahead's height/border so the row doesn't jump when
  /// a Pokemon is picked.
  Widget _disabledField(ColorScheme scheme, String label) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      child: Text(
        '-',
        style: TextStyle(
          fontSize: 14,
          color: scheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
