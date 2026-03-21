import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/image_saver.dart' as saver;
import '../utils/stat_calculator.dart';
import '../models/battle_pokemon.dart';
import '../models/stats.dart';
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
  Room _room = Room.none;

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
            // Room dropdown icon
            PopupMenuButton<Room>(
              initialValue: _room,
              tooltip: '룸',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(KoStrings.roomIcon[_room]!, style: const TextStyle(fontSize: 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Room.values
                  .map((r) => PopupMenuItem(
                      value: r,
                      child: Row(
                        children: [
                          Text(KoStrings.roomIcon[r]!, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(KoStrings.roomKo[r]!),
                        ],
                      )))
                  .toList(),
              onSelected: (v) => setState(() => _room = v),
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
                  opponentSpeed: _calcStats(_defender).speed,
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
                  opponentSpeed: _calcStats(_attacker).speed,
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

  Widget _buildDamageCalcTab() {
    return const Center(
      child: Text(
        '대미지 계산\n(준비 중)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
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

