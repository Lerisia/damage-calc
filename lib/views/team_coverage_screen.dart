import 'package:flutter/material.dart';
import '../data/abilitydex.dart';
import '../data/champions_usage.dart';
import '../data/itemdex.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../data/sample_storage.dart';
import '../models/ability.dart';
import '../models/battle_pokemon.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../models/type.dart';
import '../utils/app_strings.dart';
import '../utils/coverage_display_controller.dart';
import '../utils/korean_search.dart';
import '../utils/localization.dart';
import '../utils/team_coverage.dart';
import 'widgets/move_selector.dart';
import 'widgets/pokemon_selector.dart';
import 'widgets/sample_list_sheet.dart';
import 'widgets/type_picker_dialog.dart';
import 'widgets/typeahead_helpers.dart';

/// One slot in the team-builder. We keep just the bits that affect
/// type matchups — full BattlePokemonState is overkill here and would
/// drag along EV/level/move state nobody fills out.
class _TeamSlot {
  Pokemon? pokemon;
  String? ability;
  String? heldItem; // currently only used to honour Air Balloon / Iron Ball
  /// Up to 4 moves used for the offensive coverage matrix. Indexes
  /// are stable; null entries render as empty pickers in the UI.
  /// State-dependent moves (Tera Blast, Ivy Cudgel, …) resolve via
  /// [coverageMoveFromMove] when the matrix is built.
  final List<Move?> moves = List<Move?>.filled(4, null, growable: false);
  /// Source sample id when this slot was hydrated from a saved
  /// sample (via party load or single-slot load). Used by
  /// `_saveAsParty` to update existing samples in place on overwrite
  /// — so a custom rename like "한카리아스 (특수형)" survives a
  /// re-save when the species hasn't changed. Stays set across
  /// ability / item / move edits (the binding is to the saved
  /// sample, not to its current data).
  String? sampleId;
  /// User-applied type override (Soak / Forest's Curse / Burn Up /
  /// 3-type combos). `null` means "use the species' natural types";
  /// when non-null, all three slots are explicit (type2/type3 may
  /// still be null individually to mean "no second/third type").
  ({PokemonType type1, PokemonType? type2, PokemonType? type3})? typeOverride;

  /// Effective type1 — override wins, else species natural type1.
  PokemonType? get effectiveType1 =>
      typeOverride?.type1 ?? pokemon?.type1;

  /// Effective type2 — explicitly null when override sets it null.
  PokemonType? get effectiveType2 =>
      typeOverride != null ? typeOverride!.type2 : pokemon?.type2;

  /// Effective type3 — only ever set via override (Forest's Curse).
  PokemonType? get effectiveType3 => typeOverride?.type3;
}

/// Process-lifetime team state — survives navigating away from the
/// screen so the user doesn't lose their picks the moment they pop
/// back to the calculator. Cleared only on app restart. (Persistent
/// disk storage will hook into the existing sample save/load slot.)
class _TeamCoverageStore {
  static const int maxTeamSize = 6;
  static final List<_TeamSlot> team =
      List.generate(maxTeamSize, (_) => _TeamSlot());
  /// Name of the saved party most recently loaded into [team]. Used
  /// by `_saveAsParty` to default the save dialog name and to detect
  /// the overwrite case. Cleared on full reset.
  static String? loadedPartyName;
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
  // English-name → Move map. Used by _setPokemon to materialize the
  // curated default-moves list, and by _loadParty / _loadSampleInto
  // to rehydrate moves stored on saved samples (which only persist
  // the move name).
  static Map<String, Move>? _movesByName;

  @override
  void initState() {
    super.initState();
    _loadDexes();
  }

