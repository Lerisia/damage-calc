import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/battle_facade.dart';
import '../utils/damage_calculator.dart';
import '../utils/random_factor.dart';
import '../utils/grounded.dart';
import '../utils/item_effects.dart';
import '../utils/stat_calculator.dart';
import '../models/move.dart';
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
import 'widgets/pokemon_selector.dart';

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

  // Cached data for speed tab
  Map<String, String> _itemNameMap = {};
  Map<String, String> _abilityNameMap = {};

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

  bool _isAlwaysLast(BattlePokemonState s) {
    if (s.selectedItem == null) return false;
    if (s.dynamax != DynamaxState.none) return false;
    return getSpeedItemEffect(s.selectedItem!).alwaysLast;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSpeedTabData();
  }

  Future<void> _loadSpeedTabData() async {
    try {
      final itemJson = await rootBundle.loadString('assets/items.json');
      final List<dynamic> items = json.decode(itemJson) as List<dynamic>;
      final iMap = <String, String>{};
      for (final e in items) {
        if (e['battle'] == true) iMap[e['name'] as String] = e['nameKo'] as String;
      }

      final abilityJson = await rootBundle.loadString('assets/abilities.json');
      final List<dynamic> abilities = json.decode(abilityJson) as List<dynamic>;
      final aMap = <String, String>{};
      for (final e in abilities) {
        aMap[e['name'] as String] = e['nameKo'] as String;
      }

      if (mounted) setState(() { _itemNameMap = iMap; _abilityNameMap = aMap; });
    } catch (_) {}
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

  /// Get the 결정력 for a specific move slot from the attacker panel (for display only).
  int? _getOffensivePower(int moveIndex) {
    return _attackerPanelKey.currentState?.computeResultFor(moveIndex);
  }

  /// Get the 내구 for the defender (for display only).
  ({int physical, int special}) _getDefensiveBulk() {
    return BattleFacade.calcBulk(
      state: _defender,
      weather: _weather,
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'HP $defHp | 물리내구 ${bulk.physical} | 특수내구 ${bulk.special}',
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
              Expanded(child: _dmgCheck('오로라베일', _defender.auroraVeil, (v) {
                setState(() => _defender.auroraVeil = v);
              })),
              Expanded(child: _dmgCheck('프렌드가드', _defender.friendGuard, (v) {
                setState(() => _defender.friendGuard = v);
              })),
            ],
          ),
          const SizedBox(height: 12),

          for (int i = 0; i < 4; i++) ...[
            _buildMoveResult(i),
            if (i < 3) const Divider(height: 28),
          ],
        ],
      ),
    );
  }

  Widget _buildMoveResult(int index) {
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
    final categoryLabel = result.isPhysical ? '물리' : '특수';
    final offPower = _getOffensivePower(index);
    final bulk = _getDefensiveBulk();
    final defBulk = result.isPhysical ? bulk.physical : bulk.special;

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
        final label = RandomFactor.koLabel(info.koCount, info.totalCount) ?? '';
        final pct = (info.koCount / info.totalCount * 100);
        if (label == '확정') {
          koText = '확정 ${info.hits}타';
          koColor = info.hits <= 2 ? Colors.red : Colors.orange;
        } else {
          koText = '$label ${info.hits}타 (${pct.toStringAsFixed(1)}%)';
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
                child: Text(move.nameKo, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                )),
              ),
              const SizedBox(width: 8),
              Text(KoStrings.getTypeKo(effectiveType),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(width: 8),
              Text(effLabel, style: TextStyle(fontSize: 13, color: effColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          // 결정력 / 내구 info (display only)
          Text(
            '$categoryLabel 결정력 ${offPower ?? '-'} → $categoryLabel 내구 $defBulk',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          // % damage (main) + raw damage + KO
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${result.minPercent.toStringAsFixed(1)}% ~ ${result.maxPercent.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Text(
                '${result.minDamage} ~ ${result.maxDamage}',
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              if (koText.isNotEmpty) ...[
                const Spacer(),
                Text(koText, style: TextStyle(
                  fontSize: 16, color: koColor, fontWeight: FontWeight.bold,
                )),
              ],
            ],
          ),
          // Modifier notes
          if (result.modifierNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: result.modifierNotes.map((note) => Text(
                note,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              )).toList(),
            ),
          ],
        ],
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
          // Header: label + pokemon selector + base speed
          Row(
            children: [
              Text('$label ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              Expanded(child: PokemonSelector(
                key: ValueKey('speed_pokemon_${state.pokemonName}'),
                initialPokemonName: state.pokemonName,
                onSelected: (pokemon) => setState(() {
                  state.pokemonName = pokemon.name;
                  state.pokemonNameKo = pokemon.nameKo;
                  state.finalEvo = pokemon.finalEvo;
                  state.type1 = pokemon.type1;
                  state.type2 = pokemon.type2;
                  state.baseStats = pokemon.baseStats;
                  state.pokemonAbilities = pokemon.abilities;
                  state.selectedAbility = pokemon.abilities.isNotEmpty ? pokemon.abilities.first : null;
                  state.genderRate = pokemon.genderRate;
                  _resetCounter++;
                }),
              )),
              const SizedBox(width: 8),
              Text('종족값 $speedBase', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),

          // 실수치 → 최종
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

          // Row 1: 개체, 노력 (with 0/max), 랭크 (with -1/+1)
          Row(
            children: [
              Text('개체 ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              SizedBox(width: 40, child: _speedInput('${state.iv.speed}', (v) {
                final val = int.tryParse(v) ?? 31;
                setState(() {
                  state.iv = Stats(hp: state.iv.hp, attack: state.iv.attack, defense: state.iv.defense,
                    spAttack: state.iv.spAttack, spDefense: state.iv.spDefense, speed: val.clamp(0, 31));
                });
              })),
              const SizedBox(width: 12),
              Text('노력 ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              SizedBox(width: 44, child: _speedInput('${state.ev.speed}', (v) {
                final val = int.tryParse(v) ?? 0;
                setState(() {
                  state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                    spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: val.clamp(0, 252));
                });
              })),
              _miniButton('0', () => setState(() {
                state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                  spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: 0);
              })),
              _miniButton('max', () => setState(() {
                state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                  spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: 252);
              })),
              const SizedBox(width: 12),
              Text('랭크 ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              _miniButton('-1', () => setState(() {
                final val = (state.rank.speed - 1).clamp(-6, 6);
                state.rank = Rank(attack: state.rank.attack, defense: state.rank.defense,
                  spAttack: state.rank.spAttack, spDefense: state.rank.spDefense, speed: val);
              })),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${state.rank.speed >= 0 ? "+" : ""}${state.rank.speed}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              _miniButton('+1', () => setState(() {
                final val = (state.rank.speed + 1).clamp(-6, 6);
                state.rank = Rank(attack: state.rank.attack, defense: state.rank.defense,
                  spAttack: state.rank.spAttack, spDefense: state.rank.spDefense, speed: val);
              })),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: 레벨, 특성, 상태이상
          Row(
            children: [
              SizedBox(width: 56, child: TextFormField(
                key: ValueKey('speed_level_${state.level}'),
                initialValue: '${state.level}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(labelText: '레벨', isDense: true),
                onChanged: (v) {
                  final val = int.tryParse(v) ?? 50;
                  setState(() => state.level = val.clamp(1, 100));
                },
              )),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _speedAbilityAutocomplete(state)),
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
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: 성격, 아이템
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
              Expanded(flex: 2, child: _speedItemAutocomplete(state)),
            ],
          ),
          const SizedBox(height: 6),

          // Row 4: 순풍
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => state.tailwind = !state.tailwind),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 22, height: 22, child: Checkbox(
                        value: state.tailwind,
                        onChanged: (v) => setState(() => state.tailwind = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )),
                      const SizedBox(width: 4),
                      const Text('순풍', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ),
      ),
    );
  }

  Widget _speedInput(String initialValue, ValueChanged<String> onChanged, {String? label}) {
    return SizedBox(
      height: 32,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          prefixText: label != null ? '$label ' : null,
          prefixStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        onChanged: onChanged,
      ),
    );
  }

  String _itemKo(String? key) {
    if (key == null || key.isEmpty) return '없음';
    return _itemNameMap[key] ?? key;
  }

  String _abilityKo(String key) {
    return _abilityNameMap[key] ?? key;
  }

  Widget _speedAbilityAutocomplete(BattlePokemonState state) {
    final abilities = state.pokemonAbilities;
    final initialText = state.selectedAbility != null ? _abilityKo(state.selectedAbility!) : '';

    return KeyedSubtree(
      key: ValueKey('speed_ability_${state.selectedAbility}_${state.pokemonName}'),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: initialText),
        displayStringForOption: (a) => _abilityKo(a),
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty || textEditingValue.text == initialText) {
            return abilities;
          }
          final query = textEditingValue.text.toLowerCase();
          return abilities.where((a) =>
            _abilityKo(a).contains(query) || a.toLowerCase().contains(query));
        },
        onSelected: (v) => setState(() => state.selectedAbility = v),
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: '특성', isDense: true),
            onTap: () => controller.clear(),
          );
        },
      ),
    );
  }

  Widget _speedItemAutocomplete(BattlePokemonState state) {
    final allItems = ['', ..._itemNameMap.keys];
    if (state.selectedItem != null && allItems.contains(state.selectedItem)) {
      allItems.remove(state.selectedItem);
      allItems.insert(0, state.selectedItem!);
    }
    final initialText = _itemKo(state.selectedItem);

    return KeyedSubtree(
      key: ValueKey('speed_item_${state.selectedItem}'),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: initialText),
        displayStringForOption: (key) => _itemKo(key.isEmpty ? null : key),
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty || textEditingValue.text == initialText) {
            return allItems;
          }
          final query = textEditingValue.text.toLowerCase();
          return allItems.where((key) {
            final ko = _itemKo(key.isEmpty ? null : key);
            return ko.contains(query) || key.toLowerCase().contains(query);
          });
        },
        onSelected: (v) => setState(() => state.selectedItem = v.isEmpty ? null : v),
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(labelText: '아이템', isDense: true),
            onTap: () => controller.clear(),
          );
        },
      ),
    );
  }

  String _fmtEff(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }
}

