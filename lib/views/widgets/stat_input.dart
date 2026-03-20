import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/nature.dart';
import '../../models/rank.dart';
import '../../models/stats.dart';
import '../../utils/stat_calculator.dart';

class StatInput extends StatefulWidget {
  final int level;
  final Nature nature;
  final Stats iv;
  final Stats ev;
  final Stats baseStats;
  final List<String> pokemonAbilities;
  final String? selectedAbility;
  final String? selectedItem;
  final Rank rank;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<Nature> onNatureChanged;
  final ValueChanged<Stats> onIvChanged;
  final ValueChanged<Stats> onEvChanged;
  final ValueChanged<String> onAbilityChanged;
  final ValueChanged<String?> onItemChanged;
  final ValueChanged<Rank> onRankChanged;

  const StatInput({
    super.key,
    required this.level,
    required this.nature,
    required this.iv,
    required this.ev,
    required this.baseStats,
    required this.pokemonAbilities,
    this.selectedAbility,
    this.selectedItem,
    required this.rank,
    required this.onLevelChanged,
    required this.onNatureChanged,
    required this.onIvChanged,
    required this.onEvChanged,
    required this.onAbilityChanged,
    required this.onItemChanged,
    required this.onRankChanged,
  });

  @override
  State<StatInput> createState() => _StatInputState();
}

class _StatInputState extends State<StatInput> {
  Map<String, String> _abilityNameMap = {};
  List<String> _cachedSortedAbilities = [];
  List<String> _lastPokemonAbilities = [];
  int _evResetCounter = 0;

  static final List<DropdownMenuItem<Nature>> _natureItems = Nature.values
      .map((n) => DropdownMenuItem(value: n, child: Text(_natureLabelStatic(n))))
      .toList();

  static String _natureLabelStatic(Nature n) {
    final ko = n.nameKo;
    String buff = '', nerf = '';
    if (n.attackModifier > 1.0) buff = '공격';
    if (n.defenseModifier > 1.0) buff = '방어';
    if (n.spAttackModifier > 1.0) buff = '특공';
    if (n.spDefenseModifier > 1.0) buff = '특방';
    if (n.speedModifier > 1.0) buff = '스피드';
    if (n.attackModifier < 1.0) nerf = '공격';
    if (n.defenseModifier < 1.0) nerf = '방어';
    if (n.spAttackModifier < 1.0) nerf = '특공';
    if (n.spDefenseModifier < 1.0) nerf = '특방';
    if (n.speedModifier < 1.0) nerf = '스피드';
    if (buff.isEmpty) return '$ko (무보정)';
    return '$ko (+$buff -$nerf)';
  }

  // Item name -> Korean name
  static const Map<String, String> _itemKoMap = {
    'Choice Band': '구애머리띠',
    'Choice Specs': '구애안경',
    'Life Orb': '생명의구슬',
    'Silk Scarf': '실크스카프',
    'Muscle Band': '힘의머리띠',
    'Wise Glasses': '박식안경',
  };

  @override
  void initState() {
    super.initState();
    _loadAbilities();
  }

  Future<void> _loadAbilities() async {
    try {
      final jsonString = await rootBundle.loadString('assets/abilities.json');
      final List<dynamic> list = json.decode(jsonString) as List<dynamic>;
      final map = <String, String>{};
      for (final entry in list) {
        map[entry['name'] as String] = entry['nameKo'] as String;
      }
      setState(() {
        _abilityNameMap = map;
        _rebuildSortedAbilities();
      });
    } catch (_) {}
  }

  String _abilityKo(String englishName) {
    return _abilityNameMap[englishName] ?? englishName;
  }

  void _rebuildSortedAbilities() {
    final all = _abilityNameMap.keys.toList();
    final pokemon = widget.pokemonAbilities;
    final rest = all.where((a) => !pokemon.contains(a)).toList();
    rest.sort((a, b) => _abilityKo(a).compareTo(_abilityKo(b)));
    _cachedSortedAbilities = [...pokemon, ...rest];
    _lastPokemonAbilities = List.of(pokemon);
  }

