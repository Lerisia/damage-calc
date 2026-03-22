import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../data/abilitydex.dart';
import '../data/itemdex.dart';
import '../data/sample_storage.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/battle_facade.dart';
import '../utils/damage_calculator.dart';
import '../utils/random_factor.dart';
import '../utils/grounded.dart';
import '../utils/item_effects.dart';
import '../utils/speed_calculator.dart';
import '../utils/stat_calculator.dart';
import '../models/move.dart';
import '../models/type.dart';
import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/room.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import '../utils/localization.dart';
import '../utils/room_effects.dart';
import 'widgets/pokemon_panel.dart';
import 'widgets/speed_compare_tab.dart';
import 'widgets/pokemon_selector.dart';

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
  final _speedTabScreenshotController = ScreenshotController();

  Weather _weather = Weather.none;
  Terrain _terrain = Terrain.none;
  RoomConditions _room = const RoomConditions();

  Timer? _debounceTimer;

  // Name maps (provided by _AppLoader, already loaded)
  Map<String, String> get _abilityNameMap => widget.abilityNameMap;
  Map<String, String> get _itemNameMap => widget.itemNameMap;

  // Ability → Weather/Terrain auto-set
  static const _abilityWeather = {
    'Drought': Weather.sun,
    'Desolate Land': Weather.harshSun,
    'Drizzle': Weather.rain,
    'Primordial Sea': Weather.heavyRain,
    'Sand Stream': Weather.sandstorm,
    'Snow Warning': Weather.snow,
    'Delta Stream': Weather.strongWinds,
    'Orichalcum Pulse': Weather.sun,
  };

  static const _abilityTerrain = {
    'Electric Surge': Terrain.electric,
    'Grassy Surge': Terrain.grassy,
    'Psychic Surge': Terrain.psychic,
    'Misty Surge': Terrain.misty,
    'Hadron Engine': Terrain.electric,
  };

  /// Called when either panel changes. Debounced to avoid excessive rebuilds
  /// during rapid input (e.g. typing EVs).
  void _onPanelChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
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

    final atkWeather = atkAbility != null ? _abilityWeather[atkAbility] : null;
    final defWeather = defAbility != null ? _abilityWeather[defAbility] : null;
    if (atkWeather != null || defWeather != null) {
      _weather = atkWeather ?? defWeather!;
    }

    final atkTerrain = atkAbility != null ? _abilityTerrain[atkAbility] : null;
    final defTerrain = defAbility != null ? _abilityTerrain[defAbility] : null;
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

  Future<void> _capture() async {
    final currentTab = _tabController.index;
    Uint8List? image;

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
      try {
        image = await _speedTabScreenshotController.capture(
          delay: const Duration(milliseconds: 100),
          pixelRatio: 2.0,
        );
      } catch (_) {}
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
        content: const Text('양측 포켓몬과 날씨/필드/룸이 모두 초기화됩니다'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // Weather dropdown icon
            PopupMenuButton<Weather>(
              initialValue: _weather,
              tooltip: '날씨',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(KoStrings.weatherIcon[_weather]!, style: const TextStyle(fontSize: 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Weather.values
                  .map((w) => PopupMenuItem(
                      value: w,
                      child: Row(
                        children: [
                          Text(KoStrings.weatherIcon[w]!, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(KoStrings.weatherKo[w]!),
                        ],
                      )))
                  .toList(),
              onSelected: (v) => setState(() => _weather = v),
            ),
            // Terrain dropdown icon
            PopupMenuButton<Terrain>(
              initialValue: _terrain,
              tooltip: '필드',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(KoStrings.terrainIcon[_terrain]!, style: const TextStyle(fontSize: 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Terrain.values
                  .map((t) => PopupMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Text(KoStrings.terrainIcon[t]!, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(KoStrings.terrainKo[t]!),
                        ],
                      )))
                  .toList(),
              onSelected: (v) => setState(() => _terrain = v),
            ),
            // Room/Gravity toggle popup
            PopupMenuButton<String>(
              tooltip: '룸/중력',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_room.hasAny ? '🔄' : '🚪', style: const TextStyle(fontSize: 20)),
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
            Expanded(
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
            const SizedBox(width: 8),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '공수전환',
            onPressed: _swapSides,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '전체 초기화',
            onPressed: _resetBothSides,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: '캡처',
            onPressed: _capture,
          ),
        ],
        bottom: MediaQuery.of(context).size.width >= 1050
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1400) {
            return _buildExtraWideLayout();
          } else if (constraints.maxWidth >= 1050) {
            return _buildWideLayout();
          }
          return _buildNarrowLayout();
        },
      ),
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
            children: [
              _buildPokemonTab(0, '공격측', _attacker, _attackerPanelKey),
              _buildPokemonTab(1, '방어측', _defender, _defenderPanelKey),
              _buildDamageCalcTab(),
              Screenshot(
                  controller: _speedTabScreenshotController,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
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
      opponentGender: _defender.gender,
    );
  }

  Widget _buildDamageCalcTab() {
    final defMaxHp = _calcStats(_defender).hp;
    final defCurrentHp = (defMaxHp * _defender.hpPercent / 100).floor();
    final bulk = _getDefensiveBulk();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Screenshot(
        controller: _damageTabScreenshotController,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
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
            children: [
              Expanded(child: _dmgCheck('리플렉터', _defender.reflect, (v) {
                setState(() => _defender.reflect = v);
              })),
              Expanded(child: _dmgCheck('빛의장막', _defender.lightScreen, (v) {
                setState(() => _defender.lightScreen = v);
              })),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 12),

          for (int i = 0; i < 4; i++) ...[
            _buildMoveResult(i, bulk),
            if (i < 3) const Divider(height: 28),
          ],
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
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, typeColor, 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Move name + type + effectiveness
          Row(
            children: [
              Flexible(
                child: Text(result.move.nameKo, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                )),
              ),
              const SizedBox(width: 8),
              Text(KoStrings.getTypeKo(effectiveType),
                  style: TextStyle(fontSize: 13, color: typeColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(effLabel, style: TextStyle(fontSize: 13, color: effColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          // 결정력 / 내구 info (display only)
          Text(
            '$offLabel 결정력 ${offPower ?? '-'} → $defLabel 내구 $defBulk',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              child: Text(label, style: const TextStyle(fontSize: 12)),
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
        return name;
      case 'moldbreaker':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return name;
      case 'weather':
        const weatherKo = {
          'strong_winds': '난기류: 비행 약점 무효화',
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

class _SampleListSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('저장된 샘플이 없습니다')),
      );
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('샘플 불러오기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: samples.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final sample = samples[i];
                  final state = sample.state;
                  final itemKo = state.selectedItem != null
                      ? itemNameMap[state.selectedItem] ?? state.selectedItem
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
                      onPressed: () => onDelete(i),
                    ),
                    onTap: () => onLoad(i),
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

