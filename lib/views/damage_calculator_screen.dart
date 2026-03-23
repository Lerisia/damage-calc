import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../data/sample_storage.dart';
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

  Timer? _debounceTimer;

  // Name maps (provided by _AppLoader, already loaded)
  Map<String, String> get _abilityNameMap => widget.abilityNameMap;
  Map<String, String> get _itemNameMap => widget.itemNameMap;

  // Ability → Weather/Terrain auto-set (from weather_effects / terrain_effects)

  /// Called when either panel changes. Debounced to avoid excessive rebuilds
  /// during rapid input (e.g. typing EVs).
  void _onPanelChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _syncWeatherTerrain();
        });
      }
    });
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
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
          const SnackBar(content: Text('전체 화면이 저장되었습니다'), duration: Duration(seconds: 2)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), duration: const Duration(seconds: 2)),
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
        const SnackBar(content: Text('이미지가 저장되었습니다'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e'), duration: const Duration(seconds: 2)),
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
        title: const Text('초기화'),
        content: const Text('양측 설정과 날씨/필드/룸이 모두 초기화됩니다'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
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
    final controller = TextEditingController(text: state.pokemonNameKo);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('샘플 저장'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '샘플 이름',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('저장'),
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
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('결정력 계산기', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v0.1.0-alpha (테스트 버전)'),
            SizedBox(height: 8),
            Text('포켓몬스터 실전 배틀 유저를 위한 결정력 계산기'),
            SizedBox(height: 12),
            Text('제작  Elyss'),
            SelectableText('GitHub  github.com/Lerisia/damage-calc'),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text(
              '본 앱은 Nintendo, Game Freak, The Pokémon Company와 '
              '관련이 없는 비공식 팬메이드 앱입니다.\n'
              '포켓몬스터 관련 데이터의 저작권은 원저작자에게 있습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 12),
            Text(
              '문의 및 버그 리포트는 GitHub Issue로 부탁드립니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWideLayout;
    final maxAppBarWidth = MediaQuery.of(context).size.width >= 1400 ? 1920.0 : 1440.0;
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
            // Weather dropdown
            PopupMenuButton<Weather>(
              initialValue: _weather,
              tooltip: '날씨',
              popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 150)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _weather == Weather.none
                        ? Text('날씨', style: TextStyle(fontSize: isWide ? 16 : 14, color: Colors.grey.shade500))
                        : Text(KoStrings.weatherIcon[_weather]!, style: TextStyle(fontSize: isWide ? 24 : 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Weather.values
                  .map((w) => PopupMenuItem(
                      value: w,
                      child: Row(
                        children: [
                          if (w != Weather.none) ...[
                            Text(KoStrings.weatherIcon[w]!, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                          ],
                          Text(KoStrings.weatherKo[w]!),
                        ],
                      )))
                  .toList(),
              onSelected: (v) => setState(() => _weather = v),
            ),
            // Terrain dropdown
            PopupMenuButton<Terrain>(
              initialValue: _terrain,
              tooltip: '필드',
              popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 150)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _terrain == Terrain.none
                        ? Text('필드', style: TextStyle(fontSize: isWide ? 16 : 14, color: Colors.grey.shade500))
                        : Text(KoStrings.terrainIcon[_terrain]!, style: TextStyle(fontSize: isWide ? 24 : 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Terrain.values
                  .map((t) => PopupMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          if (t != Terrain.none) ...[
                            Text(KoStrings.terrainIcon[t]!, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                          ],
                          Text(KoStrings.terrainKo[t]!),
                        ],
                      )))
                  .toList(),
              onSelected: (v) => setState(() => _terrain = v),
            ),
            // Room/Gravity toggle popup
            PopupMenuButton<String>(
              tooltip: '룸/중력',
              popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 150)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('룸', style: TextStyle(
                      fontSize: isWide ? 16 : 14,
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
                  child: const Text('🔄 트릭룸'),
                ),
                CheckedPopupMenuItem(
                  value: 'magicRoom', checked: _room.magicRoom,
                  child: const Text('✨ 매직룸'),
                ),
                CheckedPopupMenuItem(
                  value: 'wonderRoom', checked: _room.wonderRoom,
                  child: const Text('❓ 원더룸'),
                ),
                CheckedPopupMenuItem(
                  value: 'gravity', checked: _room.gravity,
                  child: const Text('🌀 중력'),
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
            ),
            if (isWide) const Spacer() else Expanded(
              child: GestureDetector(
                onTap: () => _showAboutDialog(context),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '결정력 계산기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isWide)
              TextButton.icon(
                onPressed: _swapSides,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('공수교대', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              )
            else
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: '공수전환',
                onPressed: _swapSides,
              ),
            if (isWide)
              TextButton.icon(
                onPressed: _resetBothSides,
                icon: const Icon(Icons.refresh),
                label: const Text('초기화', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '전체 초기화',
                onPressed: _resetBothSides,
              ),
            if (isWide)
              TextButton.icon(
                onPressed: _capture,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('캡처', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              )
            else
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: '캡처',
                onPressed: _capture,
              ),
            if (isWide) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => _showAboutDialog(context),
                child: Text(
                  '결정력 계산기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                tabs: const [
                  Tab(text: '공격측'),
                  Tab(text: '방어측'),
                  Tab(text: '대미지'),
                  Tab(text: '스피드'),
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
              child: _buildPokemonTab(0, '공격측', _attacker, _attackerPanelKey),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _buildPokemonTab(1, '방어측', _defender, _defenderPanelKey),
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
              child: _buildPokemonTab(0, '공격측', _attacker, _attackerPanelKey),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _buildPokemonTab(1, '방어측', _defender, _defenderPanelKey),
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
          const TabBar(
            tabs: [
              Tab(text: '대미지'),
              Tab(text: '스피드'),
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
              _buildPokemonTab(0, '공격측', _attacker, _attackerPanelKey),
              _buildPokemonTab(1, '방어측', _defender, _defenderPanelKey),
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
              '${_attacker.pokemonNameKo}${_dynamaxLabel(_attacker)} → ${_defender.pokemonNameKo}${_dynamaxLabel(_defender)}',
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
            'HP $defCurrentHp/$defMaxHp | 물리내구 ${bulk.physical} | 특수내구 ${bulk.special}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Defensive condition checkboxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dmgCheck('리플렉터', _defender.reflect, (v) {
                setState(() => _defender.reflect = v);
              }),
              const SizedBox(width: 16),
              _dmgCheck('빛의장막', _defender.lightScreen, (v) {
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
        child: Text('기술 ${index + 1}: 미설정',
            style: TextStyle(fontSize: 16, color: Colors.grey[400])),
      );
    }

    final result = _calcDamage(index);
    final effectiveType = result.move.type;
    final offLabel = result.isPhysical ? '물리' : '특수';
    final defLabel = result.targetPhysDef ? '물리' : '특수';
    final offPower = _getOffensivePower(index);
    final defBulk = result.targetPhysDef ? bulk.physical : bulk.special;

    // Effectiveness label
    final eff = result.effectiveness;
    final String effLabel;
    final Color effColor;
    if (eff == 0) {
      effLabel = '효과 없음 (x0)';
      effColor = Colors.grey;
    } else if (eff >= 4) {
      effLabel = '효과 매우 좋음 (x${ _fmtEff(eff) })';
      effColor = Colors.red[700]!;
    } else if (eff >= 2) {
      effLabel = '효과 좋음 (x${ _fmtEff(eff) })';
      effColor = Colors.red;
    } else if (eff <= 0.25) {
      effLabel = '효과 매우 별로 (x${ _fmtEff(eff) })';
      effColor = Colors.blue[700]!;
    } else if (eff <= 0.5) {
      effLabel = '효과 별로 (x${ _fmtEff(eff) })';
      effColor = Colors.blue;
    } else {
      effLabel = '효과 보통 (x${ _fmtEff(eff) })';
      effColor = Colors.grey;
    }

    // KO info using N-hit analysis
    String koText = '';
    Color koColor = Colors.grey;
    if (!result.isEmpty && eff > 0) {
      final info = result.koInfo;
      if (info.hits > 0) {
        if (info.koCount >= info.totalCount) {
          koText = '확정 ${info.hits}타';
          koColor = info.hits <= 2 ? Colors.red : Colors.orange;
        } else {
          final pct = (info.koCount / info.totalCount * 100);
          koText = '난수 ${info.hits}타 (${pct.toStringAsFixed(1)}%)';
          koColor = Colors.orange;
        }
      }
    }

    final typeColor = KoStrings.getTypeColor(effectiveType);

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
                child: Text(result.move.nameKo, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                )),
              ),
              const SizedBox(width: 8),
              Text(KoStrings.getTypeKo(effectiveType),
                  style: TextStyle(fontSize: 14, color: typeColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(effLabel, style: TextStyle(fontSize: 14, color: effColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          // 결정력 / 내구 info (display only)
          Text(
            '$offLabel 결정력 ${offPower ?? '-'} → $defLabel 내구 $defBulk',
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
        TextSpan(text: KoStrings.getTypeKo(t),
          style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(t), fontWeight: FontWeight.bold)),
        TextSpan(text: ' (테라)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]));
    }
    // Normal: type1/type2
    final parts = <InlineSpan>[
      TextSpan(text: KoStrings.getTypeKo(state.type1),
        style: TextStyle(fontSize: 13, color: KoStrings.getTypeColor(state.type1), fontWeight: FontWeight.bold)),
    ];
    if (state.type2 != null) {
      parts.add(TextSpan(text: '/', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)));
      parts.add(TextSpan(text: KoStrings.getTypeKo(state.type2!),
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
        KoStrings.getTypeKo(type),
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
        return ' (다이맥스)';
      case DynamaxState.gigantamax:
        return ' (거다이맥스)';
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
          if (parts[2] == 'immune') return '$name 특성에 의해 무효';
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
        const screenKo = {
          'reflect': '리플렉터 ×0.5',
          'light_screen': '빛의장막 ×0.5',
          'bypass_crit': '급소: 벽 무시',
          'bypass_infiltrator': '침투: 벽 무시',
        };
        return screenKo[parts[1]] ?? note;
      case 'move':
        const moveKo = {
          'knock_off': '아이템 소지',
          'hex': '상태이상',
          'venoshock': '독 상태',
          'brine': 'HP 절반 이하',
          'collision': '효과 좋음',
          'solar_halve': '비/모래/눈',
          'grav_apple': '중력',
          'wake_up_slap': '수면 상태',
          'smelling_salts': '마비 상태',
          'barb_barrage': '독 상태',
          'bolt_beak': '선공',
          'payback': '후공',
        };
        final key = parts[1];
        final label = moveKo[key] ?? key;
        if (parts.length >= 3) return '$label ${parts[2]}';
        return label;
      case 'weather_negate':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return '$name: 날씨 무효';
      case 'terrain_negate':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return '$name: 필드 무효';
      case 'moldbreaker':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return name;
      case 'unaware':
        return _abilityNameMap['Unaware'] ?? 'Unaware';
      case 'weather':
        const weatherKo = {
          'strong_winds': '난기류: 비행 약점 무효화',
          'harsh_sun_water': '강한 햇살: 물 기술 무효',
          'heavy_rain_fire': '강한 비: 불꽃 기술 무효',
        };
        return weatherKo[parts[1]] ?? note;
      case 'ground':
        return '비접지 상태로 땅 기술 무효';
      case 'type':
        return '타입 상성에 의해 무효';
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

  const _SampleListSheet({
    required this.samples,
    this.itemNameMap = const {},
    required this.onLoad,
    required this.onDelete,
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
      return const SizedBox(
        height: 200,
        child: Center(child: Text('저장된 샘플이 없습니다')),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: '샘플 검색',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            Expanded(
              child: indices.isEmpty
                  ? Center(child: Text('검색 결과 없음',
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
                          state.nature.nameKo,
                          if (itemKo != null) itemKo,
                        ];
                        return ListTile(
                          title: Text(sample.name),
                          subtitle: Text('${state.pokemonNameKo} | ${parts.join(' ')}'),
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

