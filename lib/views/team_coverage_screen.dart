import 'package:flutter/material.dart';
import '../data/abilitydex.dart';
import '../data/champions_usage.dart';
import '../data/itemdex.dart';
import '../data/pokedex.dart';
import '../data/sample_storage.dart';
import '../models/ability.dart';
import '../models/battle_pokemon.dart';
import '../models/item.dart';
import '../models/pokemon.dart';
import '../models/type.dart';
import '../utils/app_strings.dart';
import '../utils/korean_search.dart';
import '../utils/localization.dart';
import '../utils/team_coverage.dart';
import 'widgets/pokemon_selector.dart';
import 'widgets/typeahead_helpers.dart';

/// One slot in the team-builder. We keep just the bits that affect
/// type matchups — full BattlePokemonState is overkill here and would
/// drag along EV/level/move state nobody fills out.
class _TeamSlot {
  Pokemon? pokemon;
  String? ability;
  String? heldItem; // currently only used to honour Air Balloon / Iron Ball
}

/// Process-lifetime team state — survives navigating away from the
/// screen so the user doesn't lose their picks the moment they pop
/// back to the calculator. Cleared only on app restart. (Persistent
/// disk storage will hook into the existing sample save/load slot.)
class _TeamCoverageStore {
  static const int maxTeamSize = 6;
  static final List<_TeamSlot> team =
      List.generate(maxTeamSize, (_) => _TeamSlot());
}

class TeamCoverageScreen extends StatefulWidget {
  const TeamCoverageScreen({super.key});

  @override
  State<TeamCoverageScreen> createState() => _TeamCoverageScreenState();
}

class _TeamCoverageScreenState extends State<TeamCoverageScreen> {
  static const int _maxTeamSize = _TeamCoverageStore.maxTeamSize;
  // Backed by the singleton so the picks persist across pushes/pops.
  List<_TeamSlot> get _team => _TeamCoverageStore.team;

  // Full ability/item dex maps for the typeahead pickers — same data
  // the calculator's StatInput loads. Cached statically so navigating
  // away and back doesn't re-pay the load.
  static Map<String, Ability>? _abilityDex;
  static Map<String, Item>? _itemDex;
  // Filtered, key→localized-name maps for the picker. Mirrors the
  // calculator's filtering: skip non-mainline abilities and non-battle
  // items so users don't trip over Colosseum / cosmetic entries.
  static Map<String, String>? _abilityNames;
  static Map<String, String>? _itemNames;

  @override
  void initState() {
    super.initState();
    _loadDexes();
  }

  Future<void> _loadDexes() async {
    if (_abilityDex != null && _itemDex != null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final aDex = await loadAbilitydex();
      final iDex = await loadItemdex();
      // Same filters StatInput applies — non-mainline abilities are
      // spin-off / Colosseum entries that just confuse the picker;
      // non-battle items don't matter for coverage decisions.
      final aNames = <String, String>{};
      for (final e in aDex.entries) {
        if (e.value.nonMainline) continue;
        aNames[e.key] = e.value.localizedName;
      }
      final iNames = <String, String>{};
      for (final e in iDex.entries) {
        if (e.value.battle) iNames[e.key] = e.value.localizedName;
      }
      _abilityDex = aDex;
      _itemDex = iDex;
      _abilityNames = aNames;
      _itemNames = iNames;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _setPokemon(int index, Pokemon p) {
    setState(() {
      _team[index].pokemon = p;

      // Seed ability from curated Champions Singles data; fall back
      // to the species' first listed ability.
      final curatedAbilities = championsUsageFor(p.name)?.abilities;
      String? pickedAbility;
      if (curatedAbilities != null && curatedAbilities.isNotEmpty) {
        final first = curatedAbilities.first.name;
        if (p.abilities.contains(first)) pickedAbility = first;
      }
      pickedAbility ??= p.abilities.isNotEmpty ? p.abilities.first : null;
      _team[index].ability = pickedAbility;

      // Seed item the same way the calculator's auto-load does — use
      // the curated top pick, but skip megastones for base forms so
      // dropping a Pokemon in doesn't silently mega-evolve it. Mega
      // forms get pinned to their requiredItem.
      String? pickedItem;
      if (p.requiredItem != null) {
        pickedItem = p.requiredItem;
      } else {
        final curatedItems = championsUsageFor(p.name)?.items;
        if (curatedItems != null && curatedItems.isNotEmpty) {
          final stones = megaStoneItemIds();
          for (final row in curatedItems) {
            if (!stones.contains(row.name)) {
              pickedItem = row.name;
              break;
            }
          }
        }
      }
      _team[index].heldItem = pickedItem;
    });
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.t('team.resetAll.confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.t('action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.t('team.resetAll')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      for (int i = 0; i < _team.length; i++) {
        _team[i] = _TeamSlot();
      }
    });
  }

  // Shared style for the AppBar action buttons — compact density and
  // tight padding so the three buttons fit alongside the back arrow on
  // a phone-width screen.
  static final ButtonStyle _appBarBtnStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    visualDensity: VisualDensity.compact,
  );

