import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/ability_effects.dart';
import '../utils/damage_calculator.dart';
import '../utils/defensive_calculator.dart';
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
    return calcEffectiveSpeed(
      baseSpeed: _calcStats(s).speed,
      ability: s.selectedAbility,
      item: s.selectedItem,
      status: s.status,
      weather: _weather,
      terrain: _terrain,
      isDynamaxed: s.dynamax != DynamaxState.none,
      tailwind: s.tailwind,
    );
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

  /// Get the 결정력 for a specific move slot from the attacker panel.
  int? _getOffensivePower(int moveIndex) {
    return _attackerPanelKey.currentState?.computeResultFor(moveIndex);
  }

  /// Get the 내구 for the defender.
  ({int physical, int special}) _getDefensiveBulk() {
    return DefensiveCalculator.calculate(
      baseStats: _defender.baseStats,
      iv: _defender.iv, ev: _defender.ev,
      nature: _defender.nature, level: _defender.level,
      type1: _defender.type1, type2: _defender.type2,
      rank: _defender.rank,
      weather: _weather,
      ability: _defender.selectedAbility,
      item: _defender.selectedItem,
      finalEvo: _defender.finalEvo,
      status: _defender.status,
      flowerGift: _defender.flowerGift,
      room: _room,
    );
  }

  DamageResult _calcDamage(int moveIndex) {
    final move = _attacker.moves[moveIndex];
    if (move == null) {
      return DamageResult(
        offensivePower: 0, defensiveBulk: 0,
        effectiveness: 1.0, baseDamage: 0,
        minDamage: 0, maxDamage: 0,
        defenderHp: _calcStats(_defender).hp,
        isPhysical: true,
      );
    }

    final effectiveType = _attacker.typeOverrides[moveIndex] ?? move.type;
    final effectiveCategory = _attacker.categoryOverrides[moveIndex] ?? move.category;
    final isPhysical = effectiveCategory == MoveCategory.physical;

    final offensivePower = _getOffensivePower(moveIndex) ?? 0;
    final bulk = _getDefensiveBulk();
    final defensiveBulk = isPhysical ? bulk.physical : bulk.special;
    final defHp = _calcStats(_defender).hp;

    return DamageCalculator.calculate(
      offensivePower: offensivePower,
      defensiveBulk: defensiveBulk,
      moveType: effectiveType,
      defType1: _defender.type1,
      defType2: _defender.type2,
      defenderHp: defHp,
      isPhysical: isPhysical,
    );
  }

  Widget _buildDamageCalcTab() {
    final defHp = _calcStats(_defender).hp;
    final bulk = _getDefensiveBulk();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: 공격측 → 방어측 (Korean names)
          Text(
            '${_attacker.pokemonNameKo} → ${_defender.pokemonNameKo}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            'HP $defHp | 물리내구 ${bulk.physical} | 특수내구 ${bulk.special}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

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

    final result = _calcDamage(index);
    final effectiveType = _attacker.typeOverrides[index] ?? move.type;
    final categoryLabel = result.isPhysical ? '물리' : '특수';

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

    // KO info
    String koLabel = '';
    Color koColor = Colors.grey;
    if (result.hitsToKo == 1) {
      final label = result.oneshotLabel;
      koLabel = '$label 1타';
      koColor = label == '확정' ? Colors.red : Colors.orange;
    } else if (result.hitsToKo > 0) {
      koLabel = '${result.hitsToKo}타';
      koColor = result.hitsToKo <= 2 ? Colors.red : Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Move name + type + effectiveness
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
        const SizedBox(height: 2),
        // 결정력 / 내구 info
        Text(
          '$categoryLabel 결정력 ${result.offensivePower} → $categoryLabel 내구 ${result.defensiveBulk}',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        // Damage range + percent + KO
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
            if (koLabel.isNotEmpty) ...[
              const Spacer(),
              Text(koLabel, style: TextStyle(
                fontSize: 14, color: koColor, fontWeight: FontWeight.bold,
              )),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedCompareTab() {
    final atkEffSpeed = _calcEffectiveSpeed(_attacker);
    final defEffSpeed = _calcEffectiveSpeed(_defender);
    final atkAlwaysLast = _isAlwaysLast(_attacker);
    final defAlwaysLast = _isAlwaysLast(_defender);
    final result = getSpeedResult(
      mySpeed: atkEffSpeed,
      opponentSpeed: defEffSpeed,
      myAlwaysLast: atkAlwaysLast,
      opponentAlwaysLast: defAlwaysLast,
      room: _room,
    );
    final diff = (atkEffSpeed - defEffSpeed).abs();

    String resultText;
    Color resultColor;
    String resultIcon;
    switch (result) {
      case SpeedResult.faster:
        resultText = '▲ 공격측이 ${diff} 빠름';
        resultColor = Colors.red;
        resultIcon = '▲';
      case SpeedResult.slower:
        resultText = '▼ 방어측이 ${diff} 빠름';
        resultColor = Colors.blue;
        resultIcon = '▼';
      case SpeedResult.tied:
        resultText = '⚡ 동속 (랜덤)';
        resultColor = Colors.orange;
        resultIcon = '⚡';
      case SpeedResult.alwaysFirst:
        resultText = '▲▲ 공격측 선공 (확정)';
        resultColor = Colors.red;
        resultIcon = '▲▲';
      case SpeedResult.alwaysLast:
        resultText = '▼▼ 방어측 선공 (확정)';
        resultColor = Colors.blue;
        resultIcon = '▼▼';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Attacker speed panel
          _speedPanel(
            label: '공격측',
            color: Colors.red,
            state: _attacker,
            effSpeed: atkEffSpeed,
          ),
          const SizedBox(height: 8),

          // Result banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: resultColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: resultColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(resultText, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: resultColor,
                )),
                if (_room.trickRoom)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('🔄 트릭룸 적용 중', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Defender speed panel
          _speedPanel(
            label: '방어측',
            color: Colors.blue,
            state: _defender,
            effSpeed: defEffSpeed,
          ),
        ],
      ),
    );
  }

  Widget _speedPanel({
    required String label,
    required Color color,
    required BattlePokemonState state,
    required int effSpeed,
  }) {
    final rawSpeed = _calcStats(state).speed;
    final speedBase = state.baseStats.speed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('$label ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              Expanded(child: Text(state.pokemonNameKo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),

          // Speed result
          Row(
            children: [
              Text('실수치 ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text('$rawSpeed', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text('  →  ', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
              Text('최종 ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text('$effSpeed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),

          // Speed stat row (flex-based)
          Row(
            children: [
              Expanded(flex: 2, child: Text('종족', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Center(child: Text('$speedBase', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))),
              Expanded(flex: 2, child: Text('개체', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: _speedInput('${state.iv.speed}', (v) {
                final val = int.tryParse(v) ?? 31;
                setState(() {
                  state.iv = Stats(hp: state.iv.hp, attack: state.iv.attack, defense: state.iv.defense,
                    spAttack: state.iv.spAttack, spDefense: state.iv.spDefense, speed: val.clamp(0, 31));
                });
              })),
              Expanded(flex: 2, child: Text('노력', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: _speedInput('${state.ev.speed}', (v) {
                final val = int.tryParse(v) ?? 0;
                setState(() {
                  state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                    spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: val.clamp(0, 252));
                });
              })),
              Expanded(flex: 2, child: Text('랭크', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: _speedInput('${state.rank.speed}', (v) {
                final val = int.tryParse(v) ?? 0;
                setState(() {
                  state.rank = Rank(attack: state.rank.attack, defense: state.rank.defense,
                    spAttack: state.rank.spAttack, spDefense: state.rank.spDefense, speed: val.clamp(-6, 6));
                });
              }, signed: true)),
            ],
          ),
          const SizedBox(height: 10),

          // Modifiers row (flex-based)
          Row(
            children: [
              Expanded(flex: 3, child: DropdownButtonFormField<Nature>(
                value: state.nature,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '성격', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: Nature.values.map((n) {
                  final isBuff = n.speedModifier > 1.0;
                  final isNerf = n.speedModifier < 1.0;
                  return DropdownMenuItem(value: n, child: Text(n.nameKo,
                    style: TextStyle(fontSize: 13, color: isBuff ? Colors.red : isNerf ? Colors.blue : null)));
                }).toList(),
                onChanged: (v) { if (v != null) setState(() => state.nature = v); },
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: DropdownButtonFormField<StatusCondition>(
                value: state.status,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '상태이상', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: [StatusCondition.none, StatusCondition.paralysis].map((st) {
                  return DropdownMenuItem(value: st, child: Text(
                    st == StatusCondition.none ? '없음' : '마비', style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (v) { if (v != null) setState(() => state.status = v); },
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: InkWell(
                onTap: () => setState(() => state.tailwind = !state.tailwind),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 22, height: 22, child: Checkbox(
                        value: state.tailwind,
                        onChanged: (v) => setState(() => state.tailwind = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )),
                      const SizedBox(width: 4),
                      const Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('순풍', style: TextStyle(fontSize: 14)))),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speedInput(String initialValue, ValueChanged<String> onChanged, {bool signed = false}) {
    return SizedBox(
      height: 32,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: signed ? const TextInputType.numberWithOptions(signed: true) : TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
        onChanged: onChanged,
      ),
    );
  }

  String _fmtEff(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }
}

