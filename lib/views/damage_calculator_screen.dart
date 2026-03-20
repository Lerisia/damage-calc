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
  int _resetCounter = 0;

  // Default: Bulbasaur
  PokemonType _type1 = PokemonType.grass;
  PokemonType? _type2 = PokemonType.poison;
  Stats _baseStats = const Stats(
    hp: 45, attack: 49, defense: 49,
    spAttack: 65, spDefense: 65, speed: 45,
  );
  List<String> _pokemonAbilities = ['Overgrow', 'Chlorophyll'];
  String? _selectedAbility = 'Overgrow';

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
  final List<PokemonType?> _typeOverrides = [null, null, null, null];
  final List<MoveCategory?> _categoryOverrides = [null, null, null, null];
  final List<int?> _powerOverrides = [null, null, null, null];
  final List<bool> _criticals = [false, false, false, false];

  String? _selectedItem;
  Rank _rank = const Rank();
  int _hpPercent = 100;
  Weather _weather = Weather.none;
  Terrain _terrain = Terrain.none;

  int? _computeResultFor(Move? move, bool isCritical, {
    PokemonType? typeOverride,
    MoveCategory? categoryOverride,
    int? powerOverride,
  }) {
    if (move == null) return null;
    move = move.copyWith(
      type: typeOverride,
      power: powerOverride,
      category: categoryOverride,
    );

    // Transform move (Weather Ball, HP power, terrain boost, etc.)
    final context = MoveContext(
      weather: _weather,
      terrain: _terrain,
      rank: _rank,
      hpPercent: _hpPercent,
      hasItem: _selectedItem != null,
    );
    final transformed = transformMove(move, context);

    final itemEffect = _selectedItem != null
        ? getItemEffect(_selectedItem!, move: transformed.move)
        : const ItemEffect();
    final abilityEffect = _selectedAbility != null
        ? getAbilityEffect(_selectedAbility!, move: transformed.move)
        : const AbilityEffect();

    final double statMod =
        itemEffect.statModifier * abilityEffect.statModifier;
    final double powerMod =
        itemEffect.powerModifier * abilityEffect.powerModifier;

    return OffensiveCalculator.calculate(
      baseStats: _baseStats,
      iv: _iv,
      ev: _ev,
      nature: _nature,
      level: _level,
      transformed: transformed,
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

  void _reset() {
    setState(() {
      _resetCounter++;
      _type1 = PokemonType.grass;
      _type2 = PokemonType.poison;
      _baseStats = const Stats(
        hp: 45, attack: 49, defense: 49,
        spAttack: 65, spDefense: 65, speed: 45,
      );
      _pokemonAbilities = ['Overgrow', 'Chlorophyll'];
      _selectedAbility = 'Overgrow';
      _level = 50;
      _nature = Nature.hardy;
      _iv = const Stats(
        hp: 31, attack: 31, defense: 31,
        spAttack: 31, spDefense: 31, speed: 31,
      );
      _ev = const Stats(
        hp: 0, attack: 0, defense: 0,
        spAttack: 0, spDefense: 0, speed: 0,
      );
      _moves.fillRange(0, 4, null);
      _typeOverrides.fillRange(0, 4, null);
      _categoryOverrides.fillRange(0, 4, null);
      _powerOverrides.fillRange(0, 4, null);
      _criticals.fillRange(0, 4, false);
      _selectedItem = null;
      _rank = const Rank();
      _hpPercent = 100;
      _weather = Weather.none;
      _terrain = Terrain.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결정력 계산기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '초기화',
            onPressed: _reset,
          ),
        ],
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
                key: ValueKey('pokemon_$_resetCounter'),
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
                key: ValueKey('stats_$_resetCounter'),
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
                hpPercent: _hpPercent,
                onHpPercentChanged: (v) => setState(() => _hpPercent = v),
              ),
            ),
            const SizedBox(height: 12),

            _sectionCard(
              title: '기술',
              child: Column(
                children: [
                  // Header row
                  _moveHeader(context),
                  const Divider(height: 1),
                  for (int i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(height: 2),
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

  Widget _moveHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('기술명', style: style)),
          SizedBox(width: 36, child: Text('타입', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Text('분류', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 40, child: Text('위력', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Text('급소', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text('결정력', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _moveSlot(int index) {
    final move = _moves[index];
    final effectiveType = _typeOverrides[index] ?? move?.type;
    final effectiveCategory = _categoryOverrides[index] ?? move?.category;
    final int basePower;
    if (move != null) {
      final context = MoveContext(
        weather: _weather,
        terrain: _terrain,
        rank: _rank,
        hpPercent: _hpPercent,
        hasItem: _selectedItem != null,
      );
      basePower = transformMove(move, context).move.power;
    } else {
      basePower = 0;
    }
    final effectivePower = _powerOverrides[index] ?? basePower;
    final result = _computeResultFor(move, _criticals[index],
      typeOverride: _typeOverrides[index],
      categoryOverride: _categoryOverrides[index],
      powerOverride: _powerOverrides[index],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: MoveSelector(
              key: ValueKey('move_${index}_$_resetCounter'),
              onSelected: (m) => setState(() {
                _moves[index] = m;
                _typeOverrides[index] = null;
                _categoryOverrides[index] = null;
                _powerOverrides[index] = null;
                _criticals[index] = m.hasTag('custom:always_crit');
              }),
            ),
          ),
          // Type (tappable dropdown)
          SizedBox(
            width: 40,
            child: move != null
                ? PopupMenuButton<PokemonType>(
                    initialValue: effectiveType,
                    padding: EdgeInsets.zero,
                    child: Text(
                      _typeKo(effectiveType!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _typeOverrides[index] != null ? Colors.orange : null,
                      ),
                    ),
                    itemBuilder: (_) => PokemonType.values
                        .map((t) => PopupMenuItem(value: t, child: Text(_typeKo(t), style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onSelected: (t) => setState(() => _typeOverrides[index] = t),
                  )
                : const Text('-', textAlign: TextAlign.center),
          ),
          // Category (tappable dropdown)
          SizedBox(
            width: 32,
            child: move != null
                ? PopupMenuButton<MoveCategory>(
                    initialValue: effectiveCategory,
                    padding: EdgeInsets.zero,
                    child: Text(
                      _categoryKo(effectiveCategory!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _categoryOverrides[index] != null ? Colors.orange : null,
                      ),
                    ),
                    itemBuilder: (_) => [MoveCategory.physical, MoveCategory.special]
                        .map((c) => PopupMenuItem(value: c, child: Text(_categoryKo(c), style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onSelected: (c) => setState(() => _categoryOverrides[index] = c),
                  )
                : const Text('-', textAlign: TextAlign.center),
          ),
          // Power (editable)
          SizedBox(
            width: 40,
            child: move != null
                ? SizedBox(
                    height: 28,
                    child: TextFormField(
                      key: ValueKey('power_${index}_${move.name}_$effectivePower'),
                      initialValue: '${effectivePower ?? 0}',
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                      ),
                      onChanged: (text) {
                        final parsed = int.tryParse(text);
                        if (parsed != null && parsed >= 0) {
                          setState(() => _powerOverrides[index] = parsed);
                        }
                      },
                    ),
                  )
                : const Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          ),
          // Critical
          SizedBox(
            width: 28,
            child: Checkbox(
              value: _criticals[index],
              onChanged: (v) => setState(() => _criticals[index] = v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          // Result
          SizedBox(
            width: 60,
            child: Text(
              result != null ? '$result' : '-',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeKo(PokemonType t) {
    const map = {
      PokemonType.normal: '노말', PokemonType.fire: '불꽃',
      PokemonType.water: '물', PokemonType.electric: '전기',
      PokemonType.grass: '풀', PokemonType.ice: '얼음',
      PokemonType.fighting: '격투', PokemonType.poison: '독',
      PokemonType.ground: '땅', PokemonType.flying: '비행',
      PokemonType.psychic: '에스퍼', PokemonType.bug: '벌레',
      PokemonType.rock: '바위', PokemonType.ghost: '고스트',
      PokemonType.dragon: '드래곤', PokemonType.dark: '악',
      PokemonType.steel: '강철', PokemonType.fairy: '페어리',
    };
    return map[t] ?? t.name;
  }

  String _categoryKo(MoveCategory c) {
    switch (c) {
      case MoveCategory.physical: return '물리';
      case MoveCategory.special: return '특수';
      case MoveCategory.status: return '변화';
    }
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
