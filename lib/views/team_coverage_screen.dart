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
  /// Opponent slots — dynamically grown via the "+ 상대 추가" button,
  /// capped at [maxTeamSize]. Cleared on full reset and never saved
  /// as part of a party (opponents are situational scratch data).
  static final List<_TeamSlot> opponents = <_TeamSlot>[];
  /// Name of the saved party most recently loaded into [team]. Used
  /// by `_saveAsParty` to default the save dialog name and to detect
  /// the overwrite case. Cleared on full reset.
  static String? loadedPartyName;
  /// Lineup-mode toggle ("선출 보기"). When true, the matrix dims
  /// every column and the summary collapses to 0/0; tapping a
  /// header pokemon name toggles its slot index in [lineup], which
  /// brings that column back to full opacity and adds it to the
  /// summary count.
  static bool lineupMode = false;
  /// Slot indices (within [team]) currently included in the lineup —
  /// opponent columns are never lineup-eligible. Cleared on full
  /// reset.
  static final Set<int> lineup = <int>{};
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
        if (e.value.descriptionOnly) continue;
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

  void _applyPokemonToSlot(_TeamSlot slot, Pokemon p) {
    slot.pokemon = p;

    // Seed ability from curated Champions Singles data; fall back
    // to the species' first listed ability. Pass through
    // expandAbilityKey so stateful ability bases ("Supreme
    // Overlord", "Rivalry") map to their concrete dex variants.
    final curatedAbilities = championsUsageFor(p.name)?.abilities;
    String? pickedAbility;
    if (curatedAbilities != null && curatedAbilities.isNotEmpty) {
      final first = curatedAbilities.first.name;
      if (p.abilities.contains(first)) pickedAbility = first;
    }
    pickedAbility ??= p.abilities.isNotEmpty ? p.abilities.first : null;
    slot.ability = BattlePokemonState.expandAbilityKey(pickedAbility);

    // Seed item: required-item mons (mega forms) pin to that; base
    // forms get the curated top non-megastone item so dropping a
    // pokemon in doesn't silently mega-evolve.
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
    slot.heldItem = pickedItem;

    // Move slots stay empty on species change. Type overrides too.
    for (int i = 0; i < slot.moves.length; i++) {
      slot.moves[i] = null;
    }
    slot.typeOverride = null;
  }

  void _setPokemon(_TeamSlot slot, Pokemon p) {
    setState(() => _applyPokemonToSlot(slot, p));
  }

  void _setTypeOverride(
    _TeamSlot slot,
    ({PokemonType type1, PokemonType? type2, PokemonType? type3})? override,
  ) {
    setState(() => slot.typeOverride = override);
  }

  void _setMove(_TeamSlot slot, int moveIndex, Move? move) {
    setState(() => slot.moves[moveIndex] = move);
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
      _TeamCoverageStore.opponents.clear();
      _TeamCoverageStore.loadedPartyName = null;
      _TeamCoverageStore.lineup.clear();
      _TeamCoverageStore.lineupMode = false;
    });
  }

  void _toggleLineupMode() {
    setState(() {
      _TeamCoverageStore.lineupMode = !_TeamCoverageStore.lineupMode;
      if (!_TeamCoverageStore.lineupMode) {
        // Leaving the mode wipes the picked subset so re-entering
        // starts from "nothing selected" (matches the user's
        // mental model: 선출 보기 ON = empty canvas).
        _TeamCoverageStore.lineup.clear();
      }
    });
  }

  void _toggleLineupSlot(int index) {
    setState(() {
      if (_TeamCoverageStore.lineup.contains(index)) {
        _TeamCoverageStore.lineup.remove(index);
      } else {
        _TeamCoverageStore.lineup.add(index);
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

  Widget _matrixSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _opponentSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Text(
            AppStrings.t('team.opponent'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(
            '${_TeamCoverageStore.opponents.length} / $_maxTeamSize',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Expanded(child: Divider(indent: 8, color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _addOpponentButton() {
    final canAdd = _TeamCoverageStore.opponents.length < _maxTeamSize;
    return Center(
      child: TextButton.icon(
        onPressed: canAdd ? _addOpponent : null,
        icon: const Icon(Icons.add, size: 18),
        label: Text(AppStrings.t('team.opponent.add')),
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

  /// Reset a fixed-size slot (my party) back to empty in place.
  /// Used by the X button on my-party slot cards.
  void _clearMySlot(int index) {
    setState(() {
      _team[index] = _TeamSlot();
    });
  }

  /// Drop an opponent slot from the dynamic list. Used by the X
  /// button on opponent slot cards (different semantics from
  /// _clearMySlot — opp slots aren't fixed-size).
  void _removeOpponent(int index) {
    setState(() => _TeamCoverageStore.opponents.removeAt(index));
  }

  void _addOpponent() {
    if (_TeamCoverageStore.opponents.length >= _maxTeamSize) return;
    setState(() => _TeamCoverageStore.opponents.add(_TeamSlot()));
  }

  void _setAbility(_TeamSlot slot, String ability) {
    setState(() => slot.ability = ability);
  }

  /// Item picker can clear back to "no item", so we accept null.
  void _setItem(_TeamSlot slot, String? item) {
    setState(() => slot.heldItem = item);
  }

  /// Pull a saved sample (from the shared sample storage) and copy
  /// the species + ability + item + moves into [index]. Uses the
  /// same SampleListSheet as the calculator so the load UX (party
  /// folders, expand/collapse, search, rename, move, delete) is
  /// identical across the two screens.
  Future<void> _loadSampleInto(_TeamSlot slot) async {
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
            slot.pokemon = p;
            slot.ability = s.selectedAbility;
            slot.heldItem = s.selectedItem;
            slot.sampleId = sample.id;
            for (int i = 0; i < slot.moves.length; i++) {
              slot.moves[i] = i < s.moves.length ? s.moves[i] : null;
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
      builder: (_, showOff, __) {
        Widget slotCard(
          _TeamSlot slot, {
          required int displayIndex,
          required Key key,
          required VoidCallback onClearOrRemove,
        }) =>
            RepaintBoundary(
              child: _SlotCard(
                key: key,
                index: displayIndex,
                slot: slot,
                abilityDex: _abilityDex ?? const {},
                abilityNames: _abilityNames ?? const {},
                itemDex: _itemDex ?? const {},
                itemNames: _itemNames ?? const {},
                onPokemonSelected: (p) => _setPokemon(slot, p),
                onAbilitySelected: (a) => _setAbility(slot, a),
                onItemSelected: (it) => _setItem(slot, it),
                onLoadSample: () => _loadSampleInto(slot),
                onClear: onClearOrRemove,
                showMoves: showOff,
                onMoveChanged: (mi, m) => _setMove(slot, mi, m),
                onTypeOverrideChanged: (override) =>
                    _setTypeOverride(slot, override),
              ),
            );

        final opps = _TeamCoverageStore.opponents;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── My party (fixed 6 slots)
            for (int i = 0; i < _maxTeamSize; i++) ...[
              slotCard(
                _team[i],
                displayIndex: i,
                key: ValueKey('team_slot_card_$i'),
                onClearOrRemove: () => _clearMySlot(i),
              ),
              if (i < _maxTeamSize - 1) const SizedBox(height: 4),
            ],
            // ─── Opponent party (dynamic, opt-in via "+ 추가")
            const SizedBox(height: 12),
            _opponentSectionHeader(),
            const SizedBox(height: 4),
            for (int i = 0; i < opps.length; i++) ...[
              slotCard(
                opps[i],
                displayIndex: i,
                key: ValueKey('opp_slot_card_${opps[i].hashCode}'),
                onClearOrRemove: () => _removeOpponent(i),
              ),
              if (i < opps.length - 1) const SizedBox(height: 4),
            ],
            const SizedBox(height: 4),
            _addOpponentButton(),
          ],
        );
      },
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
              // Numeric/symbolic + 선출 toggles move to the top bar
              // on wide layouts; narrow keeps both here as a single
              // row above the matrix.
              if (!isWide) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _LineupSwitch(
                      value: _TeamCoverageStore.lineupMode,
                      onToggle: _toggleLineupMode,
                    ),
                    const SizedBox(width: 8),
                    _DisplayModeToggle(mode: mode),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (showOff) _matrixSectionHeader(
                  AppStrings.t('team.matrix.defensive')),
              RepaintBoundary(
                child: _CoverageMatrix(
                  team: _team,
                  opponents: _TeamCoverageStore.opponents,
                  abilityNames: _abilityNames ?? const {},
                  symbolic: symbolic,
                  offensive: false,
                  horizontalNames: isWide,
                  lineupMode: _TeamCoverageStore.lineupMode,
                  lineup: _TeamCoverageStore.lineup,
                  onLineupToggle: _toggleLineupSlot,
                ),
              ),
              if (showOff) ...[
                const SizedBox(height: 16),
                _matrixSectionHeader(
                    AppStrings.t('team.matrix.showOffensive')),
                RepaintBoundary(
                  child: _CoverageMatrix(
                    team: _team,
                    opponents: _TeamCoverageStore.opponents,
                    abilityNames: _abilityNames ?? const {},
                    symbolic: symbolic,
                    offensive: true,
                    horizontalNames: isWide,
                    lineupMode: _TeamCoverageStore.lineupMode,
                    lineup: _TeamCoverageStore.lineup,
                    onLineupToggle: _toggleLineupSlot,
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
    // of the body. On wide layouts there's room next to it for the
    // numeric/symbolic toggle as well — pulling that out of the
    // matrix block saves a row inside the table area.
    final topToggleBar = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: CoverageDisplayController.instance.showOffensive,
            builder: (_, showOff, __) => _OffensiveSwitch(value: showOff),
          ),
          if (isWide)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LineupSwitch(
                  value: _TeamCoverageStore.lineupMode,
                  onToggle: _toggleLineupMode,
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<CoverageDisplayMode>(
                  valueListenable: CoverageDisplayController.instance.mode,
                  builder: (_, mode, __) => _DisplayModeToggle(mode: mode),
                ),
              ],
            ),
        ],
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
                  topToggleBar,
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
                  topToggleBar,
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
                  child: PokemonSelector(
                    key: ValueKey(
                        'team_slot_${widget.index}_${p?.name ?? "empty"}'),
                    initialPokemonName: p?.name,
                    onSelected: widget.onPokemonSelected,
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
  /// Opponent slots — same data shape as [team]; rendered as
  /// additional columns on the right of the my-party block,
  /// separated by a thicker vertical divider. Summary still counts
  /// only [team] (lineup applies only to my pokemon).
  final List<_TeamSlot> opponents;
  final Map<String, String> abilityNames;
  /// `true` → render multipliers as the standard Pokemon-game symbol
  /// set (◎ / ○ / △ / ▲ / ✕). `false` → numeric ("4×", "½", …).
  /// The decisive-tier pill background is shown in both modes.
  final bool symbolic;
  /// `true` → show the offensive matrix (best damage multiplier each
  /// pokemon's moves can deal vs each defender type). `false` →
  /// defensive matrix (current default).
  final bool offensive;
  /// `true` → render header pokemon names horizontally (wide-screen
  /// layout where the column width is generous enough to fit the
  /// name on one line). Saves the ~60 px the vertical-stack layout
  /// reserves for narrow phones.
  final bool horizontalNames;
  /// Lineup mode + selected indices. When [lineupMode] is true, the
  /// summary collapses to only the selected slots and unselected
  /// columns dim out. Tapping a header name fires [onLineupToggle]
  /// to flip that slot's selection.
  final bool lineupMode;
  final Set<int> lineup;
  final ValueChanged<int> onLineupToggle;

  const _CoverageMatrix({
    required this.team,
    required this.opponents,
    required this.abilityNames,
    required this.lineupMode,
    required this.lineup,
    required this.onLineupToggle,
    this.symbolic = false,
    this.offensive = false,
    this.horizontalNames = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Build per-slot cell rows for both my party and the opponent
    // party. Same logic for both — opp pokemon defend / attack the
    // exact same way as mine.
    final myDisplay = _buildDisplayMatrix(team);
    final oppDisplay = _buildDisplayMatrix(opponents);

    // Summary counts only my slots (opponents are info-only). Lineup
    // further narrows to the picked subset; empty pick → 0/0.
    final summarySource = <List<CoverageCell>>[
      for (int i = 0; i < team.length; i++)
        if (myDisplay[i] != null &&
            (!lineupMode || lineup.contains(i))) myDisplay[i]!,
    ];
    final summary = summarize(summarySource);

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
        // Opponent rows BEFORE the type rows. Each row's cell shows
        // the BEST multiplier between that opp and a my-pokemon
        // column — for the defensive matrix, that's the opp's best
        // attacking move vs my mon; for the offensive matrix, my
        // mon's best attacking move vs the opp.
        for (int oi = 0; oi < opponents.length; oi++)
          if (opponents[oi].pokemon != null)
            _opponentRow(opponents[oi], scheme),
        for (int t = 0; t < teamCoverageAttackTypes.length; t++)
          _typeRow(t, myDisplay, summary[t], scheme),
      ],
    );
  }

  /// Build a [slots.length] × 18 grid of [CoverageCell]s. Empty
  /// slots stay as `null` rows so the renderer can paint blanks.
  /// Used for both my party and opponents — same shape, same logic.
  List<List<CoverageCell>?> _buildDisplayMatrix(List<_TeamSlot> slots) {
    final filled = <CoverageSlot>[];
    final filledIdx = <int>[];
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final p = slot.pokemon;
      if (p == null) continue;
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
      filled.add(CoverageSlot(
        type1: t1,
        type2: t2,
        type3: t3,
        ability: slot.ability,
        heldItem: slot.heldItem,
        moves: coverageMoves,
      ));
      filledIdx.add(i);
    }
    final matrix = offensive
        ? offensiveCoverageMatrix(filled)
        : defensiveCoverageMatrix(filled);
    final display = List<List<CoverageCell>?>.filled(slots.length, null);
    for (int j = 0; j < filledIdx.length; j++) {
      display[filledIdx[j]] = matrix[j];
    }
    return display;
  }

  TableRow _headerRow(ColorScheme scheme) {
    return TableRow(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      children: [
        const SizedBox.shrink(),
        for (int i = 0; i < team.length; i++)
          team[i].pokemon != null
              ? _wrapNameForLineup(
                  i,
                  _nameCell(
                    team[i].pokemon!.localizedName,
                    type1: team[i].effectiveType1,
                    type2: team[i].effectiveType2,
                  ),
                )
              : SizedBox(height: horizontalNames ? 28 : 84),
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

  /// Pokemon-name header cell. On wide layouts the column is roomy
  /// enough to render the name horizontally on a single line (saves
  /// ~60 px of header height). On narrow layouts the column is too
  /// tight; we stack each character of a Korean / Japanese name
  /// (킬 / 가 / 르 / 도) or rotate an English name 90°.
  ///
  /// A faded type-color tint sits behind the name — single type =
  /// flat, dual type split: left/right for horizontal layouts, top/
  /// bottom for vertical layouts (each matching the reading flow).
  Widget _nameCell(
    String rawName, {
    required PokemonType? type1,
    required PokemonType? type2,
  }) {
    final lang = AppStrings.current;
    // Strip parenthesized form/variant suffixes for the matrix header
    // only — "킬가르도 (블레이드폼)" → "킬가르도", "오거폰 (우물의가면)"
    // → "오거폰". The slot card still shows the full name; it's only
    // here, where vertical space is tight and column reading speed
    // matters, that the parens get in the way.
    final parenIdx = rawName.indexOf('(');
    final name = parenIdx > 0 ? rawName.substring(0, parenIdx).trim() : rawName;
    if (horizontalNames) {
      // Try horizontal first; fall back to the vertical layout per
      // cell when the column is too narrow for the name. Mixed
      // layouts within one header row are fine — Table sizes the row
      // to its tallest cell, so as soon as one name needs the
      // vertical fallback the row goes back to 84 px. The user's
      // win is "horizontal whenever it fits", not "always
      // horizontal".
      return LayoutBuilder(builder: (context, constraints) {
        const style = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
        final tp = TextPainter(
          text: TextSpan(text: name, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final fits = tp.width <= constraints.maxWidth - 8;
        if (fits) {
          return SizedBox(
            height: 28,
            child: DecoratedBox(
              decoration: _horizontalNameTint(type1, type2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(name, maxLines: 1, style: style),
                ),
              ),
            ),
          );
        }
        return _verticalNameLayout(name, type1, type2, lang);
      });
    }
    return _verticalNameLayout(name, type1, type2, lang);
  }

  /// Vertical layout extracted so the horizontal-fits-or-fallback
  /// path can reuse it without code duplication.
  Widget _verticalNameLayout(
    String name,
    PokemonType? type1,
    PokemonType? type2,
    AppLanguage lang,
  ) {
    final Widget content;
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
      content = Center(
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
      );
    } else {
      content = Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return SizedBox(
      height: 84,
      child: DecoratedBox(
        decoration: _vertNameTint(type1, type2),
        child: content,
      ),
    );
  }

  /// Faded type-color background for the vertical name cell. Single
  /// type → flat 20% tint; dual type → top half [t1] / bottom half
  /// [t2] hard-stop gradient. Returns an empty decoration when no
  /// types are passed.
  static const double _vertTintAlpha = 0.20;
  BoxDecoration _vertNameTint(PokemonType? t1, PokemonType? t2) {
    if (t1 == null) return const BoxDecoration();
    final c1 = KoStrings.getTypeColor(t1).withValues(alpha: _vertTintAlpha);
    if (t2 == null) {
      return BoxDecoration(color: c1);
    }
    final c2 = KoStrings.getTypeColor(t2).withValues(alpha: _vertTintAlpha);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c1, c1, c2, c2],
        stops: const [0.0, 0.5, 0.5, 1.0],
      ),
    );
  }

  /// Horizontal version — dual type splits left/right since the name
  /// reads left-to-right.
  BoxDecoration _horizontalNameTint(PokemonType? t1, PokemonType? t2) {
    if (t1 == null) return const BoxDecoration();
    final c1 = KoStrings.getTypeColor(t1).withValues(alpha: _vertTintAlpha);
    if (t2 == null) return BoxDecoration(color: c1);
    final c2 = KoStrings.getTypeColor(t2).withValues(alpha: _vertTintAlpha);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [c1, c1, c2, c2],
        stops: const [0.0, 0.5, 0.5, 1.0],
      ),
    );
  }

  TableRow _typeRow(
      int t,
      List<List<CoverageCell>?> myMatrix,
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
          myMatrix[p] == null
              ? const SizedBox(height: 28)
              : _wrapCellForLineup(p, _multCell(myMatrix[p]![t], scheme)),
        _summaryCell(summary, scheme),
      ],
    );
  }

  /// Solid colored chip — same style as the team-builder slot's type
  /// chips and the attacker/defender panel badges. The chip fills the
  /// fixed-width type column edge-to-edge; the 3-char Korean name sits
  /// centered with the colored bg picking up any slack.
  /// Wrap a header name cell with InkWell so tapping toggles the
  /// slot in the lineup; outside lineup mode it's a passthrough.
  /// Selected lineup picks render at full opacity, the rest dim.
  Widget _wrapNameForLineup(int slotIdx, Widget child) {
    if (!lineupMode) return child;
    final selected = lineup.contains(slotIdx);
    final wrapped = Opacity(
      opacity: selected ? 1.0 : 0.30,
      child: child,
    );
    return InkWell(
      onTap: () => onLineupToggle(slotIdx),
      child: wrapped,
    );
  }

  /// Same dim treatment for the data cells in a column.
  /// One opponent row, shown above the type rows. Column 0 holds
  /// the opp's name (clipped to fit the 48 px label column), each
  /// my-pokemon column holds the best matchup multiplier for that
  /// (opp, my) pair, and the summary column is left blank — opp
  /// rows aren't part of the weak/resist count.
  TableRow _opponentRow(_TeamSlot opp, ColorScheme scheme) {
    final p = opp.pokemon!;
    return TableRow(
      // Subtle red tint so the opponent block reads as distinct
      // from the type rows below; same kind of visual cue we use
      // for the attacker/defender accent in the calc.
      decoration: BoxDecoration(
        color: Colors.red.shade50.withValues(alpha: 0.6),
      ),
      children: [
        // Opp name in the type-label column. Clip horizontally so a
        // long name like "한카리아스" reads as "한카…" — the user
        // already approved this trade-off.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text(
            p.localizedName,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        // Per-my-pokemon cells with the best matchup multiplier.
        for (int mi = 0; mi < team.length; mi++)
          team[mi].pokemon == null
              ? const SizedBox(height: 28)
              : _wrapCellForLineup(
                  mi,
                  _multCell(
                    _opponentMatchCell(opp, team[mi]),
                    scheme,
                  ),
                ),
        // Summary column intentionally blank for opp rows.
        const SizedBox.shrink(),
      ],
    );
  }

  /// Compute the best-effectiveness CoverageCell for the (opp, my)
  /// pair — direction depends on [offensive]:
  ///   - defensive matrix: opp attacks my pokemon. Take max over
  ///     opp's damaging moves of `coverageOf(moveType, my slot)`.
  ///   - offensive matrix: my pokemon attacks opp. Take max over
  ///     my pokemon's damaging moves of `coverageOf(moveType, opp
  ///     slot)`.
  /// In both directions empty / all-immune move sets collapse to
  /// 0× (rendered as 무 / ✕).
  CoverageCell _opponentMatchCell(_TeamSlot opp, _TeamSlot mySlot) {
    final attacker = offensive ? mySlot : opp;
    final defender = offensive ? opp : mySlot;
    final attackerP = attacker.pokemon;
    final defenderP = defender.pokemon;
    if (attackerP == null || defenderP == null) {
      return const CoverageCell(0, immunityReason: 'noMoves');
    }
    final defenderSlot = CoverageSlot(
      type1: defender.effectiveType1 ?? defenderP.type1,
      type2: defender.effectiveType2,
      type3: defender.effectiveType3,
      ability: defender.ability,
      heldItem: defender.heldItem,
    );
    final t1 = attacker.effectiveType1 ?? attackerP.type1;
    final coverageMoves = <CoverageMove>[
      for (final m in attacker.moves)
        if (m != null)
          coverageMoveFromMove(
            m,
            ability: attacker.ability,
            heldItem: attacker.heldItem,
            userType1: t1,
            pokemonName: attackerP.name,
          ),
    ];
    final damaging = coverageMoves.where((m) => m.isDamaging).toList();
    if (damaging.isEmpty) {
      return const CoverageCell(0, immunityReason: 'noMoves');
    }
    double best = 0;
    for (final m in damaging) {
      final cell = coverageOf(m.type, defenderSlot);
      if (cell.multiplier > best) best = cell.multiplier;
    }
    if (best == 0) {
      return const CoverageCell(0, immunityReason: 'allImmune');
    }
    return CoverageCell(best);
  }

  Widget _wrapCellForLineup(int slotIdx, Widget child) {
    if (!lineupMode) return child;
    final selected = lineup.contains(slotIdx);
    return Opacity(
      opacity: selected ? 1.0 : 0.30,
      child: child,
    );
  }

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

/// "선출 보기" switch — same shape as [_OffensiveSwitch] but tied
/// to the lineup-mode flag in [_TeamCoverageStore]. Toggles the
/// dim-everything / tap-name-to-add behavior in the matrix.
class _LineupSwitch extends StatelessWidget {
  final bool value;
  final VoidCallback onToggle;
  const _LineupSwitch({required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.t('team.matrix.lineup'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 24,
              child: Switch.adaptive(
                value: value,
                onChanged: (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
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