  Future<void> _loadDexes() async {
    if (_abilityDex != null && _itemDex != null && _movesByName != null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final aDex = await loadAbilitydex();
      final iDex = await loadItemdex();
      final allMoves = await loadAllMoves();
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
      _movesByName = {for (final m in allMoves) m.name: m};
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

      // Move slots stay empty on species change. Auto-loading from
      // Champions usage defaultMoves overstates the offensive matrix
      // — that data lists damage moves only, so a real-party 3-attack
      // + 1-status build would render as if it had a 4th coverage
      // move. Better to require an explicit pick than to mislead.
      for (int i = 0; i < _team[index].moves.length; i++) {
        _team[index].moves[i] = null;
      }
      // Type overrides were tied to the old species; drop them so
      // the new pokemon's natural types take over.
      _team[index].typeOverride = null;
    });
  }

  void _setTypeOverride(
    int index,
    ({PokemonType type1, PokemonType? type2, PokemonType? type3})? override,
  ) {
    setState(() => _team[index].typeOverride = override);
  }

  void _setMove(int slotIndex, int moveIndex, Move? move) {
    setState(() => _team[slotIndex].moves[moveIndex] = move);
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
      // No tracked party once everything's empty.
      _TeamCoverageStore.loadedPartyName = null;
    });
  }

  // Shared style for the AppBar action buttons — compact density and
  // tight padding so the three buttons fit alongside the back arrow on
  // a phone-width screen.
  static final ButtonStyle _appBarBtnStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    visualDensity: VisualDensity.compact,
  );

  Widget _matrixSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Show the saved-party picker and replace the 6 slots with the
  /// chosen team's members. Slots beyond the team's member count are
  /// cleared. Confirmation is asked only when at least one slot is
  /// already filled, so first-time use is a single-tap flow.
  Future<void> _loadParty() async {
    final initial = await SampleStorage.loadStore();
    if (!mounted) return;
    if (initial.teams.where((t) => t.memberIds.isNotEmpty).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.load.noTeams')),
      ));
      return;
    }
    final pickedId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => const _PartyPickerSheet(),
    );
    if (pickedId == null || !mounted) return;
    // Re-read store post-sheet so a delete inside the picker doesn't
    // make us look up a sample id that's gone.
    final store = await SampleStorage.loadStore();
    if (!mounted) return;

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
          final newSlot = _TeamSlot()
            ..pokemon = p
            ..ability = s.state.selectedAbility
            ..heldItem = s.state.selectedItem
            ..sampleId = s.id;
          for (int mi = 0; mi < newSlot.moves.length; mi++) {
            newSlot.moves[mi] =
                mi < s.state.moves.length ? s.state.moves[mi] : null;
          }
          _team[i] = newSlot;
        } else {
          _team[i] = _TeamSlot();
        }
      }
      // Remember the loaded party so the next save defaults its name
      // and trips the overwrite-confirm flow when the user keeps it.
      _TeamCoverageStore.loadedPartyName = team.name;
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

    // Default name: most-recently-loaded party (so re-saving with no
    // edits triggers the natural overwrite path). Falls back to
    // "파티 N" using the next number for first-time saves.
    final defaultName = _TeamCoverageStore.loadedPartyName ??
        '파티 ${store.teams.length + 1}';
    final teamName = await _promptText(
      title: AppStrings.t('team.save.title'),
      initial: defaultName,
    );
    if (teamName == null || teamName.isEmpty || !mounted) return;

    // Overwrite check: if any existing party shares the name, confirm
    // before mutating. The actual save logic below decides per-slot
    // whether to update an existing sample in place (same species
    // → preserve user-customized name) or to recreate it.
    final existingParty = store.teams
        .where((t) => t.name == teamName)
        .firstOrNull;
    if (existingParty != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.t('team.save.overwrite.title')),
          content: Text(AppStrings.t('team.save.overwrite.body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t('action.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.t('action.overwrite')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    // Names need to stay globally unique. For collision-checking we
    // ignore samples currently inside the party being overwritten —
    // those will either be kept (no rename), renamed (the old name
    // disappears anyway), or detached/deleted by the end.
    final reservedNames = store.samples
        .where((s) =>
            existingParty == null ||
            !existingParty.memberIds.contains(s.id))
        .map((s) => s.name)
        .toSet();
    String uniqueName(String base) {
      final withParty = '$base ($teamName)';
      if (!reservedNames.contains(withParty)) return withParty;
      for (int i = 2;; i++) {
        final candidate = '$withParty ($i)';
        if (!reservedNames.contains(candidate)) return candidate;
      }
    }

    BattlePokemonState buildState(_TeamSlot slot) {
      final state = BattlePokemonState();
      state.applyPokemon(slot.pokemon!);
      if (slot.ability != null) state.selectedAbility = slot.ability!;
      if (slot.heldItem != null) state.selectedItem = slot.heldItem;
      for (int mi = 0;
          mi < state.moves.length && mi < slot.moves.length;
          mi++) {
        if (slot.moves[mi] != null) state.moves[mi] = slot.moves[mi];
      }
      return state;
    }

    int saved = 0;
    if (existingParty != null) {
      // ── Overwrite path: update samples bound to slots in place
      // (preserving id + custom name when species matches), create
      // new samples for slots without a binding to this party, and
      // detach samples the user removed from the party.
      final memberIds = Set<String>.from(existingParty.memberIds);
      final keptIds = <String>{};
      // Two passes: first updates (no rename) so their existing names
      // stay in `reservedNames` as-is; renames + creates next so the
      // unique-name search avoids them.
      final firstPass = <_TeamSlot>[];
      final secondPass = <_TeamSlot>[];
      for (final slot in filled) {
        final sid = slot.sampleId;
        if (sid != null && memberIds.contains(sid)) {
          firstPass.add(slot);
        } else {
          secondPass.add(slot);
        }
      }
      for (final slot in firstPass) {
        final sid = slot.sampleId!;
        final existing = store.sampleById(sid);
        if (existing == null) {
          secondPass.add(slot);
          continue;
        }
        final state = buildState(slot);
        final speciesChanged =
            existing.state.pokemonName != slot.pokemon!.name;
        if (speciesChanged) {
          // Species swap → recompute name; the old name was tied to
          // a different species and would be misleading to keep.
          final newName = uniqueName(slot.pokemon!.localizedName);
          reservedNames.add(newName);
          await SampleStorage.updatePokemon(sid,
              name: newName, state: state);
        } else {
          // Same species → preserve the existing (possibly user-
          // customized) name. Only the state changes.
          await SampleStorage.updatePokemon(sid, state: state);
        }
        keptIds.add(sid);
        saved++;
      }
      for (final slot in secondPass) {
        final state = buildState(slot);
        final name = uniqueName(slot.pokemon!.localizedName);
        reservedNames.add(name);
        try {
          final newId = await SampleStorage.savePokemon(
              name: name, state: state, teamId: existingParty.id);
          slot.sampleId = newId;
          keptIds.add(newId);
          saved++;
        } on TeamFullException {
          break;
        }
      }
      // Drop samples the user removed from the party. Cascade-style
      // delete (matches the user's intent of "this is the new state
      // of the party").
      for (final mid in existingParty.memberIds) {
        if (!keptIds.contains(mid)) {
          await SampleStorage.deletePokemon(mid);
        }
      }
    } else {
      // ── Fresh-save path: brand-new party, every slot gets a new
      // sample with the standard "species (party)" name.
      final newPartyId = await SampleStorage.createTeam(teamName);
      for (final slot in filled) {
        final state = buildState(slot);
        final name = uniqueName(slot.pokemon!.localizedName);
        reservedNames.add(name);
        try {
          final newId = await SampleStorage.savePokemon(
              name: name, state: state, teamId: newPartyId);
          slot.sampleId = newId;
          saved++;
        } on TeamFullException {
          break;
        }
      }
    }

    if (!mounted) return;
    _TeamCoverageStore.loadedPartyName = teamName;
    setState(() {});
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

  /// Pull a saved sample (from the shared sample storage) and copy
  /// the species + ability + item + moves into [index]. Uses the
  /// same SampleListSheet as the calculator so the load UX (party
  /// folders, expand/collapse, search, rename, move, delete) is
  /// identical across the two screens.
  Future<void> _loadSampleInto(int index) async {
    final pokedex = await loadPokedex();
    if (!mounted) return;
    final byName = {for (final p in pokedex) p.name: p};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SampleListSheet(
        itemNameMap: _itemNames ?? const {},
        onLoad: (sample) {
          final s = sample.state;
          final p = byName[s.pokemonName];
          if (p == null) {
            Navigator.pop(ctx);
            return;
          }
          setState(() {
            _team[index].pokemon = p;
            _team[index].ability = s.selectedAbility;
            _team[index].heldItem = s.selectedItem;
            _team[index].sampleId = sample.id;
            for (int i = 0; i < _team[index].moves.length; i++) {
              _team[index].moves[i] = i < s.moves.length ? s.moves[i] : null;
            }
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wide layout splits into two columns: slot list on the left,
    // matrix on the right. Threshold matches the calculator's wide
    // breakpoint feel.
    final isWide = MediaQuery.of(context).size.width >= 900;

    // Slot list reacts to the offensive toggle so the move-picker
    // row appears/disappears in lockstep with the offensive matrix
    // below.
    final slotList = ValueListenableBuilder<bool>(
      valueListenable: CoverageDisplayController.instance.showOffensive,
      builder: (_, showOff, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _maxTeamSize; i++) ...[
            _SlotCard(
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
              showMoves: showOff,
              onMoveChanged: (mi, m) => _setMove(i, mi, m),
              onTypeOverrideChanged: (override) =>
                  _setTypeOverride(i, override),
            ),
            if (i < _maxTeamSize - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );

    // Matrix block reacts to BOTH the display mode (numeric/symbol)
    // and the offensive toggle. When offensive is on, the defensive
    // matrix gets a section header and the offensive matrix follows
    // below — single column on phones, side-by-side on very wide
    // screens (handled at the body level in phase 3).
    final matrix = ValueListenableBuilder<CoverageDisplayMode>(
      valueListenable: CoverageDisplayController.instance.mode,
      builder: (_, mode, __) => ValueListenableBuilder<bool>(
        valueListenable: CoverageDisplayController.instance.showOffensive,
        builder: (_, showOff, __) {
          final symbolic = mode == CoverageDisplayMode.symbolic;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DisplayModeToggle(mode: mode),
              const SizedBox(height: 6),
              if (showOff) _matrixSectionHeader(
                  AppStrings.t('team.matrix.defensive')),
              RepaintBoundary(
                child: _CoverageMatrix(
                  team: _team,
                  abilityNames: _abilityNames ?? const {},
                  symbolic: symbolic,
                  offensive: false,
                ),
              ),
              if (showOff) ...[
                const SizedBox(height: 16),
                _matrixSectionHeader(
                    AppStrings.t('team.matrix.showOffensive')),
                RepaintBoundary(
                  child: _CoverageMatrix(
                    team: _team,
                    abilityNames: _abilityNames ?? const {},
                    symbolic: symbolic,
                    offensive: true,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    // Offensive toggle is a screen-level mode (it expands the slot
    // cards AND adds the second matrix), so it lives at the very top
    // of the body — above both the slot list and the matrix region —
    // instead of being tucked next to the numeric/symbolic toggle.
    final offensiveBar = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: ValueListenableBuilder<bool>(
        valueListenable: CoverageDisplayController.instance.showOffensive,
        builder: (_, showOff, __) => _OffensiveSwitch(value: showOff),
      ),
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
                onPressed:
                    _team.any((s) => s.pokemon != null) ? _saveAsParty : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(AppStrings.t('team.save')),
                style: _appBarBtnStyle,
              ),
              TextButton.icon(
                onPressed: _loadParty,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(AppStrings.t('team.load')),
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
      // Tap on empty space → unfocus the active typeahead so its
      // overlay dismisses. flutter_typeahead's `hideOnUnfocus: true`
      // only fires on real focus changes, not on bare taps, so we
      // route every body tap through FocusManager. Same pattern as
      // dex_screen.
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: isWide
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  offensiveBar,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Slot column narrower than matrix on wide
                        // layouts — slots don't need much room past
                        // their typeahead fields, while the matrix
                        // benefits from every extra px.
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(child: slotList),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(child: matrix),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  offensiveBar,
                  slotList,
                  const SizedBox(height: 20),
                  matrix,
                ],
              ),
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
  /// When true, a 3rd row of 4 move pickers is added so the user can
  /// fill in the moves used for the offensive coverage matrix.
  final bool showMoves;
  final void Function(int moveIndex, Move? move) onMoveChanged;
  /// Tap handler for the type chips — opens the type-picker dialog
  /// and reports the user's pick (or null to clear back to natural).
  final void Function(
      ({PokemonType type1, PokemonType? type2, PokemonType? type3})?
          override) onTypeOverrideChanged;

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
    required this.showMoves,
    required this.onMoveChanged,
    required this.onTypeOverrideChanged,
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
                  child: Container(
                    // Faded type-color tint behind the name field so the
                    // user can spot a slot's typing without scanning over
                    // to the chips. Single type → flat tint, dual type
                    // → 50/50 horizontal split.
                    decoration: p == null ? null : _typeTintDecoration(p),
                    child: PokemonSelector(
                      key: ValueKey(
                          'team_slot_${widget.index}_${p?.name ?? "empty"}'),
                      initialPokemonName: p?.name,
                      onSelected: widget.onPokemonSelected,
                    ),
                  ),
                ),
                if (p != null) ...[
                  const SizedBox(width: 6),
                  // Tap any chip to open the type picker (Soak /
                  // Forest's Curse / Burn Up overrides). Chips show
                  // the EFFECTIVE types, so a Soaked Charizard
                  // displays as Water in the slot card and the
                  // matrix at the same time.
                  InkWell(
                    onTap: () => _openTypePicker(p),
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.slot.effectiveType1 != null)
                          _typeChip(widget.slot.effectiveType1!),
                        if (widget.slot.effectiveType2 != null) ...[
                          const SizedBox(width: 2),
                          _typeChip(widget.slot.effectiveType2!),
                        ],
                        if (widget.slot.effectiveType3 != null) ...[
                          const SizedBox(width: 2),
                          _typeChip(widget.slot.effectiveType3!),
                        ],
                      ],
                    ),
                  ),
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
          // ─── Row 3 (offensive mode only): 4 move pickers in a 2×2
          // grid. Disabled when no pokemon picked. Picking a pokemon
          // wipes the previous slot's moves so stale picks from the
          // last species don't bleed in.
          if (widget.showMoves) ...[
            const SizedBox(height: 4),
            _moveGrid(scheme, p),
          ],
        ],
      ),
    );
  }

  Widget _moveGrid(ColorScheme scheme, Pokemon? p) {
    Widget cell(int i) {
      return Expanded(
        child: SizedBox(
          height: 50,
          child: _moveField(scheme, p, i),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        children: [
          Row(children: [cell(0), const SizedBox(width: 6), cell(1)]),
          const SizedBox(height: 4),
          Row(children: [cell(2), const SizedBox(width: 6), cell(3)]),
        ],
      ),
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
      // Phone-width grid → drop the type/category/power suffix.
      compact: true,
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

  /// Faded type-color background for the name field. Single type =
  /// flat 18% tint; dual type = a hard-stop horizontal gradient so
  /// the split is read as "left-half type1, right-half type2"
  /// instead of a smooth blend (which loses the second type's
  /// identity).
  static const double _typeTintAlpha = 0.18;
  BoxDecoration _typeTintDecoration(Pokemon p) {
    final c1 = KoStrings.getTypeColor(p.type1).withValues(alpha: _typeTintAlpha);
    final t2 = p.type2;
    if (t2 == null) {
      return BoxDecoration(
        color: c1,
        borderRadius: BorderRadius.circular(4),
      );
    }
    final c2 = KoStrings.getTypeColor(t2).withValues(alpha: _typeTintAlpha);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [c1, c1, c2, c2],
        stops: const [0.0, 0.5, 0.5, 1.0],
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
  /// `true` → render multipliers as the standard Pokemon-game symbol
  /// set (◎ / ○ / △ / ▲ / ✕). `false` → numeric ("4×", "½", …).
  /// The decisive-tier pill background is shown in both modes.
  final bool symbolic;
  /// `true` → show the offensive matrix (best damage multiplier each
  /// pokemon's moves can deal vs each defender type). `false` →
  /// defensive matrix (current default).
  final bool offensive;

  const _CoverageMatrix({
    required this.team,
    required this.abilityNames,
    this.symbolic = false,
    this.offensive = false,
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
      // Honor user type overrides (Soak / Forest's Curse / Burn Up
      // …) if applied — both for defensive matchups and as the
      // userType1 fed into Revelation Dance / -ate resolution on
      // the offensive side.
      final t1 = slot.effectiveType1 ?? p.type1;
      final t2 = slot.effectiveType2;
      final t3 = slot.effectiveType3;
      final coverageMoves = offensive
          ? [
              for (final m in slot.moves)
                if (m != null)
                  coverageMoveFromMove(
                    m,
                    ability: slot.ability,
                    heldItem: slot.heldItem,
                    userType1: t1,
                    pokemonName: p.name,
                  ),
            ]
          : const <CoverageMove>[];
      filledCells.add(CoverageSlot(
        type1: t1,
        type2: t2,
        type3: t3,
        ability: slot.ability,
        heldItem: slot.heldItem,
        moves: coverageMoves,
      ));
      filledIndices.add(i);
    }
    final filledMatrix = offensive
        ? offensiveCoverageMatrix(filledCells)
        : defensiveCoverageMatrix(filledCells);
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
      // Vertical separators between pokemon columns are deliberately
      // beefier than the horizontal row dividers — when scanning a
      // type row across 6 mons the eye needs the column boundaries
      // to pop. Horizontals stay thin since the zebra stripes carry
      // most of the row separation.
      border: TableBorder(
        top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        left: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        horizontalInside: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.6),
        verticalInside: BorderSide(
            color: scheme.outlineVariant, width: 1.2),
      ),
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
  Widget _vertNameCell(String rawName) {
    final lang = AppStrings.current;
    // Strip parenthesized form/variant suffixes for the matrix header
    // only — "킬가르도 (블레이드폼)" → "킬가르도", "오거폰 (우물의가면)"
    // → "오거폰". The slot card still shows the full name; it's only
    // here, where vertical space is tight and column reading speed
    // matters, that the parens get in the way.
    final parenIdx = rawName.indexOf('(');
    final name = parenIdx > 0 ? rawName.substring(0, parenIdx).trim() : rawName;
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
      // Zebra stripe with a 4% black overlay on top of zinc-100 so
      // it lands ~9% darker than the surface — louder than the
      // earlier ~5% so the row separation still reads through the
      // beefier vertical gridlines.
      decoration: BoxDecoration(
        color: t.isOdd
            ? Color.alphaBlend(
                scheme.onSurface.withValues(alpha: 0.04),
                scheme.surfaceContainerHighest,
              )
            : null,
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
              ? const SizedBox(height: 28)
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
              fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
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
                  fontSize: 19,
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
                  fontSize: 19,
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
  /// a contained badge, not a full-cell tint. Symbol mode swaps the
  /// glyphs to the standard Pokemon-game set (◎ / ○ / △ / ▲ / ✕)
  /// while keeping the same colors and pills.
  ///   numeric:        symbolic:
  ///   - 4×  "4×"      ◎     — light red pill, dark red text
  ///   - 2×  "2×"      ○     — red text only
  ///   - 1×  (blank)   (blank)
  ///   - ½   "½"       △     — blue text only
  ///   - ¼   "¼"       ▲     — light blue pill, dark blue text
  ///   - 무  "무"      ✕     — light gray pill, gray text
  Widget _multCell(CoverageCell cell, ColorScheme scheme) {
    String label;
    Color fg;
    Color? pillBg;
    FontWeight weight = FontWeight.w800;
    if (cell.isImmune) {
      label = symbolic ? '✕' : AppStrings.t('team.matrix.immune');
      fg = scheme.onSurface.withValues(alpha: 0.55);
      pillBg = scheme.onSurface.withValues(alpha: 0.10);
      weight = FontWeight.w700;
    } else {
      final m = cell.multiplier;
      if (m == 4) {
        label = symbolic ? '◎' : '4×';
        fg = Colors.red.shade900;
        pillBg = Colors.red.shade100;
        weight = FontWeight.w900;
      } else if (m == 2) {
        label = symbolic ? '○' : '2×';
        fg = Colors.red.shade600;
      } else if (m == 0.5) {
        label = symbolic ? '△' : '½';
        fg = Colors.blue.shade600;
      } else if (m == 0.25) {
        label = symbolic ? '▲' : '¼';
        fg = Colors.blue.shade900;
        pillBg = Colors.blue.shade100;
        weight = FontWeight.w900;
      } else {
        label = '';
        fg = scheme.onSurface;
      }
    }
    // Per-label fontSize so the column doesn't read as lopsided.
    // Precomposed fractions (½ ¼) and the symbol-mode glyphs render
    // at sub-digit visual size in most fonts, while digit-glyph
    // labels (4×, 2×) and the localized "immune" CJK label (무) come
    // out full-height. Trim the full-height ones a touch so the row
    // feels balanced. FittedBox(scaleDown) still kicks in for narrow
    // columns regardless.
    final isFullHeight =
        label == '4×' || label == '2×' || label == AppStrings.t('team.matrix.immune');
    final fontSize = isFullHeight ? 15.0 : 17.0;
    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
          fontSize: fontSize, fontWeight: weight, color: fg, height: 1.0),
    );
    return Container(
      height: 28,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: pillBg == null
            ? text
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: text,
              ),
      ),
    );
  }

}

/// Compact two-button toggle that flips the matrix between numeric
/// and symbolic notation. Tied to [CoverageDisplayController] which
/// persists the choice to SharedPreferences (same lifecycle as the
/// language and theme settings).
class _DisplayModeToggle extends StatelessWidget {
  final CoverageDisplayMode mode;
  const _DisplayModeToggle({required this.mode});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modeBtn(
              context,
              label: AppStrings.t('team.matrix.display.numeric'),
              selected: mode == CoverageDisplayMode.numeric,
              target: CoverageDisplayMode.numeric,
            ),
            Container(
              width: 1,
              height: 20,
              color: scheme.outlineVariant,
            ),
            _modeBtn(
              context,
              label: AppStrings.t('team.matrix.display.symbolic'),
              selected: mode == CoverageDisplayMode.symbolic,
              target: CoverageDisplayMode.symbolic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeBtn(BuildContext context, {
    required String label,
    required bool selected,
    required CoverageDisplayMode target,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => CoverageDisplayController.instance.set(target),
      child: Container(
        color: selected
            ? scheme.surfaceContainerHighest
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// Single-line switch row for the offensive-coverage toggle. Right-
/// aligned to sit next to the numeric/symbolic segmented above the
/// matrix; tied to [CoverageDisplayController.showOffensive] which
/// persists the choice across launches.
class _OffensiveSwitch extends StatelessWidget {
  final bool value;
  const _OffensiveSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () =>
            CoverageDisplayController.instance.setShowOffensive(!value),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.t('team.matrix.showOffensive'),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              // shrinkWrap so the switch doesn't blow up the row
              // height on Material defaults.
              SizedBox(
                height: 24,
                child: Switch.adaptive(
                  value: value,
                  onChanged: (v) =>
                      CoverageDisplayController.instance.setShowOffensive(v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet that lists saved parties (with at least one
/// member) and lets the user pick one to load. Each row also has a
/// rename / delete menu so users don't have to bounce out to the
/// sample sheet just to clean up old parties. Returns the picked
/// party id via [Navigator.pop], or null on dismiss.
class _PartyPickerSheet extends StatefulWidget {
  const _PartyPickerSheet();

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  SampleStore _store = const SampleStore();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final store = await SampleStorage.loadStore();
    if (!mounted) return;
    setState(() {
      _store = store;
      _loading = false;
    });
  }

  Future<void> _renameTeam(TeamFolder t) async {
    final controller = TextEditingController(text: t.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('sample.team.namePrompt')),
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
    if (newName == null || newName.isEmpty || newName == t.name) return;
    await SampleStorage.renameTeam(t.id, newName);
    await _refresh();
  }

  Future<void> _deleteTeam(TeamFolder t) async {
    // Same 3-way prompt as SampleListSheet — keep the member samples
    // (move to the loose pool) or cascade-delete them with the party.
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${AppStrings.t('sample.team.delete.title')}: ${t.name}'),
        content: t.memberIds.isEmpty
            ? null
            : Text(AppStrings.t('sample.team.delete.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.cancel')),
          ),
          if (t.memberIds.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cascade'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(AppStrings.t('sample.team.delete.cascade')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: Text(t.memberIds.isEmpty
                ? AppStrings.t('action.confirm')
                : AppStrings.t('sample.team.delete.keep')),
          ),
        ],
      ),
    );
    if (result == null) return;
    await SampleStorage.deleteTeam(t.id, deleteMembers: result == 'cascade');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final candidates = _store.teams
        .where((t) => t.memberIds.isNotEmpty)
        .toList(growable: false);
    return SafeArea(
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
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  AppStrings.t('team.load.noTeams'),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            for (final t in candidates)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(t.name),
                subtitle:
                    Text('${t.memberIds.length} / $kMaxTeamSize'),
                onTap: () => Navigator.pop(context, t.id),
                trailing: PopupMenuButton<String>(
                  tooltip: '',
                  popUpAnimationStyle: AnimationStyle(
                      duration: const Duration(milliseconds: 100)),
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'rename') _renameTeam(t);
                    if (v == 'delete') _deleteTeam(t);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(AppStrings.t('sample.team.rename')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(AppStrings.t('sample.team.delete'),
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
