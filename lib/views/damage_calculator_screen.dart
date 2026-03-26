import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../data/sample_storage.dart';
import '../utils/app_strings.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/battle_facade.dart';
import '../utils/damage_calculator.dart';
import '../utils/korean_search.dart';
import '../utils/speed_calculator.dart';
import '../utils/stat_calculator.dart';
import '../models/type.dart';
import '../models/battle_pokemon.dart';
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
import 'widgets/pokemon_panel.dart';
import 'widgets/speed_compare_tab.dart';

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
  bool _useSpMode = false;


  // Name maps – loaded locally so they refresh on language change
  Map<String, String> _abilityNameMap = {};
  Map<String, String> _itemNameMap = {};

  // Ability → Weather/Terrain auto-set (from weather_effects / terrain_effects)

  /// Called when either panel changes.
  void _onPanelChanged() {
    if (mounted) {
      setState(() {
        _syncWeatherTerrain();
      });
    }
  }

  void _syncWeatherTerrain() {
    final defAbility = _defender.selectedAbility;
    final atkAbility = _attacker.selectedAbility;

    final atkWeather = atkAbility != null ? abilityWeatherMap[atkAbility] : null;
    final defWeather = defAbility != null ? abilityWeatherMap[defAbility] : null;
    if (atkWeather != null || defWeather != null) {
      _weather = atkWeather ?? defWeather!;
    }

    final atkTerrain = atkAbility != null ? abilityTerrainMap[atkAbility] : null;
    final defTerrain = defAbility != null ? abilityTerrainMap[defAbility] : null;
    if (atkTerrain != null || defTerrain != null) {
      _terrain = atkTerrain ?? defTerrain!;
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
  }

  Future<void> _loadAbilities() async {
    try {
      final dex = await loadAbilitydex();
      final map = <String, String>{};
      for (final entry in dex.entries) {
        map[entry.key] = entry.value.localizedName;
      }
      if (mounted) setState(() => _abilityNameMap = map);
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
      } else {
        _defender.reset();
      }
    });
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
        _weather = Weather.none;
        _terrain = Terrain.none;
        _room = const RoomConditions();
      });
    }
  }

  Future<void> _showSaveDialog(BattlePokemonState state) async {
    final controller = TextEditingController(text: state.localizedPokemonName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('sample.save')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AppStrings.t('sample.name'),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            if (SampleStorage.isWebStorage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  AppStrings.t('sample.browserWarning'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t('action.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(AppStrings.t('action.save')),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await SampleStorage.saveSample(name, state);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" 저장 완료'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _showLoadSheet(int side) async {
    final samples = await SampleStorage.loadSamples();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SampleListSheet(
        samples: samples,
        itemNameMap: _itemNameMap,
        onLoad: (index) {
          setState(() {
            final loaded = samples[index].state;
            if (side == 0) {
              _attacker = loaded;
            } else {
              _defender = loaded;
            }
            _resetCounter++;
          });
          Navigator.pop(ctx);
        },
        onDelete: (index) async {
          await SampleStorage.deleteSample(index);
          Navigator.pop(ctx);
          _showLoadSheet(side);
        },
        onImportComplete: () => _showLoadSheet(side),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AboutDialog(),
    );
  }

  String _languageLabel() {
    const labels = {
      AppLanguage.ko: '🇰🇷 한국어',
      AppLanguage.en: '🇺🇸 English',
      AppLanguage.ja: '🇯🇵 日本語',
    };
    return labels[AppStrings.current]!;
  }

  void _cycleLanguage() {
    final values = AppLanguage.values;
    final next = values[(AppStrings.current.index + 1) % values.length];
    AppStrings.setLanguage(next);
    _loadAbilities();
    _loadItems();
    setState(() { _resetCounter++; });
  }

  void _showBattleConditionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(AppStrings.t('toolbar.battleConditions')),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weather (radio - single select)
                Text(AppStrings.t('toolbar.weather'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Wrap(
                  spacing: 4,
                  children: Weather.values.map((w) {
                    final selected = _weather == w;
                    final label = w == Weather.none
                        ? AppStrings.t('status.none')
                        : '${KoStrings.weatherIcon[w]!} ${KoStrings.getWeatherName(w)}';
                    return ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _weather = w);
                        setDialogState(() {});
                        _onPanelChanged();
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
                  children: Terrain.values.map((t) {
                    final selected = _terrain == t;
                    final label = t == Terrain.none
                        ? AppStrings.t('status.none')
                        : '${KoStrings.terrainIcon[t]!} ${KoStrings.getTerrainName(t)}';
                    return ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _terrain = t);
                        setDialogState(() {});
                        _onPanelChanged();
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
                      label: Text('🔄 ${KoStrings.getRoomName(Room.trickRoom)}', style: const TextStyle(fontSize: 13)),
                      selected: _room.trickRoom,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(trickRoom: v));
                        setDialogState(() {});
                        _onPanelChanged();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    FilterChip(
                      label: Text('✨ ${KoStrings.getRoomName(Room.magicRoom)}', style: const TextStyle(fontSize: 13)),
                      selected: _room.magicRoom,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(magicRoom: v));
                        setDialogState(() {});
                        _onPanelChanged();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    FilterChip(
                      label: Text('❓ ${KoStrings.getRoomName(Room.wonderRoom)}', style: const TextStyle(fontSize: 13)),
                      selected: _room.wonderRoom,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(wonderRoom: v));
                        setDialogState(() {});
                        _onPanelChanged();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    FilterChip(
                      label: Text('🌀 ${KoStrings.gravityName}', style: const TextStyle(fontSize: 13)),
                      selected: _room.gravity,
                      onSelected: (v) {
                        setState(() => _room = _room.copyWith(gravity: v));
                        setDialogState(() {});
                        _onPanelChanged();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
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
                  _onPanelChanged();
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

  /// Mobile: battle conditions button showing active icons, or text when none set.
  Widget _battleConditionsButton() {
    final icons = <String>[];
    if (_weather != Weather.none) icons.add(KoStrings.weatherIcon[_weather]!);
    if (_terrain != Terrain.none) icons.add(KoStrings.terrainIcon[_terrain]!);
    if (_room.trickRoom) icons.add('🔄');
    if (_room.magicRoom) icons.add('✨');
    if (_room.wonderRoom) icons.add('❓');
    if (_room.gravity) icons.add('🌀');

    return GestureDetector(
      onTap: _showBattleConditionsDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: icons.isEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppStrings.t('toolbar.battleConditions'),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              )
            : Text(icons.join(' '), style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  /// Wide layout: individual weather dropdown (extracted from old inline code)
  Widget _weatherDropdown(double fontSize) {
    return PopupMenuButton<Weather>(
      initialValue: _weather,
      tooltip: AppStrings.t('toolbar.weather'),
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _weather == Weather.none
                ? Text(AppStrings.t('toolbar.weather'), style: TextStyle(fontSize: fontSize, color: Colors.grey.shade500))
                : Text(KoStrings.weatherIcon[_weather]!, style: const TextStyle(fontSize: 24)),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => Weather.values
          .map((w) => PopupMenuItem(
              value: w,
              child: Row(children: [
                if (w != Weather.none) ...[
                  Text(KoStrings.weatherIcon[w]!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ],
                Text(KoStrings.getWeatherName(w)),
              ])))
          .toList(),
      onSelected: (v) => setState(() => _weather = v),
    );
  }

  Widget _terrainDropdown(double fontSize) {
    return PopupMenuButton<Terrain>(
      initialValue: _terrain,
      tooltip: AppStrings.t('toolbar.terrain'),
      popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _terrain == Terrain.none
                ? Text(AppStrings.t('toolbar.terrain'), style: TextStyle(fontSize: fontSize, color: Colors.grey.shade500))
                : Text(KoStrings.terrainIcon[_terrain]!, style: const TextStyle(fontSize: 24)),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => Terrain.values
          .map((t) => PopupMenuItem(
              value: t,
              child: Row(children: [
                if (t != Terrain.none) ...[
                  Text(KoStrings.terrainIcon[t]!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ],
                Text(KoStrings.getTerrainName(t)),
              ])))
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
              color: _room.hasAny ? Colors.purple : Colors.grey.shade500,
              fontWeight: _room.hasAny ? FontWeight.bold : FontWeight.normal,
            )),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'trickRoom', checked: _room.trickRoom,
          child: Text('🔄 ${KoStrings.getRoomName(Room.trickRoom)}'),
        ),
        CheckedPopupMenuItem(
          value: 'magicRoom', checked: _room.magicRoom,
          child: Text('✨ ${KoStrings.getRoomName(Room.magicRoom)}'),
        ),
        CheckedPopupMenuItem(
          value: 'wonderRoom', checked: _room.wonderRoom,
          child: Text('❓ ${KoStrings.getRoomName(Room.wonderRoom)}'),
        ),
        CheckedPopupMenuItem(
          value: 'gravity', checked: _room.gravity,
          child: Text('🌀 ${KoStrings.gravityName}'),
        ),
      ],
      onSelected: (v) => setState(() {
        switch (v) {
          case 'trickRoom': _room = _room.copyWith(trickRoom: !_room.trickRoom);
          case 'magicRoom': _room = _room.copyWith(magicRoom: !_room.magicRoom);
          case 'wonderRoom': _room = _room.copyWith(wonderRoom: !_room.wonderRoom);
          case 'gravity': _room = _room.copyWith(gravity: !_room.gravity);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWideLayout;
    final maxAppBarWidth = MediaQuery.of(context).size.width >= 1400 ? 1920.0 : 1440.0;
    final isKo = AppStrings.current == AppLanguage.ko;
    final toolbarFontSize = isWide ? 16.0 : (isKo ? 14.0 : 11.0);
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
              const Spacer(),
              _LanguageButton(onChanged: () { _loadAbilities(); _loadItems(); setState(() { _resetCounter++; }); }),
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
              // Mobile: battle conditions button + active icons
              _battleConditionsButton(),
              const Spacer(),
              TextButton(
                onPressed: _swapSides,
                child: Text(AppStrings.t('toolbar.swap'), style: TextStyle(fontSize: toolbarFontSize, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: AppStrings.t('toolbar.reset'),
                onPressed: _resetBothSides,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: '',
                popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'language',
                    child: Row(children: [
                      const Icon(Icons.language, size: 20),
                      const SizedBox(width: 8),
                      Text(_languageLabel()),
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
                    case 'language':
                      _cycleLanguage();
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
        bottom: isWide
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
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
                onSpModeChanged: (v) => setState(() => _useSpMode = v),
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
                onSpModeChanged: (v) => setState(() => _useSpMode = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPokemonTab(int side, String label, BattlePokemonState state, GlobalKey<PokemonPanelState> panelKey) {
    final isAttacker = side == 0;
    return PokemonPanel(
            key: panelKey,
            state: state,
            weather: _weather,
            terrain: _terrain,
            room: _room,
            label: label,
            onChanged: _onPanelChanged,
            onSave: () => _showSaveDialog(state),
            onLoad: () => _showLoadSheet(side),
            onReset: () => _resetSide(side),
            resetCounter: _resetCounter,
            isAttacker: isAttacker,
            opponentSpeed: isAttacker
                ? _calcEffectiveSpeed(_defender)
                : _calcEffectiveSpeed(_attacker),
            opponentAlwaysLast: isAttacker
                ? _isAlwaysLast(_defender)
                : _isAlwaysLast(_attacker),
            opponentAttack: isAttacker
                ? _calcStats(_defender).attack
                : _calcStats(_attacker).attack,
            opponentGender: isAttacker ? _defender.gender : _attacker.gender,
            opponentWeight: isAttacker
                ? BattleFacade.effectiveWeight(_defender)
                : BattleFacade.effectiveWeight(_attacker),
            opponentHpPercent: isAttacker
                ? _defender.hpPercent
                : _attacker.hpPercent,
            useSpMode: _useSpMode,
            onSpModeChanged: (v) => setState(() => _useSpMode = v),
          );
  }


  /// Get the 결정력 for a specific move slot (always up-to-date).
  int? _getOffensivePower(int moveIndex) {
    return BattleFacade.calcOffensivePower(
      state: _attacker,
      moveIndex: moveIndex,
      weather: _weather,
      terrain: _terrain,
      room: _room,
      opponentSpeed: _calcEffectiveSpeed(_defender),
      opponentAttack: _calcStats(_defender).attack,
      opponentGender: _defender.gender,
      opponentWeight: BattleFacade.effectiveWeight(_defender),
      opponentHpPercent: _defender.hpPercent,
    );
  }

  /// Get the 내구 for the defender (for display only).
  ({int physical, int special}) _getDefensiveBulk() {
    return BattleFacade.calcBulk(
      state: _defender,
      weather: _weather,
      terrain: _terrain,
      room: _room,
    );
  }

  DamageResult _calcDamage(int moveIndex) {
    return DamageCalculator.calculate(
      attacker: _attacker,
      defender: _defender,
      moveIndex: moveIndex,
      weather: _weather,
      terrain: _terrain,
      room: _room,
      opponentAttack: _calcStats(_defender).attack,
      opponentSpeed: _calcEffectiveSpeed(_defender),
      myEffectiveSpeed: _calcEffectiveSpeed(_attacker),
      opponentGender: _defender.gender,
    );
  }

  Widget _buildDamageCalcTab() {
    final defMaxHp = _calcStats(_defender).hp;
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
            _buildMoveResult(i, bulk),
        ],
      ),
    )),
    );
  }

  Widget _buildMoveResult(int index, ({int physical, int special}) bulk) {
    final move = _attacker.moves[index];
    if (move == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('${AppStrings.t('section.moves')} ${index + 1}: ${AppStrings.t('damage.moveNotSet')}',
            style: TextStyle(fontSize: 16, color: Colors.grey[400])),
      );
    }

    final result = _calcDamage(index);
    final effectiveType = result.move.type == PokemonType.typeless
        ? null : result.move.type;
    final offLabel = result.isPhysical ? AppStrings.t('damage.physical') : AppStrings.t('damage.special');
    final defLabel = result.targetPhysDef ? AppStrings.t('damage.physical') : AppStrings.t('damage.special');
    final offPower = _getOffensivePower(index);
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: Color.lerp(Colors.white, typeColor, 0.06),
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

class _SampleListSheet extends StatefulWidget {
  final List<({String name, BattlePokemonState state})> samples;
  final Map<String, String> itemNameMap;
  final ValueChanged<int> onLoad;
  final ValueChanged<int> onDelete;
  final VoidCallback? onImportComplete;

  const _SampleListSheet({
    required this.samples,
    this.itemNameMap = const {},
    required this.onLoad,
    required this.onDelete,
    this.onImportComplete,
  });

  @override
  State<_SampleListSheet> createState() => _SampleListSheetState();
}

class _SampleListSheetState extends State<_SampleListSheet> {
  String _query = '';

  List<int> _filteredIndices() {
    if (_query.isEmpty) {
      return List.generate(widget.samples.length, (i) => i);
    }
    final scored = <(int, int)>[];
    for (int i = 0; i < widget.samples.length; i++) {
      final sample = widget.samples[i];
      final nameScore = koreanMatchScore(_query, sample.name);
      final pokemonKoScore = koreanMatchScore(_query, sample.state.pokemonNameKo);
      final pokemonEnScore = koreanMatchScore(_query, sample.state.pokemonName);
      final score = [nameScore, pokemonKoScore, pokemonEnScore].reduce(math.max);
      if (score > 0) scored.add((i, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.samples.isEmpty) {
      return SizedBox(
        height: 300,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppStrings.t('sample.empty'), style: const TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    final indices = _filteredIndices();
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            if (SampleStorage.isWebStorage)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(AppStrings.t('sample.browserWarning'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: AppStrings.t('sample.search'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            Expanded(
              child: indices.isEmpty
                  ? Center(child: Text(AppStrings.t('search.noResults'),
                      style: TextStyle(color: Colors.grey[400])))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: indices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final idx = indices[i];
                        final sample = widget.samples[idx];
                        final state = sample.state;
                        final itemKo = state.selectedItem != null
                            ? widget.itemNameMap[state.selectedItem] ?? state.selectedItem
                            : null;
                        final parts = [
                          'Lv.${state.level}',
                          state.nature.localizedName,
                          if (itemKo != null) itemKo,
                        ];
                        return ListTile(
                          title: Text(sample.name),
                          subtitle: Text('${state.localizedPokemonName} | ${parts.join(' ')}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => widget.onDelete(idx),
                          ),
                          onTap: () => widget.onLoad(idx),
                        );
                      },
                    ),
            ),
          ],
        );
      },
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

/// About dialog.
class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.t('app.title'),
        style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('v0.3.0-beta'),
          const SizedBox(height: 8),
          Text(AppStrings.t('about.description')),
          const SizedBox(height: 8),
          Text(AppStrings.t('about.subtitle'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          const Text('By  Elyss'),
          const SelectableText('Web  damage-calc.com'),
          const SelectableText('GitHub  github.com/Lerisia/damage-calc'),
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