  List<String> _sortedAbilities() {
    if (!_listEquals(_lastPokemonAbilities, widget.pokemonAbilities)) {
      _rebuildSortedAbilities();
    }
    return _cachedSortedAbilities;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final actualStats = StatCalculator.calculate(
      baseStats: widget.baseStats,
      iv: widget.iv,
      ev: widget.ev,
      nature: widget.nature,
      level: widget.level,
      rank: widget.rank,
    );

    return Column(
      children: [
        // Level + Ability (searchable)
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: '${widget.level}',
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '레벨',
                  isDense: true,
                ),
                onChanged: (text) {
                  final parsed = int.tryParse(text);
                  if (parsed != null && parsed >= 1 && parsed <= 100) {
                    widget.onLevelChanged(parsed);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _abilityNameMap.isNotEmpty
                  ? KeyedSubtree(
                      key: ValueKey('ability_${widget.selectedAbility}'),
                      child: _abilityAutocomplete(),
                    )
                  : const InputDecorator(
                      decoration: InputDecoration(labelText: '특성', isDense: true),
                      child: Text('-', style: TextStyle(color: Colors.grey)),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Nature + Item (searchable)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<Nature>(
                value: widget.nature,
                decoration: const InputDecoration(labelText: '성격', isDense: true),
                items: _natureItems,
                onChanged: (v) => widget.onNatureChanged(v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _itemAutocomplete()),
          ],
        ),
        const SizedBox(height: 12),

        _statHeader(context),
        const Divider(height: 1),

        _statRow(context, 'HP', widget.baseStats.hp, widget.iv.hp, widget.ev.hp,
            actualStats.hp, null, 0, (newIv, newEv, _) {
          widget.onIvChanged(_copyIv(hpVal: newIv));
          widget.onEvChanged(_copyEv(hpVal: newEv));
        }, rankIndex: -1),
        _statRow(context, '공격', widget.baseStats.attack, widget.iv.attack,
            widget.ev.attack, actualStats.attack, widget.nature.attackModifier,
            widget.rank.attack, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(atkVal: newIv));
          widget.onEvChanged(_copyEv(atkVal: newEv));
          if (newRank != null) _updateRank(atkVal: newRank);
        }, rankIndex: 0),
        _statRow(context, '방어', widget.baseStats.defense, widget.iv.defense,
            widget.ev.defense, actualStats.defense, widget.nature.defenseModifier,
            widget.rank.defense, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(defVal: newIv));
          widget.onEvChanged(_copyEv(defVal: newEv));
          if (newRank != null) _updateRank(defVal: newRank);
        }, rankIndex: 1),
        _statRow(context, '특공', widget.baseStats.spAttack, widget.iv.spAttack,
            widget.ev.spAttack, actualStats.spAttack, widget.nature.spAttackModifier,
            widget.rank.spAttack, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(spaVal: newIv));
          widget.onEvChanged(_copyEv(spaVal: newEv));
          if (newRank != null) _updateRank(spaVal: newRank);
        }, rankIndex: 2),
        _statRow(context, '특방', widget.baseStats.spDefense, widget.iv.spDefense,
            widget.ev.spDefense, actualStats.spDefense, widget.nature.spDefenseModifier,
            widget.rank.spDefense, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(spdVal: newIv));
          widget.onEvChanged(_copyEv(spdVal: newEv));
          if (newRank != null) _updateRank(spdVal: newRank);
        }, rankIndex: 3),
        _statRow(context, '스피드', widget.baseStats.speed, widget.iv.speed,
            widget.ev.speed, actualStats.speed, widget.nature.speedModifier,
            widget.rank.speed, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(speVal: newIv));
          widget.onEvChanged(_copyEv(speVal: newEv));
          if (newRank != null) _updateRank(speVal: newRank);
        }, rankIndex: 4),
      ],
    );
  }

  Widget _abilityAutocomplete() {
    final sorted = _sortedAbilities();
    final initialText = widget.selectedAbility != null
        ? _abilityKo(widget.selectedAbility!)
        : '';

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialText),
      displayStringForOption: (a) => _abilityKo(a),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty ||
            textEditingValue.text == initialText) {
          return sorted;
        }
        final query = textEditingValue.text.toLowerCase();
        return sorted.where((a) =>
            _abilityKo(a).contains(query) ||
            a.toLowerCase().contains(query));
      },
      onSelected: (v) => widget.onAbilityChanged(v),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '특성',
            isDense: true,
          ),
          onTap: () => controller.clear(),
        );
      },
    );
  }

  String _itemDisplayName(String? key) {
    if (key == null || key.isEmpty) return '없음';
    return _itemKoMap[key] ?? key;
  }

  Widget _itemAutocomplete() {
    final allItems = ['', ..._itemKoMap.keys];
    if (widget.selectedItem != null && allItems.contains(widget.selectedItem)) {
      allItems.remove(widget.selectedItem);
      allItems.insert(0, widget.selectedItem!);
    }

    final initialText = _itemDisplayName(widget.selectedItem);

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialText),
      displayStringForOption: (key) => _itemDisplayName(key.isEmpty ? null : key),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty ||
            textEditingValue.text == initialText) {
          return allItems;
        }
        final query = textEditingValue.text.toLowerCase();
        return allItems.where((key) {
          final ko = _itemDisplayName(key.isEmpty ? null : key);
          return ko.contains(query) || key.toLowerCase().contains(query);
        });
      },
      onSelected: (v) => widget.onItemChanged(v.isEmpty ? null : v),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '아이템',
            isDense: true,
          ),
          onTap: () => controller.clear(),
        );
      },
    );
  }

  void _updateRank({int? atkVal, int? defVal, int? spaVal, int? spdVal, int? speVal}) {
    widget.onRankChanged(Rank(
      attack: atkVal ?? widget.rank.attack,
      defense: defVal ?? widget.rank.defense,
      spAttack: spaVal ?? widget.rank.spAttack,
      spDefense: spdVal ?? widget.rank.spDefense,
      speed: speVal ?? widget.rank.speed,
    ));
  }

  Widget _statHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text('', style: style)),
          SizedBox(width: 40, child: Text('종족값', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 44, child: Text('개체값', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('노력치', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('랭크', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 44, child: Text('실수치', style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _statRow(
    BuildContext context, String label, int base, int ivVal, int evVal,
    int actual, double? natureModifier, int rankVal,
    void Function(int newIv, int newEv, int? newRank) onChanged, {
    required int rankIndex,
  }) {
    Color? actualColor;
    if (natureModifier != null && natureModifier > 1.0) actualColor = Colors.red;
    if (natureModifier != null && natureModifier < 1.0) actualColor = Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(label, style: const TextStyle(fontSize: 15))),
          SizedBox(width: 40, child: Text('$base', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))),
          SizedBox(width: 44, child: _miniInput(ivVal, 0, 31, (v) => onChanged(v, evVal, null))),
          Expanded(
            flex: 3,
            child: _evControl(evVal, (v) => onChanged(ivVal, v, null)),
          ),
          Expanded(
            flex: 2,
            child: rankIndex >= 0
                ? _rankControl(rankVal, (v) => onChanged(ivVal, evVal, v))
                : const SizedBox(),
          ),
          SizedBox(
            width: 44,
            child: Text('$actual', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: actualColor)),
          ),
        ],
      ),
    );
  }

  Widget _evControl(int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _smallButton('0', () {
          setState(() => _evResetCounter++);
          onChanged(0);
        }),
        SizedBox(
          width: 36,
          height: 32,
          child: TextFormField(
            key: ValueKey('ev_$_evResetCounter'),
            initialValue: '$value',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            ),
            onChanged: (text) {
              final parsed = int.tryParse(text);
              if (parsed != null && parsed >= 0 && parsed <= 252) {
                onChanged(parsed);
              }
            },
          ),
        ),
        _smallButton('max', () {
          setState(() => _evResetCounter++);
          onChanged(252);
        }),
      ],
    );
  }

  Widget _rankControl(int value, ValueChanged<int> onChanged) {
    final displayText = value >= 0 ? '+$value' : '$value';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _smallButton('-', value > -6 ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 28,
          child: Text(displayText, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: value > 0 ? Colors.red : value < 0 ? Colors.blue : null)),
        ),
        _smallButton('+', value < 6 ? () => onChanged(value + 1) : null),
      ],
    );
  }

  Widget _smallButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: text.length > 1 ? 32 : 26,
      height: 26,
      child: IconButton(
        onPressed: onPressed,
        icon: Text(text, style: const TextStyle(fontSize: 11)),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          side: const BorderSide(width: 0.5, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _miniInput(int value, int min, int max, ValueChanged<int> onChanged) {
    return SizedBox(
      height: 32,
      child: TextFormField(
        initialValue: '$value',
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null && parsed >= min && parsed <= max) {
            onChanged(parsed);
          }
        },
      ),
    );
  }

  Stats _copyIv({int? hpVal, int? atkVal, int? defVal, int? spaVal, int? spdVal, int? speVal}) {
    return Stats(hp: hpVal ?? widget.iv.hp, attack: atkVal ?? widget.iv.attack,
      defense: defVal ?? widget.iv.defense, spAttack: spaVal ?? widget.iv.spAttack,
      spDefense: spdVal ?? widget.iv.spDefense, speed: speVal ?? widget.iv.speed);
  }

  Stats _copyEv({int? hpVal, int? atkVal, int? defVal, int? spaVal, int? spdVal, int? speVal}) {
    return Stats(hp: hpVal ?? widget.ev.hp, attack: atkVal ?? widget.ev.attack,
      defense: defVal ?? widget.ev.defense, spAttack: spaVal ?? widget.ev.spAttack,
      spDefense: spdVal ?? widget.ev.spDefense, speed: speVal ?? widget.ev.speed);
  }

}
