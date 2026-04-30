import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../data/sample_storage.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../utils/app_strings.dart';
import '../utils/theme_controller.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/aura_effects.dart';
import '../utils/battle_facade.dart';
import '../utils/ruin_effects.dart';
import '../utils/simple_mode_controller.dart';
import 'dex_screen.dart';
import 'team_coverage_screen.dart';
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
import 'widgets/mobile_install_banner.dart';
import 'widgets/pokemon_panel.dart';
import 'widgets/sample_list_sheet.dart';
import 'widgets/speed_compare_tab.dart';

/// Page route that fades in over 120 ms instead of the platform slide.
/// We use it for the dex and party-coverage screens so they read as
/// proper standalone screens rather than transient popups, and to
/// sidestep an iOS layer-raster timing bug that surfaced during the
/// slide-in (mid-card blank rectangles in the party coverage matrix).
PageRouteBuilder<T> _fadeRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
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

  final _damageTabScreenshotController = ScreenshotController();
  final _wideLayoutScreenshotController = ScreenshotController();
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
    _tabController = TabController(length: 4, vsync: this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowPartyCoverageAnnouncement();
      // Mobile-web install nudge — fires at most once per browser.
      if (!mounted) return;
      await MobileInstallPrompt.maybeShow(context);
    });
  }

  /// One-shot "Party coverage chart is here" dialog for existing
  /// installs — shown after first frame so we're not fighting the
  /// splash. Tracked via a SharedPreferences flag so it never fires
  /// twice on the same device.
  static const _partyCoverageAnnounceKey = 'partyCoverageAnnouncementShown';
  Future<void> _maybeShowPartyCoverageAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_partyCoverageAnnounceKey) ?? false) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('announce.partyCoverage.title')),
        content: Text(AppStrings.t('announce.partyCoverage.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.confirm')),
          ),
        ],
      ),
    );
    await prefs.setBool(_partyCoverageAnnounceKey, true);
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
    super.dispose();
  }

  bool get _isWideLayout => MediaQuery.of(context).size.width >= 1050;

  Future<void> _capture() async {
    Uint8List? image;

    // Wide layout: capture entire screen
    if (_isWideLayout) {
      try {
        image = await _wideLayoutScreenshotController.capture(
          delay: const Duration(milliseconds: 100),
          pixelRatio: 2.0,
        );
      } catch (_) {}

      if (image == null || !mounted) return;
      try {
        final filename = 'pokemon_calc_${DateTime.now().millisecondsSinceEpoch}';
        await saver.saveImage(image, filename);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('msg.fullScreenSaved')), duration: const Duration(seconds: 2)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.t('msg.saveFailed')}: $e'), duration: const Duration(seconds: 2)),
        );
      }
      return;
    }

    // Narrow layout: capture current tab
    final currentTab = _tabController.index;

    if (currentTab == 0) {
      final panelState = _attackerPanelKey.currentState;
      if (panelState == null) return;
      image = await panelState.captureScreenshot();
    } else if (currentTab == 1) {
      final panelState = _defenderPanelKey.currentState;
      if (panelState == null) return;
      image = await panelState.captureScreenshot();
    } else if (currentTab == 2) {
      try {
        image = await _damageTabScreenshotController.capture(
          delay: const Duration(milliseconds: 100),
          pixelRatio: 2.0,
        );
      } catch (_) {}
    } else if (currentTab == 3) {
      final speedState = _speedTabKey.currentState;
      if (speedState != null) {
        image = await speedState.captureScreenshot();
      }
    }

    if (image == null || !mounted) return;

    try {
      final filename = 'pokemon_calc_${DateTime.now().millisecondsSinceEpoch}';
      await saver.saveImage(image, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('msg.imageSaved')), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.t('msg.saveFailed')}: $e'), duration: const Duration(seconds: 2)),
      );
    }
  }

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
    // First time the user enters Extended Mode, hand them a pointer
    // back to Simple Mode so they can find the toggle again.
    if (!next) _maybeShowExtendedModeAnnouncement();
  }

  Future<void> _maybeShowExtendedModeAnnouncement() async {
    if (await SimpleModeController.instance.extendedAnnouncementShown()) return;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('simple.extendedAnnounceTitle')),
        content: Text(AppStrings.t('simple.extendedAnnounceBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.confirm')),
          ),
        ],
      ),
    );
    await SimpleModeController.instance.markExtendedAnnouncementShown();
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
    final result = await showDialog<_SaveDialogResult>(
      context: context,
      builder: (ctx) => _SaveSampleDialog(
        defaultName: loadedName ?? state.localizedPokemonName,
        loadedName: loadedName,
      ),
    );
    if (result == null) return;
    final name = result.name;
    if (name.isEmpty) return;

    // Strip transient battle state (Tera, Dynamax, Z-Move flags)
    // from the snapshot we save — those toggles model the current
    // turn's situation, not a build property, so persisting them
    // would resurface old turn-state when the sample is loaded into
    // another match. Builds the user actually wants to keep
    // (movesets, EVs, ability, item) survive untouched.
    final saveState = BattlePokemonState.fromJson(state.toJson())
      ..terastal = const TerastalState()
      ..dynamax = DynamaxState.none
      ..zMoves = [false, false, false, false];

    final exists = await SampleStorage.sampleExists(name);
    if (exists) {
      if (!mounted) return;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.t('sample.duplicateTitle')),
          content: Text(AppStrings.t('sample.duplicateMessage')),
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
      if (overwrite != true) return;
      // Overwrite preserves the existing pokemon's id and team
      // membership — switching teams is a separate operation in the
      // load sheet.
      await SampleStorage.overwriteSample(name, saveState);
    } else {
      // Resolve target team: existing pick, or freshly created if the
      // user chose "+ 새 팀". Wrapped in a try so a TeamFullException
      // surfaces as a snackbar instead of crashing the calc.
      String? teamId = result.teamId;
      if (result.newTeamName != null) {
        teamId = await SampleStorage.createTeam(result.newTeamName!);
      }
      try {
        await SampleStorage.savePokemon(
            name: name, state: saveState, teamId: teamId);
      } on TeamFullException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.t('sample.team.fullSnack')),
        ));
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      if (side == 0) {
        _attackerLoadedName = name;
      } else {
        _defenderLoadedName = name;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$name" 저장 완료'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _showLoadSheet(int side) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // The sheet now owns its own state — it loads the SampleStore,
      // mutates teams/pokemon in place, and reloads after each
      // change. The parent only needs the load callback.
      builder: (ctx) => SampleListSheet(
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
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AboutDialog(),
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
    final result = await Navigator.of(context).push<DexPickResult>(
      _fadeRoute(
        (_) => DexScreen(initialPokemonName: initialName),
      ),
    );
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

  Future<void> _openTeamCoverage() async {
    await Navigator.of(context)
        .push(_fadeRoute((_) => const TeamCoverageScreen()));
  }

  String _languageLabel() {
    const labels = {
      AppLanguage.ko: '🇰🇷 한국어',
      AppLanguage.en: '🇺🇸 English',
      AppLanguage.ja: '🇯🇵 日本語',
    };
    return labels[AppStrings.current]!;
  }

  void _showLanguageDialog() {
    const langLabels = {
      AppLanguage.ko: '🇰🇷 한국어',
      AppLanguage.en: '🇺🇸 English',
      AppLanguage.ja: '🇯🇵 日本語',
    };
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppStrings.t('toolbar.battleConditions').isEmpty ? 'Language' : '🌐'),
        children: AppLanguage.values.map((lang) => SimpleDialogOption(
          onPressed: () {
            AppStrings.setLanguage(lang);
            _loadAbilities();
            _loadItems();
            setState(() { _resetCounter++; });
            Navigator.pop(ctx);
          },
          child: Text(
            langLabels[lang]!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppStrings.current == lang ? FontWeight.bold : FontWeight.normal,
              color: AppStrings.current == lang ? Theme.of(ctx).colorScheme.primary : null,
            ),
          ),
        )).toList(),
      ),
    );
  }

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
              TextButton.icon(
                onPressed: _capture,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(AppStrings.t('toolbar.capture'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                onPressed: () => _openDex(),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(AppStrings.t('dex.title'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                onPressed: _openTeamCoverage,
                icon: const Icon(Icons.shield_outlined),
                label: Text(AppStrings.t('team.title'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              TextButton(
                onPressed: _toggleSimpleMode,
                child: Text(
                  AppStrings.t(_simpleMode
                      ? 'simple.shortExtended'
                      : 'simple.shortSimple'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _LanguageButton(onChanged: () { _loadAbilities(); _loadItems(); setState(() { _resetCounter++; }); }),
              const SizedBox(width: 4),
              const _ThemeToggleButton(),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAboutDialog(context),
                child: Text(
                  AppStrings.t('app.title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: '',
                popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'dex',
                    child: Row(children: [
                      const Icon(Icons.menu_book_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(AppStrings.t('dex.title')),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'team',
                    child: Row(children: [
                      const Icon(Icons.shield_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(AppStrings.t('team.title')),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'language',
                    child: Row(children: [
                      const Icon(Icons.language, size: 20),
                      const SizedBox(width: 8),
                      Text(_languageLabel()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'theme',
                    child: Row(children: [
                      Icon(
                        ThemeController.instance.isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(ThemeController.instance.isDark
                          ? AppStrings.t('app.themeLight')
                          : AppStrings.t('app.themeDark')),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'about',
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(AppStrings.t('app.about')),
                    ]),
                  ),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'dex':
                      _openDex();
                    case 'team':
                      _openTeamCoverage();
                    case 'language':
                      _showLanguageDialog();
                    case 'theme':
                      ThemeController.instance.toggle();
                    case 'about':
                      _showAboutDialog(context);
                  }
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
            return Screenshot(
              controller: _wideLayoutScreenshotController,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: _buildExtraWideLayout(),
              ),
            );
          } else if (constraints.maxWidth >= 1050) {
            return Screenshot(
              controller: _wideLayoutScreenshotController,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: _buildWideLayout(),
              ),
            );
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 120),
      child: Screenshot(
        controller: _damageTabScreenshotController,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
    )),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Move name + type + effectiveness
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
              Text(effLabel, style: TextStyle(fontSize: 14, color: effColor, fontWeight: FontWeight.bold)),
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
  String _formatNote(String note) {
    // ability:AbilityName:immune
    // ability:AbilityName:×0.5
    // item:item-name:×1.2
    // screen:reflect / screen:bypass_crit
    // ground:immune / type:immune
    final parts = note.split(':');
    if (parts.length < 2) return note;

    switch (parts[0]) {
      case 'gravity':
        if (parts.length >= 2 && parts[1] == 'disabled') {
          return AppStrings.t('note.gravityDisabled');
        }
        return note;
      case 'ability':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        if (parts.length >= 3) {
          if (parts[2] == 'immune') return '$name ${AppStrings.t('note.abilityImmune')}';
          final detail = parts[2];
          // If detail starts with '-', join without space (e.g. 페어리오라-오라브레이크)
          if (detail.startsWith('-')) return '$name$detail';
          return '$name $detail';
        }
        return name;
      case 'disguise':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return '$name: ${AppStrings.t('note.disguiseDamage')}';
      case 'berryDefBoost':
        final itemName = _itemNameMap[parts[1]] ?? parts[1];
        final key = parts[1] == 'kee-berry' ? 'note.keeBerryBoost' : 'note.marangaBerryBoost';
        return '$itemName: ${AppStrings.t(key)}';
      case 'abilityDefChange':
        final abilityName = _abilityNameMap[parts[1]] ?? parts[1];
        final change = parts.length >= 3 ? parts[2] : '+1';
        final noteKey = switch (change) {
          '+2' => 'note.defUp2',
          '-1' => 'note.defDown1',
          _ => 'note.defUp1',
        };
        return '$abilityName: ${AppStrings.t(noteKey)}';
      case 'item':
        final name = _itemNameMap[parts[1]] ?? parts[1];
        if (parts.length >= 3) return '$name ${parts[2]}';
        return name;
      case 'screen':
        final screenKeys = {
          'reflect': 'note.reflect',
          'light_screen': 'note.lightScreen',
          'bypass_crit': 'note.critBypass',
          'bypass_infiltrator': 'note.infiltrator',
        };
        final key = screenKeys[parts[1]];
        return key != null ? AppStrings.t(key) : note;
      case 'move':
        final moveKeys = {
          'knock_off': 'note.knockOff',
          'hex': 'note.hex',
          'venoshock': 'note.venoshock',
          'brine': 'note.brine',
          'collision': 'note.collision',
          'solar_halve': 'note.solarHalve',
          'grav_apple': 'note.gravity',
          'wake_up_slap': 'note.sleep',
          'smelling_salts': 'note.paralysis',
          'barb_barrage': 'note.venoshock',
          'bolt_beak': 'note.boltBeak',
          'payback': 'note.payback',
          'spread': 'note.spread',
          'helpingHand': 'note.helpingHand',
          'powerSpot': 'note.powerSpot',
          'battery': 'note.battery',
          'flowerGift': 'note.flowerGift',
          'plusMinus': 'note.plusMinus',
        };
        final key = parts[1];
        final noteKey = moveKeys[key];
        final label = noteKey != null ? AppStrings.t(noteKey) : key;
        if (parts.length >= 3) return '$label ${parts[2]}';
        return label;
      case 'weather_negate':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return '$name: ${AppStrings.t('note.weatherNegate')}';
      case 'terrain_negate':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return '$name: ${AppStrings.t('note.terrainNegate')}';
      case 'moldbreaker':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return name;
      case 'unaware':
        return _abilityNameMap['Unaware'] ?? 'Unaware';
      case 'weather':
        final weatherKeys = {
          'strong_winds': 'note.strongWinds',
          'harsh_sun_water': 'note.harshSunWater',
          'heavy_rain_fire': 'note.heavyRainFire',
        };
        final wKey = weatherKeys[parts[1]];
        return wKey != null ? AppStrings.t(wKey) : note;
      case 'ground':
        return AppStrings.t('note.groundImmune');
      case 'type':
        return AppStrings.t('note.typeImmune');
      default:
        return note;
    }
  }
}

/// Result returned by [_SaveSampleDialog]. Either [teamId] is set
/// (existing team), or [newTeamName] is set (will be created on
/// confirm), or both null (loose / 팀 밖).
class _SaveDialogResult {
  final String name;
  final String? teamId;
  final String? newTeamName;
  const _SaveDialogResult({
    required this.name,
    this.teamId,
    this.newTeamName,
  });
}

/// Save dialog with name field + team picker. The team list shows
/// each team's fill state ("정공팀 (4/6)") and disables full ones so
/// the user doesn't try to push a 7th member. A "+ 새 팀" button
/// next to the dropdown opens a name prompt; the team isn't actually
/// created until the user confirms the save.
class _SaveSampleDialog extends StatefulWidget {
  final String defaultName;
  /// If the active panel was loaded from a saved sample, its current
  /// team is used as the dropdown default so re-saving doesn't
  /// silently move the pokemon out of its team.
  final String? loadedName;

  const _SaveSampleDialog({
    required this.defaultName,
    this.loadedName,
  });

  @override
  State<_SaveSampleDialog> createState() => _SaveSampleDialogState();
}

class _SaveSampleDialogState extends State<_SaveSampleDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.defaultName);

  SampleStore _store = const SampleStore();
  bool _loading = true;
  String? _selectedTeamId; // null = loose
  String? _pendingNewTeamName; // set when "+ 새 팀" provided a name

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final store = await SampleStorage.loadStore();
    if (!mounted) return;
    String? defaultTeam;
    if (widget.loadedName != null) {
      // Pre-select the team the existing sample lives in so re-save
      // keeps it there (most common workflow: tweak then save again).
      final existing = store.samples
          .where((s) => s.name == widget.loadedName)
          .firstOrNull;
      if (existing != null) {
        defaultTeam = store.teamOf(existing.id)?.id;
      }
    }
    setState(() {
      _store = store;
      _selectedTeamId = defaultTeam;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _promptNewTeamName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
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
    if (name == null || name.isEmpty) return;
    setState(() {
      _pendingNewTeamName = name;
      _selectedTeamId = null; // dropdown unselected; pending name takes over
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.t('sample.save')),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('sample.name'),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _teamPickerOrPending()),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: AppStrings.t('sample.team.add'),
                      icon: const Icon(Icons.create_new_folder_outlined,
                          size: 20),
                      onPressed: _promptNewTeamName,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (SampleStorage.isWebStorage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppStrings.t('sample.browserWarning'),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.cancel')),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pop(
                    context,
                    _SaveDialogResult(
                      name: _nameCtrl.text.trim(),
                      teamId: _pendingNewTeamName == null
                          ? _selectedTeamId
                          : null,
                      newTeamName: _pendingNewTeamName,
                    ),
                  ),
          child: Text(AppStrings.t('action.save')),
        ),
      ],
    );
  }

  Widget _teamPickerOrPending() {
    // Pending new-team takes precedence over the dropdown so the user
    // sees what they just typed; tap the chip to clear it and
    // re-pick.
    if (_pendingNewTeamName != null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.t('sample.save.team'),
        ),
        child: Row(
          children: [
            const Icon(Icons.create_new_folder, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_pendingNewTeamName!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            InkWell(
              onTap: () => setState(() => _pendingNewTeamName = null),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ],
        ),
      );
    }
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(
        value: null,
        child: Text(AppStrings.t('sample.save.team.none')),
      ),
      for (final t in _store.teams)
        DropdownMenuItem(
          value: t.id,
          enabled: t.memberIds.length < kMaxTeamSize,
          child: Text(
            '${t.name}  (${t.memberIds.length}/$kMaxTeamSize)',
            style: TextStyle(
              color: t.memberIds.length >= kMaxTeamSize
                  ? Colors.grey
                  : null,
            ),
          ),
        ),
    ];
    return DropdownButtonFormField<String?>(
      value: _selectedTeamId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppStrings.t('sample.save.team'),
        isDense: true,
      ),
      items: items,
      onChanged: (v) => setState(() => _selectedTeamId = v),
    );
  }
}

/// Compact language toggle button for wide AppBar.
class _LanguageButton extends StatelessWidget {
  final VoidCallback onChanged;
  const _LanguageButton({required this.onChanged});

  static const _langLabels = {
    AppLanguage.ko: '한국어',
    AppLanguage.en: 'English',
    AppLanguage.ja: '日本語',
  };

  static const _langCodes = {
    AppLanguage.ko: '🇰🇷',
    AppLanguage.en: '🇺🇸',
    AppLanguage.ja: '🇯🇵',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      onSelected: (lang) {
        AppStrings.setLanguage(lang);
        onChanged();
      },
      itemBuilder: (_) => AppLanguage.values.map((lang) =>
        PopupMenuItem(
          value: lang,
          child: Row(
            children: [
              Text('${_langCodes[lang]!} ', style: const TextStyle(fontSize: 16)),
              Text(_langLabels[lang]!,
                style: TextStyle(
                  fontWeight: AppStrings.current == lang ? FontWeight.bold : FontWeight.normal,
                  color: AppStrings.current == lang ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ).toList(),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(_langCodes[AppStrings.current]!,
          style: const TextStyle(
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

/// Theme toggle for wide AppBar. Shows a sun icon in dark mode, moon in light.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          onPressed: () => ThemeController.instance.toggle(),
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
          ),
          tooltip: isDark
              ? AppStrings.t('app.themeLight')
              : AppStrings.t('app.themeDark'),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}

/// About dialog.
class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

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
          const Text('v1.6.4'),
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

