import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../utils/app_strings.dart';
import '../models/move_tags.dart';
import '../utils/aura_effects.dart';
import '../utils/battle_facade.dart';
import '../utils/random_factor.dart';
import '../utils/ruin_effects.dart';
import '../utils/calc_handoff.dart';
import '../utils/sample_save_flow.dart';
import '../utils/simple_mode_controller.dart';
import 'root_shell.dart';
import 'widgets/app_settings_menu.dart';
import 'widgets/first_launch_scope_dialog.dart';
import 'widgets/reverse_calc_dialog.dart';
import '../utils/sprite_pack_manager.dart';
import 'dex_screen.dart' show DexPickResult;
import 'simple_mode_screen.dart';
import '../utils/damage_calculator.dart';
import '../utils/speed_calculator.dart';
import '../utils/stat_calculator.dart';
import '../models/type.dart';
import '../models/battle_pokemon.dart';
import '../models/terastal.dart';
import '../models/dynamax.dart';
import '../models/stats.dart';
import '../models/room.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import '../utils/localization.dart';
import '../utils/terrain_effects.dart' show abilityTerrainMap;
import '../utils/weather_effects.dart' show abilityWeatherMap;
import '../data/abilitydex.dart';
import '../data/itemdex.dart';
import '../utils/url_navigator_stub.dart'
    if (dart.library.html) '../utils/url_navigator_web.dart' as nav;
import 'widgets/champions_learnset_notice.dart';
import 'widgets/mobile_install_banner.dart';
import 'widgets/modifier_note.dart';
import 'widgets/pokemon_panel.dart';
import 'widgets/sample_list_sheet.dart';
import 'widgets/speed_compare_tab.dart';

/// TabController that defaults to a 180 ms transition instead of
/// Material's 300 ms — this calc runs inside a 1-minute battle
/// command select, so each saved 120 ms of swipe animation matters.
/// TabBar internally calls `controller.animateTo(i)` without a
/// duration override, so subclassing is the cleanest way to set a
/// shop-wide default.
class _FastTabController extends TabController {
  _FastTabController({required super.length, required super.vsync});

  @override
  void animateTo(int value,
      {Duration? duration, Curve curve = Curves.ease}) {
    super.animateTo(value,
        duration: duration ?? const Duration(milliseconds: 180),
        curve: curve);
  }
}

class DamageCalculatorScreen extends StatefulWidget {
  final Map<String, String> abilityNameMap;
  final Map<String, String> itemNameMap;

  const DamageCalculatorScreen({
    super.key,
    this.abilityNameMap = const {},
    this.itemNameMap = const {},
  });

  @override
  State<DamageCalculatorScreen> createState() => _DamageCalculatorScreenState();
}

