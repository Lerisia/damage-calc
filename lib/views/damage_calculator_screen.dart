import 'package:flutter/material.dart';
import '../models/move.dart';
import '../models/nature.dart';
import '../models/rank.dart';
import '../models/stats.dart';
import '../models/type.dart';
import '../models/weather.dart';
import '../models/terrain.dart';
import '../utils/offensive_calculator.dart';
import '../utils/move_transform.dart';
import '../utils/item_effects.dart';
import '../utils/ability_effects.dart';
import 'widgets/pokemon_selector.dart';
import 'widgets/move_selector.dart';
import 'widgets/stat_input.dart';

class DamageCalculatorScreen extends StatefulWidget {
  const DamageCalculatorScreen({super.key});

  @override
  State<DamageCalculatorScreen> createState() => _DamageCalculatorScreenState();
}

class _DamageCalculatorScreenState extends State<DamageCalculatorScreen> {
  PokemonType _type1 = PokemonType.normal;
  PokemonType? _type2;
  Stats _baseStats = const Stats(
    hp: 0, attack: 0, defense: 0,
    spAttack: 0, spDefense: 0, speed: 0,
  );
  List<String> _pokemonAbilities = [];
  String? _selectedAbility;

  int _level = 50;
  Nature _nature = Nature.hardy;
  Stats _iv = const Stats(
    hp: 31, attack: 31, defense: 31,
    spAttack: 31, spDefense: 31, speed: 31,
  );
  Stats _ev = const Stats(
    hp: 0, attack: 0, defense: 0,
    spAttack: 0, spDefense: 0, speed: 0,
  );

  // 4 move slots
  final List<Move?> _moves = [null, null, null, null];
  final List<bool> _criticals = [false, false, false, false];

  String? _selectedItem;
  Rank _rank = const Rank();
  Weather _weather = Weather.none;
  Terrain _terrain = Terrain.none;

  int? _computeResultFor(Move? move, bool isCritical) {
    if (move == null) return null;

    final itemEffect = _selectedItem != null
        ? getItemEffect(_selectedItem!, move: move)
        : const ItemEffect();
    final abilityEffect = _selectedAbility != null
        ? getAbilityEffect(_selectedAbility!, move: move)
        : const AbilityEffect();

    final double statMod =
        itemEffect.statModifier * abilityEffect.statModifier;
    final double powerMod =
        itemEffect.powerModifier * abilityEffect.powerModifier;

    var effectiveMove = applyWeatherToMove(move, _weather);
    effectiveMove = applyTerrainToMove(effectiveMove, _terrain);

    return OffensiveCalculator.calculate(
      baseStats: _baseStats,
      iv: _iv,
      ev: _ev,
      nature: _nature,
      level: _level,
      move: effectiveMove,
      type1: _type1,
      type2: _type2,
      rank: _rank,
      weather: _weather,
      terrain: _terrain,
      statModifier: statMod,
      powerModifier: powerMod,
      isCritical: isCritical,
    );
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결정력 계산기'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard(
              title: '포켓몬',
              child: PokemonSelector(
                onSelected: (name, type1, type2, baseStats, abilities) {
                  setState(() {
                    _type1 = type1;
                    _type2 = type2;
                    _baseStats = baseStats;
                    _pokemonAbilities = abilities;
                    _selectedAbility =
                        abilities.isNotEmpty ? abilities.first : null;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            _sectionCard(
              title: '능력치',
              child: StatInput(
                level: _level,
                nature: _nature,
                iv: _iv,
                ev: _ev,
                baseStats: _baseStats,
                pokemonAbilities: _pokemonAbilities,
                selectedAbility: _selectedAbility,
                selectedItem: _selectedItem,
                rank: _rank,
                onLevelChanged: (v) => setState(() => _level = v),
                onNatureChanged: (v) => setState(() => _nature = v),
                onIvChanged: (v) => setState(() => _iv = v),
                onEvChanged: (v) => setState(() => _ev = v),
                onAbilityChanged: (v) => setState(() => _selectedAbility = v),
                onItemChanged: (v) => setState(() => _selectedItem = v),
                onRankChanged: (v) => setState(() => _rank = v),
              ),
            ),
            const SizedBox(height: 12),

            _sectionCard(
              title: '기술',
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      const SizedBox(
                        width: 32,
                        child: Text('급소', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                      const SizedBox(
                        width: 64,
                        child: Text('결정력', textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (int i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _moveSlot(i),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            _sectionCard(
              title: '필드 효과',
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Weather>(
                      value: _weather,
                      decoration: const InputDecoration(
                        labelText: '날씨',
                        isDense: true,
                      ),
                      items: Weather.values
                          .map((w) => DropdownMenuItem(
                              value: w, child: Text(_weatherKo(w))))
                          .toList(),
                      onChanged: (v) => setState(() => _weather = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<Terrain>(
                      value: _terrain,
                      decoration: const InputDecoration(
                        labelText: '필드',
                        isDense: true,
                      ),
                      items: Terrain.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(_terrainKo(t))))
                          .toList(),
                      onChanged: (v) => setState(() => _terrain = v!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moveSlot(int index) {
    final result = _computeResultFor(_moves[index], _criticals[index]);

    return Row(
      children: [
        Expanded(
          child: MoveSelector(
            key: ValueKey('move_$index'),
            onSelected: (move) => setState(() => _moves[index] = move),
          ),
        ),
        SizedBox(
          width: 32,
          child: Checkbox(
            value: _criticals[index],
            onChanged: (v) => setState(() => _criticals[index] = v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        // Result
        SizedBox(
          width: 64,
          child: Text(
            result != null ? '$result' : '-',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String _weatherKo(Weather w) {
    switch (w) {
      case Weather.none: return '없음';
      case Weather.sun: return '쾌청';
      case Weather.rain: return '비';
      case Weather.sandstorm: return '모래바람';
      case Weather.snow: return '눈';
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
