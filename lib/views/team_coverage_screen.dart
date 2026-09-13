import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import '../models/nature.dart';
import '../models/nature_profile.dart';
import '../models/pokemon.dart';
import '../models/stats.dart';
import '../models/type.dart';
import '../i18n/app_strings.dart';
import '../controllers/calc_handoff.dart';
import '../controllers/champions_filter_controller.dart';
import '../calc/champions_mode.dart';
import '../calc/stat_calculator.dart';
import '../controllers/coverage_display_controller.dart';
import '../search/korean_search.dart';
import '../search/ability_picker.dart';
import '../platform/party_image_save.dart';
import '../controllers/sample_save_flow.dart';
import 'widgets/ev_sp_cell.dart';
import 'widgets/matchup_badge.dart';
import 'widgets/coverage_display_toggle.dart';
import 'widgets/trainer_card_dialog.dart';
import '../i18n/localization.dart';
import '../platform/page_routes.dart';
import '../platform/sprite_pack_manager.dart';
import '../calc/team_coverage.dart';
import 'root_shell.dart';
import 'widgets/app_bottom_nav.dart' show AppNavTab;
import 'widgets/app_settings_menu.dart';
import 'widgets/champions_speed_tier_sheet.dart';
import 'widgets/champions_usage_rank_sheet.dart';
import 'widgets/type_chart_sheet.dart';
import 'widgets/move_selector.dart';
import 'widgets/pokemon_sprite.dart';
import 'widgets/pokemon_selector.dart';
import 'widgets/sample_list_sheet.dart';
import 'widgets/type_picker_dialog.dart';
import 'widgets/typeahead_helpers.dart';
import '../data/ability_variants.dart';
import '../search/item_picker.dart';
import 'widgets/nature_pick_menu.dart';
import 'widgets/type_chip.dart';
import 'widgets/champions_scope_listener.dart';
import '../data/name_maps.dart';

part 'team_coverage/store.dart';
part 'team_coverage/slot_summary_card.dart';
part 'team_coverage/slot_card.dart';
part 'team_coverage/coverage_matrix.dart';
part 'team_coverage/party_picker.dart';

class TeamCoverageScreen extends StatefulWidget {
  const TeamCoverageScreen({super.key});

  @override
  State<TeamCoverageScreen> createState() => _TeamCoverageScreenState();
}

