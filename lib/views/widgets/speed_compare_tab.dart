import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
import '../../utils/speed_calculator.dart';
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
  final Map<String, String> abilityNameMap;
  final Map<String, String> itemNameMap;

  const SpeedCompareTab({
    super.key,
    required this.attacker,
    required this.defender,
    required this.weather,
    required this.terrain,
    required this.room,
    required this.onChanged,
    required this.resetCounter,
    required this.abilityNameMap,
    required this.itemNameMap,
  });

  @override
  State<SpeedCompareTab> createState() => _SpeedCompareTabState();
}

class _SpeedCompareTabState extends State<SpeedCompareTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, String> get _abilityNameMap => widget.abilityNameMap;
  Map<String, String> get _itemNameMap => widget.itemNameMap;

  int _calcEffectiveSpeed(BattlePokemonState s) {
    return BattleFacade.calcSpeed(
      state: s,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
    );
  }

  bool _isAlwaysLast(BattlePokemonState s) => isAlwaysLast(s);

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
              Expanded(flex: 2, child: _SpeedNumInput(
                value: state.iv.speed,
                min: 0, max: 31,
                onChanged: (val) {
                  setState(() {
                    state.iv = Stats(hp: state.iv.hp, attack: state.iv.attack, defense: state.iv.defense,
                      spAttack: state.iv.spAttack, spDefense: state.iv.spDefense, speed: val);
                  });
                  _notify();
                },
              )),
              const SizedBox(width: 8),
              Text('노력 ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Expanded(flex: 3, child: _SpeedNumInput(
                value: state.ev.speed,
                min: 0, max: 252,
                onChanged: (val) {
                  setState(() {
                    state.ev = Stats(hp: state.ev.hp, attack: state.ev.attack, defense: state.ev.defense,
                      spAttack: state.ev.spAttack, spDefense: state.ev.spDefense, speed: val);
                  });
                  _notify();
                },
              )),
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
              Expanded(flex: 2, child: _SpeedNumInput(
                value: state.rank.speed,
                min: -6, max: 6,
                signed: true,
                onChanged: (val) {
                  setState(() {
                    state.rank = Rank(attack: state.rank.attack, defense: state.rank.defense,
                      spAttack: state.rank.spAttack, spDefense: state.rank.spDefense, speed: val);
                  });
                  _notify();
                },
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 56, child: _SpeedNumInput(
                value: state.level,
                min: 1, max: 100,
                label: '레벨',
                onChanged: (val) {
                  setState(() => state.level = val);
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
          if (!kIsWeb && textEditingValue.composing != TextRange.empty) return sorted;
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
    final allKeys = ['', ..._itemNameMap.keys];
    final allItems = state.selectedItem != null
        ? [state.selectedItem!, ...allKeys.where((k) => k != state.selectedItem)]
        : allKeys;
    final initialText = _itemKo(state.selectedItem);

    return KeyedSubtree(
      key: ValueKey('speed_item_${state.selectedItem}'),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: initialText),
        displayStringForOption: (key) => _itemKo(key.isEmpty ? null : key),
        optionsBuilder: (textEditingValue) {
          if (!kIsWeb && textEditingValue.composing != TextRange.empty) return allItems;
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

/// Numeric input that maintains its own controller so parent rebuilds
/// don't steal focus. External value changes (e.g. button press) update
/// the displayed text without recreating the widget.
class _SpeedNumInput extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final bool signed;
  final String? label;
  final ValueChanged<int> onChanged;

  const _SpeedNumInput({
    required this.value,
    required this.min,
    required this.max,
    this.signed = false,
    this.label,
    required this.onChanged,
  });

  @override
  State<_SpeedNumInput> createState() => _SpeedNumInputState();
}

class _SpeedNumInputState extends State<_SpeedNumInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_SpeedNumInput old) {
    super.didUpdateWidget(old);
    // Update text when value changes externally (button press, pokemon change)
    // but not while the user is typing (controller text would differ)
    final currentParsed = int.tryParse(_controller.text);
    if (currentParsed != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.label != null ? null : 32,
      child: TextFormField(
        controller: _controller,
        keyboardType: widget.signed
            ? const TextInputType.numberWithOptions(signed: true)
            : TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: widget.label,
          contentPadding: widget.label != null ? null : const EdgeInsets.symmetric(vertical: 6),
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) {
            widget.onChanged(parsed.clamp(widget.min, widget.max));
          } else if (text.isEmpty) {
            widget.onChanged(widget.min);
          }
        },
      ),
    );
  }
}
