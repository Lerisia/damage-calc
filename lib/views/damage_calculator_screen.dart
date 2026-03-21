import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/ability_effects.dart';
import '../utils/damage_calculator.dart';
import '../utils/grounded.dart';
import '../utils/item_effects.dart';
import '../utils/move_transform.dart';
import '../utils/stat_calculator.dart';
import '../models/move.dart';
import '../models/type.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/stats.dart';
import '../models/status.dart';
import '../models/room.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import '../utils/localization.dart';
import 'widgets/pokemon_panel.dart';

class DamageCalculatorScreen extends StatefulWidget {
  const DamageCalculatorScreen({super.key});

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

  Weather _weather = Weather.none;
  Terrain _terrain = Terrain.none;
  RoomConditions _room = const RoomConditions();

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
    double speed = _calcStats(s).speed.toDouble();
    if (s.selectedAbility != null) {
      speed *= getSpeedAbilityModifier(s.selectedAbility!,
          weather: _weather, terrain: _terrain, status: s.status);
    }
    if (s.selectedItem != null) {
      // Choice Scarf is nullified during Dynamax
      final isDmaxed = s.dynamax != DynamaxState.none;
      if (!(isDmaxed && s.selectedItem == 'choice-scarf')) {
        final effect = getSpeedItemEffect(s.selectedItem!);
        speed *= effect.speedModifier;
      }
    }
    // Paralysis halves speed (Quick Feet negates this)
    if (s.status == StatusCondition.paralysis &&
        s.selectedAbility != 'Quick Feet') {
      speed *= 0.5;
    }
    return speed.floor();
  }

  bool _isAlwaysLast(BattlePokemonState s) {
    if (s.selectedItem == null) return false;
    if (s.dynamax != DynamaxState.none) return false;
    return getSpeedItemEffect(s.selectedItem!).alwaysLast;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final currentTab = _tabController.index;
    PokemonPanelState? panelState;
    if (currentTab == 0) {
      panelState = _attackerPanelKey.currentState;
    } else if (currentTab == 1) {
      panelState = _defenderPanelKey.currentState;
    }
    if (panelState == null) return;

    final image = await panelState.captureScreenshot();
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

  void _reset() {
    setState(() {
      _resetCounter++;
      final currentTab = _tabController.index;
      if (currentTab == 0) {
        _attacker.reset();
      } else if (currentTab == 1) {
        _defender.reset();
      }
    });
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
            tooltip: '초기화',
            onPressed: _reset,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: '캡처',
            onPressed: _capture,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '공격측'),
            Tab(text: '방어측'),
            Tab(text: '대미지'),
            Tab(text: '스피드'),
          ],
        ),
      ),
      body: Column(
        children: [

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PokemonPanel(
                  key: _attackerPanelKey,
                  state: _attacker,
                  weather: _weather,
                  terrain: _terrain,
                  room: _room,
                  label: '공격측',
                  onChanged: () => setState(() {}),
                  resetCounter: _resetCounter,
                  opponentSpeed: _calcEffectiveSpeed(_defender),
                  opponentAlwaysLast: _isAlwaysLast(_defender),
                  opponentAttack: _calcStats(_defender).attack,
                  opponentGender: _defender.gender,
                ),
                PokemonPanel(
                  key: _defenderPanelKey,
                  state: _defender,
                  weather: _weather,
                  terrain: _terrain,
                  room: _room,
                  label: '방어측',
                  onChanged: () => setState(() {}),
                  resetCounter: _resetCounter,
                  isAttacker: false,
                  opponentSpeed: _calcEffectiveSpeed(_attacker),
                  opponentAlwaysLast: _isAlwaysLast(_attacker),
                  opponentAttack: _calcStats(_attacker).attack,
                  opponentGender: _attacker.gender,
                ),
                _buildDamageCalcTab(),
                _buildSpeedCompareTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DamageResult _calcDamage(BattlePokemonState atk, BattlePokemonState def, int moveIndex) {
    final move = atk.moves[moveIndex];
    if (move == null) {
      return const DamageResult(
        minDamage: 0, maxDamage: 0,
        minPercent: 0, maxPercent: 0,
        effectiveness: 1.0, hits: 0,
      );
    }

    final effectiveMove = move.copyWith(
      type: atk.typeOverrides[moveIndex],
      category: atk.categoryOverrides[moveIndex],
      power: atk.powerOverrides[moveIndex],
    );

    final context = MoveContext(
      weather: _weather,
      terrain: _terrain,
      rank: atk.rank,
      hpPercent: atk.hpPercent,
      hasItem: atk.selectedItem != null,
      ability: atk.selectedAbility,
      status: atk.status,
    );
    final transformed = transformMove(effectiveMove, context);

    // Attacker modifiers (simplified from pokemon_panel logic)
    double atkStatMod = 1.0;
    double atkPowerMod = 1.0;

    // Ally boosts
    if (atk.helpingHand) atkPowerMod *= 1.5;
    if (atk.charge && effectiveMove.type == PokemonType.electric) atkPowerMod *= 2.0;
    if (atk.battery && effectiveMove.category == MoveCategory.special) atkPowerMod *= 1.3;
    if (atk.powerSpot) atkPowerMod *= 1.3;
    if (atk.steelySpirit && effectiveMove.type == PokemonType.steel) atkPowerMod *= 1.5;
    if (atk.flowerGift && effectiveMove.category == MoveCategory.physical &&
        (_weather == Weather.sun || _weather == Weather.harshSun)) atkStatMod *= 1.5;

    return DamageCalculator.calculate(
      atkBaseStats: atk.baseStats, atkIv: atk.iv, atkEv: atk.ev,
      atkNature: atk.nature, atkLevel: atk.level,
      atkType1: atk.type1, atkType2: atk.type2,
      atkRank: atk.rank,
      atkAbility: atk.selectedAbility,
      atkItem: atk.selectedItem,
      atkStatus: atk.status,
      atkHpPercent: atk.hpPercent,
      atkStatModifier: atkStatMod,
      atkPowerModifier: atkPowerMod,
      transformed: transformed,
      isCritical: atk.criticals[moveIndex],
      opponentAttack: _calcStats(def).attack,
      defBaseStats: def.baseStats, defIv: def.iv, defEv: def.ev,
      defNature: def.nature, defLevel: def.level,
      defType1: def.type1, defType2: def.type2,
      defRank: def.rank,
      defAbility: def.selectedAbility,
      defItem: def.selectedItem,
      defFinalEvo: def.finalEvo,
      defStatus: def.status,
      weather: _weather,
      terrain: _terrain,
      room: _room,
      atkGrounded: isGrounded(
        type1: atk.type1, type2: atk.type2,
        ability: atk.selectedAbility, item: atk.selectedItem,
        gravity: _room.gravity,
      ),
      hasGuts: atk.selectedAbility == 'Guts',
    );
  }

  Widget _buildDamageCalcTab() {
    final defHp = _calcStats(_defender).hp;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            '${_attacker.pokemonName} → ${_defender.pokemonName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            '방어측 HP: $defHp',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Each move result
          for (int i = 0; i < 4; i++) ...[
            _buildMoveResult(i),
            if (i < 3) const Divider(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildMoveResult(int index) {
    final move = _attacker.moves[index];
    if (move == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('기술 ${index + 1}: 미설정',
            style: TextStyle(color: Colors.grey[400])),
      );
    }

    final result = _calcDamage(_attacker, _defender, index);
    final effectiveType = _attacker.typeOverrides[index] ?? move.type;

    // Effectiveness label
    String effLabel = '';
    Color effColor = Colors.grey;
    if (result.effectiveness == 0) {
      effLabel = '효과 없음';
      effColor = Colors.grey;
    } else if (result.effectiveness >= 4) {
      effLabel = '효과 발군 (x4)';
      effColor = Colors.red[700]!;
    } else if (result.effectiveness >= 2) {
      effLabel = '효과 발군';
      effColor = Colors.red;
    } else if (result.effectiveness <= 0.25) {
      effLabel = '효과 별로 (x0.25)';
      effColor = Colors.blue[700]!;
    } else if (result.effectiveness <= 0.5) {
      effLabel = '효과 별로';
      effColor = Colors.blue;
    }

    // Hits to KO label
    String hitsLabel = '';
    if (result.hits == 1) {
      hitsLabel = '확정 1타';
    } else if (result.hits > 0) {
      hitsLabel = '확정 ${result.hits}타';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(move.nameKo, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold,
            )),
            const SizedBox(width: 8),
            Text(KoStrings.getTypeKo(effectiveType),
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (effLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(effLabel, style: TextStyle(fontSize: 12, color: effColor, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${result.minDamage} ~ ${result.maxDamage}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text(
              '(${result.minPercent.toStringAsFixed(1)}% ~ ${result.maxPercent.toStringAsFixed(1)}%)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        if (hitsLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(hitsLabel, style: TextStyle(
              fontSize: 13, color: result.hits <= 2 ? Colors.red : Colors.orange,
              fontWeight: FontWeight.w600,
            )),
          ),
      ],
    );
  }

  Widget _buildSpeedCompareTab() {
    return const Center(
      child: Text(
        '스피드 비교\n(준비 중)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}