class _TeamCoverageScreenState extends State<TeamCoverageScreen>
    with SingleTickerProviderStateMixin {
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

  /// Tab controller shared between the TabBar/TabBarView and the
  /// camera button — the button reads [_tabController.index] to
  /// route capture to the right widget (party / defense / offense).
  late final TabController _tabController =
      TabController(length: 3, vsync: this)
        ..addListener(() {
          // Rebuild the AppBar so the camera button's enabled/disabled
          // state can react to the active tab (party-empty disables
          // capture on party tab; coverage tabs only care that
          // there's at least one slot to chart against).
          if (mounted) setState(() {});
        });

  @override
  void initState() {
    super.initState();
    _loadDexes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      final aNames = abilityNames(aDex);
      final iNames = heldItemNames(iDex);
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

    // Type overrides reset on species change.
    slot.typeOverride = null;

    // Pull the full curated usage entry once — EVs, nature, and moves
    // all auto-fill from the same Champions Singles snapshot so the
    // slot lands on a complete real build instead of blank fields.
    final usage = championsUsageFor(p.name);

    // EV spread: stored as EVs internally (so the calc-side handoff
    // stays unchanged); UI converts to SP at the display boundary.
    final defaultSp = usage?.defaultSp;
    slot.evs =
        defaultSp != null ? ChampionsMode.spToEvStats(defaultSp) : null;

    // Nature: parse the curated top pick; keep null on unknown names
    // so the picker shows blank rather than a wrong guess.
    slot.nature = null;
    final natureName = usage?.natures.isNotEmpty == true
        ? usage!.natures.first.name.toLowerCase()
        : null;
    if (natureName != null) {
      try {
        slot.nature = NatureProfile.fromNature(Nature.values.byName(natureName));
      } catch (_) {/* unknown nature name — leave null */}
    }

    // Moves: auto-fill from curated defaultMoves. Empty / unresolved
    // entries become null so the move grid renders an empty slot.
    final defaultMoves = usage?.defaultMoves ?? const [];
    for (int i = 0; i < slot.moves.length; i++) {
      slot.moves[i] =
          i < defaultMoves.length ? findMoveByName(defaultMoves[i].name) : null;
    }
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

  /// Two-option chooser shown when the user taps the camera button
  /// on the party tab: plain party list (existing capture flow)
  /// vs. trainer card (editable name / season / avatar + party).
  /// Defense / offense tabs skip this picker and capture directly.
  Future<void> _showPartyCaptureChoice() async {
    int? choice = 0;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocalState) {
          return AlertDialog(
            title: Text(AppStrings.t('team.captureChoice.title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<int>(
                  value: 0,
                  groupValue: choice,
                  onChanged: (v) => setLocalState(() => choice = v),
                  title: Text(AppStrings.t('team.captureChoice.party')),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                RadioListTile<int>(
                  value: 1,
                  groupValue: choice,
                  onChanged: (v) => setLocalState(() => choice = v),
                  title:
                      Text(AppStrings.t('team.captureChoice.trainerCard')),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppStrings.t('action.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, choice),
                child: Text(AppStrings.t('team.captureChoice.confirm')),
              ),
            ],
          );
        });
      },
    );
    if (picked == null || !mounted) return;
    if (picked == 0) {
      await _capturePartyImage();
    } else {
      await _showTrainerCardDialog();
    }
  }

  /// Trainer-card editor + capture entry point. Opens the dialog
  /// where the user fills in name / season / score / avatar; the
  /// dialog handles the offscreen render + save itself so this
  /// screen stays slim.
  Future<void> _showTrainerCardDialog() async {
    if (!mounted) return;
    // Pass both species + shiny flag through TrainerCardSlot so the
    // generated trainer card honours the user's shiny toggle on each
    // slot (previously the card always rendered the regular sprite).
    final party = [
      for (final s in _team)
        TrainerCardSlot(pokemon: s.pokemon, shiny: s.shiny),
    ];
    await showDialog(
      context: context,
      builder: (_) => TrainerCardDialog(party: party),
    );
  }

  /// Capture the current party as a PNG and save it to the user's
  /// gallery (mobile) or trigger a browser download (web). Image is
  /// a clean composition — party name top-left, 6 [_SlotSummaryCard]
  /// instances stacked below — rendered into an off-screen
  /// [OverlayEntry] so the user doesn't see the snapshot flicker on
  /// their screen.
  Future<void> _capturePartyImage() async {
    final hasAny = _team.any((s) => s.pokemon != null);
    if (!hasAny) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.image.empty')),
      ));
      return;
    }
    final partyName = _TeamCoverageStore.loadedPartyName ??
        AppStrings.t('team.image.defaultName');
    final scheme = Theme.of(context).colorScheme;
    final boundaryKey = GlobalKey();

    // Snapshot widget tree. Width sized for portrait phone viewing
    // (~iPhone Pro logical width) so the saved image fits comfortably
    // when the user re-views or shares it on a phone — earlier
    // 640-px render came out as a wide rectangle that wasted a lot
    // of vertical room. pixelRatio 3.0 keeps the PNG sharp at the
    // smaller logical size.
    final snapshot = Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 390,
          // Extra bottom padding so the captured image has a bit of
          // breathing room under the last slot card.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                partyName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < _team.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _SlotSummaryCard(
                  index: i + 1,
                  slot: _team[i],
                  abilityNames: _abilityNames ?? const {},
                  itemNames: _itemNames ?? const {},
                  onTap: () {/* unused in snapshot */},
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Off-screen positioning instead of Offstage — Offstage skips
    // paint, and RepaintBoundary.toImage relies on the paint phase
    // having actually run. -10000 left puts it well past any device
    // width while keeping it in the painted region.
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(left: -10000, top: 0, child: snapshot),
    );
    overlay.insert(entry);
    try {
      // Give the framework a frame to lay out and paint the
      // off-screen tree before we ask for its pixels.
      await Future.delayed(const Duration(milliseconds: 200));
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('RepaintBoundary missing render object');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('PNG encoding returned no bytes');
      }
      final bytes = byteData.buffer.asUint8List();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${_sanitizeFilename(partyName)}_$stamp.png';
      await savePartyImageBytes(bytes, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.image.saved')),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppStrings.t('team.image.failed')}: $e'),
      ));
    } finally {
      entry.remove();
    }
  }

  /// Capture the current coverage matrix (defense or offense) as
  /// a PNG. Mirrors [_capturePartyImage]'s offscreen-overlay +
  /// RepaintBoundary pattern; just swaps the contents and uses a
  /// wider canvas (the matrix has 18 type columns).
  Future<void> _captureCoverageChart({required bool offensive}) async {
    if (!_team.any((s) => s.pokemon != null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.image.empty')),
      ));
      return;
    }
    final partyName = _TeamCoverageStore.loadedPartyName ??
        AppStrings.t('team.image.defaultName');
    final tabLabel = AppStrings.t(
        offensive ? 'team.tab.offense' : 'team.tab.defense');
    final title = '$partyName · $tabLabel';
    final scheme = Theme.of(context).colorScheme;
    final boundaryKey = GlobalKey();
    final symbolic = CoverageDisplayController.instance.mode.value ==
        CoverageDisplayMode.symbolic;

    final snapshot = Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          // Aim for ~square aspect: narrower canvas + rotated type
          // headers (horizontalNames: false below) compress the 18
          // type columns into a width that matches the 6-slot stack
          // height plus title + padding.
          width: 480,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              _CoverageMatrix(
                team: _team,
                opponents: _TeamCoverageStore.opponents,
                abilityNames: _abilityNames ?? const {},
                symbolic: symbolic,
                offensive: offensive,
                // Rotated type-name headers keep each type column
                // narrow, which lets the whole matrix fit a roughly
                // square canvas without horizontal overflow.
                horizontalNames: false,
                lineupMode: _TeamCoverageStore.lineupMode,
                lineup: _TeamCoverageStore.lineup,
                onLineupToggle: (_) {/* unused in snapshot */},
              ),
            ],
          ),
        ),
      ),
    );

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(left: -10000, top: 0, child: snapshot),
    );
    overlay.insert(entry);
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('RepaintBoundary missing render object');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('PNG encoding returned no bytes');
      }
      final bytes = byteData.buffer.asUint8List();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final suffix = offensive ? 'offense' : 'defense';
      final filename =
          '${_sanitizeFilename(partyName)}_${suffix}_$stamp.png';
      await savePartyImageBytes(bytes, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.image.saved')),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppStrings.t('team.image.failed')}: $e'),
      ));
    } finally {
      entry.remove();
    }
  }

  static String _sanitizeFilename(String s) {
    // Conservative filename — strip anything that isn't word /
    // Hangul / hyphen so iOS Files / Android MediaStore don't
    // reject the name. Hangul jamo + syllable ranges + 0-9 +
    // ASCII letters + _ - are kept.
    return s.replaceAll(
        RegExp(r'[^\w\-가-힣ㄱ-ㅎㅏ-ㅣ]'), '_');
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
    final pickedId = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
          ),
          child: const _PartyPickerSheet(),
        ),
      ),
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
            ..evs = s.state.ev
            ..nature = s.state.nature
            ..shiny = s.state.shiny
            ..sampleId = s.id
            ..loadedSampleName = s.name;
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
        AppStrings.t('team.defaultName').replaceAll('{n}', '${store.teams.length + 1}');
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
      if (slot.evs != null) state.ev = slot.evs!;
      if (slot.nature != null) state.nature = slot.nature!;
      state.shiny = slot.shiny;
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

  /// Build a fresh BattlePokemonState from a team slot and push it
  /// into the calculator via [CalcHandoff]. Pops the navigation
  /// stack back to the calc (which sits at root) so the user lands
  /// on whichever mode (simple / extended) they were last using —
  /// both modes consume the calc-side _attacker/_defender state
  /// that the handoff replaces.
  Future<void> _sendSlotToCalc(_TeamSlot slot, int side) async {
    final p = slot.pokemon;
    if (p == null || !mounted) return;
    final state = BattlePokemonState();
    state.applyPokemon(p);
    if (slot.ability != null) state.selectedAbility = slot.ability!;
    if (slot.heldItem != null) state.selectedItem = slot.heldItem;
    if (slot.evs != null) state.ev = slot.evs!;
    if (slot.nature != null) state.nature = slot.nature!;
    state.shiny = slot.shiny;
    for (int i = 0;
        i < state.moves.length && i < slot.moves.length;
        i++) {
      if (slot.moves[i] != null) state.moves[i] = slot.moves[i];
    }
    CalcHandoff.instance.stage(
      side: side,
      state: state,
      loadedSampleName: slot.loadedSampleName,
    );
    if (!mounted) return;
    // CalcHandoff already staged — switch to the calc tab so the
    // user lands on the calculator with their pick applied. The team
    // tab's state stays intact thanks to RootShell's IndexedStack.
    RootShell.of(context).setTab(AppNavTab.calc);
  }

  /// Pull a saved sample (from the shared sample storage) and copy
  /// the species + ability + item + moves into [index]. Uses the
  /// same SampleListSheet as the calculator so the load UX (party
  /// folders, expand/collapse, search, rename, move, delete) is
  /// identical across the two screens.
  /// Save the slot's current contents (pokemon + ability + item + 4
  /// moves) as a standalone sample. The user picks a name; existing
  /// samples with the same name are overwritten after a confirm
  /// dialog. Used by the editor popup's 💾 button.
  Future<void> _saveSlotAsSample(_TeamSlot slot) async {
    final p = slot.pokemon;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('team.save.empty')),
      ));
      return;
    }
    // Reuse the calculator's save dialog + overwrite/team-move
    // pipeline so the per-slot save behaves identically (name field
    // pre-filled with the loaded sample's name, team picker, "+ 새
    // 팀" prompt, overwrite confirm, team-full snackbar).
    final state = BattlePokemonState();
    state.applyPokemon(p);
    if (slot.ability != null) state.selectedAbility = slot.ability!;
    if (slot.heldItem != null) state.selectedItem = slot.heldItem;
    if (slot.evs != null) state.ev = slot.evs!;
    if (slot.nature != null) state.nature = slot.nature!;
    state.shiny = slot.shiny;
    for (int i = 0;
        i < state.moves.length && i < slot.moves.length;
        i++) {
      if (slot.moves[i] != null) state.moves[i] = slot.moves[i];
    }
    final outcome = await SampleSaveFlow.run(
      context: context,
      state: state,
      loadedName: slot.loadedSampleName,
    );
    if (outcome == null || !mounted) return;
    // Rebind the slot to whatever sample now backs that name —
    // matches the calc's `_attackerLoadedName = outcome.name`
    // behaviour, and keeps subsequent `_saveAsParty` runs anchored
    // to the same sample id.
    setState(() {
      slot.loadedSampleName = outcome.name;
      slot.sampleId = outcome.sampleId;
    });
  }

  Future<void> _loadSampleInto(_TeamSlot slot) async {
    final pokedex = await loadPokedex();
    if (!mounted) return;
    final byName = {for (final p in pokedex) p.name: p};
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(viewInsets: EdgeInsets.zero),
        child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        // Cap the dialog width so it doesn't sprawl across the whole
        // browser window on desktop. Mobile screens stay below the
        // cap and fill naturally.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(ctx).height * 0.9,
          child: SampleListSheet(
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
            slot.evs = s.ev;
            slot.nature = s.nature;
            slot.shiny = s.shiny;
            slot.sampleId = sample.id;
            slot.loadedSampleName = sample.name;
            for (int i = 0; i < slot.moves.length; i++) {
              slot.moves[i] = i < s.moves.length ? s.moves[i] : null;
            }
          });
          Navigator.pop(ctx);
        },
      ),
        ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wide screens get the same 3-tab structure as narrow — the only
    // wide-specific behaviour left is whether matrix-header names
    // render horizontally (room to fit them) vs the vertical stacked
    // layout phones use.
    final isWide = MediaQuery.of(context).size.width >= 1050;

    // Slot rows are now read-only summary cards (sprite + name +
    // types + ability/item + 4 move pills). Tap to open the modal
    // editor sheet that contains the full form (selector, ability,
    // item, type override, 4 move pickers, sample-load, clear).
    // Callbacks fire in real time as the user edits, so closing the
    // sheet doesn't need an explicit commit step.
    void openEditor(_TeamSlot slot, int displayIndex,
        VoidCallback onClearOrRemove) {
      showDialog(
        context: context,
        builder: (dialogCtx) {
          final size = MediaQuery.sizeOf(dialogCtx);
          final width = (size.width - 32).clamp(280.0, 480.0);
          // StatefulBuilder so the load handler (and any other async
          // mutation that bypasses _SlotCard's own setState chain)
          // can force the popup to repaint without closing it. This
          // is what lets the sample sheet stack on top of the editor
          // instead of replacing it.
          return StatefulBuilder(
            builder: (statefulCtx, popupSetState) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 24),
                child: GestureDetector(
                  // Tap anywhere outside an input drops focus so the
                  // IME collapses. Without this, EV / typeahead
                  // inputs trap focus and the user has no way out
                  // short of pressing back. translucent so child
                  // taps still reach buttons.
                  behavior: HitTestBehavior.translucent,
                  onTap: () =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: size.height * 0.8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header row sits outside the form so the form
                      // itself can use full inner width for the
                      // species selector (long Korean names were
                      // ellipsizing). Buttons:
                      //   📂 = load sample — opens the sample sheet
                      //        on top of the editor (editor stays
                      //        open behind), then repaints on return
                      //        so the loaded species shows up
                      //        immediately.
                      //   🗑 = delete the slot.
                      //   ✕  = close the editor (no destructive
                      //        action); all in-flight edits are
                      //        already committed via callbacks, so
                      //        close just dismisses.
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(8, 8, 4, 0),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: AppStrings.t('team.sample.load'),
                              icon: const Icon(Icons.folder_open,
                                  size: 22),
                              onPressed: () async {
                                await _loadSampleInto(slot);
                                // Repaint the editor so the loaded
                                // species' sprite / ability / item /
                                // moves render immediately — host
                                // setState doesn't reach the dialog
                                // overlay.
                                popupSetState(() {});
                              },
                            ),
                            IconButton(
                              tooltip: AppStrings.t('team.slot.save'),
                              icon: const Icon(Icons.save_outlined,
                                  size: 22),
                              onPressed: () =>
                                  _saveSlotAsSample(slot),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: AppStrings.t('team.slot.delete'),
                              icon: const Icon(Icons.delete_outline,
                                  size: 22),
                              onPressed: () {
                                onClearOrRemove();
                                Navigator.of(dialogCtx).pop();
                              },
                            ),
                            IconButton(
                              tooltip: AppStrings.t('action.close'),
                              icon: const Icon(Icons.close, size: 22),
                              onPressed: () =>
                                  Navigator.of(dialogCtx).pop(),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _SlotCard(
                            index: displayIndex,
                            slot: slot,
                            abilityDex: _abilityDex ?? const {},
                            abilityNames: _abilityNames ?? const {},
                            itemDex: _itemDex ?? const {},
                            itemNames: _itemNames ?? const {},
                            onPokemonSelected: (p) =>
                                _setPokemon(slot, p),
                            onAbilitySelected: (a) =>
                                _setAbility(slot, a),
                            onItemSelected: (it) =>
                                _setItem(slot, it),
                            showMoves: true,
                            onMoveChanged: (mi, m) =>
                                _setMove(slot, mi, m),
                            onTypeOverrideChanged: (override) =>
                                _setTypeOverride(slot, override),
                            onEvChanged: (ev) =>
                                setState(() => slot.evs = ev),
                            onNatureChanged: (n) =>
                                setState(() => slot.nature = n),
                            onShinyChanged: (v) =>
                                setState(() => slot.shiny = v),
                            onSendToCalc: (side) {
                              Navigator.of(dialogCtx).pop();
                              _sendSlotToCalc(slot, side);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              );
            },
          );
        },
      ).then((_) => setState(() {})); // refresh summary on close
    }

    Widget buildSlotCard(
      _TeamSlot slot, {
      required int displayIndex,
      required Key key,
      required VoidCallback onClearOrRemove,
    }) =>
        RepaintBoundary(
          child: _SlotSummaryCard(
            key: key,
            index: displayIndex,
            slot: slot,
            abilityNames: _abilityNames ?? const {},
            itemNames: _itemNames ?? const {},
            onTap: () => openEditor(slot, displayIndex, onClearOrRemove),
          ),
        );

    final allyList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _maxTeamSize; i++) ...[
          buildSlotCard(
            _team[i],
            displayIndex: i,
            key: ValueKey('team_slot_card_$i'),
            onClearOrRemove: () => _clearMySlot(i),
          ),
          if (i < _maxTeamSize - 1) const SizedBox(height: 4),
        ],
      ],
    );

    final opponentList = Builder(
      builder: (_) {
        final opps = _TeamCoverageStore.opponents;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _opponentSectionHeader(),
            const SizedBox(height: 4),
            for (int i = 0; i < opps.length; i++) ...[
              buildSlotCard(
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

    // Single-column slot list used inside the Party tab. The wide-
    // layout 2-column split (ally | opp) folds back into one column
    // here because tab-switching costs ~zero on wide too.
    final slotList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        allyList,
        const SizedBox(height: 12),
        opponentList,
      ],
    );

    // Matrix-tab toolbar: 선출 (lineup) + 숫자/기호 (display mode)
    // switches. Same control surface for both defense and offense
    // matrices so users don't relearn anything per tab.
    Widget matrixTools() => ValueListenableBuilder<CoverageDisplayMode>(
          valueListenable: CoverageDisplayController.instance.mode,
          builder: (_, mode, __) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _LineupSwitch(
                  value: _TeamCoverageStore.lineupMode,
                  onToggle: _toggleLineupMode,
                ),
                const SizedBox(width: 8),
                CoverageDisplayToggle(mode: mode),
              ],
            ),
          ),
        );

    Widget matrixFor({required bool offensive}) =>
        ValueListenableBuilder<CoverageDisplayMode>(
          valueListenable: CoverageDisplayController.instance.mode,
          builder: (_, mode, __) {
            final symbolic = mode == CoverageDisplayMode.symbolic;
            return RepaintBoundary(
              child: _CoverageMatrix(
                team: _team,
                opponents: _TeamCoverageStore.opponents,
                abilityNames: _abilityNames ?? const {},
                symbolic: symbolic,
                offensive: offensive,
                horizontalNames: isWide,
                lineupMode: _TeamCoverageStore.lineupMode,
                lineup: _TeamCoverageStore.lineup,
                onLineupToggle: _toggleLineupSlot,
              ),
            );
          },
        );

    // Per-tab content. Each tab is its own SingleChildScrollView so
    // scroll position stays independent per tab, like the calculator's
    // attacker / defender / damage tabs.
    // Party tab — no "변화기 보기" toggle here; the team-builder
    // MoveSelectors force-show status moves regardless of the global
    // preference, so the toggle has nothing to gate.
    final partyTab = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: slotList,
    );

    final defenseTab = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          matrixTools(),
          matrixFor(offensive: false),
        ],
      ),
    );

    final offenseTab = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          matrixTools(),
          matrixFor(offensive: true),
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
      // Cap AppBar visual width to match the body so the toolbar
      // chrome sits centered above the panes on 4K screens.
      appBar: cappedAppBar(
        // Matches body cap (1500) so the toolbar centers above
        // the 3-column body on ultra-wide displays.
        maxWidth: 1500,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: MediaQuery.sizeOf(context).width >= 1050
              ? IconButton(
                  // Wide-only — narrow widths return via the bottom
                  // nav's '계산기' tab. This is the root route of
                  // the team-builder tab's nested navigator so
                  // there's nothing to pop; semantically the back
                  // button switches to calc.
                  tooltip:
                      MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const BackButtonIcon(),
                  onPressed: () =>
                      RootShell.of(context).setTab(AppNavTab.calc),
                )
              : null,
          titleSpacing: 0,
          title: SingleChildScrollView(
            // Party-level actions (load saved party, save current
            // party, reset). Horizontal scroll so narrow widths degrade
            // to a swipe instead of clipped labels.
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: _team.any((s) => s.pokemon != null)
                      ? _saveAsParty
                      : null,
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
                  onPressed: _team.any((s) => s.pokemon != null)
                      ? _resetAll
                      : null,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(AppStrings.t('team.resetAll')),
                  style: _appBarBtnStyle,
                ),
                // Camera button → save a PNG of whatever tab the
                // user is on (party / defense chart / offense chart).
                // Disabled (greyed) when no slot is filled so the
                // user doesn't get an empty capture on tap.
                IconButton(
                  tooltip: AppStrings.t('team.image.tooltip'),
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  onPressed: _team.any((s) => s.pokemon != null)
                      ? () {
                          switch (_tabController.index) {
                            case 0:
                              // Party tab gives the user a choice —
                              // a plain party list capture or a
                              // trainer-card composition with
                              // editable name / season / avatar.
                              _showPartyCaptureChoice();
                            case 1:
                              _captureCoverageChart(offensive: false);
                            case 2:
                              _captureCoverageChart(offensive: true);
                          }
                        }
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          actions: [
            // Wide-only Champions speed-tier shortcut. Narrow layouts
            // reach the same sheet via AppSettingsMenu's "스피드표"
            // entry below — sliced this way so narrow's tight app bar
            // doesn't pick up another button it can't comfortably fit.
            if (isWide) ...[
              TextButton.icon(
                onPressed: () => ChampionsUsageRankSheet.show(context),
                icon: const Icon(Icons.leaderboard, size: 20),
                label: Text(AppStrings.t('usageRank.menuLabel')),
              ),
              TextButton.icon(
                onPressed: () => ChampionsSpeedTierSheet.show(context),
                icon: const Icon(Icons.speed, size: 20),
                label: Text(AppStrings.t('speedTier.menuLabel')),
              ),
              TextButton.icon(
                onPressed: () => TypeChartSheet.show(context),
                icon: const Icon(Icons.grid_on, size: 20),
                label: Text(AppStrings.t('typeChart.menuLabel')),
              ),
            ],
            AppSettingsMenu(onLanguageChanged: () => setState(() {})),
          ],
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
        // Wide screens (≥1050) get the original 3-column side-by-side
        // layout that the team-builder used to ship with: Party,
        // Defense, Offense all visible at once. Restored after the
        // 3-internal-tab refactor (commit 3ae2f5f) drew user
        // complaints — users on wide displays want all three panes
        // open simultaneously without tab-switching, since that's
        // the whole point of having a wide screen.
        //
        // Narrow keeps the tab structure for vertical-phone usage.
        child: isWide
            ? LayoutBuilder(
                builder: (context, c) {
                  // Cap the 3-column layout at 1500-pt wide and
                  // top-center on larger displays. Matches the dex
                  // screen's larger cap; without this, ultra-wide
                  // monitors stretch each column past readable
                  // width with no extra information to show.
                  final w = c.maxWidth.clamp(0.0, 1500.0);
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: w,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: partyTab),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(child: defenseTab),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(child: offenseTab),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: AppStrings.t('team.tab.party')),
                      Tab(text: AppStrings.t('team.tab.defense')),
                      Tab(text: AppStrings.t('team.tab.offense')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [partyTab, defenseTab, offenseTab],
                    ),
                  ),
                ],
              ),
      ),
      ),
    );
  }
}

// _LabeledField removed — the ability + item line now uses inline
// Text.rich rendering (see _abilityItemLine).

// _EvCell extracted to widgets/ev_sp_cell.dart so the focus-
// persistence contract is covered by a dedicated widget test.