  /// Show the saved-party picker and replace the 6 slots with the
  /// chosen team's members. Slots beyond the team's member count are
  /// cleared. Confirmation is asked only when at least one slot is
  /// already filled, so first-time use is a single-tap flow.
  Future<void> _loadParty() async {
    final store = await SampleStorage.loadStore();
    if (!mounted) return;
    final candidates = store.teams
        .where((t) => t.memberIds.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.load.noTeams')),
      ));
      return;
    }
    final pickedId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              dense: true,
              title: Text(
                AppStrings.t('team.load.title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            for (final t in candidates)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(t.name),
                subtitle:
                    Text('${t.memberIds.length} / $kMaxTeamSize'),
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ),
      ),
    );
    if (pickedId == null || !mounted) return;

    // Confirm replacement only when the user would lose work.
    if (_team.any((s) => s.pokemon != null)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(AppStrings.t('team.load.replaceConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t('action.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.t('action.confirm')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final team = store.teams.firstWhere((t) => t.id == pickedId);
    final pokedex = await loadPokedex();
    if (!mounted) return;
    final byName = {for (final p in pokedex) p.name: p};
    setState(() {
      for (int i = 0; i < _team.length; i++) {
        if (i < team.memberIds.length) {
          final s = store.sampleById(team.memberIds[i]);
          if (s == null) {
            _team[i] = _TeamSlot();
            continue;
          }
          final p = byName[s.state.pokemonName];
          if (p == null) {
            _team[i] = _TeamSlot();
            continue;
          }
          _team[i] = _TeamSlot()
            ..pokemon = p
            ..ability = s.state.selectedAbility
            ..heldItem = s.state.selectedItem;
        } else {
          _team[i] = _TeamSlot();
        }
      }
    });
  }

  /// Persist the current 6 slots as a new saved party. The samples
  /// are intentionally stub-y — species + ability + item only — since
  /// the party screen doesn't capture EV/IV/level/moves. Users can
  /// open the saved sample in the calculator afterwards to flesh out
  /// the rest of the build.
  Future<void> _saveAsParty() async {
    final filled = <_TeamSlot>[];
    for (final s in _team) {
      if (s.pokemon != null) filled.add(s);
    }
    if (filled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.save.empty')),
      ));
      return;
    }
    final store = await SampleStorage.loadStore();
    if (!mounted) return;

    // Default name "파티 N" using the next available number across
    // the existing parties — simple, predictable, and the user can
    // edit before confirming.
    final defaultName = '파티 ${store.teams.length + 1}';
    final teamName = await _promptText(
      title: AppStrings.t('team.save.title'),
      initial: defaultName,
    );
    if (teamName == null || teamName.isEmpty || !mounted) return;

    // Names must stay globally unique. Try species, then "species
    // (party)", then numeric suffix. Bake names into the local set as
    // we go so two slots of the same species don't collide with each
    // other within this save batch.
    final existingNames = store.samples.map((s) => s.name).toSet();
    String uniqueName(String base) {
      if (!existingNames.contains(base)) return base;
      final withParty = '$base ($teamName)';
      if (!existingNames.contains(withParty)) return withParty;
      for (int i = 2;; i++) {
        final candidate = '$withParty ($i)';
        if (!existingNames.contains(candidate)) return candidate;
      }
    }

    final teamId = await SampleStorage.createTeam(teamName);
    int saved = 0;
    for (final slot in filled) {
      final state = BattlePokemonState();
      state.applyPokemon(slot.pokemon!);
      // applyPokemon seeds ability/item from curated defaults — only
      // override when the user explicitly picked something different.
      if (slot.ability != null) state.selectedAbility = slot.ability!;
      if (slot.heldItem != null) state.selectedItem = slot.heldItem;
      final name = uniqueName(slot.pokemon!.localizedName);
      existingNames.add(name);
      try {
        await SampleStorage.savePokemon(
            name: name, state: state, teamId: teamId);
        saved++;
      } on TeamFullException {
        // Shouldn't hit — we just created the team — but bail clean
        // if the schema ever changes.
        break;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"$teamName" ${AppStrings.t('team.save.done')} ($saved)'),
    ));
  }

  /// Minimal name-prompt dialog for the party-save flow. Standalone
  /// so it doesn't need to reach into the slot card's helper.
  Future<String?> _promptText({
    required String title,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(AppStrings.t('action.confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _clearSlot(int index) {
    setState(() {
      _team[index] = _TeamSlot();
    });
  }

  void _setAbility(int index, String ability) {
    setState(() => _team[index].ability = ability);
  }

  /// Item picker can clear back to "no item", so we accept null.
  void _setItem(int index, String? item) {
    setState(() => _team[index].heldItem = item);
  }

  /// Pull a saved sample (from the calculator's attacker/defender
  /// sample storage) and copy just the bits the team builder cares
  /// about into [index].
  Future<void> _loadSampleInto(int index) async {
    final samples = await SampleStorage.loadSamples();
    if (!mounted) return;
    if (samples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.sample.empty')),
      ));
      return;
    }
    final pokedex = await loadPokedex();
    if (!mounted) return;
    // Build a map name → Pokemon once so we can rehydrate samples
    // whose persisted state only kept the `pokemonName` string.
    final byName = {for (final p in pokedex) p.name: p};
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (int i = 0; i < samples.length; i++)
              ListTile(
                title: Text(samples[i].name),
                subtitle: Text(samples[i].state.localizedPokemonName,
                    style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final s = samples[picked].state;
    final p = byName[s.pokemonName];
    if (p == null) return;
    setState(() {
      _team[index].pokemon = p;
      _team[index].ability = s.selectedAbility;
      _team[index].heldItem = s.selectedItem;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wide layout splits into two columns: slot list on the left,
    // matrix on the right. Threshold matches the calculator's wide
    // breakpoint feel.
    final isWide = MediaQuery.of(context).size.width >= 900;

    final slotList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _maxTeamSize; i++) ...[
          _SlotCard(
            // Keying by index keeps the typeahead controllers stable
            // across slot mutations — without the key, swapping which
            // Pokemon is in slot 0 would shred slot 0's text state.
            key: ValueKey('team_slot_card_$i'),
            index: i,
            slot: _team[i],
            abilityDex: _abilityDex ?? const {},
            abilityNames: _abilityNames ?? const {},
            itemDex: _itemDex ?? const {},
            itemNames: _itemNames ?? const {},
            onPokemonSelected: (p) => _setPokemon(i, p),
            onAbilitySelected: (a) => _setAbility(i, a),
            onItemSelected: (it) => _setItem(i, it),
            onLoadSample: () => _loadSampleInto(i),
            onClear: () => _clearSlot(i),
          ),
          if (i < _maxTeamSize - 1) const SizedBox(height: 4),
        ],
      ],
    );

    // Pass ALL 6 slots — including empty ones — so the matrix grid
    // is dimensionally stable. Empty slots render blank cells; the
    // summary only counts filled ones.
    final matrix = _CoverageMatrix(
      team: _team,
      abilityNames: _abilityNames ?? const {},
    );

    return PopScope(
      // Block iOS swipe-back / Android system back so a stray drag
      // along the edge doesn't lose the user's whole team. Only the
      // explicit AppBar back arrow exits the screen — that's a
      // deliberate tap, not an accidental drag.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
      appBar: AppBar(
        // Override the auto-implied BackButton (which calls
        // Navigator.maybePop and would be blocked by canPop:false).
        // Navigator.pop bypasses PopScope, so this still exits.
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Title row hosts party-level actions (load saved party, save
        // current party, reset). Wrapped in a horizontal scroll so
        // narrow screens degrade to a swipe instead of a clipped
        // label.
        titleSpacing: 0,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: _loadParty,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(AppStrings.t('team.load')),
                style: _appBarBtnStyle,
              ),
              TextButton.icon(
                onPressed:
                    _team.any((s) => s.pokemon != null) ? _saveAsParty : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(AppStrings.t('team.save')),
                style: _appBarBtnStyle,
              ),
              TextButton.icon(
                onPressed:
                    _team.any((s) => s.pokemon != null) ? _resetAll : null,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(AppStrings.t('team.resetAll')),
                style: _appBarBtnStyle,
              ),
            ],
          ),
        ),
      ),
      body: isWide
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(child: slotList),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(child: matrix),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  slotList,
                  const SizedBox(height: 20),
                  matrix,
                ],
              ),
            ),
      ),
    );
  }
}

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
  final VoidCallback onLoadSample;
  final VoidCallback onClear;

  const _SlotCard({
    super.key,
    required this.index,
    required this.slot,
    required this.abilityDex,
    required this.abilityNames,
    required this.itemDex,
    required this.itemNames,
    required this.onPokemonSelected,
    required this.onAbilitySelected,
    required this.onItemSelected,
    required this.onLoadSample,
    required this.onClear,
  });

  @override
  State<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<_SlotCard> {
  final _abilityController = TextEditingController();
  final _itemController = TextEditingController();
  final _abilityFocus = FocusNode();
  final _itemFocus = FocusNode();

  // Cached sorted ability list. Same approach as StatInput — own
  // abilities first (sorted by their declaration order), then the
  // rest A→Z by Korean name. Recomputed only when the species'
  // ability list changes.
  List<String> _cachedSortedAbilities = const [];
  List<String> _lastPokemonAbilities = const [];

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

  /// Expand Supreme Overlord into its 0–5 stacked variants so all
  /// six count as "own" abilities for the gray/non-gray split.
  static List<String> _expandAbilities(
      List<String> abilities, Map<String, String> nameMap) {
    final expanded = <String>[];
    for (final a in abilities) {
      if (a == 'Supreme Overlord') {
        for (int i = 0; i <= 5; i++) {
          final key = 'Supreme Overlord $i';
          if (nameMap.containsKey(key)) expanded.add(key);
        }
      } else {
        expanded.add(a);
      }
    }
    return expanded;
  }

  void _rebuildSortedAbilities(List<String> pokemonAbilities) {
    final all = widget.abilityNames.keys.toList();
    final own = _expandAbilities(pokemonAbilities, widget.abilityNames);
    final rest = all.where((a) => !own.contains(a)).toList();
    rest.sort((a, b) => _abilityLabel(a).compareTo(_abilityLabel(b)));
    _cachedSortedAbilities = [...own, ...rest];
    _lastPokemonAbilities = List.of(pokemonAbilities);
  }

  List<String> _sortedAbilities(List<String> pokemonAbilities) {
    if (!_listEquals(_lastPokemonAbilities, pokemonAbilities) ||
        _cachedSortedAbilities.isEmpty) {
      _rebuildSortedAbilities(pokemonAbilities);
    }
    return _cachedSortedAbilities;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Row 1: index | name selector | type chips | load | clear
          // Fixed height so the card doesn't jump when type chips or
          // the clear button appear after a pokemon is picked.
          SizedBox(
            height: 36,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: PokemonSelector(
                    key: ValueKey(
                        'team_slot_${widget.index}_${p?.name ?? "empty"}'),
                    initialPokemonName: p?.name,
                    onSelected: widget.onPokemonSelected,
                  ),
                ),
                if (p != null) ...[
                  const SizedBox(width: 6),
                  _typeChip(p.type1),
                  if (p.type2 != null) ...[
                    const SizedBox(width: 2),
                    _typeChip(p.type2!),
                  ],
                ],
                const SizedBox(width: 4),
                IconButton(
                  tooltip: AppStrings.t('team.sample.load'),
                  icon: const Icon(Icons.folder_open, size: 18),
                  onPressed: widget.onLoadSample,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
                if (p != null)
                  IconButton(
                    tooltip: '',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClear,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
              ],
            ),
          ),
          // ─── Row 2: ability + item dropdowns. Fixed height matches
          // a TextField with a floating label, so swapping the
          // disabled placeholder for an active typeahead doesn't
          // resize the card.
          const SizedBox(height: 4),
          SizedBox(
            height: 50,
            child: Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: _abilityField(scheme, p),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _itemField(scheme, p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(PokemonType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(type),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        KoStrings.getTypeName(type),
        style: const TextStyle(
            fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Ability typeahead — same pattern as StatInput._abilityAutocomplete:
  // own abilities sorted to the top, others gray, tri-language search.
  Widget _abilityField(ColorScheme scheme, Pokemon? p) {
    if (p == null || widget.abilityNames.isEmpty) {
      return _disabledField(scheme, AppStrings.t('label.ability'));
    }
    final sorted = _sortedAbilities(p.abilities);
    final initialText = widget.slot.ability != null
        ? _abilityLabel(widget.slot.ability!)
        : '';
    if (!_abilityFocus.hasFocus) {
      _abilityController.text = initialText;
    }

    final ownSet = <String>{
      for (final a in p.abilities)
        if (a == 'Supreme Overlord')
          for (int i = 0; i <= 5; i++) 'Supreme Overlord $i'
        else
          a,
    };

    return buildTypeAhead<String>(
      controller: _abilityController,
      focusNode: _abilityFocus,
      suggestionsCallback: (query) {
        if (query.isEmpty || query == initialText) return sorted;
        return sorted.where((a) {
          final data = widget.abilityDex[a];
          return triLanguageScore(query,
                nameKo: data?.nameKo ?? _abilityLabel(a),
                nameEn: data?.nameEn ?? a,
                nameJa: data?.nameJa ?? '',
                internalKey: a,
              ) >
              0;
        }).toList();
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
      onSubmittedPick: (text) {
        if (text.isEmpty) return null;
        final matches = sorted.where((a) {
          final data = widget.abilityDex[a];
          return triLanguageScore(text,
                nameKo: data?.nameKo ?? _abilityLabel(a),
                nameEn: data?.nameEn ?? a,
                nameJa: data?.nameJa ?? '',
                internalKey: a,
              ) >
              0;
        }).toList();
        return matches.isNotEmpty ? matches.first : null;
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
    final allItems = ['', ...widget.itemNames.keys];
    if (widget.slot.heldItem != null && allItems.contains(widget.slot.heldItem)) {
      allItems.remove(widget.slot.heldItem);
      allItems.insert(0, widget.slot.heldItem!);
    }
    final initialText = _itemLabel(widget.slot.heldItem);
    if (!_itemFocus.hasFocus) {
      _itemController.text = initialText;
    }

    return buildTypeAhead<String>(
      controller: _itemController,
      focusNode: _itemFocus,
      suggestionsCallback: (text) {
        if (text.isEmpty || text == initialText) return allItems;
        return allItems.where((key) {
          final data = widget.itemDex[key];
          return triLanguageScore(text,
                nameKo: data?.nameKo ?? _itemLabel(key.isEmpty ? null : key),
                nameEn: data?.nameEn ?? '',
                nameJa: data?.nameJa ?? '',
                internalKey: key,
              ) >
              0;
        }).toList();
      },
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
      onSubmittedPick: (text) {
        if (text.isEmpty) return null;
        final matches = allItems.where((key) {
          final data = widget.itemDex[key];
          return triLanguageScore(text,
                nameKo: data?.nameKo ?? _itemLabel(key.isEmpty ? null : key),
                nameEn: data?.nameEn ?? '',
                nameJa: data?.nameJa ?? '',
                internalKey: key,
              ) >
              0;
        }).toList();
        return matches.isNotEmpty ? matches.first : null;
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

class _CoverageMatrix extends StatelessWidget {
  final List<_TeamSlot> team;
  final Map<String, String> abilityNames;

  const _CoverageMatrix({
    required this.team,
    required this.abilityNames,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The matrix grid is dimensionally stable: always [team.length]
    // Pokemon columns (typically 6, even when slots are empty). Empty
    // slots produce a `null` row internally, which the renderer paints
    // as a blank cell. The summary on the right only counts filled
    // slots, so 0/0 reads cleanly when the team is empty.
    final filledCells = <CoverageSlot>[];
    final filledIndices = <int>[];
    for (int i = 0; i < team.length; i++) {
      final slot = team[i];
      final p = slot.pokemon;
      if (p == null) continue;
      filledCells.add(CoverageSlot(
        type1: p.type1,
        type2: p.type2,
        ability: slot.ability,
        heldItem: slot.heldItem,
      ));
      filledIndices.add(i);
    }
    final filledMatrix = defensiveCoverageMatrix(filledCells);
    final summary = summarize(filledMatrix);

    // Re-expand into a [team.length × 18] grid where empty slots get
    // null rows. Renderer keys off this for blank cells.
    final List<List<CoverageCell>?> displayMatrix =
        List<List<CoverageCell>?>.filled(team.length, null);
    for (int j = 0; j < filledIndices.length; j++) {
      displayMatrix[filledIndices[j]] = filledMatrix[j];
    }

    // Type-label column is sized to a snug 3-char chip (Korean type
    // names cap at 3 chars: 에스퍼, 고스트, 드래곤, 페어리) — no
    // wasted whitespace around it. The remaining width is split
    // between the 6 Pokemon columns and the summary block via flex.
    return Table(
      defaultColumnWidth: const FlexColumnWidth(1.0),
      columnWidths: {
        0: const FixedColumnWidth(48),
        for (int i = 0; i < team.length; i++)
          i + 1: const FlexColumnWidth(1.0),
        team.length + 1: const FlexColumnWidth(1.8),
      },
      border: TableBorder.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6), width: 0.6),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(scheme),
        for (int t = 0; t < teamCoverageAttackTypes.length; t++)
          _typeRow(t, displayMatrix, summary[t], scheme),
      ],
    );
  }

  TableRow _headerRow(ColorScheme scheme) {
    return TableRow(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      children: [
        const SizedBox.shrink(),
        for (final slot in team)
          slot.pokemon != null
              ? _vertNameCell(slot.pokemon!.localizedName)
              : const SizedBox(height: 84),
        // Color-coded labels side-by-side, with the same thicker
        // left divider that the data rows carry below.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                AppStrings.t('team.matrix.weak'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                ),
              ),
              Text(
                AppStrings.t('team.matrix.resist'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Vertical Pokemon name cell. For Korean / Japanese we stack the
  /// name one character per line (킬 / 가 / 르 / 도) — every character
  /// is its own glyph in those scripts, so this reads naturally and
  /// keeps the header column narrow on phones. For English we fall
  /// back to a 90° rotated label since stacking each letter would be
  /// unreadable for a name like "Aegislash".
  Widget _vertNameCell(String name) {
    final lang = AppStrings.current;
    if (lang == AppLanguage.ko || lang == AppLanguage.ja) {
      // Drop spaces / hyphens that show up in some long names — they
      // waste a stack row and don't add information ("미라이돈"보다
      // "미라이 돈" 같은 케이스).
      final chars = name.runes
          .map((r) => String.fromCharCode(r))
          .where((c) => c.trim().isNotEmpty)
          .toList();
      // Cap at 6 stacked chars so 84 px is enough; longer names (rare
      // in the dex) trail off with an ellipsis row.
      final shown = chars.length <= 6 ? chars : [...chars.take(5), '…'];
      return SizedBox(
        height: 84,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in shown)
                Text(
                  c,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 84,
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  TableRow _typeRow(
      int t,
      List<List<CoverageCell>?> matrix,
      CoverageColumnSummary summary,
      ColorScheme scheme) {
    final attackType = teamCoverageAttackTypes[t];
    return TableRow(
      // Zebra-stripe data rows. surfaceContainerHighest is wired to
      // zinc-100 (#F4F4F5) on light / zinc-800 on dark in this app's
      // theme — that lands right on the conventional GitHub /
      // Bootstrap table-stripe contrast (~5% delta from surface),
      // which is the "국룰" zebra value. Full alpha so it actually
      // reads; the prior 0.35 was too faint.
      decoration: BoxDecoration(
        color: t.isOdd ? scheme.surfaceContainerHighest : null,
      ),
      children: [
        // No horizontal padding — the type chip fills the 48 px
        // column flush, no whitespace either side. Vertical pad is
        // just enough to keep the chip from touching the row borders.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _attackTypeChip(attackType),
        ),
        for (int p = 0; p < team.length; p++)
          // Empty slot → blank cell so the column stays in place
          // without inviting the eye to read anything into it.
          matrix[p] == null
              ? const SizedBox(height: 22)
              : _multCell(matrix[p]![t], scheme),
        _summaryCell(summary, scheme),
      ],
    );
  }

  /// Solid colored chip — same style as the team-builder slot's type
  /// chips and the attacker/defender panel badges. The chip fills the
  /// fixed-width type column edge-to-edge; the 3-char Korean name sits
  /// centered with the colored bg picking up any slack.
  Widget _attackTypeChip(PokemonType type) {
    return ClipRect(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: KoStrings.getTypeColor(type),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          KoStrings.getTypeName(type),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: const TextStyle(
              fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Background tint for the weak/resist halves of the summary cell —
  /// gets denser the more team members fall into that bucket. 0 is
  /// transparent so it blends with the row's zebra stripe; 6 (full
  /// team) is the most saturated shade we'll show.
  Color _summaryBg(int count, MaterialColor base) {
    return switch (count) {
      0 => Colors.transparent,
      1 => base.shade50,
      2 => base.shade100,
      3 => base.shade200,
      4 => base.shade300,
      _ => base.shade400, // 5 or 6
    };
  }

  /// Side-by-side numbers — weak (red) on the left, resist+immune
  /// (blue) on the right. Each half carries a tint that grows with
  /// the count, so the eye can scan the column and spot the worst
  /// (densest red) and best (densest blue) types at a glance without
  /// reading the digits. Fenced off from the matrix by a thicker
  /// left border.
  Widget _summaryCell(CoverageColumnSummary summary, ColorScheme scheme) {
    final resistOrImmune = summary.resist + summary.immune;
    final weakBg = _summaryBg(summary.weak, Colors.red);
    final resistBg = _summaryBg(resistOrImmune, Colors.blue);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: weakBg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${summary.weak}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: summary.weak > 0
                      ? Colors.red.shade900
                      : scheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: resistBg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '$resistOrImmune',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: resistOrImmune > 0
                      ? Colors.blue.shade900
                      : scheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One matrix cell. Common matchups (2×, ½) read as colored text
  /// only so the chart doesn't go busy. The three decisive tiers —
  /// 4× quad-weak, ¼ quad-resist, and 무 immune — get a small filled
  /// pill behind the glyph so they pop on a column scan. The pill
  /// fits inside the existing 22 px row (no height change); it's just
  /// a contained badge, not a full-cell tint.
  ///   - 4×  "4×"  — light red pill, dark red text
  ///   - 2×  "2×"  — red text only
  ///   - 1×  (blank)
  ///   - ½   "½"   — blue text only
  ///   - ¼   "¼"   — light blue pill, dark blue text
  ///   - 무  "무"  — light gray pill, gray text
  Widget _multCell(CoverageCell cell, ColorScheme scheme) {
    String label;
    Color fg;
    Color? pillBg;
    FontWeight weight = FontWeight.w800;
    if (cell.isImmune) {
      label = AppStrings.t('team.matrix.immune');
      fg = scheme.onSurface.withValues(alpha: 0.55);
      pillBg = scheme.onSurface.withValues(alpha: 0.10);
      weight = FontWeight.w700;
    } else {
      final m = cell.multiplier;
      if (m == 4) {
        label = '4×';
        fg = Colors.red.shade900;
        pillBg = Colors.red.shade100;
        weight = FontWeight.w900;
      } else if (m == 2) {
        label = '2×';
        fg = Colors.red.shade600;
      } else if (m == 0.5) {
        label = '½';
        fg = Colors.blue.shade600;
      } else if (m == 0.25) {
        label = '¼';
        fg = Colors.blue.shade900;
        pillBg = Colors.blue.shade100;
        weight = FontWeight.w900;
      } else {
        label = '';
        fg = scheme.onSurface;
      }
    }
    final text = Text(
      label,
      style: TextStyle(fontSize: 13, fontWeight: weight, color: fg, height: 1.0),
    );
    return Container(
      height: 22,
      alignment: Alignment.center,
      child: pillBg == null
          ? text
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: text,
            ),
    );
  }

}
