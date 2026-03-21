import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/battle_pokemon.dart';
import '../../models/dynamax.dart';
import '../../models/nature.dart';
import '../../models/rank.dart';
import '../../models/stats.dart';
import '../../models/status.dart';
import '../../models/room.dart';
import '../../models/terrain.dart';
import '../../models/weather.dart';
import '../../utils/battle_facade.dart';
import '../../utils/item_effects.dart';
import '../../utils/stat_calculator.dart';
import '../../utils/room_effects.dart';
import '../widgets/pokemon_selector.dart';

/// Self-contained speed comparison tab with keep-alive.
class SpeedCompareTab extends StatefulWidget {
  final BattlePokemonState attacker;
  final BattlePokemonState defender;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final VoidCallback onChanged;
  final int resetCounter;

  const SpeedCompareTab({
    super.key,
    required this.attacker,
    required this.defender,
    required this.weather,
    required this.terrain,
    required this.room,
    required this.onChanged,
    required this.resetCounter,
  });

  @override
  State<SpeedCompareTab> createState() => _SpeedCompareTabState();
}

class _SpeedCompareTabState extends State<SpeedCompareTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, String> _itemNameMap = {};
  Map<String, String> _abilityNameMap = {};
  List<String>? _cachedItemKeys;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      if (mounted) {
        setState(() {
          _itemNameMap = iMap;
          _abilityNameMap = aMap;
          _cachedItemKeys = null;
        });
      }
    } catch (_) {}
  }

  int _calcEffectiveSpeed(BattlePokemonState s) {
    return BattleFacade.calcSpeed(
      state: s,
      weather: widget.weather,
      terrain: widget.terrain,
    );
  }

  bool _isAlwaysLast(BattlePokemonState s) {
    if (s.selectedItem == null) return false;
    if (s.dynamax != DynamaxState.none) return false;
    return getSpeedItemEffect(s.selectedItem!).alwaysLast;
  }

  void _notify() {
    widget.onChanged();
  }

  String _itemKo(String? key) {
    if (key == null || key.isEmpty) return '없음';
    if (_itemNameMap.isEmpty) return '...';
    return _itemNameMap[key] ?? key;
  }

  String _abilityKo(String key) {
    if (_abilityNameMap.isEmpty) return '...';
    return _abilityNameMap[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final atk = widget.attacker;
    final def = widget.defender;
    final atkEffSpeed = _calcEffectiveSpeed(atk);
    final defEffSpeed = _calcEffectiveSpeed(def);
    final atkAlwaysLast = _isAlwaysLast(atk);
    final defAlwaysLast = _isAlwaysLast(def);
    final result = getSpeedResult(
      mySpeed: atkEffSpeed,
      opponentSpeed: defEffSpeed,
      myAlwaysLast: atkAlwaysLast,
      opponentAlwaysLast: defAlwaysLast,
      room: widget.room,
    );
    final diff = (atkEffSpeed - defEffSpeed).abs();

    String resultText;
    Color resultColor;
    switch (result) {
      case SpeedResult.faster:
        resultText = '▲ 공격측이 $diff 빠름';
        resultColor = Colors.red;
      case SpeedResult.slower:
        resultText = '▼ 방어측이 $diff 빠름';
        resultColor = Colors.blue;
      case SpeedResult.tied:
        resultText = '⚡ 동속 (랜덤)';
        resultColor = Colors.orange;
      case SpeedResult.alwaysFirst:
        resultText = '▲▲ 공격측 선공 (확정)';
        resultColor = Colors.red;
      case SpeedResult.alwaysLast:
        resultText = '▼▼ 방어측 선공 (확정)';
        resultColor = Colors.blue;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _speedPanel(label: '공격측', color: Colors.red, state: atk, effSpeed: atkEffSpeed),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: resultColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(resultText, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: resultColor,
                )),
                if (widget.room.trickRoom)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('🔄 트릭룸 적용 중', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _speedPanel(label: '방어측', color: Colors.blue, state: def, effSpeed: defEffSpeed),
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
    final rawSpeed = StatCalculator.calculate(
      baseStats: state.baseStats, iv: state.iv, ev: state.ev,
      nature: state.nature, level: state.level, rank: state.rank,
    ).speed;
    final speedBase = state.baseStats.speed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$label ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              Expanded(child: PokemonSelector(
                key: ValueKey('speed_pokemon_${widget.resetCounter}_${state.pokemonName}'),
                initialPokemonName: state.pokemonName,
                onSelected: (pokemon) {
                  setState(() {
                    state.pokemonName = pokemon.name;
                    state.pokemonNameKo = pokemon.nameKo;
                    state.finalEvo = pokemon.finalEvo;
                    state.type1 = pokemon.type1;
                    state.type2 = pokemon.type2;
                    state.baseStats = pokemon.baseStats;
                    state.pokemonAbilities = pokemon.abilities;
                    state.selectedAbility = pokemon.abilities.isNotEmpty ? pokemon.abilities.first : null;
                    state.genderRate = pokemon.genderRate;
                  });
                  _notify();
                },
              )),
              const SizedBox(width: 8),
              Text('종족값 $speedBase', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
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
          Row(
            children: [
              Text('개체 ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Expanded(flex: 2, child: _speedInput(
                key: ValueKey('iv_${state.iv.speed}'),
                '${state.iv.speed}', (v) {
                final val = int.tryParse(v) ?? 31;
                setState(() {
                  state.iv = Stats(hp: state.iv.hp, attack: state.iv.attack, defense: state.iv.defense,
                    spAttack: state.iv.spAttack, spDefense: state.iv.spDefense, speed: val.clamp(0, 31));
                });
                _notify();
              })),
              const SizedBox(width: 8),
              Text('노력 ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Expanded(flex: 3, child: _speedInput(
                key: ValueKey('ev_${state.ev.speed}'),
                '${state.ev.speed}', (v) {
                final val = int.tryParse(v) ?? 0;
                setState(() {
                  state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                    spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: val.clamp(0, 252));
                });
                _notify();
              })),
              _miniButton('0', () {
                setState(() {
                  state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                    spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: 0);
                });
                _notify();
              }),
              _miniButton('max', () {
                setState(() {
                  state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                    spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: 252);
                });
                _notify();
              }),
              const SizedBox(width: 8),
              Text('랭크 ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Expanded(flex: 2, child: _speedInput(
                key: ValueKey('rank_${state.rank.speed}'),
                '${state.rank.speed}', (v) {
                final val = int.tryParse(v) ?? 0;
                setState(() {
                  state.rank = Rank(attack: state.rank.attack, defense: state.rank.defense,
                    spAttack: state.rank.spAttack, spDefense: state.rank.spDefense, speed: val.clamp(-6, 6));
                });
                _notify();
              }, signed: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 56, child: TextFormField(
                key: ValueKey('speed_level_${widget.resetCounter}_${state.level}'),
                initialValue: '${state.level}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(labelText: '레벨', isDense: true),
                onChanged: (v) {
                  final val = int.tryParse(v) ?? 50;
                  setState(() => state.level = val.clamp(1, 100));
                  _notify();
                },
              )),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _abilityAutocomplete(state)),
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
                onChanged: (v) { if (v != null) { setState(() => state.status = v); _notify(); } },
              )),
            ],
          ),
          const SizedBox(height: 8),
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
                onChanged: (v) { if (v != null) { setState(() => state.nature = v); _notify(); } },
              )),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _itemAutocomplete(state)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              InkWell(
                onTap: () { setState(() => state.tailwind = !state.tailwind); _notify(); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 22, height: 22, child: Checkbox(
                        value: state.tailwind,
                        onChanged: (v) { setState(() => state.tailwind = v ?? false); _notify(); },
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

  Widget _speedInput(String initialValue, ValueChanged<String> onChanged, {
    Key? key, String? label, bool signed = false,
  }) {
    return SizedBox(
      key: key,
      height: 32,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: signed
            ? const TextInputType.numberWithOptions(signed: true)
            : TextInputType.number,
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

  Widget _miniButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade200,
          ),
          child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ),
      ),
    );
  }

  /// Returns all abilities sorted: pokemon's own abilities first, then the rest
  /// alphabetically by Korean name. Only includes abilities with Korean names.
  List<String> _sortedAbilities(BattlePokemonState state) {
    if (_abilityNameMap.isEmpty) return state.pokemonAbilities;
    final pokemon = state.pokemonAbilities
        .where((a) => _abilityNameMap.containsKey(a))
        .toList();
    final rest = _abilityNameMap.keys
        .where((a) => !state.pokemonAbilities.contains(a))
        .toList();
    rest.sort((a, b) => _abilityKo(a).compareTo(_abilityKo(b)));
    return [...pokemon, ...rest];
  }

  Widget _abilityAutocomplete(BattlePokemonState state) {
    final sorted = _sortedAbilities(state);
    final initialText = state.selectedAbility != null ? _abilityKo(state.selectedAbility!) : '';

    return KeyedSubtree(
      key: ValueKey('speed_ability_${state.selectedAbility}_${state.pokemonName}'),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: initialText),
        displayStringForOption: (a) => _abilityKo(a),
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty || textEditingValue.text == initialText) {
            return sorted;
          }
          final query = textEditingValue.text.toLowerCase();
          return sorted.where((a) {
            final ko = _abilityKo(a);
            return ko.contains(query) || a.toLowerCase().contains(query);
          });
        },
        onSelected: (v) { setState(() => state.selectedAbility = v); _notify(); },
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

  Widget _itemAutocomplete(BattlePokemonState state) {
    _cachedItemKeys ??= ['', ..._itemNameMap.keys];
    final allItems = state.selectedItem != null
        ? [state.selectedItem!, ..._cachedItemKeys!.where((k) => k != state.selectedItem)]
        : _cachedItemKeys!;
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
        onSelected: (v) { setState(() => state.selectedItem = v.isEmpty ? null : v); _notify(); },
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
}