class _DamageCalculatorScreenState extends State<DamageCalculatorScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  var _attacker = BattlePokemonState();
  var _defender = BattlePokemonState();
  final _attackerPanelKey = GlobalKey<PokemonPanelState>();
  final _defenderPanelKey = GlobalKey<PokemonPanelState>();
  int _resetCounter = 0;

  final _speedTabKey = GlobalKey<SpeedCompareTabState>();

  Weather _weather = Weather.none;
  Terrain _terrain = Terrain.none;
  RoomConditions _room = const RoomConditions();
  AuraToggles _auras = const AuraToggles();
  RuinToggles _ruins = const RuinToggles();
  bool _useSpMode = true;
  /// Shared expansion state for the per-side "Doubles-only options"
  /// section — when the user expands one panel, the other also shows.
  bool _doublesExpanded = false;

  /// When true, the normal tabs are replaced with the compact Simple
  /// Mode view. Each mode owns its own per-side state and both stay
  /// mounted (IndexedStack), so toggling back and forth preserves
  /// inputs within a session. Battle environment is shared via the
  /// top toolbar. Persisted across launches via [SimpleModeController].
  bool _simpleMode = SimpleModeController.instance.isSimple.value;

  // Damage-tab move sum: tap a result block to add it (× count, max 8
  // total). Convolves the per-shot 16-roll distributions to give a
  // joint damage distribution across the selected uses. Stat / ability
  // / item changes flow through naturally because we recompute every
  // build; only the move *list itself* changing forces a reset (signature
  // captured at first add).
  static const int _kSumMax = 8;
  final Map<int, int> _summedSlots = {};
  List<String?> _summedSig = const [];

  // Name of the sample currently loaded on each side (used to prefill the
  // save dialog so users can update presets in place). Cleared when the
  // Pokémon species changes or the side is reset.
  String? _attackerLoadedName;
  String? _defenderLoadedName;
  String? _prevAtkPokemon;
  String? _prevDefPokemon;


  // Name maps – loaded locally so they refresh on language change
  Map<String, String> _abilityNameMap = {};
  Map<String, String> _itemNameMap = {};
  // Subset of abilities the picker is allowed to show (i.e. not
  // nonMainline). Both maps stay full so lookups by key still resolve,
  // but the typeahead's suggestion list is filtered through this set
  // so users don't stumble into Colosseum-only abilities mid-battle.
  Set<String> _pickableAbilities = {};

  // Ability → Weather/Terrain auto-set (from weather_effects / terrain_effects)

  /// Called when either panel changes.
  void _onPanelChanged() {
    if (mounted) {
      setState(() {
        // Clear any loaded-sample memory on species change — a different
        // Pokémon implies a new preset rather than an edit of the current one.
        if (_prevAtkPokemon != _attacker.pokemonName) {
          if (_prevAtkPokemon != null) _attackerLoadedName = null;
          _prevAtkPokemon = _attacker.pokemonName;
        }
        if (_prevDefPokemon != _defender.pokemonName) {
          if (_prevDefPokemon != null) _defenderLoadedName = null;
          _prevDefPokemon = _defender.pokemonName;
        }
        _syncWeatherTerrain();
      });
    }
  }

  String? _prevAtkAbility;
  String? _prevDefAbility;

  /// Repair loaded preset data with latest movedex/pokedex/itemdex data.
  /// Presets saved in older versions may be missing fields (zPower, tags, etc.)
  /// or have outdated values (power, type, base stats from patches).
  void _repairPresetData(BattlePokemonState state) {
    // Repair moves
    if (_moveCache != null) {
      for (int i = 0; i < state.moves.length; i++) {
        final saved = state.moves[i];
        if (saved == null) continue;
        final canonical = _moveCache![saved.name];
        if (canonical != null) {
          state.moves[i] = canonical;
        }
      }
    }

    // Repair Pokemon data (base stats, types, abilities)
    if (_pokemonCache != null && state.pokemonName != null) {
      final canonical = _pokemonCache![state.pokemonName!];
      if (canonical != null) {
        state.baseStats = canonical.baseStats;
        state.type1 = canonical.type1;
        state.type2 = canonical.type2;
        state.pokemonAbilities = canonical.abilities;
        state.weight = canonical.weight;
        state.isMega = canonical.isMega;
        state.canDynamax = canonical.canDynamax;
        state.canGmax = canonical.canGmax;
        if (state.isMega) {
          state.zMoves = [false, false, false, false];
          state.terastal = const TerastalState();
        }
      }
    }
  }

  Map<String, Move>? _moveCache;
  Map<String, Pokemon>? _pokemonCache;

  Future<void> _ensureDataCaches() async {
    if (_moveCache == null) {
      _moveCache = await loadMovedex();
    }
    if (_pokemonCache == null) {
      final pokedex = await loadPokedex();
      _pokemonCache = {for (final p in pokedex) p.name: p};
    }
  }

  void _syncWeatherTerrain() {
    final atkAbility = _attacker.selectedAbility;
    final defAbility = _defender.selectedAbility;

    final atkChanged = atkAbility != _prevAtkAbility;
    final defChanged = defAbility != _prevDefAbility;
    final prevAtk = _prevAtkAbility;
    final prevDef = _prevDefAbility;
    _prevAtkAbility = atkAbility;
    _prevDefAbility = defAbility;

    if (!atkChanged && !defChanged) return;

    // Auto-set: a new ability appears that maps to weather/terrain.
    if (atkChanged && atkAbility != null) {
      final w = abilityWeatherMap[atkAbility];
      if (w != null) _weather = w;
      final t = abilityTerrainMap[atkAbility];
      if (t != null) _terrain = t;
    }
    if (defChanged && defAbility != null) {
      final w = abilityWeatherMap[defAbility];
      if (w != null) _weather = w;
      final t = abilityTerrainMap[defAbility];
      if (t != null) _terrain = t;
    }

    // Auto-clear by transition: an ability that *was* justifying the
    // current weather/terrain got removed, and no replacement justifies
    // it anymore. Purely user-set values (where no prev ability sourced
    // it) stay put.
    if (_weather != Weather.none) {
      final prevHadSource =
          (prevAtk != null && abilityWeatherMap[prevAtk] == _weather) ||
          (prevDef != null && abilityWeatherMap[prevDef] == _weather);
      final nowHasSource =
          (atkAbility != null && abilityWeatherMap[atkAbility] == _weather) ||
          (defAbility != null && abilityWeatherMap[defAbility] == _weather);
      if (prevHadSource && !nowHasSource) _weather = Weather.none;
    }
    if (_terrain != Terrain.none) {
      final prevHadSource =
          (prevAtk != null && abilityTerrainMap[prevAtk] == _terrain) ||
          (prevDef != null && abilityTerrainMap[prevDef] == _terrain);
      final nowHasSource =
          (atkAbility != null && abilityTerrainMap[atkAbility] == _terrain) ||
          (defAbility != null && abilityTerrainMap[defAbility] == _terrain);
      if (prevHadSource && !nowHasSource) _terrain = Terrain.none;
    }
  }

  void _swapSides() {
    setState(() {
      final temp = _attacker;
      _attacker = _defender;
      _defender = temp;
      _resetCounter++;
    });
  }

  Stats _calcStats(BattlePokemonState s) {
    return StatCalculator.calculate(
      baseStats: s.baseStats, iv: s.iv, ev: s.ev,
      nature: s.nature, level: s.level, rank: s.rank,
    );
  }

  int _calcEffectiveSpeed(BattlePokemonState s) {
    return BattleFacade.calcSpeed(
      state: s,
      weather: _weather,
      terrain: _terrain,
      room: _room,
    );
  }

  bool _isAlwaysLast(BattlePokemonState s) => isAlwaysLast(s);

  @override
  void initState() {
    super.initState();
    _tabController = _FastTabController(length: 4, vsync: this);
    // Refresh state on tab change (e.g. for toolbar button visibility)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        FocusManager.instance.primaryFocus?.unfocus();
        _attackerPanelKey.currentState?.scrollToTop();
        _defenderPanelKey.currentState?.scrollToTop();
        _speedTabKey.currentState?.scrollToTop();
        setState(() {});
      }
    });
    _loadAbilities();
    _loadItems();
    _loadSpMode();
    _loadDoublesExpanded();
    _ensureDataCaches();
    // Pick up external mode changes (e.g. the first-launch prompt
    // sets simple/extended via SimpleModeController.setSimple — the
    // calc has already initialised _simpleMode from the controller's
    // current value, so without this listener the dialog's choice
    // would be persisted to prefs but the running calc would not
    // re-render in the new mode until next restart).
    SimpleModeController.instance.isSimple.addListener(_onSimpleModeChanged);
    // First-launch (or first-launch-after-update) scope prompt —
    // shows a non-dismissable dialog until the user picks between
    // Champions-only and full Pokédex. Existing users see it once
    // on next launch by design. No-op once the prompt-shown flag
    // is set.
    maybeShowFirstLaunchScopePrompt(context);
    // Listen for cross-screen hand-offs (team builder → calc).
    // Fires whenever a sibling screen calls CalcHandoff.stage(),
    // even while we're sitting under another route on the stack.
    CalcHandoff.instance.addListener(_consumeCalcHandoff);
    // Drain anything that landed before the listener was attached
    // (extremely rare — the inbox is normally empty at boot, but
    // defensive in case a future surface stages during async load).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeCalcHandoff();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowSpritePackUpdate();
      if (!mounted) return;
      // Mobile-web install nudge — keeps showing until the user opts
      // out via "Don't show again" (same dismissal semantics as the
      // sprite announcement above).
      await MobileInstallPrompt.maybeShow(context);
      if (!mounted) return;
      // One-shot notice for the 2026-06-17 Champions roster
      // expansion — learnsets for new roster members are still
      // inherited from Showdown and may not match the in-game
      // pool until ChampionsLab refreshes upstream.
      await ChampionsLearnsetNotice.maybeShow(context);
    });
  }

  /// Sprite-pack update nag. Fires only when (a) the user has at
  /// least one pack installed and (b) at least one installed style's
  /// VERSION marker disagrees with [kLatestSpritePackVersion]. There
  /// is no permanent dismiss — the user can only snooze for a week
  /// or a month, by design, so a stale pack eventually surfaces
  /// again until the user re-imports the latest ZIP.
  ///
  /// Skipped on web (no pack management) and for users who haven't
  /// onboarded onto any pack yet (their initial install banner lives
  /// inside the style dialog).
  static const _packNagSnoozeUntilKey = 'spritePackNagSnoozeUntilMs';
  Future<void> _maybeShowSpritePackUpdate() async {
    if (kIsWeb) return;
    final mgr = SpritePackManager.instance;
    if (!mgr.hasAnyInstalled) return;
    if (!mgr.isAnyOutOfDate(kLatestSpritePackVersion)) return;
    final prefs = await SharedPreferences.getInstance();
    final snoozeUntil = prefs.getInt(_packNagSnoozeUntilKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < snoozeUntil) return;
    if (!mounted) return;
    Future<void> snooze(int days) async {
      await prefs.setInt(
        _packNagSnoozeUntilKey,
        now + days * Duration.millisecondsPerDay,
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('sprite.update.title')),
        content: Text(AppStrings.t('sprite.update.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.close')),
          ),
          TextButton(
            onPressed: () async {
              await snooze(7);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppStrings.t('action.snoozeWeek')),
          ),
          TextButton(
            onPressed: () async {
              await snooze(30);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppStrings.t('action.snoozeMonth')),
          ),
        ],
      ),
    );
  }

  static const _spModeKey = 'use_sp_mode';
  static const _spModeMigrationKey = 'sp_mode_migrated_to_default_v1';

  Future<void> _loadSpMode() async {
    final prefs = await SharedPreferences.getInstance();
    // One-time migration: force existing users to SP mode after Champions release
    final migrated = prefs.getBool(_spModeMigrationKey) ?? false;
    if (!migrated) {
      await prefs.setBool(_spModeKey, true);
      await prefs.setBool(_spModeMigrationKey, true);
    }
    final saved = prefs.getBool(_spModeKey) ?? true;
    if (mounted && saved != _useSpMode) setState(() => _useSpMode = saved);
  }

  void _setSpMode(bool v) {
    setState(() => _useSpMode = v);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_spModeKey, v);
    });
  }

  static const _doublesExpandedKey = 'doubles_expanded';

  Future<void> _loadDoublesExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_doublesExpandedKey) ?? false;
    if (mounted && saved != _doublesExpanded) {
      setState(() => _doublesExpanded = saved);
    }
  }

  void _setDoublesExpanded(bool v) {
    setState(() => _doublesExpanded = v);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_doublesExpandedKey, v);
    });
  }

  Future<void> _loadAbilities() async {
    try {
      final dex = await loadAbilitydex();
      final map = <String, String>{};
      final pickable = <String>{};
      for (final entry in dex.entries) {
        map[entry.key] = entry.value.localizedName;
        if (!entry.value.nonMainline) pickable.add(entry.key);
      }
      if (mounted) setState(() {
        _abilityNameMap = map;
        _pickableAbilities = pickable;
      });
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    try {
      final dex = await loadItemdex();
      final map = <String, String>{};
      for (final entry in dex.entries) {
        if (entry.value.battle) {
          map[entry.key] = entry.value.localizedName;
        }
      }
      if (mounted) setState(() => _itemNameMap = map);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    CalcHandoff.instance.removeListener(_consumeCalcHandoff);
    SimpleModeController.instance.isSimple.removeListener(_onSimpleModeChanged);
    super.dispose();
  }

  void _onSimpleModeChanged() {
    final v = SimpleModeController.instance.isSimple.value;
    if (!mounted || v == _simpleMode) return;
    setState(() => _simpleMode = v);
  }

  /// Apply a pending team-builder → calc payload to attacker /
  /// defender. Runs after the sender pops back to us via
  /// `popUntil((r) => r.isFirst)`, so the IndexedStack-style
  /// Simple/Extended view picks the new state up on its next build.
  void _consumeCalcHandoff() {
    final payload = CalcHandoff.instance.consume();
    if (payload == null || !mounted) return;
    setState(() {
      _resetCounter++;
      if (payload.side == 0) {
        _attacker = payload.state;
        _attackerLoadedName = payload.loadedSampleName;
        _prevAtkPokemon = payload.state.pokemonName;
      } else {
        _defender = payload.state;
        _defenderLoadedName = payload.loadedSampleName;
        _prevDefPokemon = payload.state.pokemonName;
      }
      _syncWeatherTerrain();
    });
    // Extended mode hides the non-active side behind a tab — surface
    // the one we just received so the user sees their handoff land
    // instead of staring at the wrong side. payload.side maps 1:1 to
    // tab index (0 = attacker, 1 = defender). Simple mode shows both
    // sides at once so the tab change is harmless background state.
    if (payload.side < _tabController.length) {
      _tabController.animateTo(payload.side);
    }
  }

  bool get _isWideLayout => MediaQuery.of(context).size.width >= 1050;

  void _resetSide(int side) {
    setState(() {
      _resetCounter++;
      if (side == 0) {
        _attacker.reset();
        _attackerLoadedName = null;
        _prevAtkPokemon = null;
      } else {
        _defender.reset();
        _defenderLoadedName = null;
        _prevDefPokemon = null;
      }
    });
  }

  // Singles/doubles toggle was removed — doubles features are always
  // available via the collapsed per-side "Doubles-only options" section.

  /// Flip between Simple and Normal mode. Each mode's state is
  /// independent and persisted in its own widget subtree (via
  /// IndexedStack), so switching back and forth is lossless within a
  /// session — no data migration needed.
  void _toggleSimpleMode() {
    final next = !_simpleMode;
    setState(() => _simpleMode = next);
    SimpleModeController.instance.setSimple(next);
  }

  Future<void> _resetBothSides() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('reset.title')),
        content: Text(AppStrings.t('reset.message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.t('action.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t('action.confirm'))),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _resetCounter++;
        _attacker.reset();
        _defender.reset();
        _attackerLoadedName = null;
        _defenderLoadedName = null;
        _prevAtkPokemon = null;
        _prevDefPokemon = null;
        _weather = Weather.none;
        _terrain = Terrain.none;
        _room = const RoomConditions();
        _auras = const AuraToggles();
        _ruins = const RuinToggles();
      });
    }
  }

  Future<void> _showSaveDialog(int side, BattlePokemonState state) async {
    final loadedName = side == 0 ? _attackerLoadedName : _defenderLoadedName;
    final outcome = await SampleSaveFlow.run(
      context: context,
      state: state,
      loadedName: loadedName,
    );
    if (outcome == null || !mounted) return;
    setState(() {
      if (side == 0) {
        _attackerLoadedName = outcome.name;
      } else {
        _defenderLoadedName = outcome.name;
      }
    });
  }

  Future<void> _showLoadSheet(int side) async {
    // Snappy dialog instead of slide-up bottom sheet — the in-battle
    // load flow has to be fast, and the bottom-sheet animation
    // dragged enough that the user noticed.
    //
    // The MediaQuery override zeroes viewInsets.bottom so the dialog
    // does NOT shrink when the search keyboard appears — users
    // expect the visible list area to stay constant while they type
    // (scrolling reveals items the keyboard happens to cover).
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
        itemNameMap: _itemNameMap,
        onLoad: (sample) {
          setState(() {
            final loaded = sample.state;
            _repairPresetData(loaded);
            if (side == 0) {
              _attacker = loaded;
              _attackerLoadedName = sample.name;
              _prevAtkPokemon = loaded.pokemonName;
            } else {
              _defender = loaded;
              _defenderLoadedName = sample.name;
              _prevDefPokemon = loaded.pokemonName;
            }
            _resetCounter++;
            _syncWeatherTerrain();
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

  /// Open the Pokédex screen, optionally focused on a specific
  /// Pokemon. [initialName] mirrors [BattlePokemonState.pokemonName]
  /// when invoked from the per-side panel "open in dex" button.
  ///
  /// If the user taps one of the dex header's "To attacker" /
  /// "To defender" buttons, the dex pops with a [DexPickResult] and
  /// we apply the picked Pokemon to the chosen side, bumping
  /// [_resetCounter] so Simple Mode re-hydrates its per-side UI. In
  /// the narrow extended layout we also switch the tab so the user
  /// lands on the side they just populated.
  Future<void> _openDex({String? initialName}) async {
    // Stays as a root-navigator modal push (NOT a tab switch) because
    // the user expects to pick a Pokémon and return to calc with the
    // result, not land on the dex tab. RootShell.openDexAsPicker
    // pushes on the root navigator above the IndexedStack, so the
    // dex tab's own state is unaffected by this overlay.
    final result =
        await RootShell.of(context).openDexAsPicker(initialName: initialName);
    if (!mounted || result == null) return;
    final target = result.side == 0 ? _attacker : _defender;
    setState(() {
      target.applyPokemon(result.pokemon);
      _resetCounter++;
    });
    _onPanelChanged();
    if (!_simpleMode) {
      // Narrow layout has tabs 0=attacker, 1=defender, …; wide layouts
      // ignore tab changes, so this is a no-op there.
      _tabController.animateTo(result.side);
    }
  }


  // Language / sprite-style / about helpers moved to AppSettingsMenu.
  // _showAboutDialog stays — the footer credit-line still opens it.

  /// Chip for a field-state ability (aura/ruin) in the battle conditions
  /// dialog. Auto-locked to ON when either the attacker or defender has
  /// the ability — its field-state is then inevitable and user-toggling
  /// would be misleading.
  Widget _envFieldChip({
    required String label,
    required String ability,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final forced = _attacker.selectedAbility == ability ||
        _defender.selectedAbility == ability;
    return FilterChip(
      showCheckmark: false,
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: forced || value,
      onSelected: forced ? null : onChanged,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showBattleConditionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            // Redundant header dropped — the button the user tapped
            // already said "배틀환경"; repeating it inside wastes
            // vertical space on short screens.
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: SingleChildScrollView(
              // Scroll when the chip list is taller than the viewport
              // leaves room for it (small phones / landscape). Without
              // this the column just overflows off the bottom of the
              // dialog.
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weather (radio - single select)
                Text(AppStrings.t('toolbar.weather'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Wrap(
                  spacing: 4,
                  children: Weather.values.where((w) => w != Weather.none).map((w) {
                    final selected = _weather == w;
                    final label = KoStrings.getWeatherName(w);
                    return ChoiceChip(
                      showCheckmark: false,
                      label: Text(label, style: const TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _weather = selected ? Weather.none : w);
                        setDialogState(() {});
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Terrain (radio - single select)
                Text(AppStrings.t('toolbar.terrain'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Wrap(
                  spacing: 4,
                  children: Terrain.values.where((t) => t != Terrain.none).map((t) {
                    final selected = _terrain == t;
                    final label = KoStrings.getTerrainName(t);
                    return ChoiceChip(
                      showCheckmark: false,
                      label: Text(label, style: const TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _terrain = selected ? Terrain.none : t);
                        setDialogState(() {});
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Room + Gravity (checkboxes - multi select)
                Text(AppStrings.t('toolbar.room'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Wrap(
                  spacing: 4,
                  children: [
                    FilterChip(
                      showCheckmark: false,
                      label: Text(KoStrings.getRoomName(Room.trickRoom), style: const TextStyle(fontSize: 13)),
                      selected: _room.trickRoom,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(trickRoom: v));
                        setDialogState(() {});
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    FilterChip(
                      showCheckmark: false,
                      label: Text(KoStrings.getRoomName(Room.magicRoom), style: const TextStyle(fontSize: 13)),
                      selected: _room.magicRoom,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(magicRoom: v));
                        setDialogState(() {});
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    FilterChip(
                      showCheckmark: false,
                      label: Text(KoStrings.getRoomName(Room.wonderRoom), style: const TextStyle(fontSize: 13)),
                      selected: _room.wonderRoom,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(wonderRoom: v));
                        setDialogState(() {});
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    FilterChip(
                      showCheckmark: false,
                      label: Text(KoStrings.gravityName, style: const TextStyle(fontSize: 13)),
                      selected: _room.gravity,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(gravity: v));
                        setDialogState(() {});
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Aura — forced ON when either side's ability matches
                Text(AppStrings.t('section.aura'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Wrap(
                  spacing: 4,
                  children: [
                    _envFieldChip(
                      label: AppStrings.t('damage.allyFairyAura'),
                      ability: 'Fairy Aura',
                      value: _auras.fairyAura,
                      onChanged: (v) {
                        setState(() => _auras = _auras.copyWith(fairyAura: v));
                        setDialogState(() {});
                      },
                    ),
                    _envFieldChip(
                      label: AppStrings.t('damage.allyDarkAura'),
                      ability: 'Dark Aura',
                      value: _auras.darkAura,
                      onChanged: (v) {
                        setState(() => _auras = _auras.copyWith(darkAura: v));
                        setDialogState(() {});
                      },
                    ),
                    _envFieldChip(
                      label: AppStrings.t('damage.allyAuraBreak'),
                      ability: 'Aura Break',
                      value: _auras.auraBreak,
                      onChanged: (v) {
                        setState(() => _auras = _auras.copyWith(auraBreak: v));
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Ruin — dex order: Tablets → Sword → Vessel → Beads
                Text(AppStrings.t('section.ruin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Wrap(
                  spacing: 4,
                  children: [
                    _envFieldChip(
                      label: AppStrings.t('damage.allyTabletsOfRuin'),
                      ability: 'Tablets of Ruin',
                      value: _ruins.tabletsOfRuin,
                      onChanged: (v) {
                        setState(() => _ruins = _ruins.copyWith(tabletsOfRuin: v));
                        setDialogState(() {});
                      },
                    ),
                    _envFieldChip(
                      label: AppStrings.t('damage.allySwordOfRuin'),
                      ability: 'Sword of Ruin',
                      value: _ruins.swordOfRuin,
                      onChanged: (v) {
                        setState(() => _ruins = _ruins.copyWith(swordOfRuin: v));
                        setDialogState(() {});
                      },
                    ),
                    _envFieldChip(
                      label: AppStrings.t('damage.allyVesselOfRuin'),
                      ability: 'Vessel of Ruin',
                      value: _ruins.vesselOfRuin,
                      onChanged: (v) {
                        setState(() => _ruins = _ruins.copyWith(vesselOfRuin: v));
                        setDialogState(() {});
                      },
                    ),
                    _envFieldChip(
                      label: AppStrings.t('damage.allyBeadsOfRuin'),
                      ability: 'Beads of Ruin',
                      value: _ruins.beadsOfRuin,
                      onChanged: (v) {
                        setState(() => _ruins = _ruins.copyWith(beadsOfRuin: v));
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _weather = Weather.none;
                    _terrain = Terrain.none;
                    _room = const RoomConditions();
                  });
                  setDialogState(() {});
                },
                child: Text(AppStrings.t('toolbar.conditionsReset')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppStrings.t('action.close')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Abilities that force a field-state (aura/ruin) ON regardless of the
  /// user's toggle. If either Pokemon has one, the field is active.
  static const _auraRuinAbilities = {
    'Fairy Aura', 'Dark Aura', 'Aura Break',
    'Tablets of Ruin', 'Sword of Ruin', 'Vessel of Ruin', 'Beads of Ruin',
  };

  /// Names of every currently-active battle condition, in display order:
  /// weather → terrain → rooms → auras → ruins. Ability-forced entries
  /// (e.g. Chien-Pao for Sword of Ruin) are included.
  List<String> get _activeConditionNames {
    final names = <String>[];
    if (_weather != Weather.none) names.add(KoStrings.getWeatherName(_weather));
    if (_terrain != Terrain.none) names.add(KoStrings.getTerrainName(_terrain));
    if (_room.trickRoom) names.add(KoStrings.getRoomName(Room.trickRoom));
    if (_room.magicRoom) names.add(KoStrings.getRoomName(Room.magicRoom));
    if (_room.wonderRoom) names.add(KoStrings.getRoomName(Room.wonderRoom));
    if (_room.gravity) names.add(KoStrings.gravityName);
    if (_auras.fairyAura || _abilityPresent('Fairy Aura')) names.add(AppStrings.t('damage.allyFairyAura'));
    if (_auras.darkAura || _abilityPresent('Dark Aura')) names.add(AppStrings.t('damage.allyDarkAura'));
    if (_auras.auraBreak || _abilityPresent('Aura Break')) names.add(AppStrings.t('damage.allyAuraBreak'));
    if (_ruins.tabletsOfRuin || _abilityPresent('Tablets of Ruin')) names.add(AppStrings.t('damage.allyTabletsOfRuin'));
    if (_ruins.swordOfRuin || _abilityPresent('Sword of Ruin')) names.add(AppStrings.t('damage.allySwordOfRuin'));
    if (_ruins.vesselOfRuin || _abilityPresent('Vessel of Ruin')) names.add(AppStrings.t('damage.allyVesselOfRuin'));
    if (_ruins.beadsOfRuin || _abilityPresent('Beads of Ruin')) names.add(AppStrings.t('damage.allyBeadsOfRuin'));
    return names;
  }

  bool get _hasActiveConditions => _activeConditionNames.isNotEmpty;

  /// Mobile: battle conditions button. When no condition is active,
  /// shows the "배틀환경" label; as soon as something is on, replaces
  /// the label with a comma-separated list of active condition names.
  Widget _battleConditionsButton() {
    final names = _activeConditionNames;
    final active = names.isNotEmpty;
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurface;
    final label = active
        ? names.join(' · ')
        : AppStrings.t('toolbar.battleConditions');
    return GestureDetector(
      onTap: _showBattleConditionsDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: active ? activeColor : inactiveColor,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _weatherDropdown(double fontSize) {
    final active = _weather != Weather.none;
    return PopupMenuButton<Weather>(
      initialValue: _weather,
      tooltip: AppStrings.t('toolbar.weather'),
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              active
                  ? KoStrings.getWeatherName(_weather)
                  : AppStrings.t('toolbar.weather'),
              style: TextStyle(
                fontSize: fontSize,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade500,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => Weather.values
          .map((w) => PopupMenuItem(
              value: w,
              child: Text(KoStrings.getWeatherName(w))))
          .toList(),
      onSelected: (v) => setState(() => _weather = v),
    );
  }

  Widget _terrainDropdown(double fontSize) {
    final active = _terrain != Terrain.none;
    return PopupMenuButton<Terrain>(
      initialValue: _terrain,
      tooltip: AppStrings.t('toolbar.terrain'),
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              active
                  ? KoStrings.getTerrainName(_terrain)
                  : AppStrings.t('toolbar.terrain'),
              style: TextStyle(
                fontSize: fontSize,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade500,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => Terrain.values
          .map((t) => PopupMenuItem(
              value: t,
              child: Text(KoStrings.getTerrainName(t))))
          .toList(),
      onSelected: (v) => setState(() => _terrain = v),
    );
  }

  Widget _roomDropdown(double fontSize) {
    return PopupMenuButton<String>(
      tooltip: '${AppStrings.t('toolbar.room')}',
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.t('toolbar.room'), style: TextStyle(
              fontSize: fontSize,
              color: _room.hasAny
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
              fontWeight: _room.hasAny ? FontWeight.bold : FontWeight.normal,
            )),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _stickyCheckItem(
          label: KoStrings.getRoomName(Room.trickRoom),
          getValue: () => _room.trickRoom,
          onToggle: () => setState(() => _room = _room.copyWith(trickRoom: !_room.trickRoom)),
        ),
        _stickyCheckItem(
          label: KoStrings.getRoomName(Room.magicRoom),
          getValue: () => _room.magicRoom,
          onToggle: () => setState(() => _room = _room.copyWith(magicRoom: !_room.magicRoom)),
        ),
        _stickyCheckItem(
          label: KoStrings.getRoomName(Room.wonderRoom),
          getValue: () => _room.wonderRoom,
          onToggle: () => setState(() => _room = _room.copyWith(wonderRoom: !_room.wonderRoom)),
        ),
        _stickyCheckItem(
          label: KoStrings.gravityName,
          getValue: () => _room.gravity,
          onToggle: () => setState(() => _room = _room.copyWith(gravity: !_room.gravity)),
        ),
      ],
    );
  }

  /// True when either side's selected ability matches [ability] — the
  /// corresponding field-state toggle should be locked ON.
  bool _abilityPresent(String ability) =>
      _attacker.selectedAbility == ability ||
      _defender.selectedAbility == ability;

  /// Checkbox menu entry that DOESN'T close the parent popup on tap —
  /// wraps the body in a non-interactive PopupMenuItem (so Flutter's
  /// built-in close-on-select doesn't fire) and uses a StatefulBuilder
  /// to reflect live state changes inside the still-open popup.
  PopupMenuEntry<String> _stickyCheckItem({
    required String label,
    required bool Function() getValue,
    required VoidCallback onToggle,
    bool enabled = true,
  }) {
    // Force text color to normal onSurface — [PopupMenuItem] with
    // `enabled: false` otherwise dims every child via DefaultTextStyle.
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      enabled: false,
      padding: EdgeInsets.zero,
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          final value = getValue();
          return InkWell(
            onTap: enabled ? () { onToggle(); setLocal(() {}); } : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value: value,
                      onChanged: enabled
                          ? (_) { onToggle(); setLocal(() {}); }
                          : null,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _auraDropdown(double fontSize) {
    final fairyForced = _abilityPresent('Fairy Aura');
    final darkForced = _abilityPresent('Dark Aura');
    final breakForced = _abilityPresent('Aura Break');
    final anyActive = fairyForced || darkForced || breakForced ||
        _auras.hasAny;
    return PopupMenuButton<String>(
      tooltip: AppStrings.t('section.aura'),
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.t('section.aura'), style: TextStyle(
              fontSize: fontSize,
              color: anyActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
              fontWeight: anyActive ? FontWeight.bold : FontWeight.normal,
            )),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _stickyCheckItem(
          label: AppStrings.t('damage.allyFairyAura'),
          getValue: () => fairyForced || _auras.fairyAura,
          onToggle: () => setState(() => _auras = _auras.copyWith(fairyAura: !_auras.fairyAura)),
          enabled: !fairyForced,
        ),
        _stickyCheckItem(
          label: AppStrings.t('damage.allyDarkAura'),
          getValue: () => darkForced || _auras.darkAura,
          onToggle: () => setState(() => _auras = _auras.copyWith(darkAura: !_auras.darkAura)),
          enabled: !darkForced,
        ),
        _stickyCheckItem(
          label: AppStrings.t('damage.allyAuraBreak'),
          getValue: () => breakForced || _auras.auraBreak,
          onToggle: () => setState(() => _auras = _auras.copyWith(auraBreak: !_auras.auraBreak)),
          enabled: !breakForced,
        ),
      ],
    );
  }

  Widget _ruinDropdown(double fontSize) {
    final tabletsForced = _abilityPresent('Tablets of Ruin');
    final swordForced = _abilityPresent('Sword of Ruin');
    final vesselForced = _abilityPresent('Vessel of Ruin');
    final beadsForced = _abilityPresent('Beads of Ruin');
    final anyActive = tabletsForced || swordForced || vesselForced ||
        beadsForced || _ruins.hasAny;
    return PopupMenuButton<String>(
      tooltip: AppStrings.t('section.ruin'),
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.t('section.ruin'), style: TextStyle(
              fontSize: fontSize,
              color: anyActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
              fontWeight: anyActive ? FontWeight.bold : FontWeight.normal,
            )),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _stickyCheckItem(
          label: AppStrings.t('damage.allyTabletsOfRuin'),
          getValue: () => tabletsForced || _ruins.tabletsOfRuin,
          onToggle: () => setState(() => _ruins = _ruins.copyWith(tabletsOfRuin: !_ruins.tabletsOfRuin)),
          enabled: !tabletsForced,
        ),
        _stickyCheckItem(
          label: AppStrings.t('damage.allySwordOfRuin'),
          getValue: () => swordForced || _ruins.swordOfRuin,
          onToggle: () => setState(() => _ruins = _ruins.copyWith(swordOfRuin: !_ruins.swordOfRuin)),
          enabled: !swordForced,
        ),
        _stickyCheckItem(
          label: AppStrings.t('damage.allyVesselOfRuin'),
          getValue: () => vesselForced || _ruins.vesselOfRuin,
          onToggle: () => setState(() => _ruins = _ruins.copyWith(vesselOfRuin: !_ruins.vesselOfRuin)),
          enabled: !vesselForced,
        ),
        _stickyCheckItem(
          label: AppStrings.t('damage.allyBeadsOfRuin'),
          getValue: () => beadsForced || _ruins.beadsOfRuin,
          onToggle: () => setState(() => _ruins = _ruins.copyWith(beadsOfRuin: !_ruins.beadsOfRuin)),
          enabled: !beadsForced,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWideLayout;
    final maxAppBarWidth = MediaQuery.of(context).size.width >= 1400 ? 1920.0 : 1440.0;
    final toolbarFontSize = isWide ? 16.0 : 14.0;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        actions: const [SizedBox.shrink()],
        title: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? maxAppBarWidth : double.infinity),
            child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 0),
            child: Row(
          children: [
            if (isWide) ...[
              // Wide: keep separate dropdowns
              _weatherDropdown(toolbarFontSize),
              _terrainDropdown(toolbarFontSize),
              _roomDropdown(toolbarFontSize),
              _auraDropdown(toolbarFontSize),
              _ruinDropdown(toolbarFontSize),
              const Spacer(),
              TextButton.icon(
                onPressed: _swapSides,
                icon: const Icon(Icons.swap_horiz),
                label: Text(AppStrings.t('toolbar.swap'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                onPressed: _resetBothSides,
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.t('toolbar.reset'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              // Mode toggle lives next to swap/reset on wide so it
              // sits in the user's main scan path (capture used to
              // be here — moved out because the simple↔extended
              // toggle was getting buried in the far-right cluster
              // with locale/theme controls).
              TextButton.icon(
                onPressed: _toggleSimpleMode,
                icon: const Icon(Icons.tune),
                label: Text(
                    AppStrings.t(_simpleMode
                        ? 'simple.shortExtended'
                        : 'simple.shortSimple'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              // Dex / Move Dex / Team Builder toolbar entries lived
              // here back when the shared bottom nav was hidden on
              // wide layouts. The bar is now always visible (see
              // AppBottomNav), so these duplicated the same tab
              // switches one row apart and were just clutter.
              const Spacer(),
              // Single overflow menu — same component the narrow
              // layout uses below. Wide layout used to surface
              // sprite-style / language / theme / about as separate
              // icon buttons; the user asked to consolidate, matching
              // mobile's "one ⋮ button" affordance.
              AppSettingsMenu(
                onLanguageChanged: () {
                  _loadAbilities();
                  _loadItems();
                  setState(() {
                    _resetCounter++;
                  });
                },
              ),
              const SizedBox(width: 8),
            ] else ...[
              // Mobile: battle conditions fills the left-hand gap up to
              // the swap/reset/menu cluster. Expanded + align-left lets
              // the label use its natural width and only ellipsis when
              // it would actually collide with the right-side buttons.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _battleConditionsButton(),
                ),
              ),
              // Swap + Reset are available in both modes. The mode
              // toggle gets its own dedicated slot right before the
              // overflow menu so users don't have to dig for it.
              TextButton(
                onPressed: _swapSides,
                child: Text(AppStrings.t('toolbar.swap'), style: TextStyle(fontSize: toolbarFontSize, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: _resetBothSides,
                child: Text(AppStrings.t('toolbar.reset'), style: TextStyle(fontSize: toolbarFontSize, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: _toggleSimpleMode,
                child: Text(
                  AppStrings.t(_simpleMode
                      ? 'simple.shortExtended'
                      : 'simple.shortSimple'),
                  style: TextStyle(fontSize: toolbarFontSize, fontWeight: FontWeight.w600),
                ),
              ),
              AppSettingsMenu(
                onLanguageChanged: () {
                  // Calc owns localized ability/item name caches that
                  // have to be re-pulled in the new language; for
                  // the dex / move dex / team builder screens a
                  // plain setState is enough.
                  _loadAbilities();
                  _loadItems();
                  setState(() => _resetCounter++);
                },
              ),
            ],
          ],
        ),
          ),
          ),
        ),
        bottom: (isWide || _simpleMode)
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: AppStrings.t('tab.attacker')),
                  Tab(text: AppStrings.t('tab.defender')),
                  Tab(text: AppStrings.t('tab.damage')),
                  Tab(text: AppStrings.t('tab.speed')),
                ],
              ),
      ),
      // Only the active mode's subtree is mounted — IndexedStack kept
      // both laid out, which on iOS made the keyboard animation feel
      // sluggish because every viewInsets change re-laid out both
      // normal and simple subtrees. State still persists because the
      // attacker/defender BattlePokemonState live on this parent and
      // Simple Mode re-hydrates its controllers from them on init.
      body: _simpleMode
          ? SimpleModeView(
              attacker: _attacker,
              defender: _defender,
              weather: _weather,
              terrain: _terrain,
              room: _room,
              auras: _auras,
              ruins: _ruins,
              resetCounter: _resetCounter,
              onChanged: _onPanelChanged,
              abilityNameMap: _abilityNameMap,
              pickableAbilities: _pickableAbilities,
              itemNameMap: _itemNameMap,
              onSaveSide: (side) => _showSaveDialog(
                side, side == 0 ? _attacker : _defender),
              onLoadSide: (side) => _showLoadSheet(side),
              onResetSide: (side) => _resetSide(side),
              onOpenDexForSide: (side) => _openDex(
                initialName:
                    (side == 0 ? _attacker : _defender).pokemonName,
              ),
            )
          : GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1400) {
            return _buildExtraWideLayout();
          } else if (constraints.maxWidth >= 1050) {
            return _buildWideLayout();
          }
          return _buildNarrowLayout();
        },
      )),
    );
  }

  /// Extra-wide layout: 4 columns (Attacker | Defender | Damage | Speed)
  /// Each column capped at 480px, centered on very wide screens.
  Widget _buildExtraWideLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1920),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPokemonTab(0, AppStrings.t('tab.attacker'), _attacker, _attackerPanelKey),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _buildPokemonTab(1, AppStrings.t('tab.defender'), _defender, _defenderPanelKey),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _buildDamageCalcTab(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SpeedCompareTab(
                attacker: _attacker,
                defender: _defender,
                weather: _weather,
                terrain: _terrain,
                room: _room,
                onChanged: _onPanelChanged,
                resetCounter: _resetCounter,
                abilityNameMap: _abilityNameMap,
                itemNameMap: _itemNameMap,
                useSpMode: _useSpMode,
                onSpModeChanged: _setSpMode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wide layout: 3 columns (Attacker | Defender | Damage+Speed tabs)
  /// Each column capped at 480px, centered.
  Widget _buildWideLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPokemonTab(0, AppStrings.t('tab.attacker'), _attacker, _attackerPanelKey),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _buildPokemonTab(1, AppStrings.t('tab.defender'), _defender, _defenderPanelKey),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _buildRightPanel(),
            ),
          ],
        ),
      ),
    );
  }

  /// Right panel for wide layout: Damage and Speed as sub-tabs
  Widget _buildRightPanel() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: AppStrings.t('tab.damage')),
              Tab(text: AppStrings.t('tab.speed')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDamageCalcTab(),
                SpeedCompareTab(
                  attacker: _attacker,
                  defender: _defender,
                  weather: _weather,
                  terrain: _terrain,
                  room: _room,
                  onChanged: _onPanelChanged,
                  resetCounter: _resetCounter,
                  abilityNameMap: _abilityNameMap,
                  itemNameMap: _itemNameMap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Narrow layout: current 4-tab mobile layout
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPokemonTab(0, AppStrings.t('tab.attacker'), _attacker, _attackerPanelKey),
              _buildPokemonTab(1, AppStrings.t('tab.defender'), _defender, _defenderPanelKey),
              _buildDamageCalcTab(),
              SpeedCompareTab(
                key: _speedTabKey,
                attacker: _attacker,
                defender: _defender,
                weather: _weather,
                terrain: _terrain,
                room: _room,
                onChanged: _onPanelChanged,
                resetCounter: _resetCounter,
                abilityNameMap: _abilityNameMap,
                itemNameMap: _itemNameMap,
                useSpMode: _useSpMode,
                onSpModeChanged: _setSpMode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPokemonTab(int side, String label, BattlePokemonState state, GlobalKey<PokemonPanelState> panelKey) {
    final isAttacker = side == 0;
    // Cache the opponent's derived numbers once per build — the panel
    // needs Speed + Attack + Defense + SpDefense, and previously each
    // accessor recomputed the full Stats. Same-build local so any
    // setState produces a fresh value naturally.
    final opponent = isAttacker ? _defender : _attacker;
    final opponentStats = _calcStats(opponent);
    final opponentSpeed = _calcEffectiveSpeed(opponent);
    return PokemonPanel(
            key: panelKey,
            state: state,
            weather: _weather,
            terrain: _terrain,
            room: _room,
            auras: _auras,
            ruins: _ruins,
            label: label,
            onChanged: _onPanelChanged,
            onSave: () => _showSaveDialog(side, state),
            onLoad: () => _showLoadSheet(side),
            onReset: () => _resetSide(side),
            onOpenDex: () => _openDex(initialName: state.pokemonName),
            resetCounter: _resetCounter,
            isAttacker: isAttacker,
            opponentSpeed: opponentSpeed,
            opponentAlwaysLast: _isAlwaysLast(opponent),
            opponentAttack: opponentStats.attack,
            opponentDefense: opponentStats.defense,
            opponentSpDefense: opponentStats.spDefense,
            opponentGender: opponent.gender,
            opponentWeight: BattleFacade.effectiveWeight(opponent),
            opponentHpPercent: opponent.hpPercent,
            opponentItem: opponent.selectedItem,
            opponentAbility: opponent.selectedAbility,
            doublesExpanded: _doublesExpanded,
            onDoublesExpandToggle: () =>
                _setDoublesExpanded(!_doublesExpanded),
            useSpMode: _useSpMode,
            onSpModeChanged: _setSpMode,
            abilityNameMap: _abilityNameMap,
            itemNameMap: _itemNameMap,
          );
  }


  /// Get the 결정력 for a specific move slot (always up-to-date).
  /// Caller passes pre-computed defender attack/speed so the damage
  /// tab doesn't recompute the same Stats/Speed once per slot.
  int? _getOffensivePower(int moveIndex,
      {required int defAttack, required int defSpeed}) {
    return BattleFacade.calcOffensivePower(
      state: _attacker,
      moveIndex: moveIndex,
      weather: _weather,
      terrain: _terrain,
      room: _room,
      auras: _auras,
      ruins: _ruins,
      opponentSpeed: defSpeed,
      opponentAttack: defAttack,
      opponentGender: _defender.gender,
      opponentWeight: BattleFacade.effectiveWeight(_defender),
      opponentHpPercent: _defender.hpPercent,
      opponentItem: _defender.selectedItem,
      opponentAbility: _defender.selectedAbility,
    );
  }

  /// Get the 내구 for the defender (for display only).
  ({int physical, int special}) _getDefensiveBulk() {
    return BattleFacade.calcBulk(
      state: _defender,
      weather: _weather,
      terrain: _terrain,
      room: _room,
      ruins: _ruins,
      opponentAbility: _attacker.selectedAbility,
    );
  }

  DamageResult _calcDamage(int moveIndex,
      {required int atkSpeed,
      required int defSpeed,
      required int defAttack}) {
    return DamageCalculator.calculate(
      attacker: _attacker,
      defender: _defender,
      moveIndex: moveIndex,
      weather: _weather,
      terrain: _terrain,
      room: _room,
      auras: _auras,
      ruins: _ruins,
      opponentAttack: defAttack,
      opponentSpeed: defSpeed,
      myEffectiveSpeed: atkSpeed,
      opponentGender: _defender.gender,
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Damage sum (대미지 합산)
  //
  // Tap a move's result block to add it to a running sum at the
  // bottom of the damage tab. Backed by the existing per-shot 16-roll
  // distributions and `RandomFactor.multiHitDistributionFromRolls` —
  // each shot (single-hit move = one shot, multi-hit move = N shots)
  // is treated identically and convolved into a joint distribution.
  // ────────────────────────────────────────────────────────────────────

  /// Snapshot of the attacker's move name list — captured at first add.
  /// On every build we compare against the current names; mismatch →
  /// reset (the user's mental anchor was tied to specific move names).
  List<String?> _currentMoveNames() =>
      [for (final m in _attacker.moves) m?.name];

  /// True for OHKO / Sheer Cold style moves whose damage isn't a
  /// normal stat-based calc — these shouldn't be summable. Status
  /// moves are already filtered upstream (the result card collapses
  /// to nothing for them).
  bool _moveSummable(Move move) {
    if (move.category == MoveCategory.status) return false;
    if (move.hasTag(MoveTags.ohko)) return false;
    if (move.hasTag(MoveTags.ohkoIceImmune)) return false;
    return true;
  }

  /// Total selected count across all slots.
  int get _summedTotal =>
      _summedSlots.values.fold(0, (a, b) => a + b);

  void _addToSum(int slot) {
    final move = _attacker.moves[slot];
    if (move == null || !_moveSummable(move)) return;
    if (_summedTotal >= _kSumMax) return;
    setState(() {
      // Capture the signature lazily so an empty sum doesn't pin to
      // an unrelated move list state.
      if (_summedSlots.isEmpty) {
        _summedSig = _currentMoveNames();
      }
      _summedSlots[slot] = (_summedSlots[slot] ?? 0) + 1;
    });
  }

  void _removeSumEntry(int slot) {
    if (!_summedSlots.containsKey(slot)) return;
    setState(() {
      _summedSlots.remove(slot);
      if (_summedSlots.isEmpty) _summedSig = const [];
    });
  }

  void _resetSum() {
    if (_summedSlots.isEmpty) return;
    setState(() {
      _summedSlots.clear();
      _summedSig = const [];
    });
  }

  /// Convolve two damage distributions (a + b → a+b). Output is
  /// `{damage: probability}`. Pure helper — no closure on instance
  /// state — so safe to call from [_setKoLabel].
  Map<int, double> _convolveDist(Map<int, double> a, Map<int, double> b) {
    final out = <int, double>{};
    for (final ea in a.entries) {
      for (final eb in b.entries) {
        final k = ea.key + eb.key;
        out[k] = (out[k] ?? 0) + ea.value * eb.value;
      }
    }
    return out;
  }

  /// Compute "확정/난수 N세트 (XX.X%)" for the sum. Returns ('', grey)
  /// when the result isn't worth displaying (sum is 0 damage or the
  /// 5-set cap can't reach the defender's HP).
  (String, Color) _setKoLabel(
    Map<int, double> oneSetDist,
    int defenderHp, {
    required int minDmg,
    required int maxDmg,
  }) {
    if (maxDmg <= 0 || defenderHp <= 0) return ('', Colors.grey);
    const cap = 5;

    // Quick range bounds: smallest N where guaranteed (every roll
    // would already KO) and smallest N where ANY roll could KO.
    final guaranteedN = minDmg > 0 ? (defenderHp / minDmg).ceil() : cap + 1;
    final possibleN = (defenderHp / maxDmg).ceil();
    if (possibleN > cap) return ('', Colors.grey);

    if (guaranteedN <= possibleN) {
      // Min already ≥ HP at this N → 확정.
      final tmpl = AppStrings.t('damage.sum.guaranteedSet');
      return (tmpl.replaceFirst('{n}', '$possibleN'), Colors.red);
    }

    // Random KO at this N: convolve N copies of the one-set dist
    // and integrate ≥ HP.
    var dist = oneSetDist;
    for (int i = 1; i < possibleN; i++) {
      dist = _convolveDist(dist, oneSetDist);
    }
    double prob = 0;
    for (final e in dist.entries) {
      if (e.key >= defenderHp) prob += e.value;
    }
    if (prob <= 0) return ('', Colors.grey);
    if (prob >= 1.0 - 1e-9) {
      final tmpl = AppStrings.t('damage.sum.guaranteedSet');
      return (tmpl.replaceFirst('{n}', '$possibleN'), Colors.red);
    }
    final pct = prob * 100;
    final pctText = pct >= 99.95
        ? '>99.9'
        : pct < 0.05 ? '<0.1' : pct.toStringAsFixed(1);
    final tmpl = AppStrings.t('damage.sum.randomSet');
    return (
      '${tmpl.replaceFirst('{n}', '$possibleN')} ($pctText%)',
      Colors.orange,
    );
  }

  /// Drops the sum if the move list has changed since selection. Called
  /// at the top of [_buildDamageCalcTab]; safe even when the sum is
  /// empty (early exit).
  void _maybeInvalidateSum() {
    if (_summedSlots.isEmpty) return;
    final now = _currentMoveNames();
    bool same = now.length == _summedSig.length;
    if (same) {
      for (int i = 0; i < now.length; i++) {
        if (now[i] != _summedSig[i]) { same = false; break; }
      }
    }
    if (!same) {
      // Build-time invalidation: schedule the clear for after the
      // frame so we don't setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_summedSlots.isEmpty) return;
        setState(() {
          _summedSlots.clear();
          _summedSig = const [];
        });
      });
    }
  }

  Widget _buildDamageCalcTab() {
    // Cache stats/speed once per build — every setState forces a fresh
    // build() so these always reflect current attacker/defender state,
    // and we avoid recomputing the same Stats/Speed 6×–9× across the
    // 4 move rows + summary header (especially load-bearing in wide
    // mode where every panel edit re-runs this whole tab).
    final defStats = _calcStats(_defender);
    final atkSpeed = _calcEffectiveSpeed(_attacker);
    final defSpeed = _calcEffectiveSpeed(_defender);

    final defMaxHp = defStats.hp;
    final defCurrentHp = (defMaxHp * _defender.hpPercent / 100).floor();
    final bulk = _getDefensiveBulk();

    // Stat / item / weather changes flow through naturally because we
    // recompute on every build. But if the attacker's *moves* shifted
    // since the user last added one, the sum would silently mean
    // something different — drop it instead.
    _maybeInvalidateSum();

    // Sticky-footer layout: scrollable cards on top, sum block pinned
    // to the bottom of the tab. Without this, on short viewports the
    // user would have to scroll past 4 move cards to reach the sum
    // every time they tapped one — broken with each new selection.
    // Footer collapses to a thin hint when empty so the scrollable
    // area gives up almost no vertical space in the common case.
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    // Header line 1: names
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_attacker.localizedPokemonName}${_dynamaxLabel(_attacker)} → ${_defender.localizedPokemonName}${_dynamaxLabel(_defender)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Header line 2: types
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dmgTypeText(_attacker),
                        const Text('  →  ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        _dmgTypeText(_defender),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HP $defCurrentHp/$defMaxHp | ${AppStrings.t('section.physBulk')} ${bulk.physical} | ${AppStrings.t('section.specBulk')} ${bulk.special}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Defensive condition checkboxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dmgCheck(AppStrings.t('damage.reflect'), _defender.reflect, (v) {
                          setState(() => _defender.reflect = v);
                        }),
                        const SizedBox(width: 16),
                        _dmgCheck(AppStrings.t('damage.lightScreen'), _defender.lightScreen, (v) {
                          setState(() => _defender.lightScreen = v);
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),

                    for (int i = 0; i < 4; i++)
                      _buildMoveResult(i, bulk,
                          atkSpeed: atkSpeed,
                          defSpeed: defSpeed,
                          defAttack: defStats.attack),
                  ],
                ),
              ),
            ),
            // Footer is its own composite layer so the scroll above
          // doesn't drag it through the rasterizer every frame.
          RepaintBoundary(
            child: _buildSumFooter(
              atkSpeed: atkSpeed,
              defSpeed: defSpeed,
              defAttack: defStats.attack,
              defenderHp: defCurrentHp,
              defenderMaxHp: defMaxHp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveResult(int index, ({int physical, int special}) bulk,
      {required int atkSpeed,
      required int defSpeed,
      required int defAttack}) {
    final move = _attacker.moves[index];
    if (move == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('${AppStrings.t('section.moves')} ${index + 1}: ${AppStrings.t('damage.moveNotSet')}',
            style: TextStyle(fontSize: 16, color: Colors.grey[400])),
      );
    }
    // Status moves carry no damage information — rendering the standard
    // damage card just shows "0~0%" which reads as a bug. Hide the slot
    // entirely; the move is still selected, the user just won't see a
    // result block for it.
    if (move.category == MoveCategory.status) {
      return const SizedBox.shrink();
    }

    final result = _calcDamage(index,
        atkSpeed: atkSpeed, defSpeed: defSpeed, defAttack: defAttack);
    final effectiveType = result.move.type == PokemonType.typeless
        ? null : result.move.type;
    final offLabel = result.isPhysical ? AppStrings.t('damage.physical') : AppStrings.t('damage.special');
    final defLabel = result.targetPhysDef ? AppStrings.t('damage.physical') : AppStrings.t('damage.special');
    final offPower = _getOffensivePower(index,
        defAttack: defAttack, defSpeed: defSpeed);
    final defBulk = result.targetPhysDef ? bulk.physical : bulk.special;

    // Effectiveness label
    final eff = result.effectiveness;
    final String effLabel;
    final Color effColor;
    if (eff == 0) {
      effLabel = '${AppStrings.t('eff.immune')} (x0)';
      effColor = Colors.grey;
    } else if (eff >= 4) {
      effLabel = '${AppStrings.t('eff.superEffective4x')} (x${ _fmtEff(eff) })';
      effColor = Colors.red[700]!;
    } else if (eff >= 2) {
      effLabel = '${AppStrings.t('eff.superEffective')} (x${ _fmtEff(eff) })';
      effColor = Colors.red;
    } else if (eff <= 0.25) {
      effLabel = '${AppStrings.t('eff.notVeryEffective025')} (x${ _fmtEff(eff) })';
      effColor = Colors.blue[700]!;
    } else if (eff <= 0.5) {
      effLabel = '${AppStrings.t('eff.notVeryEffective')} (x${ _fmtEff(eff) })';
      effColor = Colors.blue;
    } else {
      effLabel = '${AppStrings.t('eff.neutral')} (x${ _fmtEff(eff) })';
      effColor = Colors.grey;
    }

    // KO info using N-hit analysis
    String koText = '';
    Color koColor = Colors.grey;
    if (!result.isEmpty && eff > 0) {
      final info = result.koInfo;
      if (info.hits > 0) {
        if (info.koCount >= info.totalCount) {
          koText = '${AppStrings.t('ko.guaranteed')} ${info.hits}${AppStrings.t('ko.hit')}';
          koColor = info.hits <= 2 ? Colors.red : Colors.orange;
        } else {
          final pct = (info.koCount / info.totalCount * 100);
          koText = '${AppStrings.t('ko.random')} ${info.hits}${AppStrings.t('ko.hit')} (${pct.toStringAsFixed(1)}%)';
          koColor = Colors.orange;
        }
      }
    }

    final typeColor = effectiveType != null
        ? KoStrings.getTypeColor(effectiveType)
        : Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Color.lerp(baseBg, typeColor, isDark ? 0.18 : 0.09);

    final summable = _moveSummable(result.move);
    final selectedCount = _summedSlots[index] ?? 0;
    final scheme = Theme.of(context).colorScheme;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        // Selected slot gets a thin accent border so the user can spot
        // which results are currently in the sum at a glance.
        border: selectedCount > 0
            ? Border.all(color: scheme.primary, width: 1.5)
            : null,
      ),
      // 역산 chip + Stack/Positioned scaffolding intentionally
      // omitted for 1.9.x — the reverse-calc feature is deferred
      // to 1.10. Module and dialog code (reverse_calc.dart,
      // reverse_calc_dialog.dart) are kept on main so we can
      // re-enable later without re-writing.
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Move name + type + effectiveness. Sum selection is shown
                // by the card's accent border + the chips in the sticky
                // footer below — repeating it here as a "×N" badge just
                // crowded the row into wrapping.
                Row(
                  children: [
                    Flexible(
                      child: Text(result.move.localizedName, style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                      )),
                    ),
                    const SizedBox(width: 8),
                    Text(effectiveType != null ? KoStrings.getTypeName(effectiveType) : '-',
                        style: TextStyle(fontSize: 14, color: typeColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(effLabel,
                        style: TextStyle(fontSize: 14, color: effColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
          // 결정력 / 내구 info (display only)
          Text(
            '$offLabel ${AppStrings.t('move.offensive')} ${offPower ?? '-'} → $defLabel ${AppStrings.t('section.bulk')} $defBulk',
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          // % damage + raw damage + KO (scales down if needed, never truncates)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  '${result.minPercent.toStringAsFixed(1)}~${result.maxPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${result.minDamage}~${result.maxDamage})',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (koText.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(koText, style: TextStyle(
                    fontSize: 16, color: koColor, fontWeight: FontWeight.bold,
                  )),
                ],
              ],
            ),
          ),
          // 16-roll distribution. Single-hit moves get one row; multi-hit
          // moves with identical per-hit rolls collapse to one row, but
          // escalating-power (Triple Axel) or Parental-Bond style moves
          // where hits actually differ get one row per hit.
          ..._buildDamageRolls(result),
          // Modifier notes
          if (result.modifierNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: result.modifierNotes.map((note) => Text(
                _formatNote(note),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              )).toList(),
            ),
          ],
        ],
      ),
    );

    // Summable moves (everything except status / OHKO) get an InkWell
    // so a tap adds the slot to the sum. Skipped moves are passed
    // through unwrapped — their result card stays interactive-feeling
    // dead, and the user just doesn't see any feedback on tap.
    //
    // RepaintBoundary isolates each card into its own composite layer
    // so iOS scroll re-uses cached layer pixels (translation only)
    // instead of re-rasterizing all 4 cards every frame during fling.
    final wrapped = summable
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              // Match the card's outer corner so the ripple stays inside.
              borderRadius: BorderRadius.circular(10),
              onTap: () => _addToSum(index),
              child: card,
            ),
          )
        : card;
    return RepaintBoundary(child: wrapped);
  }

  /// Inline "역산" chip living in each damage card's percent row.
  /// Wrapped in a 32-pt OutlinedButton so the row stays vertically
  /// balanced with the KO text alongside it. Tap → opens the
  /// [ReverseCalcDialog] with the current attacker/defender/move
  /// context pre-filled; user types the damage they actually took
  /// and gets the attacker (Atk/SpA EV, nature) candidates back.
  Widget _reverseChip(int moveIndex) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: () => _openReverseCalc(moveIndex),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          AppStrings.t('reverse.chip'),
          style:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _openReverseCalc(int moveIndex) {
    final move = _attacker.moves[moveIndex];
    showDialog(
      context: context,
      builder: (_) => ReverseCalcDialog(
        attacker: _attacker,
        defender: _defender,
        moveIndex: moveIndex,
        weather: _weather,
        terrain: _terrain,
        room: _room,
        auras: _auras,
        ruins: _ruins,
        onApply: move == null
            ? null
            : (candidate) {
                setState(() {
                  applyReverseCalcCandidate(
                      _attacker, candidate, move.category);
                  // Bumping the reset counter forces the attacker
                  // panel's SelectAllField cells to re-pick up the
                  // new EV value (their controllers only re-seed
                  // when their key changes).
                  _resetCounter++;
                });
              },
      ),
    );
  }

  /// Compact sticky-feeling footer block at the bottom of the damage
  /// tab. Empty state is a thin one-line hint; populated state shows
  /// the per-slot chips with × counts, the convolved damage range,
  /// and the resulting KO probability against the defender's current HP.
  Widget _buildSumFooter({
    required int atkSpeed,
    required int defSpeed,
    required int defAttack,
    required int defenderHp,
    required int defenderMaxHp,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final total = _summedTotal;

    if (total == 0) {
      // Compact empty state — small dashed-feel text, no big chrome.
      // SafeArea pushes the hint above the iOS home-indicator bar so
      // the swipe gesture handle isn't sitting on top of the text.
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: Text(
            AppStrings.t('damage.sum.emptyHint'),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Build the joint distribution by concatenating every selected
    // shot (single-hit = 1 shot, multi-hit = N shots) and convolving
    // through the existing helper. This way a single-hit Tackle and a
    // multi-hit Bullet Seed contribute the same way: each shot is a
    // 16-roll uniform distribution.
    final allShots = <List<int>>[];
    final entries = <({int slot, int count, DamageResult result})>[];
    for (final entry in _summedSlots.entries) {
      final slot = entry.key;
      final count = entry.value;
      final res = _calcDamage(slot,
          atkSpeed: atkSpeed, defSpeed: defSpeed, defAttack: defAttack);
      entries.add((slot: slot, count: count, result: res));
      for (int i = 0; i < count; i++) {
        if (res.perHitAllRolls != null) {
          allShots.addAll(res.perHitAllRolls!);
        } else {
          allShots.add(res.allRolls);
        }
      }
    }

    final oneSetDist = RandomFactor.multiHitDistributionFromRolls(allShots);
    int minDmg = 1 << 30, maxDmg = 0;
    for (final e in oneSetDist.entries) {
      if (e.key < minDmg) minDmg = e.key;
      if (e.key > maxDmg) maxDmg = e.key;
    }
    if (oneSetDist.isEmpty) { minDmg = 0; maxDmg = 0; }

    final minPct = defenderMaxHp > 0 ? minDmg / defenderMaxHp * 100 : 0.0;
    final maxPct = defenderMaxHp > 0 ? maxDmg / defenderMaxHp * 100 : 0.0;

    // N-set KO: how many full repetitions of this combo are needed
    // to KO. Mirrors a single move's "1타 / 2타" pattern but the unit
    // is "세트" (one application of the user's selected combo).
    // Cap at 5 — beyond that the answer is rarely actionable in
    // practice, and convolution depth grows with N.
    final (koText, koColor) = _setKoLabel(
      oneSetDist, defenderHp,
      minDmg: minDmg, maxDmg: maxDmg,
    );

    return SafeArea(
      top: false,
      // Push the populated footer above the iOS home-indicator bar
      // too — otherwise the disclaimer / KO line ends up under the
      // swipe gesture handle on devices with no physical home button.
      child: Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${AppStrings.t('damage.sum.title')} ($total/$_kSumMax)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: AppStrings.t('damage.sum.reset'),
                onPressed: _resetSum,
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in entries)
                if (_attacker.moves[e.slot] != null)
                  InputChip(
                    label: Text(
                      e.count > 1
                          ? '${_attacker.moves[e.slot]!.localizedName} ×${e.count}'
                          : _attacker.moves[e.slot]!.localizedName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: () => _removeSumEntry(e.slot),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  '${minPct.toStringAsFixed(1)}~${maxPct.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('($minDmg~$maxDmg)',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                if (koText.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(koText,
                      style: TextStyle(
                          fontSize: 16,
                          color: koColor,
                          fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.t('damage.sum.disclaimer'),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildDamageRolls(DamageResult result) {
    final perHit = result.perHitAllRolls;
    final List<List<int>> rows;
    if (perHit == null || perHit.isEmpty) {
      if (result.allRolls.isEmpty) return const [];
      rows = [result.allRolls];
    } else {
      // Collapse if every hit has the same rolls (Bullet Seed-style).
      final unique = perHit.map((r) => r.join(',')).toSet();
      rows = unique.length == 1 ? [perHit[0]] : perHit;
    }
    final showHitLabels = rows.length > 1;
    return [
      const SizedBox(height: 6),
      for (int i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            showHitLabels
                ? '${i + 1}: ${rows[i].join(', ')}'
                : rows[i].join(', '),
            style: TextStyle(fontSize: 11, color: Colors.grey[600],
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
    ];
  }

  Widget _dmgTypeText(BattlePokemonState state) {
    // Terastal: show tera type only (overrides original)
    if (state.terastal.active && state.terastal.teraType != null &&
        state.terastal.teraType != PokemonType.stellar) {
      final t = state.terastal.teraType!;
      return Text.rich(TextSpan(children: [
        TextSpan(text: KoStrings.getTypeName(t),
          style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(t), fontWeight: FontWeight.bold)),
        TextSpan(text: ' (${AppStrings.t('label.terastalShort')})', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]));
    }
    // Normal: type1/type2
    final parts = <InlineSpan>[
      TextSpan(text: KoStrings.getTypeName(state.type1),
        style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(state.type1), fontWeight: FontWeight.bold)),
    ];
    if (state.type2 != null) {
      parts.add(TextSpan(text: '/', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)));
      parts.add(TextSpan(text: KoStrings.getTypeName(state.type2!),
        style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(state.type2!), fontWeight: FontWeight.bold)));
    }
    return Text.rich(TextSpan(children: parts));
  }

  Widget _dmgTypeBadge(PokemonType type) {
    final color = KoStrings.getTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        KoStrings.getTypeName(type),
        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _dmgCheck(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )),
            const SizedBox(width: 2),
            Flexible(child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: const TextStyle(fontSize: 14)),
            )),
          ],
        ),
      ),
    );
  }


  String _dynamaxLabel(BattlePokemonState state) {
    switch (state.dynamax) {
      case DynamaxState.dynamax:
        return ' (${AppStrings.t("label.dynamax")})';
      case DynamaxState.gigantamax:
        return ' (${AppStrings.t("label.gigantamax")})';
      default:
        return '';
    }
  }

  String _fmtEff(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }

  /// Format structured modifier notes into localized Korean text.
  /// Delegates to the shared [formatModifierNote] (modifier_note.dart)
  /// so the Damage tab, the result panel and the 결정력 breakdown popup
  /// all use one formatter — no stale second copy to drift.
  String _formatNote(String note) => formatModifierNote(
        note,
        abilityNameMap: _abilityNameMap,
        itemNameMap: _itemNameMap,
      );
}

/// About dialog.
class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({super.key});

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.elyss.damagecalc';
  static const _appStoreUrl =
      'https://apps.apple.com/kr/app/id6761017449';

  /// See MobileInstallPrompt.open — bypass url_launcher entirely
  /// and assign window.location directly via the conditional-import
  /// helper. CanvasKit's synthesized clicks aren't seen as user
  /// gestures by browsers, so url_launcher's launch silently fails.
  void _open(String url) {
    nav.navigateTo(url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.t('app.title'),
        style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('v1.12.5'),
          const SizedBox(height: 8),
          Text(AppStrings.t('about.description')),
          const SizedBox(height: 8),
          Text(AppStrings.t('about.subtitle'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          const Text('By  Elyss'),
          const SelectableText('Web  damage-calc.com'),
          const SelectableText('GitHub  github.com/Lerisia/damage-calc'),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _open(_playStoreUrl),
                icon: const Icon(Icons.android, size: 16),
                label: Text(AppStrings.t('banner.getAndroid'),
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _open(_appStoreUrl),
                icon: const Icon(Icons.apple, size: 16),
                label: Text(AppStrings.t('banner.getIos'),
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            AppStrings.t('about.beta'),
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.t('about.disclaimer'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          // Sprite-credit block — required by the Smogon Sprite
          // Project's non-profit-use clause and by general fairness
          // (the BW pixel set is community-made fan art). Pinned in
          // the About dialog so it stays visible regardless of which
          // screen the user is on.
          Text(
            AppStrings.t('sprite.creditTitle'),
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.t('sprite.creditBody'),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
      ],
    );
  }
}
