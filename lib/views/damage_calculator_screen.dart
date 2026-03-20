import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/image_saver.dart' as saver;
import '../models/battle_pokemon.dart';
import '../models/room.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'widgets/pokemon_panel.dart';

class DamageCalculatorScreen extends StatefulWidget {
  const DamageCalculatorScreen({super.key});

  @override
  State<DamageCalculatorScreen> createState() => _DamageCalculatorScreenState();
}

class _DamageCalculatorScreenState extends State<DamageCalculatorScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  final _attacker = BattlePokemonState();
  final _defender = BattlePokemonState();
  final _attackerPanelKey = GlobalKey<PokemonPanelState>();
  final _defenderPanelKey = GlobalKey<PokemonPanelState>();
  int _resetCounter = 0;

  Weather _weather = Weather.none;
  Terrain _terrain = Terrain.none;
  Room _room = Room.none;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                    Text(_weatherIcon(_weather), style: const TextStyle(fontSize: 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Weather.values
                  .map((w) => PopupMenuItem(
                      value: w,
                      child: Row(
                        children: [
                          Text(_weatherIcon(w), style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(_weatherKo(w)),
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
                    Text(_terrainIcon(_terrain), style: const TextStyle(fontSize: 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Terrain.values
                  .map((t) => PopupMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Text(_terrainIcon(t), style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(_terrainKo(t)),
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
                    Text(_roomIcon(_room), style: const TextStyle(fontSize: 20)),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (_) => Room.values
                  .map((r) => PopupMenuItem(
                      value: r,
                      child: Row(
                        children: [
                          Text(_roomIcon(r), style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(_roomKo(r)),
                        ],
                      )))
                  .toList(),
              onSelected: (v) => setState(() => _room = v),
            ),
            const Spacer(),
            Text(
              '결정력 계산기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: '캡처',
            onPressed: _capture,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '초기화',
            onPressed: _reset,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '공격측'),
            Tab(text: '방어측'),
            Tab(text: '대미지 계산'),
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
                ),
                _buildDamageCalcTab(),
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

  String _weatherIcon(Weather w) {
    switch (w) {
      case Weather.none: return '☁️';
      case Weather.sun: return '☀️';
      case Weather.rain: return '🌧️';
      case Weather.sandstorm: return '🏜️';
      case Weather.snow: return '❄️';
      case Weather.harshSun: return '🔥';
      case Weather.heavyRain: return '🌊';
      case Weather.strongWinds: return '🌪️';
    }
  }

  String _roomIcon(Room r) {
    switch (r) {
      case Room.none: return '🚪';
      case Room.trickRoom: return '🔄';
      case Room.magicRoom: return '✨';
      case Room.wonderRoom: return '❓';
    }
  }

  String _roomKo(Room r) {
    switch (r) {
      case Room.none: return '없음';
      case Room.trickRoom: return '트릭룸';
      case Room.magicRoom: return '매직룸';
      case Room.wonderRoom: return '원더룸';
    }
  }

  String _terrainIcon(Terrain t) {
    switch (t) {
      case Terrain.none: return '🌍';
      case Terrain.electric: return '⚡';
      case Terrain.grassy: return '🌿';
      case Terrain.psychic: return '🔮';
      case Terrain.misty: return '💫';
    }
  }

  String _weatherKo(Weather w) {
    switch (w) {
      case Weather.none: return '없음';
      case Weather.sun: return '쾌청';
      case Weather.rain: return '비';
      case Weather.sandstorm: return '모래바람';
      case Weather.snow: return '눈';
      case Weather.harshSun: return '강한 햇살';
      case Weather.heavyRain: return '강한 비';
      case Weather.strongWinds: return '난기류';
    }
  }

  String _terrainKo(Terrain t) {
    switch (t) {
      case Terrain.none: return '없음';
      case Terrain.electric: return '일렉트릭필드';
      case Terrain.grassy: return '그래스필드';
      case Terrain.psychic: return '사이코필드';
      case Terrain.misty: return '미스트필드';
    }
  }
}
