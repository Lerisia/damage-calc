import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../data/abilitydex.dart';
import '../data/itemdex.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/battle_facade.dart';
import '../utils/damage_calculator.dart';
import '../utils/random_factor.dart';
import '../utils/grounded.dart';
import '../utils/item_effects.dart';
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

  // Name maps for _formatNote (loaded async)
  Map<String, String> _abilityNameMap = {};
  Map<String, String> _itemNameMap = {};

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

  /// Called when either panel changes. Syncs weather/terrain from abilities.
  void _onPanelChanged() {
    setState(() {
      _syncWeatherTerrain();
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
    // Rebuild only when switching to damage/speed tabs (index 2, 3)
    // to pick up latest mutable state without rebuilding on attacker/defender tab switches
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index >= 2) {
        setState(() {});
      }
    });
    _loadNameMaps();
  }

  Future<void> _loadNameMaps() async {
    try {
      final items = await loadItemdex();
      final abilities = await loadAbilitydex();
      final iMap = <String, String>{};
      for (final e in items.values) {
        iMap[e.name] = e.nameKo;
      }
      final aMap = <String, String>{};
      for (final e in abilities.values) {
        aMap[e.name] = e.nameKo;
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
                  onChanged: _onPanelChanged,
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
                  onChanged: _onPanelChanged,
                  resetCounter: _resetCounter,
                  isAttacker: false,
                  opponentSpeed: _calcEffectiveSpeed(_attacker),
                  opponentAlwaysLast: _isAlwaysLast(_attacker),
                  opponentAttack: _calcStats(_attacker).attack,
                  opponentGender: _attacker.gender,
                ),
                _buildDamageCalcTab(),
                SpeedCompareTab(
                  attacker: _attacker,
                  defender: _defender,
                  weather: _weather,
                  terrain: _terrain,
                  room: _room,
                  onChanged: () => setState(() {}),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: 공격측 → 방어측 with type info
          Text(
            '${_attacker.pokemonNameKo} → ${_defender.pokemonNameKo}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dmgTypeBadge(_attacker.type1),
              if (_attacker.type2 != null) ...[
                const SizedBox(width: 3),
                _dmgTypeBadge(_attacker.type2!),
              ],
              if (_attacker.terastal.active && _attacker.terastal.teraType != null) ...[
                const Text(' → ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                _dmgTypeBadge(_attacker.terastal.teraType!),
              ],
              const SizedBox(width: 12),
              const Text('→', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(width: 12),
              _dmgTypeBadge(_defender.type1),
              if (_defender.type2 != null) ...[
                const SizedBox(width: 3),
                _dmgTypeBadge(_defender.type2!),
              ],
              if (_defender.terastal.active && _defender.terastal.teraType != null) ...[
                const Text(' → ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                _dmgTypeBadge(_defender.terastal.teraType!),
              ],
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
                child: Text(move.nameKo, style: const TextStyle(
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
          return '$name ${parts[2]}';
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
        };
        final key = parts[1];
        final label = moveKo[key] ?? key;
        if (parts.length >= 3) return '$label ${parts[2]}';
        return label;
      case 'moldbreaker':
        final name = _abilityNameMap[parts[1]] ?? parts[1];
        return '$name: 상대 특성 무시';
      case 'ground':
        return '비접지 상태로 땅 기술 무효';
      case 'type':
        return '타입 상성에 의해 무효';
      default:
        return note;
    }
  }
}

